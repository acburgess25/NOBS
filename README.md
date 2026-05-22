# NOBS

**Your private AI. No cloud. No compromise.**

NOBS is a privacy-first personal AI assistant that runs entirely on your devices — on-device with Apple Intelligence, or on your own home server. Your data never touches a third-party cloud.

## What it does
- **Memories** — Capture and recall anything about your life
- **Tasks** — Smart task management with AI context
- **HomeKit** — Control your home with natural language
- **Health** — AI that knows your health context (on-device only)
- **Voice** — Encrypted voice conversations with your AI

## Privacy
On iPhone 15 Pro / 16+: Apple Intelligence (fully on-device, free)  
On older hardware: NOBS Server subscription (your home server, no big tech)

## Building
Requires Xcode 16+, Swift 6, xcodegen.

```bash
brew install xcodegen
xcodegen generate
open NOBS.xcodeproj
```

## CI/CD
Push to `main` → GitHub Actions (Swift build check) + Xcode Cloud (TestFlight)

---
Built by [Alex Burgess](https://nobsdash.com)
