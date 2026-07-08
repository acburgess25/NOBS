# Tier 1 Apple slice — implementation spec

**Status:** Shipped (July 2026)  
**Captured:** July 6, 2026  
**Shipped:** July 8, 2026 — all five features implemented; physical device sign-off tracked in [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md)  
**Source:** [`APPLE_PLATFORM_BRAINSTORM.md`](APPLE_PLATFORM_BRAINSTORM.md) Tier 1  
**Product anchors:** [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §§5–6, 19  
**Depends on:** Morning Briefing v2 (shipped), physical iPhone QA path in [`CURRENT_STATE.md`](CURRENT_STATE.md)

## Goal

Deliver five Apple-native capabilities that make NOBS feel individual on day one for a typical user — without a settings maze, without silent automation, and without claiming unfinished work.

**Launch moment supported:** chaotic day → realistic plan in seconds, reachable from chat, Today, Lock Screen, Siri, and one actionable notification.

## Non-goals (this slice)

- HealthKit, HomeKit, Messages/Mail reading, CloudKit sync, Live Activities  
- Silent calendar edits, purchases, or external sends  
- Tank backend changes (reuse existing `/briefing`, `/chat`, `/agent/*`)  
- Google/Alexa home unification  

---

## Shared foundation

All five features read from the same on-device preference and briefing state.

### 1. `UserProfile` (local, JSON in App Group + Keychain for device token only)

Store in App Group `group.com.nobsdash.nobs` as `user-profile.json`. Codable, versioned.

```swift
struct UserProfile: Codable {
    var schemaVersion: Int = 1
    var displayName: String?
    var preferredTone: TonePreference = .neutral      // neutral | warm | direct | witty
    var workingHoursStart: String?                    // "09:00" local
    var workingHoursEnd: String?                      // "17:30" local
    var mentalLoadSources: [String]                   // free-text tags from chat
    var morningRoutineNote: String?
    var eveningRoutineNote: String?
    var proactivityLevel: ProactivityLevel = .balanced // quiet | balanced | proactive
    var privacyComfort: PrivacyComfort = .localFirst   // localFirst | tankPreferred | cloudOk
    var onboardingCompletedAt: Date?
    var immediateProblem: String?                     // one sentence
    var focusPolicies: [FocusPolicy]                  // see Feature 4
    var accessibilityPreferences: AccessibilityPreferences
}

struct FocusPolicy: Codable {
    var focusIdentifier: String                       // system Focus id or slug
    var displayName: String
    var responseStyle: ResponseStyle                  // concise | standard | reflective
    var allowProactiveNotifications: Bool
    var preferredContext: BriefingContextBucket?      // business | personal | shared
}

struct AccessibilityPreferences: Codable {
    var responseLength: ResponseLength = .standard    // brief | standard | detailed
    var prefersVoiceFirst: Bool = false
    var speakingRate: Float = 0.5                     // AVSpeechUtterance rate
}
```

**Service:** `NOBS/Services/UserProfileStore.swift` — load/save, merge partial updates from chat or onboarding.

**Exposure:** `AppModel` publishes `@Published var profile: UserProfile` and applies profile to briefing tone strings and notification policy.

### 2. App Group + Widget extension target

| Target | Bundle ID suffix | Purpose |
|--------|------------------|---------|
| `NOBS` | `com.nobs.app` | Main app |
| `NOBSWidgets` | `com.nobs.app.widgets` | Home Screen + Lock Screen widgets |
| `NOBSIntents` | (same as app) | App Intents live in main target |

- Enable App Group `group.com.nobsdash.nobs` on both targets (see `NOBS/Services/AppGroupStore.swift`).  
- Share: `user-profile.json`, `latest-briefing.json`, `widget-snapshot.json` (redacted public fields only).

### 3. `BriefingSnapshot` (widget-safe)

Derived from `DailyBriefing` after generation. Never includes raw event titles on Lock Screen unless user opts in via Privacy.

```swift
struct BriefingSnapshot: Codable {
    var date: String
    var topline: String
    var priorityCount: Int
    var topPriority: String?           // first priority; nil on Lock Screen if redaction on
    var hasConflict: Bool
    var conflictSummary: String?       // e.g. "1 overlap needs a decision"
    var route: String                  // Local | Tank
    var generatedAt: Date
    var redactDetailsOnLockScreen: Bool = true
}
```

Write snapshot in `AppModel` whenever `briefing` updates.

### 4. Deep links

Uniform URL scheme: `nobs://`

| Path | Action |
|------|--------|
| `nobs://today` | Open Today |
| `nobs://chat?prompt=…` | Open chat with prefilled user message |
| `nobs://conflict?id=…` | Open conflict resolution sheet |
| `nobs://privacy` | Open Privacy |

Widget, notification, and App Intent handlers use these URLs (already partially wired via `onOpenURL` for Tank pairing — extend, do not replace).

---

## Feature 1 — Conversational onboarding + progressive permissions

**Frameworks:** SwiftUI, TipKit (contextual tips only), EventKit (permission at moment of value)  
**Replaces:** static two-card `OnboardingView` + immediate Sign In as the only personalization step.

### v1 scope

After brand slides (keep existing 2 pages), transition into **chat-shaped onboarding** — not a separate wizard.

**Conversation script (deterministic local prompts, not LLM-required for v1):**

| Step | NOBS asks | User provides | Persisted field |
|------|-----------|---------------|-----------------|
| 1 | "What should I call you?" | name | `displayName` |
| 2 | "What usually creates mental load — work, home, health, or something else?" | 1–3 tags | `mentalLoadSources` |
| 3 | "When do you usually start and finish your working day?" | times or skip | `workingHoursStart/End` |
| 4 | "Quiet, balanced, or proactive check-ins?" | choice chips | `proactivityLevel` |
| 5 | "What's one thing I could help with today?" | free text | `immediateProblem` |
| 6 | Optional Sign in with Apple (existing `SignInView`) | auth | Tank token unchanged |

**Progressive permission (not in onboarding script):**

- Calendar: first time user opens Today or onboarding mentions scheduling → inline card in chat or Today (existing pattern).  
- Reminders: when briefing would improve with reminders and access missing.  
- Notifications: only when Feature 5 would fire (see below).  
- TipKit: one tip on first Today visit — "Your briefing builds from calendar events you can see before anything is sent."

### Files

| File | Change |
|------|--------|
| `NOBS/Views/OnboardingView.swift` | Add `ConversationalOnboardingView` or embed script in chat |
| `NOBS/Views/OnboardingChatView.swift` | **New** — step state machine, chip replies |
| `NOBS/Services/UserProfileStore.swift` | **New** |
| `NOBS/Models/UserProfile.swift` | **New** |
| `NOBS/AppModel.swift` | Load profile on `start()`, apply to responses |
| `NOBS/ConversationView.swift` | Route incomplete profile to onboarding chat |

### Acceptance criteria

- [ ] New user completes onboarding in &lt; 2 minutes without opening Settings.  
- [ ] Profile survives app restart (App Group JSON).  
- [ ] Calendar permission is **not** requested before step 6 or first Today visit.  
- [ ] `immediateProblem` seeds first chat message after onboarding: "You said X — want me to draft a plan?"  
- [ ] VoiceOver: each step has clear heading and button labels.  
- [ ] Skip path exists for every optional question.

### Out of scope

- LLM-driven onboarding interview  
- Health, location, HomeKit prompts  

---

## Feature 2 — Briefing widget (WidgetKit)

**Frameworks:** WidgetKit, SwiftUI, App Intents (widget configuration tap)  
**Entitlements:** App Group only (no EventKit in extension for v1 — read snapshot written by app).

### v1 scope

One widget family in `NOBSWidgets`:

**`NOBSBriefingWidget`** — supports `.systemSmall` and `.systemMedium`.

| Size | Content |
|------|---------|
| Small | NOBS mark, topline (2 lines), conflict badge if `hasConflict`, route pill |
| Medium | Topline + up to 2 priorities (or "3 priorities" count if redacted) + "Open plan" button |

**Timeline provider:**

- Refresh at `generatedAt + 30 min`, next calendar hour, and when app calls `WidgetCenter.shared.reloadTimelines(ofKind:)`.  
- Placeholder and snapshot use static sample data (no real PII in Xcode previews).  
- Lock Screen: use redacted snapshot (`topPriority` nil, `conflictSummary` generic).

**Optional v1.1 in same PR if trivial:** `accessoryRectangular` Lock Screen — topline only.

### Files

| File | Change |
|------|--------|
| `NOBSWidgets/NOBSWidgetsBundle.swift` | **New target** |
| `NOBSWidgets/BriefingWidget.swift` | **New** |
| `NOBSWidgets/BriefingSnapshotReader.swift` | **New** |
| `NOBS.xcodeproj/project.pbxproj` | Widget extension target + App Group |
| `NOBS/AppModel.swift` | Write `widget-snapshot.json` after briefing; reload timelines |

### Acceptance criteria

- [ ] Widget renders offline from last briefing without launching app.  
- [ ] Tap opens `nobs://today`.  
- [ ] Lock Screen variant does not show event titles when `redactDetailsOnLockScreen == true`.  
- [ ] Dynamic Type: topline truncates gracefully.  
- [ ] Empty state: "Open NOBS to build today's plan."

### Out of scope

- EventKit in extension  
- WeatherKit / MapKit (Tier 2)  
- Interactive buttons that mutate calendar (iOS 17+ App Intents button — defer)

---

## Feature 3 — App Intents + Siri

**Frameworks:** App Intents, App Shortcuts provider  
**Reference:** [`WWDC26_IMPACT.md`](WWDC26_IMPACT.md) §3

### v1 intent catalog

Implement four intents. All return a spoken + dialog string and open the app when confirmation is required.

| Intent | Phrase examples | Behavior |
|--------|-----------------|----------|
| `PrepareDayIntent` | "Prepare my day in NOBS" | Ensure calendar access; run `generateBriefing()`; speak topline + first priority |
| `ExplainScheduleIntent` | "What's unrealistic today in NOBS" | Read `conflictsOrRisks` from cached briefing or quick local scan |
| `AskNOBSIntent` | "Ask NOBS …" | Opens chat with `prompt` parameter; optional Tank send |
| `ShowPrivacyReceiptIntent` | "Show NOBS privacy receipt" | Opens Privacy or shows last receipt dialog |

**AppShortcutsProvider:** register phrases with `applicationName: "NOBS"`.

**Offline:** `PrepareDayIntent` and `ExplainScheduleIntent` use on-device briefing path when Tank unavailable (mirror `AppModel.generateBriefing()`).

**Sensitive inputs:** intents never accept passwords, health, or message bodies in v1.

### Files

| File | Change |
|------|--------|
| `NOBS/Intents/NOBSShortcuts.swift` | **New** — `AppShortcutsProvider` |
| `NOBS/Intents/PrepareDayIntent.swift` | **New** |
| `NOBS/Intents/ExplainScheduleIntent.swift` | **New** |
| `NOBS/Intents/AskNOBSIntent.swift` | **New** |
| `NOBS/Intents/ShowPrivacyReceiptIntent.swift` | **New** |
| `NOBS/AppModel.swift` | `@MainActor` methods callable from intents via `AppModel.shared` or `NOBSAppDelegate` holder |

**Pattern:** static `AppModel.shared` set in `NOBSApp.init` for intent process (document in code comment — App Intents may run in extension context).

### Acceptance criteria

- [ ] Intents appear in Shortcuts app under NOBS.  
- [ ] Siri handles each phrase with &lt; 3 s local path when briefing cached.  
- [ ] Denied calendar: intent returns honest "Open Today to connect calendar" — no fake briefing.  
- [ ] `AppIntentsTests` or manual Shortcuts run: each intent returns non-empty dialog.  
- [ ] Every intent result includes processing route in dialog when briefing was used ("Processed on this iPhone" / "Refined on Tank").

### Out of scope

- `capture commitment`, home intents, Research Library intents (later catalog per WWDC26 doc)  
- Siri AI handoff / App Schema conformance (evaluate after v1 intents ship)

---

## Feature 4 — Focus-aware behavior

**Frameworks:** `AppIntents` (`SetFocusFilterIntent` / Focus filter APIs), `FocusStatus` (if available), UserNotifications policy  
**Reference:** [`TOOL_EXPANSION.md`](TOOL_EXPANSION.md) §16

### v1 scope

**A. Read current Focus** when generating briefing and chat replies:

| Focus (approximate) | Behavior |
|---------------------|----------|
| Work / Do Not Disturb | `responseStyle = concise`; suppress proactive notifications; prefer `business` context in priorities |
| Personal | `standard` style; include personal reminders prominently |
| Sleep | no proactive notifications; chat replies offer "tomorrow" framing only |

**B. Focus Filter configuration (one-time setup in Focus settings):**

Expose NOBS filters via `FocusFilterIntent`:

- `nobs.proactivity.quiet` — hide proactive notification category  
- `nobs.context.business` — prefer business briefing bucket  
- `nobs.context.personal` — prefer personal bucket  

**C. Learn policy in chat (not Settings):**

When NOBS detects mismatch (e.g. work Focus + heavy personal calendar load), offer once:

> "You're in Work Focus but most of today's load is personal. Want me to stay concise and work-focused anyway?"

Approve → save `FocusPolicy`. Decline → remember for session.

### Files

| File | Change |
|------|--------|
| `NOBS/Services/FocusContextService.swift` | **New** — wrap Focus status read |
| `NOBS/Intents/NOBSFocusFilter.swift` | **New** — filter definitions |
| `NOBS/AppModel.swift` | Apply `FocusPolicy` in `generateOnDeviceBriefing()` and `localResponse()` |
| `NOBS/Models/UserProfile.swift` | `focusPolicies` array |

### Acceptance criteria

- [ ] Work Focus active → briefing topline is shorter (max ~120 chars) and priorities prefer business events.  
- [ ] Sleep Focus → `NotificationScheduler` does not schedule proactive clarifying notifications.  
- [ ] User can revoke focus policy in chat: "Reset focus behavior."  
- [ ] No notification spam when DND is on (respect system suppression).

### Out of scope

- Automatic Focus **activation** (only read + filter surfaces)  
- Location-triggered Focus  

---

## Feature 5 — Clarifying question notification

**Frameworks:** UserNotifications, App Intents (notification actions), `UNNotificationCategory`

### v1 scope

When `DailyBriefing.oneUsefulQuestion` is non-nil **and** `profile.proactivityLevel != .quiet` **and** Focus allows proactive notifications:

1. Schedule **one** local notification within 15 minutes of briefing generation.  
2. Title: "NOBS — quick question"  
3. Body: the `oneUsefulQuestion` string (max 180 chars).  
4. Category: `NOBS_CLARIFY` with actions:
   - **Open in NOBS** → `nobs://chat?prompt=…` (encoded question)  
   - **Dismiss**  
5. If overlap detected (`buildClarifyingQuestion` overlap branch), add dynamic actions:
   - **Keep [Event A]**  
   - **Keep [Event B]**  
   - Actions do **not** edit calendar in v1 — they open chat with a prefilled resolution prompt for user confirmation.

**Conflict identity:** extend `generateOnDeviceBriefing()` to attach optional `ClarifyingConflict` struct:

```swift
struct ClarifyingConflict: Codable {
    var question: String
    var optionA: ConflictOption   // id, label (event title), eventID
    var optionB: ConflictOption
}
```

Store in `latest-briefing.json` for notification action handlers.

### Files

| File | Change |
|------|--------|
| `NOBS/Services/NotificationScheduler.swift` | **New** |
| `NOBS/Services/NotificationDelegate.swift` | **New** — `UNUserNotificationCenterDelegate` |
| `NOBS/NOBSApp.swift` | Register delegate, request authorization only from scheduler |
| `NOBS/AppModel.swift` | Call scheduler after briefing; cancel prior `NOBS_CLARIFY` same day |
| `NOBS/Views/ConflictResolutionSheet.swift` | **New** — optional sheet from `nobs://conflict` |

### Permission UX

Request notification permission with copy:

> "NOBS can ask one quick question when your day needs a decision — not a stream of alerts."

Show only when first clarifying question would fire. If denied, show in-app banner on Today instead.

### Acceptance criteria

- [ ] At most **one** clarifying notification per calendar day.  
- [ ] Quiet proactivity → no notification; question visible on Today only.  
- [ ] Tap action opens chat with correct prefilled prompt.  
- [ ] No calendar writes from notification actions.  
- [ ] Activity log entry: "Clarifying question surfaced" with Local route.  
- [ ] Denied notifications → Today card highlights the question with accent.

### Out of scope

- Push / APNs remote notifications  
- Tank-scheduled notifications (use local scheduler only in v1)  
- Auto-reschedule calendar events  

---

## Implementation order

Dependencies dictate this sequence:

```
1. Shared foundation (UserProfile, App Group, BriefingSnapshot, deep links)
2. Feature 1 — Conversational onboarding (profile populated early)
3. Feature 2 — Widget (reads snapshot; validates App Group)
4. Feature 4 — Focus-aware behavior (affects briefing + notifications)
5. Feature 5 — Clarifying notification (depends on briefing + focus + profile)
6. Feature 3 — App Intents (calls same AppModel paths; easiest to test last)
```

**Suggested PR split:**

| PR | Contents |
|----|----------|
| A | Shared foundation + Feature 1 |
| B | Widget extension + snapshot pipeline |
| C | Focus service + notification scheduler + Feature 5 |
| D | App Intents + Siri phrases |

---

## Privacy and data minimization

| Data | Widget | Intent | Notification | Leaves device |
|------|--------|--------|--------------|---------------|
| Event titles | Redacted on Lock Screen | Spoken only if calendar permitted | Only in action labels if user already saw briefing | Tank briefing: titles + times only (existing contract) |
| User profile | Name optional in widget debug only — not shown in v1 | Used for tone | Not included | Not in v1 |
| Focus state | N/A | N/A | Gates send | Never |

Update Privacy view copy to list Widget, Siri, and Notifications with plain-language toggles linking to system Settings.

---

## Verification

### iOS build

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build
```

Add widget scheme build:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBSWidgets \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build
```

### Manual test matrix (physical iPhone required for Siri/notifications)

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Fresh install → onboarding chat | Profile saved; no calendar prompt |
| 2 | Complete onboarding → Today → allow calendar → briefing | Snapshot written; widget updates |
| 3 | Add widget to Home Screen | Shows topline from step 2 |
| 4 | Enable Work Focus → regenerate briefing | Shorter topline; business-first priorities |
| 5 | Overlapping events → briefing | One notification or Today banner with question |
| 6 | Tap "Keep Event A" notification action | Chat opens with resolution prompt; calendar unchanged |
| 7 | "Prepare my day in NOBS" to Siri | Speaks topline; opens app on failure |
| 8 | Deny notifications | No OS alert; question still on Today |
| 9 | Tank offline | Widget and Siri use Local briefing path |
| 10 | VoiceOver through onboarding + widget | Labels coherent |

### Backend

No new routes required. Existing `python3 scripts/dev.py check` must stay green.

---

## Documentation updates on ship

- [x] [`CURRENT_STATE.md`](CURRENT_STATE.md) — Tier 1 capabilities under Working now  
- [ ] [`APPLE_PLATFORM_BRAINSTORM.md`](APPLE_PLATFORM_BRAINSTORM.md) — mark Tier 1 items implemented  
- [ ] [`ISSUE_BACKLOG.md`](ISSUE_BACKLOG.md) — close or link related onboarding/Siri/widget issues  
- [x] [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md) — physical validation template (Tier 1.1)

---

## Resolved decisions (at ship)

1. **App Group ID** — `group.com.nobsdash.nobs` (entitlements + `AppGroupStore.swift`).  
2. **Sign in with Apple** — optional after conversational onboarding; Tank pairing via QR or manual token.  
3. **Lock Screen detail** — default redacted (`redactDetailsOnLockScreen == true`).
