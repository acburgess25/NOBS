# App Review notes (paste into App Store Connect)

## Beta / TestFlight notes

NOBS is a local-first personal assistant prototype. This build is intended for public TestFlight beta.

### Tank is optional
- The app works fully in **Local** mode without any server.
- **Tank** is the user's self-hosted homelab API on their private network (FastAPI + Ollama).
- Reviewers can skip Sign in with Apple and skip Tank setup during onboarding.
- Manual Tank URL field in Privacy accepts `http://127.0.0.1:8000` only if a local mock server is running; not required.

### How to exercise core flows without Tank
1. Launch app → complete conversational onboarding (name, preferences, skip Sign in with Apple).
2. Open **Today** → tap **Allow Calendar access** when prompted (Simulator: Features → add sample events).
3. Tap **Create** briefing → review priorities and privacy receipt.
4. Open **Chat** → send "What's on my calendar?" → response shows **Local** badge.
5. Add **Today's plan** widget from Home Screen → tap opens Today.

### Permissions (progressive, in context)
- **Calendar** — Today briefing only; requested from Today.
- **Reminders** — briefing context; requested from Today.
- **Camera** — QR scan for Tank pairing only; Privacy → Scan QR.
- **Notifications** — at most one clarifying question per day when schedule is ambiguous; user can deny.
- **Local network** — Tank chat/sync when user configures Tank address.

### Sign in with Apple
Used to authenticate with the user's Tank. Skip is available. Not required for beta testing.

### In-app purchases
Tips and NOBScloud subscription products may appear under Privacy → Support. Tips are optional donations. NOBScloud is a future optional capacity tier—core local features remain free.

### Encryption
Uses standard HTTPS only; `ITSAppUsesNonExemptEncryption` is false.

### Contact
Alexander Burgess — use App Store Connect contact details on file.
