"""Agent tasks, approvals, and proposals -- the approval gate itself.

`decide_agent_approval` is the most safety-critical route in the API. It runs a
tool the model asked for, so it re-reads the stored approval and executes the
exact arguments that were approved; it never regenerates them. The claim is
atomic, which is what makes an approval non-replayable, and the tool's risk is
re-checked at execution time so a registry change between approval and
execution cannot quietly widen what was authorized.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.agent import (
    AgentModelError,
    AgentTaskRequest,
    AgentTaskResponse,
    ApprovalDecision,
    ApprovalView,
    TankAgent,
)
from app.dependencies import (
    SettingsDep,
    StoreDep,
    ToolsDep,
    TransportDep,
    require_device_token,
)
from app.schemas import ProposalDecision, ProposalView

router = APIRouter()


@router.post(
    "/agent/tasks",
    response_model=AgentTaskResponse,
    tags=["agent"],
    dependencies=[Depends(require_device_token)],
)
async def run_agent_task(
    request: AgentTaskRequest,
    settings: SettingsDep,
    store: StoreDep,
    tools: ToolsDep,
    transport: TransportDep,
) -> AgentTaskResponse:
    agent = TankAgent(
        settings=settings,
        store=store,
        tools=tools,
        transport=transport,
    )
    try:
        return await agent.run(request)
    except AgentModelError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Tank agent model is unavailable",
        ) from error


@router.get(
    "/agent/approvals",
    response_model=list[ApprovalView],
    tags=["agent"],
    dependencies=[Depends(require_device_token)],
)
async def list_agent_approvals(
    store: StoreDep,
    approval_status: str = "pending",
) -> list[ApprovalView]:
    return [ApprovalView.model_validate(item) for item in store.list_approvals(approval_status)]


@router.post(
    "/agent/approvals/{approval_id}",
    response_model=ApprovalView,
    tags=["agent"],
    dependencies=[Depends(require_device_token)],
)
async def decide_agent_approval(
    approval_id: str,
    decision: ApprovalDecision,
    store: StoreDep,
    tools: ToolsDep,
) -> ApprovalView:
    try:
        approval = store.get_approval(approval_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Approval not found") from error

    if decision.decision == "deny":
        try:
            denied = store.decide_approval(approval_id, "denied")
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error
        store.record_event(
            approval["run_id"],
            "approval_denied",
            {"approval_id": approval_id, "tool": approval["tool_name"]},
        )
        return ApprovalView.model_validate(denied)

    try:
        claimed = store.claim_approval(approval_id)
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error

    tool = tools.get(claimed["tool_name"])
    if tool is None or tool.risk != claimed["risk"]:
        failed = store.finish_approval(
            approval_id,
            "failed",
            {"error": "Approved tool is no longer available with the same risk"},
        )
        return ApprovalView.model_validate(failed)

    try:
        result = tools.execute(tool.name, claimed["arguments"])
        final_status = "approved"
    except (OSError, ValueError) as error:
        result = {"error": str(error)}
        final_status = "failed"
    finished = store.finish_approval(approval_id, final_status, result)
    store.record_event(
        claimed["run_id"],
        "approval_executed",
        {
            "approval_id": approval_id,
            "tool": tool.name,
            "status": final_status,
            "result": result,
        },
    )
    return ApprovalView.model_validate(finished)


@router.get(
    "/agent/proposals",
    response_model=list[ProposalView],
    tags=["agent"],
    dependencies=[Depends(require_device_token)],
)
async def list_agent_proposals(
    store: StoreDep,
    proposal_status: str | None = None,
) -> list[ProposalView]:
    return [ProposalView.model_validate(item) for item in store.list_proposals(proposal_status)]


@router.post(
    "/agent/proposals/{proposal_id}/decide",
    response_model=ProposalView,
    tags=["agent"],
    dependencies=[Depends(require_device_token)],
)
async def decide_agent_proposal(
    proposal_id: str,
    decision: ProposalDecision,
    store: StoreDep,
) -> ProposalView:
    db_decision = "approved" if decision.decision == "approve" else "dismissed"
    try:
        finished = store.decide_proposal(proposal_id, db_decision)
        return ProposalView.model_validate(finished)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Proposal not found") from error
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
