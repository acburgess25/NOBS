"""
NOBS Homelab Agent — Main orchestration loop.

Runs proposals on a schedule using APScheduler:
  - Every 30m: Career proposals (LinkedIn job scraping)
  - Every 2h:  Homelab proposals (Docker/Ollama updates)
  - Every 4h:  Design proposals
  - Every 4h:  Engineering proposals
  - Every 6h:  SEO proposals
  - Every 6h:  Visual proposals

Each proposal is sent to the Approval API → ntfy → iPhone.
Approved tasks are picked up and executed here.
"""

from __future__ import annotations

import asyncio
import logging
import os

import httpx
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from proposals.career import CareerProposal
from proposals.homelab import HomelabProposal
from proposals.design import DesignProposal
from proposals.engineering import EngineeringProposal
from proposals.seo import SeoProposal
from proposals.visual import VisualProposal
from executor import execute_approved_tasks

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("nobs-agent")

APPROVAL_API = os.getenv("APPROVAL_API_URL", "http://approval-api:5051")


async def run_career_proposals() -> None:
    log.info("Running career proposal scan…")
    try:
        proposal = CareerProposal(approval_api=APPROVAL_API)
        await proposal.run()
    except Exception as e:
        log.error(f"Career proposal failed: {e}")


async def run_homelab_proposals() -> None:
    log.info("Running homelab proposal scan…")
    try:
        proposal = HomelabProposal(approval_api=APPROVAL_API)
        await proposal.run()
    except Exception as e:
        log.error(f"Homelab proposal failed: {e}")


async def run_design_proposals() -> None:
    log.info("Running design proposal scan…")
    try:
        proposal = DesignProposal(approval_api=APPROVAL_API)
        await proposal.run()
    except Exception as e:
        log.error(f"Design proposal failed: {e}")


async def run_engineering_proposals() -> None:
    log.info("Running engineering proposal scan…")
    try:
        proposal = EngineeringProposal(approval_api=APPROVAL_API)
        await proposal.run()
    except Exception as e:
        log.error(f"Engineering proposal failed: {e}")


async def run_seo_proposals() -> None:
    log.info("Running SEO proposal scan…")
    try:
        proposal = SeoProposal(approval_api=APPROVAL_API)
        await proposal.run()
    except Exception as e:
        log.error(f"SEO proposal failed: {e}")


async def run_visual_proposals() -> None:
    log.info("Running visual proposal scan…")
    try:
        proposal = VisualProposal(approval_api=APPROVAL_API)
        await proposal.run()
    except Exception as e:
        log.error(f"Visual proposal failed: {e}")


async def poll_and_execute() -> None:
    """Check for approved tasks every 10 seconds and execute them."""
    while True:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(f"{APPROVAL_API}/queue?status=approved", timeout=5)
                tasks = resp.json()

            for task in tasks:
                action = task.get("payload", {}).get("action", "unknown")
                if action == "system_trigger_scan":
                    log.info("System triggered scan request received. Executing scans in background...")

                    def _log_task_exc(t: asyncio.Task) -> None:
                        if not t.cancelled() and (exc := t.exception()):
                            log.error("background scan task %s raised: %s", t.get_name(), exc)

                    for coro in (
                        run_career_proposals(),
                        run_homelab_proposals(),
                        run_design_proposals(),
                        run_engineering_proposals(),
                        run_seo_proposals(),
                        run_visual_proposals(),
                    ):
                        t = asyncio.create_task(coro)
                        t.add_done_callback(_log_task_exc)
                    async with httpx.AsyncClient() as client:
                        await client.post(f"{APPROVAL_API}/complete?task_id={task['id']}", timeout=5)
                else:
                    log.info(f"Executing approved task: {task['id']} — {task['title']}")
                    await execute_approved_tasks(task, approval_api=APPROVAL_API)

        except Exception as e:
            log.warning(f"Executor poll error: {e}")

        await asyncio.sleep(10)


async def main() -> None:
    scheduler = AsyncIOScheduler()

    # Career scan every 30 minutes
    scheduler.add_job(run_career_proposals, "interval", minutes=30,
                      id="career", misfire_grace_time=300)

    # Homelab scan every 2 hours
    scheduler.add_job(run_homelab_proposals, "interval", hours=2,
                      id="homelab", misfire_grace_time=300)

    # Design scan every 4 hours
    scheduler.add_job(run_design_proposals, "interval", hours=4,
                      id="design", misfire_grace_time=300)

    # Engineering scan every 4 hours
    scheduler.add_job(run_engineering_proposals, "interval", hours=4,
                      id="engineering", misfire_grace_time=300)

    # SEO scan every 6 hours
    scheduler.add_job(run_seo_proposals, "interval", hours=6,
                      id="seo", misfire_grace_time=300)

    # Visual scan every 6 hours
    scheduler.add_job(run_visual_proposals, "interval", hours=6,
                      id="visual", misfire_grace_time=300)

    # Run once immediately on startup so you see something right away
    scheduler.add_job(run_homelab_proposals, "date", id="homelab_boot")
    scheduler.add_job(run_career_proposals,  "date", id="career_boot")
    scheduler.add_job(run_design_proposals,  "date", id="design_boot")
    scheduler.add_job(run_engineering_proposals, "date", id="engineering_boot")
    scheduler.add_job(run_seo_proposals,     "date", id="seo_boot")
    scheduler.add_job(run_visual_proposals,  "date", id="visual_boot")

    scheduler.start()
    log.info("NOBS Agent started — scheduler running.")

    # Run the executor loop concurrently
    await poll_and_execute()


if __name__ == "__main__":
    asyncio.run(main())
