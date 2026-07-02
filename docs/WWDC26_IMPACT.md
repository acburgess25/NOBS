# WWDC26 Impact on NOBS

**Status:** Architecture input  
**Reviewed:** July 1, 2026  
**Source policy:** Apple announcements, developer documentation, release notes, and WWDC26 sessions only.

## Executive Decision

WWDC26 materially improves the feasibility of NOBS and changes the implementation order.

NOBS should not build a parallel Apple intelligence stack where Apple now provides a privacy-preserving system primitive. It should use Apple frameworks for device-local inference, Siri distribution, system actions, media surfaces, indexing, testing, and model integration while preserving NOBS's differentiators:

- one assistant across Apple, Google, Amazon, and user-owned hardware;
- transparent Local, Tank, and NOBScloud routing;
- user-owned Tank and future NOBSbox compute;
- sourced overnight research;
- custom skill generation and scanning;
- no data monetization, artificial limits, or forced hardware churn.

Apple's complete WWDC26 catalog contains more than 100 sessions. The authoritative indexes are Apple's [WWDC26 video library](https://developer.apple.com/videos/wwdc2026/) and [developer updates page](https://developer.apple.com/whats-new/).

## 1. Strategic Change: Siri AI

Apple introduced Siri AI with:

- natural, multi-turn conversation;
- personal-context retrieval across messages, email, photos, notes, and other sources;
- onscreen and camera understanding;
- web-backed current information;
- expanded cross-app actions;
- a dedicated Siri conversation app with iCloud history sync.

Sources: [Apple's WWDC26 announcement](https://www.apple.com/newsroom/2026/06/apple-unveils-next-generation-of-apple-intelligence-siri-ai-and-more/) and the [iOS 27 preview](https://www.apple.com/os/ios/).

### NOBS decision

Siri AI is both a distribution surface and the nearest direct competitor.

NOBS should:

1. expose useful NOBS actions through App Intents and App Schemas;
2. allow Siri to hand an explicit NOBS request into the NOBS intent router;
3. preserve NOBS-owned memory, Tank research, home translation, and routing transparency;
4. avoid duplicating generic Siri features unless NOBS adds privacy, cross-platform continuity, sourced knowledge, or automation value;
5. keep the NOBS app as the authoritative place for activity, memory, privacy receipts, household orchestration, and research.

## 2. Foundation Models as the Apple-Side Router

The Foundation Models framework now supports:

- on-device Apple models;
- Private Cloud Compute models;
- external server providers;
- Core AI custom models;
- dynamic model profiles;
- structured generation and tool calling;
- agentic app patterns;
- improved error types;
- an `fm` CLI and Python SDK.

Sources: [Foundation Models documentation](https://developer.apple.com/documentation/FoundationModels/), [Foundation Models updates](https://developer.apple.com/documentation/Updates/FoundationModels), and WWDC26 sessions for agentic apps, external providers, Private Cloud Compute, and the `fm` tools in the [session library](https://developer.apple.com/videos/wwdc2026/).

### NOBS decision

Create a NOBS model abstraction with a stable, platform-neutral request contract. On Apple platforms, adapt it to Foundation Models. Candidate routes are:

| Route | Purpose | Default trust posture |
|---|---|---|
| iPhone on-device | Everyday private assistance | Default |
| Core AI model | Specialized local capability | Local-only |
| Tank provider | Larger private household model | Preferred at home |
| Private Cloud Compute | Apple privacy-preserving escalation | Optional |
| NOBScloud provider | Cross-platform heavy work and continuity | Paid and policy-controlled |

The router must expose the selected route, reason, data categories, fallback, and privacy receipt. The shared NOBS contract must not require Foundation Models so Windows Tank and future NOBSbox implementations remain portable.

## 3. App Intents, App Schemas, and Shortcuts

WWDC26 expands App Intents with:

- App Schema conformance for Siri and Apple Intelligence domains;
- richer app entities and enums;
- `IntentFile` for content shared by other apps;
- advanced Siri actions;
- `AppIntentsTesting` validation;
- natural-language Shortcut creation.

Sources: [App Intents updates](https://developer.apple.com/documentation/Updates/AppIntents), [AppIntent](https://developer.apple.com/documentation/AppIntents/AppIntent), and the WWDC26 App Intents, App Schemas, Shortcuts, and testing sessions in the [video library](https://developer.apple.com/videos/wwdc2026/).

### NOBS decision

App Intents become an MVP architecture boundary, not a late integration.

Initial intent families:

- prepare or summarize my day;
- capture a commitment;
- create or update a reminder;
- explain a schedule conflict;
- start a NOBS conversation;
- run an approved home intention;
- query a Research Library topic;
- show recent NOBS activity or privacy receipt.

Every intent must define confirmation behavior, sensitive inputs, offline behavior, and a deterministic error state.

## 4. Core AI and MLX

Core AI provides a system path for importing, optimizing, and vending custom on-device models in a form usable by Foundation Models. Apple also expanded MLX for local agentic AI, numerical computing, and distributed inference and training.

Sources: Apple's [platform update index](https://developer.apple.com/documentation/updates?changes=latest_major), the Core AI sessions, and the MLX sessions in the [WWDC26 library](https://developer.apple.com/videos/wwdc2026/).

### NOBS decision

- Use Core AI for Apple-specific compact or specialized models when it improves privacy, latency, or offline function.
- Keep Ollama/portable providers on Tank behind the shared model contract.
- Treat MLX as a future macOS/NOBSbox research path, not an iPhone MVP dependency.
- Do not train on private user information by default. “Learning” updates approved memory, retrieval, preferences, or local adapters under an explicit policy.

## 5. Evaluations and Agent Security

WWDC26 introduced an Evaluations framework and sessions covering:

- robust agent evaluation;
- prompt improvement with hill-climbing;
- Instruments profiling for agentic apps;
- threat mitigation for agentic features;
- App Attest;
- Trust Insights.

Sources: the Evaluations, Instruments, agent-security, App Attest, and Trust Insights sessions in the [WWDC26 library](https://developer.apple.com/videos/wwdc2026/) and [Bundle Resources updates](https://developer.apple.com/documentation/updates/bundleresources?changes=_2%2C_2).

### NOBS decision

No NOBS agent, skill, model route, or high-impact automation is production-ready without evaluation.

Required suites:

- correctness and structured-output conformance;
- privacy-route adherence;
- unsupported-feature honesty;
- confirmation and automation boundaries;
- prompt-injection resistance;
- sensitive-data minimization;
- hallucination and citation quality;
- offline and dependency-failure behavior;
- latency and resource use;
- accessibility of generated responses.

Generated and community skills must still pass the NOBS Skill Policy. Apple tooling supplements rather than replaces NOBS scanning and sandboxing.

## 6. Research Library and Core Spotlight

WWDC26 includes LLM search with Core Spotlight.

Source: “LLM search using Core Spotlight” in the [WWDC26 session library](https://developer.apple.com/videos/wwdc2026/).

### NOBS decision

Index approved Research Library summaries and metadata locally so users can retrieve NOBS knowledge from Apple system search without uploading the complete library.

Indexable fields may include:

- title and concise summary;
- topic and project links;
- source count and confidence;
- last-updated date;
- safe deep link into NOBS.

Private source contents, health context, household secrets, or protected memory should not be indexed unless the user explicitly opts in.

## 7. Media Continuity

WWDC26 introduced:

- a cross-platform Now Playing Swift framework;
- remote media sessions for playback on external devices;
- Music Understanding for rhythm, pace, loudness, key, and instrument activity;
- MusicKit updates;
- generated subtitles and subtitle styles;
- conversational CarPlay apps;
- Live Activities and WidgetKit guidance.

Sources: [Now Playing framework session](https://developer.apple.com/videos/play/wwdc2026/312/), [Music Understanding documentation](https://developer.apple.com/documentation/MusicUnderstanding), and the audio/video sessions in the [WWDC26 library](https://developer.apple.com/videos/wwdc2026/).

### NOBS decision

Use Now Playing remote media sessions as the Apple-facing representation for Tank- or household-device playback where supported. This is directly aligned with NOBS's goal of continuing music, podcasts, briefings, and media controls across phone, car, headphones, speakers, Watch, Apple TV, and Vision Pro.

Music Understanding is exploratory. It may improve context-aware media selection but must not become a covert mood-profiling mechanism.

## 8. Home Intelligence

iOS 27 adds:

- combined intelligent Home activity notifications;
- descriptions and natural-language search for HomeKit Secure Video;
- 4K camera streaming and recording on supported hardware.

These features have device, home-hub, Apple Intelligence, and in some cases iCloud+ requirements. Source: [iOS 27 Home features and availability notes](https://www.apple.com/os/ios/).

### NOBS decision

Do not duplicate Apple's camera intelligence. NOBS should unify the event with:

- non-Apple smart-home systems;
- household roles and privacy;
- activity history;
- routines and response options;
- Tank-local research and diagnostics;
- cross-platform notification routing.

Home Assistant/Tank remains the translation layer. Apple Home remains a first-class endpoint.

## 9. Xcode 27 and Device Hub

Xcode 27 adds:

- agent plugins with skills, MCP servers, and agent configurations;
- Agent Client Protocol support;
- agent filesystem security controls;
- agent-assisted UI prototyping and translation;
- Device Hub for simulated and physical devices;
- Swift 6.4 and updated platform SDKs;
- performance and agentic debugging improvements.

Sources: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes), [Device Hub documentation](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub), and “What's new in Xcode 27” in the [session library](https://developer.apple.com/videos/wwdc2026/).

### NOBS decision

The iOS QA matrix should include:

- compact and large iPhone simulators;
- iPad layout when added;
- light/dark appearance;
- Dynamic Type and accessibility sizes;
- reduced motion and increased contrast;
- offline, Tank offline, and cloud-disabled states;
- permission denied, limited, and granted states;
- physical-device testing for hardware-dependent frameworks.

Device Hub centralizes the destinations. Automated `xcodebuild` and `simctl` checks remain useful for repeatable CI and screenshot comparison.

## 10. Platform Opportunities

### iOS 27

Relevant additions include Siri AI, contextual suggestions, Call Context, natural-language Shortcuts, Home intelligence, improved accessibility, translated generated captions, system performance work, and Liquid Glass refinements. Source: [iOS 27 preview](https://www.apple.com/os/ios/).

### iPadOS 27

Relevant additions include Siri AI, Visual Intelligence for onscreen content, productivity-oriented Apple Intelligence, and the same App Intents surface. Source: [iPadOS 27 preview](https://www.apple.com/os/ipados/).

### macOS 27 Golden Gate

Relevant additions include Siri AI in Spotlight, onscreen Visual Intelligence, local MLX agentic workflows, and virtualization/container improvements. Source: [macOS 27 preview](https://www.apple.com/os/macos/).

### watchOS 27

Relevant additions include Siri AI, a dedicated Siri app, Smart Stack access through a single-tap gesture, Workout Buddy, and health insights. Source: [watchOS 27 preview](https://www.apple.com/os/watchos/).

### visionOS 27

Relevant additions include gaze-aware Siri and Visual Intelligence, spatial Mac model preview, Reality Composer Pro 3, RealityKit and object-tracking improvements, USDKit/OpenUSD, spatial web environments, and immersive-video tools. Source: [visionOS 27 preview](https://www.apple.com/os/visionos/).

### tvOS 27

Relevant developer changes include Dynamic Type and the cross-platform Now Playing/media work. Source: the tvOS and audio/video sessions in the [WWDC26 library](https://developer.apple.com/videos/wwdc2026/).

## 11. Other Frameworks to Track

The following are not immediate NOBS MVP dependencies but have credible future value:

- Bluetooth Channel Sounding for accessory proximity;
- new MetricKit performance signals;
- PaperKit and PencilKit;
- Center Stage and high-resolution camera APIs;
- gRPC for Swift;
- Metal tensors and neural rendering;
- WebKit 27, web extensions, CSS Grid Lanes, and the HTML model element;
- StoreKit Background Assets;
- subscriptions for groups and organizations;
- Wallet updates and App Store retention messaging;
- Reality Composer Pro 3 and Spatial Preview.

## 12. Immediate Technical Roadmap

Complete these in order before deep feature implementation:

1. **Model-routing spike:** prove Foundation Models abstraction with on-device and mock Tank/provider routes.
2. **App Schema inventory:** map NOBS actions to available schema domains and identify custom intents.
3. **Intent contract:** define confirmation, offline, sensitive-input, and failure behavior.
4. **Core AI feasibility:** test one small specialized model and document device constraints.
5. **Evaluation harness:** establish deterministic cases for privacy, routing, honesty, and structured output.
6. **Agent-security review:** threat-model model tools, app intents, research ingestion, and generated skills.
7. **Spotlight index prototype:** index a safe mock Research Library entry and deep-link into NOBS.
8. **Now Playing prototype:** represent mock Tank playback as a remote media session.
9. **Device Hub matrix:** automate build and screenshot capture on representative simulators.
10. **Siri boundary review:** document what Siri owns, what NOBS owns, and where explicit handoff occurs.

## 13. Release Gate

WWDC26 APIs are beta. Any implementation must be tested again against final Xcode and operating-system releases. Prompt behavior must be reevaluated when Apple's built-in model changes.
