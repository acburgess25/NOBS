# NOBS — iOS UI Kit

> Your private AI. No cloud. No compromise.

A complete iOS app UI kit for **NOBS** — a privacy-first personal AI that runs entirely on the user's local network. This file is what you ship to engineering. Open `NOBS UI Kit.html` to view the full design canvas.

---

## What's in the canvas

| Section | Contents |
|---|---|
| **Cover** | Brand at a glance, four-color palette |
| **Design system** | Color (light + dark), Type scale, Spacing & radii, Components, App icon |
| **Onboarding** | Welcome + all 5 steps (light), Step 3 (dark) |
| **Memories** | Card feed, Personal/Work toggle (light + dark) |
| **Tasks** | Pending + Completed sections, animated checkboxes (light + dark) |
| **More · Tools** | Reminders, HomeKit, Health, Integrations (light + dark) |
| **Settings** | Account, privacy, danger zone (light + dark) |
| **States** | Empty Memories, Add Memory (keyboard up), Memory Detail, HomeKit Quick Sheet |
| **Handoff** | SwiftUI token export, component anatomy, implementation notes |

Drag artboards to reorder, double-click labels to rename. Hit the expand icon on any artboard to view it fullscreen with ←/→/↑/↓ navigation.

---

## Visual direction — Warm & Human

| | Value |
|---|---|
| Light background | `#FAF8F5` warm off-white |
| Dark background | `#1C1917` deep warm charcoal |
| Primary action | `#D97706` amber |
| Done / safe | `#65A36E` sage |
| Danger | `#C75D5D` rose |
| Type | SF Pro Rounded (`design: .rounded`) |
| Radii | 16–22pt for cards, full for pills |
| Shadows | Warm soft elevation instead of harsh dividers |
| Hit targets | ≥ 44pt always |

---

## Lifting into SwiftUI

The **Swift tokens** artboard in the canvas contains a copy-paste-ready `NOBSTheme.swift`. It exports:

- `NOBSColor` — all light + dark surface colors + brand accents
- `NOBSRadius` — `sm` through `xl3` + `pill`
- `NOBSSpace` — 4pt grid (`s1`–`s8`)
- `NOBSFont` — rounded type ramp matching the kit 1:1

Read the **Handoff notes** artboard for the eight rules that turn this kit into a real product (type stack, color modes, radii intentions, shadows-over-separators, etc).

---

## File layout

```
NOBS UI Kit.html          ← open this
nobs-tokens.jsx           ← colors, type, radii, spacing, icons
nobs-components.jsx       ← buttons, cards, rows, switches, tab bar, logomark
nobs-screens.jsx          ← all six screens + state variants
nobs-system.jsx           ← design system documentation artboards
nobs-spec.jsx             ← Swift token export, anatomy, handoff notes
design-canvas.jsx         ← pan/zoom canvas host (starter)
ios-frame.jsx             ← iPhone 16 Pro device chrome (starter)
```

iPhone 16 Pro: **393 × 852pt** (logical).
