"""Briefing schedules and the overnight work queue.

Both are ways of asking the Tank to do something later. Scheduled work runs
through the same tool registry and approval policy as anything else -- a
schedule is not a way around consent -- so nothing here executes a tool
directly; it only records intent for the scheduler to pick up.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import StoreDep, require_device_token
from app.schemas import (
    CreateScheduleRequest,
    OvernightTaskCreateRequest,
    OvernightTaskView,
    ScheduleView,
    UpdateScheduleRequest,
)

router = APIRouter()


@router.post(
    "/schedules",
    response_model=ScheduleView,
    tags=["schedules"],
    dependencies=[Depends(require_device_token)],
)
async def create_schedule(request: CreateScheduleRequest, store: StoreDep) -> ScheduleView:
    schedule = store.create_briefing_schedule(request.time_of_day)
    return ScheduleView.model_validate(schedule)


@router.get(
    "/schedules",
    response_model=list[ScheduleView],
    tags=["schedules"],
    dependencies=[Depends(require_device_token)],
)
async def list_schedules(store: StoreDep) -> list[ScheduleView]:
    return [ScheduleView.model_validate(item) for item in store.list_briefing_schedules()]


@router.patch(
    "/schedules/{schedule_id}",
    response_model=ScheduleView,
    tags=["schedules"],
    dependencies=[Depends(require_device_token)],
)
async def update_schedule(
    schedule_id: str,
    request: UpdateScheduleRequest,
    store: StoreDep,
) -> ScheduleView:
    try:
        schedule = store.update_briefing_schedule(schedule_id, request.status)
        return ScheduleView.model_validate(schedule)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Schedule not found") from error
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.post(
    "/overnight/tasks",
    response_model=OvernightTaskView,
    tags=["overnight"],
    dependencies=[Depends(require_device_token)],
)
async def enqueue_overnight_task(
    request: OvernightTaskCreateRequest,
    store: StoreDep,
) -> OvernightTaskView:
    task = store.enqueue_overnight_task(
        objective=request.objective,
        context=request.context,
        task_type=request.task_type.value,
        mode=request.mode,
        priority=request.priority,
    )
    return OvernightTaskView.model_validate(task)


@router.get(
    "/overnight/tasks",
    response_model=list[OvernightTaskView],
    tags=["overnight"],
    dependencies=[Depends(require_device_token)],
)
async def list_overnight_tasks(
    store: StoreDep,
    task_status: str | None = None,
) -> list[OvernightTaskView]:
    return [
        OvernightTaskView.model_validate(item) for item in store.list_overnight_tasks(task_status)
    ]


@router.get(
    "/overnight/tasks/{task_id}",
    response_model=OvernightTaskView,
    tags=["overnight"],
    dependencies=[Depends(require_device_token)],
)
async def get_overnight_task(task_id: str, store: StoreDep) -> OvernightTaskView:
    try:
        task = store.get_overnight_task(task_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Overnight task not found") from error
    return OvernightTaskView.model_validate(task)


@router.post(
    "/overnight/tasks/{task_id}/cancel",
    response_model=OvernightTaskView,
    tags=["overnight"],
    dependencies=[Depends(require_device_token)],
)
async def cancel_overnight_task(task_id: str, store: StoreDep) -> OvernightTaskView:
    try:
        store.get_overnight_task(task_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Overnight task not found") from error
    try:
        task = store.cancel_overnight_task(task_id)
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return OvernightTaskView.model_validate(task)
