# NOBS — No-BS Personal Assistant

A privacy-first, Apple-ecosystem AI assistant that acts like a real assistant: it makes phone calls, browses the web, controls your smart home, manages reminders, screens unknown callers, and chats with you over iMessage — all while keeping every learned fact on your own device.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                   NOBS Apps                     │
│   iOS App  │  macOS App  │  watchOS Complication │
└────────────┬────────────────────────────────────┘
             │  Swift Package (NOBSKit)
┌────────────▼────────────────────────────────────┐
│  NOBSAssistant  ◄──  Central Coordinator        │
│  Routes intents to the right module             │
└──┬──────┬──────┬──────┬──────┬──────┬──────────┘
   │      │      │      │      │      │
NOBSCore  │  NOBSCallKit  │  NOBSHomeKit  │
Local AI  │  (CallKit +   │  (HomeKit)    │
Client    │   Google Voice│               │
          │               │               │
     NOBSiMessage   NOBSDatabase   NOBSReminders
     (Messages.app  (Work / Personal  (EventKit)
      integration)   CoreData stores)
```

### Key Design Principles

| Principle | Implementation |
|-----------|---------------|
| **On-device privacy** | All learned context is stored in encrypted Core Data databases on the user's device. Nothing is sent to third-party clouds. |
| **Local model** | The AI runs on a user-owned server. Apps communicate via a local network REST/WebSocket API (`NOBSCore`). |
| **Work / Personal separation** | Two isolated Core Data persistent stores — every piece of information is tagged to a context at write time. |
| **Modular** | Each capability lives in its own Swift target so individual features can be shipped, tested, and updated independently. |

---

## Modules

### `NOBSCore` — AI Model Client
Connects to a locally hosted LLM server (Ollama, LM Studio, or any OpenAI-compatible endpoint).
- `ModelClient` — async HTTP client for chat completions
- `PromptBuilder` — assembles system prompts with user context
- `IntentParser` — extracts typed `AssistantIntent` values from model JSON output
- `AssistantIntent` — enum of every action the assistant can perform

### `NOBSAssistant` — Central Coordinator
Receives `AssistantIntent` values and dispatches them to the right module handler.
- Multi-turn conversation history (in-memory)
- `IntentHandler` protocol — implement to add new capabilities
- `IntentRouter` — finds the right handler for each intent

### `NOBSCallKit` — Phone Calls & Call Screening
- Outbound calls via `CXCallController`
- Inbound call screening — unknown callers are asked to identify themselves
- `CallScreener` — contact-list-based decision engine
- Google Voice bridge via `NOBSVoice`

### `NOBSiMessage` — iMessage Integration
- Receives messages via Share / Notification extension
- Sends replies through the Messages URL scheme
- On-device `ConversationHistory` stored in `NOBSDatabase`

### `NOBSHomeKit` — Smart Home
- Wraps `HomeKit` (`HMHomeManager`) to enumerate and control accessories
- Handles lights, locks, thermostats, scenes, and automations
- Graceful fallback when running on non-HomeKit platforms (tests, Linux)

### `NOBSDatabase` — Work / Personal Data Stores
- Two separate `NSPersistentContainer` stacks (never shared)
- Encrypted with `NSPersistentStoreFileProtectionKey`
- `MemoryRepository` — store and search on-device learned facts
- `TaskRepository` — create and complete user tasks

### `NOBSReminders` — Reminders & EventKit
- Creates, updates, and queries reminders via `EventKit`
- Tags each reminder with `nobs-context:personal` or `nobs-context:work`
- Handles iOS 17+ and older `requestAccess` APIs

### `NOBSVoice` — Google Voice API
- OAuth 2.0 authorization code flow
- Access token refresh management
- REST calls to place calls and send SMS via Google Voice
- `VoiceIntentHandler` bridges Google Voice into the NOBS intent pipeline

---

## Requirements

- Xcode 15+
- iOS 17+ / macOS 14+
- A locally running LLM server (e.g. [Ollama](https://ollama.com)) on the same network
- Google Cloud project with Voice API enabled (for Google Voice features)
- Apple Developer account (for CallKit, HomeKit, iMessage entitlements)

---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/acburgess25/NOBS.git
cd NOBS

# Open in Xcode
open Package.swift   # library-only work
```

### 1 — Configure your local LLM endpoint

Edit `Sources/NOBSCore/ModelClient.swift`:
```swift
ModelConfiguration.localhost   // http://127.0.0.1:11434 by default
// or supply your server IP:
ModelConfiguration(localEndpoint: URL(string: "http://192.168.1.10:11434")!)
```

Install [Ollama](https://ollama.com) on your server and pull a model:
```bash
ollama pull llama3
```

### 2 — Google Voice API

1. Create credentials in [Google Cloud Console](https://console.cloud.google.com).
2. Enable the **Google Voice** and **Cloud Speech-to-Text** APIs.
3. Pass credentials to `VoiceClient` (store `clientID` / `clientSecret` in the iOS Keychain — never in source files).

### 3 — Apple Entitlements

In your Xcode app target, enable:
- `HomeKit`
- `Siri`
- `CallKit` (com.apple.developer.callkit)
- `iMessage Extension`

Add `NSRemindersUsageDescription` to `Info.plist`.

---

## Privacy

- **No cloud sync of personal data.** Core Data stores live in the app's sandboxed container.
- **Work and Personal databases never mix** at the storage layer.
- **Google Voice credentials** are stored in the iOS Keychain, never in plain text.
- **Call screening decisions** are made on-device; audio is never uploaded.
- **Conversation history** is stored locally and never leaves the device.
