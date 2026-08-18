"""Dream Team Sandbox sessions, drafts, and proposals.

The sandbox refines work with several local agents and then produces a
proposal. Approving one is a state change, so it goes through the sandbox's
own approve/reject path rather than being written here, and `/dream-team/policy`
documents in the API itself that refinement stays local and spends no cloud
quota.
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies import (
    SandboxDep,
    SettingsDep,
    StoreDep,
    require_device_token,
)
from app.dream_team import DreamTeamModelError, LocalFirstPolicy
from app.schemas import (
    DreamTeamApproveResponse,
    DreamTeamProposalDecision,
    DreamTeamProposalView,
    DreamTeamSessionCreateRequest,
    DreamTeamSessionView,
)

router = APIRouter()


@router.post(
    "/dream-team/sessions",
    response_model=DreamTeamSessionView,
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def create_dream_team_session(
    request: DreamTeamSessionCreateRequest,
    settings: SettingsDep,
    store: StoreDep,
) -> DreamTeamSessionView:
    if not settings.dream_team_enabled:
        raise HTTPException(status_code=503, detail="Dream Team Sandbox is disabled")
    policy = LocalFirstPolicy()
    session = store.create_dream_team_session(
        objective=request.objective,
        context=request.context,
        config={
            "local_first_policy": policy.as_dict(),
            "model": settings.dream_team_model or settings.ollama_model,
            "max_agents": settings.dream_team_max_agents,
            "max_iterations": settings.dream_team_max_iterations,
        },
    )
    return DreamTeamSessionView.model_validate(session)


@router.get(
    "/dream-team/sessions",
    response_model=list[DreamTeamSessionView],
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def list_dream_team_sessions(
    store: StoreDep,
    session_status: str | None = None,
) -> list[DreamTeamSessionView]:
    return [
        DreamTeamSessionView.model_validate(item)
        for item in store.list_dream_team_sessions(session_status)
    ]


@router.get(
    "/dream-team/sessions/{session_id}",
    response_model=DreamTeamSessionView,
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def get_dream_team_session(session_id: str, store: StoreDep) -> DreamTeamSessionView:
    try:
        session = store.get_dream_team_session(session_id, include_details=True)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Session not found") from error
    return DreamTeamSessionView.model_validate(session)


@router.post(
    "/dream-team/sessions/{session_id}/run",
    response_model=DreamTeamSessionView,
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def run_dream_team_session(
    session_id: str,
    settings: SettingsDep,
    sandbox: SandboxDep,
) -> DreamTeamSessionView:
    if not settings.dream_team_enabled:
        raise HTTPException(status_code=503, detail="Dream Team Sandbox is disabled")
    try:
        session = await sandbox.run_session(session_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Session not found") from error
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except DreamTeamModelError as error:
        raise HTTPException(
            status_code=503,
            detail="Local Ollama could not complete dream team refinement",
        ) from error
    return DreamTeamSessionView.model_validate(session)


@router.get(
    "/dream-team/proposals",
    response_model=list[DreamTeamProposalView],
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def list_dream_team_proposals(
    store: StoreDep,
    proposal_status: str | None = "pending",
) -> list[DreamTeamProposalView]:
    return [
        DreamTeamProposalView.model_validate(item)
        for item in store.list_dream_team_proposals(proposal_status)
    ]


@router.get(
    "/dream-team/proposals/{proposal_id}",
    response_model=DreamTeamProposalView,
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def get_dream_team_proposal(proposal_id: str, store: StoreDep) -> DreamTeamProposalView:
    try:
        proposal = store.get_dream_team_proposal(proposal_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Proposal not found") from error
    return DreamTeamProposalView.model_validate(proposal)


@router.post(
    "/dream-team/proposals/{proposal_id}/decide",
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def decide_dream_team_proposal(
    proposal_id: str,
    decision: DreamTeamProposalDecision,
    sandbox: SandboxDep,
) -> DreamTeamProposalView | DreamTeamApproveResponse:
    try:
        if decision.decision == "approve":
            result = sandbox.approve_proposal(proposal_id)
            return DreamTeamApproveResponse(
                proposal=DreamTeamProposalView.model_validate(result["proposal"]),
                active_manifests=result["active_manifests"],
                local_first_policy=LocalFirstPolicy().as_dict(),
            )
        result = sandbox.reject_proposal(proposal_id)
        return DreamTeamProposalView.model_validate(result)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Proposal not found") from error
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.get(
    "/dream-team/policy",
    tags=["dream-team"],
    dependencies=[Depends(require_device_token)],
)
async def dream_team_policy(settings: SettingsDep) -> dict[str, Any]:
    """Documents local-first processing for dream team refinement."""
    policy = LocalFirstPolicy()
    return {
        **policy.as_dict(),
        "model": settings.dream_team_model or settings.ollama_model,
        "max_agents": settings.dream_team_max_agents,
        "max_iterations": settings.dream_team_max_iterations,
        "sandbox_max_steps": settings.dream_team_sandbox_max_steps,
        "external_tools_excluded_from_sandbox": sorted(
            {
                "web_search",
                "read_url",
                "lookup_wikipedia",
                "read_news_feeds",
                "get_weather",
            }
        ),
        "would_use_cloud_quota": False,
    }
