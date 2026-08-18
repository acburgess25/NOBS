"""Calendar and reminder sync from the user's Apple devices.

The phone is the source of truth; these routes accept a snapshot and replace
what the Tank holds. Both carry personal content, so both require a device
token -- there is no unauthenticated read of what is stored here.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.dependencies import StoreDep, require_device_token
from app.schemas import SyncCalendarRequest, SyncRemindersRequest

router = APIRouter()


@router.post(
    "/sync/calendar",
    tags=["sync"],
    dependencies=[Depends(require_device_token)],
)
async def sync_calendar(request: SyncCalendarRequest, store: StoreDep) -> dict[str, str]:
    events = [item.model_dump(mode="json") for item in request.events]
    store.sync_calendar(events)
    return {"status": "ok"}


@router.post(
    "/sync/reminders",
    tags=["sync"],
    dependencies=[Depends(require_device_token)],
)
async def sync_reminders(request: SyncRemindersRequest, store: StoreDep) -> dict[str, str]:
    reminders = [item.model_dump(mode="json") for item in request.reminders]
    store.sync_reminders(reminders)
    return {"status": "ok"}
