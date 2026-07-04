# Daily briefing slice — implementation spec

Status: implemented, deployed, and live-verified on Tank July 3, 2026. This vertical slice from
[`CURRENT_STATE.md`](CURRENT_STATE.md), scoped for immediate implementation.

## Backend (Tank FastAPI)

Add a device-token-protected briefing contract. Follow the existing `/chat`
patterns in `app/main.py` exactly (httpx to Ollama with the
`app.state.ollama_transport` test override, `PrivacyReceipt`, HTTPException
mapping for timeout/connect/status/parse failures).

### `POST /briefing`

Request (pydantic models, validated):

```json
{
  "date": "2026-07-04",
  "calendar": [{"title": "Design sync", "start": "10:00", "context": "business"}],
  "reminders": [{"title": "Call plumber", "context": "personal"}]
}
```

- `context` is an enum: `personal | business | shared`. Lists may be empty.
- Compose a single Ollama chat call (model from settings) asking for a warm,
  concise briefing with three clearly separated sections: Personal, Business,
  and Shared. The system prompt must instruct the model to use ONLY the
  provided items — no invented events.
- Response: `{"date", "personal", "business", "shared", "generated_at", "route": "Tank", "privacy_receipt"}`.
  The receipt's `used` names the calendar/reminder item counts sent; `shared` is `[]`; `changed` is `[]`.
- Persist the latest briefing per date in the existing SQLite `AgentStore`
  (new table + `save_briefing` / `latest_briefing` methods mirroring the
  approvals patterns).

### `GET /briefing/latest`

Returns the most recent stored briefing or 404. Device token required.

### Tests (mirror `tests/test_chat.py` helpers)

- auth required on both routes (401 anonymous).
- valid request with a `httpx.MockTransport` fake Ollama returns parsed sections
  and stores them; `GET /briefing/latest` then returns the same content.
- Ollama timeout maps to 503; malformed model output maps to 502.
- context enum rejects unknown values (422).

## iOS app (SwiftUI, `NOBS/`)

1. **Briefing card on the Today surface**: a "Morning briefing" action that
   gathers the day's EventKit events already displayed, maps them to the
   request contract (user-visible before sending), posts to `/briefing`, and
   renders the three sections with the existing privacy-receipt affordance.
2. **Approvals screen on the Activity surface**: list `GET /agent/approvals`
   (pending), with Approve/Deny actions calling the existing decide endpoint;
   show empty state and offline fallback consistent with chat's honest-fallback
   pattern.

Build verification: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project NOBS.xcodeproj -scheme NOBS -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' CODE_SIGNING_ALLOWED=NO build`

## Out of scope for this slice

Persistent scheduler, push notifications, email/messages sources, memory. Do
not send raw event notes or attendees to Tank — titles, times, and contexts only.

## Implementation result

- Authenticated `POST /briefing` and `GET /briefing/latest` are implemented with
  validated Personal, Business, and Shared contexts and SQLite persistence.
- Today shows the exact calendar events before sending only titles, times, and
  inferred calendar context to Tank; notes, attendees, and locations are excluded.
- Activity lists pending approvals and supports explicit approve or deny actions.
- Backend tests and the iOS 27 simulator build pass. The Tank deployment was
  live-verified with fake Personal and Business items, anonymous rejection, latest
  retrieval, and unchanged dashboard run metrics; the fake record was removed afterward.

## Verification checklist

- `python3 scripts/dev.py check` green (tests + lint).
- iOS simulator build green.
- Live check on Tank: authenticated `POST /briefing` with two fake items
  returns three sections; dashboard `runs_24h` unaffected; anonymous request 401.
- Update `CURRENT_STATE.md` "Working now" when shipped.
