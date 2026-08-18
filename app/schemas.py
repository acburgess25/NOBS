"""Request and response models for the Tank HTTP API.

These are the wire contract. The iPhone app, the macOS supervisor, and the
dashboard all decode exactly what is declared here, so a change to a field
name or type is a breaking protocol change -- not a local refactor. Keeping them in one file makes that contract readable
on its own, instead of interleaved with the routes that happen to use it.
"""

from __future__ import annotations

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field

from app.briefing import BriefingCalendarItem, BriefingReminderItem, PrivacyReceipt


class ChatMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=20_000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=40)


class ChatResponse(BaseModel):
    message: str
    route: str
    privacy_receipt: PrivacyReceipt


class ProposalView(BaseModel):
    id: str
    title: str
    description: str
    proposal_type: str
    status: str
    created_at: str
    decided_at: str | None


class ProposalDecision(BaseModel):
    decision: Literal["approve", "dismiss"]


class ScheduleView(BaseModel):
    id: str
    time_of_day: str
    status: str
    created_at: str


class CreateScheduleRequest(BaseModel):
    time_of_day: str = Field(pattern="^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")


class UpdateScheduleRequest(BaseModel):
    status: Literal["active", "paused", "revoked"]


class OvernightTaskType(str, Enum):
    research = "research"
    memory_consolidation = "memory_consolidation"
    briefing_prep = "briefing_prep"
    custom = "custom"


class OvernightTaskCreateRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=10_000)
    context: Literal["personal", "business", "shared"] = "personal"
    mode: Literal["assistant", "developer"] = "assistant"
    task_type: OvernightTaskType = OvernightTaskType.custom
    priority: int = Field(default=0, ge=0, le=10)


class OvernightTaskView(BaseModel):
    id: str
    objective: str
    context: str
    mode: str
    task_type: str
    priority: int
    status: str
    result: dict[str, Any] | None
    error: str | None
    created_at: str
    started_at: str | None
    completed_at: str | None


class SyncCalendarRequest(BaseModel):
    events: list[BriefingCalendarItem]


class SyncRemindersRequest(BaseModel):
    reminders: list[BriefingReminderItem]


class AppleAuthRequest(BaseModel):
    user_identifier: str = Field(min_length=1, max_length=256)
    identity_token: str | None = None


class AppleAuthResponse(BaseModel):
    device_token: str


class DreamTeamSessionCreateRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=2000)
    context: Literal["personal", "business", "shared"] = "personal"


class DreamTeamDraftView(BaseModel):
    id: str
    session_id: str
    name: str
    role: str
    persona: dict[str, Any]
    score: float | None
    iteration: int
    status: str
    test_result: dict[str, Any] | None
    created_at: str
    updated_at: str


class DreamTeamProposalView(BaseModel):
    id: str
    session_id: str
    title: str
    summary: str
    members: list[dict[str, Any]]
    metadata: dict[str, Any]
    status: str
    created_at: str
    decided_at: str | None


class DreamTeamSessionView(BaseModel):
    id: str
    objective: str
    context: str
    status: str
    config: dict[str, Any]
    result_summary: str | None
    created_at: str
    updated_at: str
    drafts: list[DreamTeamDraftView] | None = None
    proposals: list[DreamTeamProposalView] | None = None


class DreamTeamProposalDecision(BaseModel):
    decision: Literal["approve", "reject"]


class DreamTeamApproveResponse(BaseModel):
    proposal: DreamTeamProposalView
    active_manifests: int
    local_first_policy: dict[str, Any]


class WorkplaceBrowserSessionRequest(BaseModel):
    agent_id: str = Field(min_length=1, max_length=120)
    url: str = Field(min_length=1, max_length=2000)


class PairingStateView(BaseModel):
    open: bool
    expires_in_seconds: int | None
    ttl_seconds: int


class PairingSecretView(PairingStateView):
    url: str
    token: str
