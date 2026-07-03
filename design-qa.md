# NOBS Portfolio Design QA

- **Source visual truth:** `design/nobs-portfolio-workshop-reference.png`
- **Implementation screenshots:** `website/qa-hero.png`, `website/qa-architecture.png`, `website/qa-work.png`, `website/qa-roadmap.png`, and `website/qa-mobile.png`
- **Combined comparison evidence:** `website/qa-comparison.png`
- **Viewports:** 1440 × 1024 desktop and 390 × 844 mobile
**State:** default hero; architecture; work-so-far; first roadmap item expanded; mobile default and menu-open states

## Findings

No actionable P0, P1, or P2 mismatches remain.

- **Fonts and typography:** Newsreader reproduces the editorial display character of the visual target; DM Sans provides a restrained, readable UI/body face. Display scale, optical contrast, line height, and mobile wrapping preserve the reference hierarchy.
- **Spacing and layout rhythm:** The desktop hero retains the reference's asymmetric copy/product composition, large quiet margins, thin rules, and artifact-like code panel. Longer content is intentionally separated into interactive page sections instead of compressing all progress into one static grid. Mobile collapses cleanly without horizontal overflow.
- **Colors and visual tokens:** Cream, deep forest, sage, muted gray-green, and lightly tinted section surfaces closely match the source. State indicators retain non-color labels.
- **Image quality and asset fidelity:** The approved NOBS app screenshot is used directly and remains sharp and legible. Phosphor icons replace interface glyphs; no placeholder art, emoji, or handcrafted SVG assets are present.
- **Copy and content:** The implementation keeps the personal build-in-public framing, names Alexander Burgess, distinguishes Local/Tank/NOBScloud, and labels unfinished work honestly. Claims are grounded in the current repository.
- **Interaction and accessibility:** Desktop and mobile navigation work, the menu exposes correct expanded state, roadmap controls expose `aria-expanded`, focus states are visible, the health artifact supplies feedback, semantic headings are ordered, and reduced-motion preferences are respected.

## Patches made during QA

- Replaced an unavailable icon export with the matching Phosphor `HardDrives` icon.
- Added the pnpm workspace build allowlist needed for Vite's esbuild binary.
- Removed global smooth-scroll behavior that interfered with deterministic capture while retaining explicit smooth navigation.
- Verified mobile navigation closes after selecting Architecture.
- Verified the roadmap accordion opens the selected step.

## Full-view and focused comparison

`website/qa-comparison.png` places the source visual and all four implemented desktop regions in the same comparison canvas. Focused captures were required because the reference compresses a complete page into one tall board while the implementation gives each interactive section a full viewport of breathing room.

## Follow-up polish

- [P3] Add a custom social-sharing image and favicon before public deployment.
- [P3] Consider self-hosting the two Google fonts before production to remove a third-party font request.

## Implementation checklist

- [x] Faithful responsive hero
- [x] Approved product screenshot
- [x] Interactive desktop and mobile navigation
- [x] Responsive system architecture
- [x] Evidence-backed progress section
- [x] Expandable roadmap
- [x] Production build
- [x] Desktop and mobile visual QA

final result: passed
