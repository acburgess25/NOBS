"""The v1 briefing and sync wire contract shared with Apple clients."""

from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field


class PrivacyReceipt(BaseModel):
    used: list[str]
    processed: str
    shared: list[str]
    changed: list[str]


class BriefingContext(str, Enum):
    personal = "personal"
    business = "business"
    shared = "shared"


class BriefingCalendarItem(BaseModel):
    """Calendar facts Tank is allowed to see.

    Event locations stay on the device. The field is intentionally absent, so a
    client that still sends one is ignored rather than required, stored, or
    handed to the model. Pydantic's default is to drop unknown fields.
    """

    title: str = Field(min_length=1, max_length=500)
    start: str = Field(min_length=1, max_length=50)
    end: str | None = Field(default=None, max_length=50)
    context: BriefingContext


class BriefingReminderItem(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    due: str | None = Field(default=None, max_length=50)
    context: BriefingContext


class BriefingRequest(BaseModel):
    date: date
    calendar: list[BriefingCalendarItem] = Field(max_length=100)
    reminders: list[BriefingReminderItem] = Field(max_length=100)


class BriefingSections(BaseModel):
    topline: str = Field(min_length=1, max_length=600)
    priorities: list[str] = Field(default_factory=list, max_length=5)
    conflicts_or_risks: list[str] = Field(default_factory=list, max_length=8)
    recommended_plan: list[str] = Field(default_factory=list, max_length=10)
    one_useful_question: str | None = Field(default=None, max_length=300)
    suggested_next_actions: list[str] = Field(default_factory=list, max_length=6)


class BriefingResponse(BriefingSections):
    date: date
    generated_at: datetime
    route: str
    privacy_receipt: PrivacyReceipt


class SyncCalendarRequest(BaseModel):
    events: list[BriefingCalendarItem]


class SyncRemindersRequest(BaseModel):
    reminders: list[BriefingReminderItem]
