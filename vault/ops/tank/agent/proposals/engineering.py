from __future__ import annotations
import logging
from pathlib import Path
import json
import httpx
import os

log = logging.getLogger("nobs-agent.engineering")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:14b")
WEBSITE_DIR = Path("/var/www/nobsdash")

class EngineeringProposal:
    def __init__(self, approval_api: str) -> None:
        self.approval_api = approval_api

    async def run(self) -> None:
        if not WEBSITE_DIR.exists():
            log.warning(f"Website dir {WEBSITE_DIR} does not exist inside agent container")
            return
            
        samples = []
        for ext in ("*.html", "*.js", "*.css"):
            for f in WEBSITE_DIR.rglob(ext):
                if f.stat().st_size > 100000:
                    continue
                try:
                    content = f.read_text(errors="replace")[:3000]
                    rel = f.relative_to(WEBSITE_DIR)
                    samples.append(f"### {rel}\n```\n{content}\n```\n")
                except Exception:
                    continue
                if len(samples) >= 6:
                    break
            if len(samples) >= 6:
                break
        
        sample = "\n".join(samples)
        if not sample:
            log.info("No website files found to audit for engineering")
            return

        prompt = (
            f"You are a senior systems engineer reviewing the website codebase.\n"
            f"Identify security bugs, rendering errors, performance issues, and code smells, and propose actionable fixes.\n\n"
            f"CODE SAMPLE:\n{sample}\n\n"
            f"Output ONLY a JSON array, max 3 proposals. Each item must contain title, mission, and the absolute file path:\n"
            '[{"title": "Short imperative title", "mission": "Specific technical change instructions with reasoning", "file_path": "/var/www/nobsdash/filename"}]\n'
            f"Output JSON only."
        )

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{OLLAMA_URL}/api/generate",
                    json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False, "format": "json"},
                    timeout=120
                )
                raw = resp.json().get("response", "").strip()
                proposals = json.loads(raw)
                if isinstance(proposals, dict):
                    for k in ("proposals", "items", "fixes"):
                        if k in proposals:
                            proposals = proposals[k]
                            break
                if isinstance(proposals, dict):
                    proposals = [proposals]
        except Exception as e:
            log.warning(f"Ollama engineering analysis failed: {e}")
            return

        if not isinstance(proposals, list):
            log.warning(f"Ollama engineering response was not a list: {raw}")
            return

        for p in proposals[:3]:
            title = p.get("title", "Code Improvement")
            mission = p.get("mission", "")
            file_path = p.get("file_path") or "/var/www/nobsdash/index.html"
            
            proposal = {
                "category": "engineering",
                "title": f"Coding Team: {title}",
                "summary": mission,
                "payload": {
                    "action": "apply_code_improvement",
                    "file_path": file_path,
                    "mission": mission,
                }
            }
            await self._submit(proposal)

    async def _submit(self, proposal: dict) -> None:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.approval_api}/queue", timeout=5)
                if resp.status_code == 200:
                    for task in resp.json():
                        if task["title"] == proposal["title"] and task["status"] in ("pending", "approved", "completed"):
                            log.info(f"Skipping duplicate engineering proposal: {proposal['title']}")
                            return
        except Exception as e:
            log.warning(f"Failed to check duplicate engineering proposal: {e}")

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(f"{self.approval_api}/propose", json=proposal, timeout=10)
                resp.raise_for_status()
                log.info(f"Submitted engineering proposal: {proposal['title']}")
        except Exception as e:
            log.warning(f"Failed to submit engineering proposal: {e}")
