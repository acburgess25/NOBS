from __future__ import annotations
import logging
from pathlib import Path
import json
import httpx
import os
import base64
from playwright.async_api import async_playwright

log = logging.getLogger("nobs-agent.visual")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:14b")

PAGES = [
    ("https://nobsdash.com",            "home"),
    ("https://nobsdash.com/agency/",    "agency"),
    ("https://nobsdash.com/research/",  "research"),
]

class VisualProposal:
    def __init__(self, approval_api: str) -> None:
        self.approval_api = approval_api

    async def run(self) -> None:
        try:
            async with async_playwright() as pw:
                browser = await pw.chromium.launch(headless=True)
                ctx = await browser.new_context(viewport={"width": 1440, "height": 900})
                
                for url, name in PAGES:
                    log.info(f"Visual Team: Screenshotting {name} page at {url}")
                    page = await ctx.new_page()
                    try:
                        await page.goto(url, wait_until="domcontentloaded", timeout=20000)
                        await page.wait_for_timeout(3000) # wait for animations
                        screenshot_bytes = await page.screenshot(type="png")
                        
                        # Analyze using LLaVA + Qwen
                        proposals = await self._analyze(screenshot_bytes, name)
                        log.info(f"Visual Team: Got {len(proposals)} proposals for {name}")
                        
                        for p in proposals[:2]:
                            title = p.get("title", "Visual Adjustment")
                            mission = p.get("mission", "")
                            
                            proposal = {
                                "category": "design",
                                "title": f"Visual Team ({name}): {title}",
                                "summary": mission,
                                "payload": {
                                    "action": "apply_code_improvement",
                                    "file_path": f"/var/www/nobsdash/{name}/index.html" if name != "home" else "/var/www/nobsdash/index.html",
                                    "mission": mission,
                                }
                            }
                            await self._submit(proposal)
                    except Exception as e:
                        log.warning(f"Failed to screenshot/analyze {name}: {e}")
                    finally:
                        await page.close()
                await ctx.close()
                await browser.close()
        except Exception as e:
            log.warning(f"Visual Team run failed: {e}")

    async def _analyze(self, screenshot_bytes: bytes, page_name: str) -> list[dict]:
        # 1. Describe screenshot using LLaVA
        img_b64 = base64.b64encode(screenshot_bytes).decode()
        desc_prompt = (
            f"Describe this screenshot of the {page_name} page of an AI brand website. "
            "List concrete visual observations: dominant colors, typography style, layout structure, "
            "spacing density, inconsistencies, weak hierarchy, alignment problems, dated elements, "
            "or anything unprofessional. Be specific. 3-5 bullet points."
        )
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{OLLAMA_URL}/api/generate",
                    json={"model": "llava:13b", "prompt": desc_prompt, "images": [img_b64], "stream": False},
                    timeout=180
                )
                description = resp.json().get("response", "").strip()
        except Exception as e:
            log.warning(f"LLaVA description failed: {e}")
            return []

        if not description:
            return []

        # 2. Structure description using Qwen
        qwen_prompt = (
            f"A reviewer described visual issues on the NOBS website {page_name} page:\n\n"
            f"{description}\n\n"
            "Convert these observations into 2-3 concrete design proposals for the static HTML/CSS site. "
            "Output ONLY a JSON array. Each item:\n"
            '{"title":"<short>", "mission":"<specific change with file:selector + reason>"}'
        )
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{OLLAMA_URL}/api/generate",
                    json={"model": OLLAMA_MODEL, "prompt": qwen_prompt, "stream": False, "format": "json"},
                    timeout=90
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
                if isinstance(proposals, list):
                    return proposals
        except Exception as e:
            log.warning(f"Qwen structure failed: {e}")
        return []

    async def _submit(self, proposal: dict) -> None:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.approval_api}/queue", timeout=5)
                if resp.status_code == 200:
                    for task in resp.json():
                        if task["title"] == proposal["title"] and task["status"] in ("pending", "approved", "completed"):
                            log.info(f"Skipping duplicate visual proposal: {proposal['title']}")
                            return
        except Exception as e:
            log.warning(f"Failed to check duplicate visual proposal: {e}")

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(f"{self.approval_api}/propose", json=proposal, timeout=10)
                resp.raise_for_status()
                log.info(f"Submitted visual proposal: {proposal['title']}")
        except Exception as e:
            log.warning(f"Failed to submit visual proposal: {e}")
