from __future__ import annotations
import logging
from pathlib import Path
import json
import httpx
import os
from playwright.async_api import async_playwright

log = logging.getLogger("nobs-agent.seo")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:14b")

PAGES = [
    ("https://nobsdash.com",            "home"),
    ("https://nobsdash.com/agency/",    "agency"),
    ("https://nobsdash.com/research/",  "research"),
]

class SeoProposal:
    def __init__(self, approval_api: str) -> None:
        self.approval_api = approval_api

    async def run(self) -> None:
        try:
            async with async_playwright() as pw:
                browser = await pw.chromium.launch(headless=True)
                ctx = await browser.new_context()
                
                for url, name in PAGES:
                    log.info(f"SEO Team: Auditing {name} page at {url}")
                    page = await ctx.new_page()
                    try:
                        await page.goto(url, wait_until="domcontentloaded", timeout=20000)
                        
                        # 1. Audit HTML page directly using Playwright evaluation
                        audit_results = await page.evaluate("""() => {
                            const title = document.title;
                            const descriptionMeta = document.querySelector('meta[name="description"]');
                            const description = descriptionMeta ? descriptionMeta.getAttribute('content') : '';
                            const h1s = Array.from(document.querySelectorAll('h1')).map(h => h.innerText);
                            const images = Array.from(document.querySelectorAll('img'));
                            const imagesWithoutAlt = images.filter(img => !img.getAttribute('alt')).map(img => img.src);
                            
                            return {
                                title,
                                description,
                                h1Count: h1s.length,
                                h1s,
                                totalImages: images.length,
                                imagesWithoutAltCount: imagesWithoutAlt.length,
                                imagesWithoutAlt: imagesWithoutAlt.slice(0, 5)
                            };
                        }""")
                        
                        # 2. Get load performance times
                        perf_timing = await page.evaluate("() => JSON.stringify(window.performance.timing)")
                        perf_data = json.loads(perf_timing)
                        load_time_ms = perf_data.get("loadEventEnd", 0) - perf_data.get("navigationStart", 0)
                        audit_results["loadTimeMs"] = load_time_ms
                        
                        # 3. Analyze and propose fixes using Qwen
                        proposals = await self._analyze(url, audit_results)
                        log.info(f"SEO Team: Got {len(proposals)} proposals for {name}")
                        
                        for p in proposals[:2]:
                            title = p.get("title", "SEO Improvement")
                            mission = p.get("mission", "")
                            
                            proposal = {
                                "category": "seo",
                                "title": f"SEO Team ({name}): {title}",
                                "summary": mission,
                                "payload": {
                                    "action": "apply_code_improvement",
                                    "file_path": f"/var/www/nobsdash/{name}/index.html" if name != "home" else "/var/www/nobsdash/index.html",
                                    "mission": mission,
                                }
                            }
                            await self._submit(proposal)
                    except Exception as e:
                        log.warning(f"Failed to audit {name}: {e}")
                    finally:
                        await page.close()
                await ctx.close()
                await browser.close()
        except Exception as e:
            log.warning(f"SEO Team run failed: {e}")

    async def _analyze(self, url: str, audit: dict) -> list[dict]:
        prompt = (
            f"You are a senior SEO and Web Performance Auditor reviewing {url}.\n"
            f"Here are the audited metrics for the page:\n"
            f"  Page Load Time: {audit['loadTimeMs']}ms\n"
            f"  Title: '{audit['title']}'\n"
            f"  Meta Description: '{audit['description']}'\n"
            f"  H1 Tags count: {audit['h1Count']} (values: {audit['h1s']})\n"
            f"  Total Images: {audit['totalImages']} (Images missing alt: {audit['imagesWithoutAltCount']})\n\n"
            f"Propose 2-3 specific improvements to optimize the page's SEO, accessibility, and speed. Focus on structural HTML fixes.\n"
            f"Output ONLY a JSON array of proposals. Each item:\n"
            f'{{"title":"<short>", "mission":"<specific change with file:selector + reason>"}}\n'
            f"JSON only."
        )
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{OLLAMA_URL}/api/generate",
                    json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False, "format": "json"},
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
            log.warning(f"SEO Qwen structure failed: {e}")
        return []

    async def _submit(self, proposal: dict) -> None:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{self.approval_api}/queue", timeout=5)
                if resp.status_code == 200:
                    for task in resp.json():
                        if task["title"] == proposal["title"] and task["status"] in ("pending", "approved", "completed"):
                            log.info(f"Skipping duplicate SEO proposal: {proposal['title']}")
                            return
        except Exception as e:
            log.warning(f"Failed to check duplicate SEO proposal: {e}")

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(f"{self.approval_api}/propose", json=proposal, timeout=10)
                resp.raise_for_status()
                log.info(f"Submitted SEO proposal: {proposal['title']}")
        except Exception as e:
            log.warning(f"Failed to submit SEO proposal: {e}")
