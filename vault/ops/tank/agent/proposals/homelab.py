"""
Homelab proposal generator.

Checks for:
  - Docker images with newer versions available
  - New Ollama models worth pulling
  - System health issues worth flagging
"""

from __future__ import annotations

import logging
import os

import httpx

log = logging.getLogger("nobs-agent.homelab")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")
DOCKER_SOCK = "/var/run/docker.sock"


class HomelabProposal:
    def __init__(self, approval_api: str) -> None:
        self.approval_api = approval_api

    async def run(self) -> None:
        proposals = []
        proposals += await self._check_docker_updates()
        proposals += await self._check_ollama_models()

        for proposal in proposals:
            await self._submit(proposal)

    async def _get_remote_digest(self, image: str) -> str | None:
        try:
            if image.startswith("ghcr.io/"):
                parts = image[8:].split(":")
                repo = parts[0]
                tag = parts[1] if len(parts) > 1 else "latest"
                token_url = f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repo}:pull"
                async with httpx.AsyncClient() as client:
                    r = await client.get(token_url, timeout=5)
                    token = r.json().get("token")
                    url = f"https://ghcr.io/v2/{repo}/manifests/{tag}"
                    headers = {
                        "Authorization": f"Bearer {token}",
                        "Accept": "application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json"
                    }
                    r = await client.head(url, headers=headers, timeout=5)
                    if r.status_code != 200:
                        r = await client.get(url, headers=headers, timeout=5)
                    return r.headers.get("Docker-Content-Digest")
            else:
                # Docker Hub
                parts = image.split(":")
                repo = parts[0]
                if "/" not in repo:
                    repo = f"library/{repo}"
                tag = parts[1] if len(parts) > 1 else "latest"
                token_url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull"
                async with httpx.AsyncClient() as client:
                    r = await client.get(token_url, timeout=5)
                    token = r.json().get("token")
                    url = f"https://registry-1.docker.io/v2/{repo}/manifests/{tag}"
                    headers = {
                        "Authorization": f"Bearer {token}",
                        "Accept": "application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json"
                    }
                    r = await client.head(url, headers=headers, timeout=5)
                    if r.status_code != 200:
                        r = await client.get(url, headers=headers, timeout=5)
                    return r.headers.get("Docker-Content-Digest")
        except Exception as e:
            log.warning(f"Failed to fetch remote digest for {image}: {e}")
            return None

    # ------------------------------------------------------------------
    # Docker update checker
    # ------------------------------------------------------------------
    async def _check_docker_updates(self) -> list[dict]:
        """Pull digest comparison to detect stale images."""
        results = []
        try:
            async with httpx.AsyncClient(transport=httpx.AsyncHTTPTransport(
                uds=DOCKER_SOCK
            )) as client:
                containers_resp = await client.get("http://localhost/containers/json")
                containers = containers_resp.json()

            stale = []
            for c in containers:
                name = c["Names"][0].lstrip("/")
                c_id = c["Id"]

                # Fetch config image name
                async with httpx.AsyncClient(transport=httpx.AsyncHTTPTransport(
                    uds=DOCKER_SOCK
                )) as client:
                    detail_resp = await client.get(f"http://localhost/containers/{c_id}/json")
                    config_image = detail_resp.json().get("Config", {}).get("Image", "")

                # Skip local image builds
                if config_image.startswith("homelab-") or "approval-api" in config_image or "agent" in config_image:
                    continue

                remote_digest = await self._get_remote_digest(config_image)
                if not remote_digest:
                    continue

                # Inspect local image for this tag
                try:
                    async with httpx.AsyncClient(transport=httpx.AsyncHTTPTransport(
                        uds=DOCKER_SOCK
                    )) as client:
                        img_resp = await client.get(f"http://localhost/images/{config_image}/json")
                        img_data = img_resp.json()
                        local_image_id = img_data.get("Id", "")
                        repo_digests = img_data.get("RepoDigests", []) or []
                except Exception:
                    local_image_id = ""
                    repo_digests = []

                running_image_id = c["ImageID"]

                has_matching_digest = any(remote_digest in rd for rd in repo_digests)
                is_running_latest_id = (running_image_id == local_image_id)

                if not (has_matching_digest and is_running_latest_id):
                    stale.append(f"• {name} ({config_image})")

            if stale:
                results.append({
                    "category": "homelab",
                    "title": "Docker containers may have updates",
                    "summary": (
                        f"Found {len(stale)} containers with updates available. "
                        f"Pull latest images and recreate containers?\n" +
                        "\n".join(stale)
                    ),
                    "payload": {
                        "action": "docker_pull_all",
                        "containers": [s.split(" ")[1] for s in stale],
                    },
                })
        except Exception as e:
            log.warning(f"Docker check failed: {e}")

        return results

    # ------------------------------------------------------------------
    # Ollama model discovery
    # ------------------------------------------------------------------
    async def _check_ollama_models(self) -> list[dict]:
        """Suggest new models from Ollama library based on your use case."""
        results = []
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{OLLAMA_URL}/api/tags", timeout=5)
                local_models = {m["name"] for m in resp.json().get("models", [])}
                local_base_names = {m.split(":")[0] for m in local_models}

            # Curated suggestions relevant to your profile (updated manually)
            suggestions = [
                {
                    "name": "deepseek-r1:14b",
                    "reason": "Strong reasoning model, great for coding problems and LeetCode prep",
                },
                {
                    "name": "mistral-small3.1:24b",
                    "reason": "Balanced speed/quality for general tasks",
                },
                {
                    "name": "nomic-embed-text",
                    "reason": "Embedding model — enables semantic search over your Obsidian vault",
                },
            ]

            new_models = [
                s for s in suggestions
                if s["name"] not in local_models and s["name"].split(":")[0] not in local_base_names
            ]

            for model in new_models[:2]:  # max 2 suggestions per run
                results.append({
                    "category": "homelab",
                    "title": f"New Ollama model available: {model['name']}",
                    "summary": model["reason"],
                    "payload": {
                        "action": "ollama_pull",
                        "model": model["name"],
                    },
                })

        except Exception as e:
            log.warning(f"Ollama check failed: {e}")

        return results

    # ------------------------------------------------------------------
    # Submit
    # ------------------------------------------------------------------
    async def _submit(self, proposal: dict) -> None:
        # Avoid duplicate submissions for pending, approved, or completed tasks
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.approval_api}/queue", timeout=5)
                if resp.status_code == 200:
                    existing_tasks = resp.json()
                    for task in existing_tasks:
                        if task["title"] == proposal["title"] and task["status"] in ("pending", "approved", "completed"):
                            log.info(f"Skipping duplicate homelab proposal: {proposal['title']}")
                            return
        except Exception as e:
            log.warning(f"Failed to check for duplicate homelab proposals: {e}")

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.approval_api}/propose",
                json=proposal,
                timeout=10,
            )
            resp.raise_for_status()
            log.info(f"Submitted homelab proposal: {proposal['title']}")
