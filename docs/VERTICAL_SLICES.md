# Vertical slices — next two bets

**Status:** Spec (July 8, 2026)  
**Source:** [`FEATURE_BRAINSTORM.md`](FEATURE_BRAINSTORM.md) recommended portfolio  
**Product anchor:** [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) — *chaotic day → realistic plan in seconds*

Two slices picked from the recommended next five bets. Each is scoped for a 2–4 week vertical delivery with clear acceptance criteria.

---

## Slice 1: Unified briefing builder

### Problem

Briefing heuristics and Ollama prompts are duplicated across three places today:

| Location | Role |
|----------|------|
| `app/main.py` | `POST /briefing`, `_detect_briefing_risks`, `_merge_briefing_with_heuristics` |
| `app/scheduler.py` | Scheduled morning/evening generation, duplicate system prompts |
| `NOBS/AppModel.swift` | On-device Morning Briefing v2 (`generateOnDeviceBriefing`) |

Scheduler briefings can diverge from iOS and manual `/briefing` calls because they do not share the same merge logic or evening heuristics.

### Goal

One Tank module — `app/briefing.py` — owns prompts, risk detection, overload flags, clarifying-question rules, and response shaping for **morning**, **evening**, and **scheduler** paths. iOS keeps on-device generation for offline-first UX but documents which heuristics must stay aligned (or calls a lightweight shared contract).

### Scope

**In:**

- Extract `_BRIEFING_SYSTEM_PROMPT`, `_EVENING_BRIEFING_SYSTEM_PROMPT`, `_detect_briefing_risks`, `_merge_briefing_with_heuristics`, and evening merge helpers into `app/briefing.py`.
- Public API: `build_briefing_request(...)`, `merge_model_sections(...)`, `detect_risks(...)`, `BriefingKind` enum (`morning` | `evening`).
- Refactor `app/main.py` `POST /briefing` and `app/scheduler.py` `trigger_briefing_generation` to import from `app/briefing.py` only.
- Optional: add `kind` field to `BriefingRequest` if not already present end-to-end.
- Weather topline hook (Open-Meteo tool output) as an optional `weather_summary` input — display only when provided; never invent conditions.

**Out:**

- iOS rewrite to call Tank for first pass (iOS stays on-device first, Tank refines — existing pattern).
- Push notifications for scheduled briefings.
- Memory injection into briefings (separate slice).

### Files

| File | Change |
|------|--------|
| `app/briefing.py` | **New** — prompts, heuristics, merge helpers, shared types |
| `app/main.py` | Import briefing module; thin route handlers |
| `app/scheduler.py` | Import prompts and generation helper from briefing module |
| `tests/test_briefing.py` | Extend with heuristic parity tests (morning + evening) |
| `tests/test_scheduler.py` | Assert scheduler uses same merge output as `/briefing` |
| `docs/CURRENT_STATE.md` | Update when shipped |

### Acceptance criteria

1. `python3 scripts/dev.py check` passes with new `tests/test_briefing.py` coverage for risk detection, overload flag, and evening merge.
2. Identical calendar/reminder fixture produces identical `conflicts_or_risks`, `one_useful_question`, and `suggested_next_actions` from `POST /briefing` and scheduler-triggered generation.
3. System prompts exist in exactly one module (`app/briefing.py`); grep finds no duplicate `_BRIEFING_SYSTEM_PROMPT` in `main.py` or `scheduler.py`.
4. Evening kind returns guilt-free wrap-up fields per [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §4.
5. Existing iOS briefing flow unchanged; simulator build still green.

### Test plan

```bash
python3 scripts/dev.py check
pytest tests/test_briefing.py tests/test_scheduler.py -v
```

Manual:

1. `POST /briefing` with 8 overlapping events → overload risk and clarifying question present.
2. Create active schedule at current local time (`settings.timezone`) → scheduler writes same-shaped briefing to SQLite.
3. iOS Today → generate briefing → Tank refine → compare conflict/risk sections with Tank-only curl response.

---

## Slice 2: Day Rescue mode

### Problem

Today detects overload and overlaps (Morning Briefing v2, event overlap icons, `ClarifyingConflict`) but does not walk the full six-step overload escalation from [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §4. `ConflictResolutionSheet` only picks must-attend between two events and prefills chat — it is not a coordinated rescue flow.

### Goal

One tap from Today when overload is detected: explain → revised plan → 1–3 reversible fixes, wired through existing `ConflictResolutionSheet` and approval queue. Full UI spec in [`DAY_RESCUE_SPEC.md`](DAY_RESCUE_SPEC.md).

### Scope

**In:**

- Overload banner/card on `TodayView` when briefing risks include overload or ≥7 events / overlap cluster.
- "Rescue my day" entry opens a multi-step sheet (extends `ConflictResolutionSheet` pattern).
- Steps 1–3 of product escalation (explain, revised schedule, one-tap reversible suggestions) in v1.
- Suggested fixes enqueue Tank approval-gated calendar nudges where applicable; no silent EventKit writes.
- Deep link `nobs://rescue` and App Intent stub optional.

**Out (v1):**

- Steps 4–6 (trusted block moves, draft messages, send automation).
- Live Activity progress.
- Full afternoon-only "Fix my afternoon" variant (follow-on).

### Files

| File | Change |
|------|--------|
| `docs/DAY_RESCUE_SPEC.md` | UI flow spec (this slice depends on it) |
| `NOBS/Views/TodayView.swift` | Overload CTA, rescue entry point |
| `NOBS/Views/ConflictResolutionSheet.swift` | Extend or sibling `DayRescueSheet` |
| `NOBS/AppModel.swift` | Rescue state machine, revised plan generation, approval requests |
| `NOBS/Models/NOBSModels.swift` | `DayRescuePlan`, `RescueAction` types |
| `app/main.py` or `app/briefing.py` | Optional `POST /briefing/rescue` for Tank-side replan |
| `tests/` | Swift unit tests for overload detection gate; backend tests if rescue endpoint added |

### Acceptance criteria

1. User with ≥7 events or explicit "overload" risk sees **Rescue my day** on Today without opening chat.
2. Rescue flow step 1 explains the capacity problem in plain language with visible calendar evidence.
3. Step 2 shows a revised sequencing (priorities + recommended plan) distinct from the static briefing list.
4. Step 3 offers 1–3 reversible actions; choosing one creates a pending approval or opens chat with prefilled prompt — never silent calendar mutation.
5. `ConflictResolutionSheet` overlap path still works independently for single-pair conflicts.
6. Privacy receipt shows Local/Tank route for any Tank-assisted replan.
7. iOS simulator build passes.

### Test plan

Simulator:

1. Seed calendar with 8 events including one overlap → generate briefing → confirm Rescue CTA visible.
2. Complete rescue flow → verify Activity shows pending approval or chat prompt with correct prefill.
3. Deny approval → calendar unchanged.
4. Approve low-risk nudge (when implemented) → receipt in Activity.

Backend (if `/briefing/rescue` added):

```bash
pytest tests/test_briefing.py -k rescue -v
```

Regression: existing `Resolve overlap` button on Today still opens `ConflictResolutionSheet`.

---

## Sequencing

Build **Slice 1 first**. Unified header-aligns scheduler and API quality so Day Rescue replans use the same heuristics everywhere. Slice 2 depends on trustworthy overload detection and revised-plan output from the unified builder.

---

## Related docs

| Doc | Role |
|-----|------|
| [`DAY_RESCUE_SPEC.md`](DAY_RESCUE_SPEC.md) | Day Rescue UI flow detail |
| [`BRIEFING_SLICE_SPEC.md`](BRIEFING_SLICE_SPEC.md) | Original morning briefing slice (shipped) |
| [`FEATURE_BRAINSTORM.md`](FEATURE_BRAINSTORM.md) | Full idea backlog |
| [`CURRENT_STATE.md`](CURRENT_STATE.md) | Implementation truth |
