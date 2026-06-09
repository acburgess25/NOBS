"""
Career proposal generator.

Uses Playwright to browse LinkedIn job postings matching your target role
(Apple internships, IS-related tech roles) and generates tailored proposals
using Ollama, sent to your iPhone for approval before any action is taken.
"""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path

import httpx

log = logging.getLogger("nobs-agent.career")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:14b")
SESSION_DIR = Path("/sessions/linkedin")

# Job searches to run
JOB_SEARCHES = [
    {
        "keywords": "Apple internship information systems",
        "location": "United States",
        "remote": False,
    },
    {
        "keywords": "IT infrastructure intern summer 2026",
        "location": "United States",
        "remote": True,
    },
    {
        "keywords": "DevOps cloud intern 2026",
        "location": "United States",
        "remote": True,
    },
]

# Already-seen job IDs (avoid duplicate proposals)
SEEN_FILE = Path("/data/seen_jobs.json")


class CareerProposal:
    def __init__(self, approval_api: str) -> None:
        self.approval_api = approval_api
        self._seen: set[str] = self._load_seen()

    def _load_seen(self) -> set[str]:
        if SEEN_FILE.exists():
            return set(json.loads(SEEN_FILE.read_text()))
        return set()

    def _save_seen(self) -> None:
        SEEN_FILE.parent.mkdir(parents=True, exist_ok=True)
        SEEN_FILE.write_text(json.dumps(list(self._seen)))

    async def run(self) -> None:
        jobs = await self._scrape_linkedin_jobs()
        log.info(f"Found {len(jobs)} new jobs")

        for job in jobs[:3]:  # max 3 proposals per run
            summary = await self._generate_summary(job)
            await self._submit({
                "category": "career",
                "title": f"Job Match: {job['title']} @ {job['company']}",
                "summary": summary,
                "payload": {
                    "action": "career_job_found",
                    "job_id": job["id"],
                    "job_url": job["url"],
                    "job_title": job["title"],
                    "company": job["company"],
                    "location": job["location"],
                },
            })
            self._seen.add(job["id"])

        self._save_seen()

    # ------------------------------------------------------------------
    # LinkedIn scraper via Playwright
    # ------------------------------------------------------------------
    async def _scrape_linkedin_jobs(self) -> list[dict]:
        """
        Uses Playwright to search LinkedIn jobs.
        Falls back to LinkedIn's public jobs feed if no session is available.
        """
        jobs = []
        try:
            from playwright.async_api import async_playwright

            async with async_playwright() as pw:
                browser = await pw.chromium.launch(headless=True)

                # Use saved session if available, else use guest mode
                ctx_args: dict = {}
                if SESSION_DIR.exists():
                    ctx_args["storage_state"] = str(SESSION_DIR / "state.json")

                ctx = await browser.new_context(**ctx_args)
                page = await ctx.new_page()

                for search in JOB_SEARCHES:
                    kw = search["keywords"].replace(" ", "%20")
                    url = (
                        f"https://www.linkedin.com/jobs/search/"
                        f"?keywords={kw}&f_TPR=r604800"  # past week
                    )
                    if search.get("remote"):
                        url += "&f_WT=2"

                    await page.goto(url, wait_until="domcontentloaded", timeout=30_000)
                    await page.wait_for_timeout(3000)

                    job_cards = await page.query_selector_all(
                        ".jobs-search__results-list li, .job-search-card"
                    )

                    for card in job_cards[:25]:
                        try:
                            title_el = await card.query_selector("h3, .base-search-card__title")
                            company_el = await card.query_selector("h4, .base-search-card__subtitle")
                            location_el = await card.query_selector(".job-search-card__location")
                            link_el = await card.query_selector("a[href*='/jobs/']")

                            title = (await title_el.inner_text()).strip() if title_el else "Unknown"
                            company = (await company_el.inner_text()).strip() if company_el else "Unknown"
                            location = (await location_el.inner_text()).strip() if location_el else ""
                            url = await link_el.get_attribute("href") if link_el else ""

                            # Derive a stable ID from title+company
                            job_id = f"{title}-{company}".lower().replace(" ", "-")[:64]

                            if job_id not in self._seen:
                                jobs.append({
                                    "id": job_id,
                                    "title": title,
                                    "company": company,
                                    "location": location,
                                    "url": url.split("?")[0] if url else "",
                                })
                        except Exception:
                            continue

                await ctx.close()
                await browser.close()

        except Exception as e:
            log.warning(f"LinkedIn scrape failed: {e}")

        return jobs

    # ------------------------------------------------------------------
    # Ollama summary generation
    # ------------------------------------------------------------------
    async def _generate_summary(self, job: dict) -> str:
        prompt = (
            f"You are a career advisor for a sophomore studying Information Systems "
            f"at University of Arkansas who wants to work at Apple long-term.\n\n"
            f"Job found:\n"
            f"  Title: {job['title']}\n"
            f"  Company: {job['company']}\n"
            f"  Location: {job['location']}\n"
            f"  URL: {job['url']}\n\n"
            f"Write a 2-3 sentence push notification summary: Is this worth applying to? "
            f"Why is it a good or weak fit? Keep it direct and punchy."
        )

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{OLLAMA_URL}/api/generate",
                    json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False},
                    timeout=60,
                )
                return resp.json().get("response", "").strip()
        except Exception as e:
            log.warning(f"Ollama summary failed: {e}")
            return f"{job['title']} at {job['company']} in {job['location']}."

    # ------------------------------------------------------------------
    # Submit
    # ------------------------------------------------------------------
    async def _submit(self, proposal: dict) -> None:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.approval_api}/propose",
                json=proposal,
                timeout=10,
            )
            resp.raise_for_status()
            log.info(f"Submitted career proposal: {proposal['title']}")
