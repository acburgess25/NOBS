# NOBS Initial Conversation Design QA

## Evidence

- Source of visual truth: `/Users/ab/Documents/NOBS/design/nobs-option-3-reference.png`
- Implementation capture: `/Users/ab/Documents/NOBS/design/qa/nobs-implementation-v4.png`
- Side-by-side comparison: `/Users/ab/Documents/NOBS/design/qa/nobs-comparison-v4.png`
- Viewport: iPhone 17 Pro simulator on iOS 27, normalized to 390 x 844 for comparison
- State: initial light-mode conversation using the local sample agenda

The full-screen comparison is sufficient for both layout and detail review because all typography, controls, dividers, agenda rows, suggestion chips, and composer elements remain legible at the normalized viewport.

## Review

- Typography: editorial serif greeting, rounded NOBS wordmark, body hierarchy, metadata, and green emphasis match the reference intent.
- Spacing and layout: the header, introduction, highlight, divider, message, complete five-item agenda, suggestion strip, and composer fit without overlap or hidden content.
- Color: warm canvas, dark evergreen text, sage accents, translucent message bubble, and low-contrast rules remain faithful to the approved direction.
- Controls: the processing badge, synopsis affordance, suggestion chips, add button, voice button, and send button use native controls with appropriate visual states.
- Copy: the approved sample conversation is preserved. Interactive preview responses clearly identify unavailable integrations as coming soon and never claim access that is not implemented.
- Device chrome: the simulator's status bar and Dynamic Island differ from the generated concept image; this is expected platform chrome, not an app discrepancy.

## Corrections Applied

- Rebalanced type sizes and vertical rhythm from the first implementation pass.
- Restored the sage local-status indicator and made processing details inspectable.
- Tightened the introduction, highlight, divider, user-message, and agenda spacing so all five agenda items remain visible above the composer.
- Added honest local, Tank, and NOBScloud route metadata for preview responses.

No P0, P1, or P2 visual discrepancies remain in the tested state.

final result: passed
