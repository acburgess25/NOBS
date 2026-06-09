"""
Task executor — runs approved tasks fetched from the approval API queue.

Each task has an 'action' in its payload that determines what gets run.
Execution is conservative in v1: log, pull, or draft — never auto-post.
"""

from __future__ import annotations

import logging
import os
import subprocess

import httpx

log = logging.getLogger("nobs-agent.executor")

APPROVAL_API   = os.getenv("APPROVAL_API_URL",   "http://approval-api:5051")
OLLAMA_URL     = os.getenv("OLLAMA_URL",          "http://host.docker.internal:11434")
OLLAMA_MODEL   = os.getenv("OLLAMA_MODEL",        "qwen2.5-coder:14b")
COMPOSE_FILE   = os.getenv("HOMELAB_COMPOSE_FILE", "/opt/homelab/docker-compose.yml")


async def execute_approved_tasks(task: dict, approval_api: str) -> None:
    action = task.get("payload", {}).get("action", "unknown")

    try:
        if action == "docker_pull_all":
            await _docker_pull_all(task)
        elif action == "ollama_pull":
            await _ollama_pull(task)
        elif action == "career_job_found":
            await _career_draft_outreach(task)
        elif action == "apply_code_improvement":
            await _apply_code_improvement(task)
        else:
            log.warning(f"Unknown action: {action}")

        # Mark task as completed
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{approval_api}/complete?task_id={task['id']}",
                timeout=5,
            )

    except Exception as e:
        log.error(f"Executor failed for task {task['id']}: {e}")


# ---------------------------------------------------------------------------
# Action handlers
# ---------------------------------------------------------------------------

async def _docker_pull_all(task: dict) -> None:
    """Pull latest images and recreate containers."""
    containers = task["payload"].get("containers", [])
    log.info(f"Pulling Docker images for: {containers}")
    
    # 1. Pull latest images
    result_pull = subprocess.run(
        ["docker", "compose", "-f", COMPOSE_FILE, "pull"],
        capture_output=True, text=True
    )
    log.info(result_pull.stdout)
    if result_pull.returncode != 0:
        log.error(result_pull.stderr)
        
    # 2. Recreate containers with new images
    log.info("Recreating updated containers...")
    result_up = subprocess.run(
        ["docker", "compose", "-f", COMPOSE_FILE, "up", "-d"],
        capture_output=True, text=True
    )
    log.info(result_up.stdout)
    if result_up.returncode != 0:
        log.error(result_up.stderr)


async def _ollama_pull(task: dict) -> None:
    """Pull a new Ollama model."""
    model = task["payload"].get("model")
    log.info(f"Pulling Ollama model: {model}")
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{OLLAMA_URL}/api/pull",
            json={"name": model},
            timeout=600,  # models are large
        )
        log.info(f"Ollama pull response: {resp.status_code}")


async def _career_draft_outreach(task: dict) -> None:
    """
    Draft a personalized LinkedIn outreach message using Ollama.
    Sends the draft back as a NEW proposal (so you can approve the message itself).
    """
    payload = task["payload"]
    job_title = payload.get("job_title", "")
    company   = payload.get("company", "")
    job_url   = payload.get("job_url", "")

    prompt = (
        f"Write a short, genuine LinkedIn connection request message (under 300 chars) "
        f"from a sophomore Information Systems student at University of Arkansas "
        f"who wants to apply for: {job_title} at {company}.\n"
        f"Job URL: {job_url}\n"
        f"Be direct, mention their homelab/AI infrastructure experience, and ask to connect. "
        f"No fluff. Sound human, not like a template."
    )

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": OLLAMA_MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "stream": False,
                },
                timeout=60,
            )
            draft = resp.json().get("message", {}).get("content", "").strip()

        # Submit the draft as a NEW proposal for your approval before sending
        async with httpx.AsyncClient() as client:
            await client.post(
                f"{APPROVAL_API}/propose",
                json={
                    "category": "career",
                    "title": f"Send outreach to {company}?",
                    "summary": f"Draft message:\n\n{draft}\n\nJob: {job_url}",
                    "payload": {
                        "action": "career_send_outreach",
                        "message": draft,
                        "job_url": job_url,
                        "company": company,
                    },
                },
                timeout=10,
            )
        log.info(f"Drafted outreach for {company}, sent for approval")

    except Exception as e:
        log.error(f"Draft outreach failed: {e}")


async def _apply_code_improvement(task: dict) -> None:
    """
    Applies an approved code improvement using Ollama to rewrite the file.
    """
    payload = task.get("payload", {})
    file_path = payload.get("file_path")
    mission = payload.get("mission")

    if not file_path or not mission:
        log.error("Missing file_path or mission in apply_code_improvement payload")
        return

    log.info(f"Applying code improvement to {file_path}")
    
    if not os.path.exists(file_path):
        log.error(f"File to improve does not exist inside container: {file_path}")
        return

    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as f:
            current_content = f.read()
    except Exception as e:
        log.error(f"Failed to read file {file_path}: {e}")
        return

    prompt = (
        f"You are an expert web developer and UI designer.\n"
        f"We need to apply an approved improvement to a website file.\n\n"
        f"FILE TO MODIFY: {file_path}\n"
        f"CHANGE MISSION:\n{mission}\n\n"
        f"CURRENT FILE CONTENT:\n{current_content}\n\n"
        f"Apply the CHANGE MISSION precisely to the CURRENT FILE CONTENT. "
        f"Return the ENTIRE updated file content. Do NOT explain, do NOT add conversational comments, and do NOT wrap the code in markdown code blocks. "
        f"Your entire response will be written directly to the file. Make sure your response starts with the start of the code and ends with the end of the code."
    )

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{OLLAMA_URL}/api/generate",
                json={
                    "model": OLLAMA_MODEL,
                    "prompt": prompt,
                    "stream": False,
                },
                timeout=120,
            )
            resp.raise_for_status()
            updated_code = resp.json().get("response", "").strip()

        # Strip markdown fences if present
        if updated_code.startswith("```"):
            lines = updated_code.splitlines()
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            updated_code = "\n".join(lines)

        if not updated_code:
            log.error("Ollama returned empty response for code improvement")
            return

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_code)
            
        log.info(f"Successfully applied code improvement to {file_path}")

    except Exception as e:
        log.error(f"Failed to apply code improvement to {file_path}: {e}")
