# Google Home integration — architecture and learning path

**Status:** Approved direction (not yet shipped)  
**Last updated:** July 7, 2026  
**Product authority:** [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §11 (Unified Smart Home)

Google Home and Amazon Alexa unification remain **coming soon** in the iPhone app until Tank + Home Assistant paths are reliable end-to-end. The app must not claim a device action ran unless it did.

---

## Decision summary

| Question | Decision |
|----------|----------|
| Integrate Google Home directly in the iPhone app first? | **No.** Tank is the private intent router; Home Assistant is the translation layer. |
| How does NOBS control Google-linked devices? | Import devices into **Home Assistant** (Nest, vendor integrations, Matter), then use existing Tank agent tools. |
| When do we add Google Home APIs directly? | **After** HA bridge is proven — OAuth on Tank or in-app Home setup, with Activity approvals. |
| Cloud-to-cloud Google integration (manufacturer path)? | **Out of scope.** That is for device makers, not NOBS. |
| iPhone Home tab today? | `ComingSoonView` — honest placeholder until read-only device list + approvals ship. |

---

## Architecture

```text
iPhone (Chat / Home tab / Activity)
        │  device token
        ▼
Tank agent + allowlisted tools
        │
        ├── list_home_devices        (read-only)
        ├── control_home_device      (approval-gated)
        └── control_secure_home_device (approval-gated, locks/alarms)
        │
        ▼
Home Assistant (LAN)
        │
        ├── Google Nest (SDM API)
        ├── Vendor clouds (Hue, Tuya, …)
        ├── Matter devices
        └── google_assistant / Matter hub (bidirectional, later)
        │
        ▼
Google Home / Nest Hub / Assistant speakers
```

**Voice from Google toward NOBS** (e.g. “Hey Google, good night”) is a separate, later path via Home Assistant’s [Google Assistant integration](https://www.home-assistant.io/integrations/google_assistant/) or Google Home APIs — not the first milestone.

---

## What exists in the repo today

| Component | Location |
|-----------|----------|
| Home Assistant HTTP client | `app/home_assistant.py` |
| Agent tools | `list_home_devices`, `control_home_device`, `control_secure_home_device` in `app/agent_tools.py` |
| Tank config | `NOBS_HOMEASSISTANT_URL`, `NOBS_HOMEASSISTANT_TOKEN` in `app/config.py` |
| Tests | `tests/test_home_assistant.py` |
| Honest chat fallback | `NOBS/AppModel.swift` — Google/Alexa unification “coming soon” |
| Home tab placeholder | `NOBS/ConversationView.swift` → `ComingSoonView` |

---

## Integration paths (learn in this order)

### 1. Home Assistant on Tank (near-term — matches product sequencing)

1. Run Home Assistant on the LAN (Docker, VM, or dedicated host).
2. Add controllable entities (demo integration, smart plug, or Nest via [HA Nest integration](https://www.home-assistant.io/integrations/nest/)).
3. Create a [long-lived access token](https://developers.home-assistant.io/docs/auth_api/#long-lived-access-token).
4. Configure Tank:
   ```bash
   NOBS_HOMEASSISTANT_URL=http://192.168.x.x:8123
   NOBS_HOMEASSISTANT_TOKEN=<token>
   ```
5. Chat: *“What smart home devices do you see?”* → agent calls `list_home_devices`.
6. Request a state change → flows through **Activity approvals** before execution.

This is Google Home inside NOBS **without** a Google SDK in Swift: Google-linked gear appears as HA entities.

### 2. Nest / Google Device Access (official Nest API)

For Nest thermostats, cameras, doorbells:

- [Google Nest Device Access](https://developers.google.com/nest/device-access) — one-time **$5** fee, OAuth, Pub/Sub for events.
- Home Assistant [Nest integration](https://www.home-assistant.io/integrations/nest/) walks through Google Cloud + Device Access setup.
- Troubleshooting: [Partner Connections Manager](https://nestservices.google.com/partnerconnections) when entities go unavailable.

### 3. Google Home APIs (medium-term, direct)

Google’s newer [Home APIs](https://developers.home.google.com/) (structures, rooms, devices, traits, OAuth) may eventually allow Tank or the iPhone app to talk to Google’s graph directly.

- Prefer **OAuth on Tank** first (tokens stay off the phone).
- Any direct iOS OAuth needs a clear privacy story and App Review notes.
- Do **not** ship until Activity/approval UI covers home actions.

### 4. Matter bridge (bidirectional unification)

[Home Assistant Matter Hub](https://riddix.github.io/home-assistant-matter-hub/) can expose HA entities to Google Home locally. Useful when “make my home one” reconciliation is ready — not for beta.

---

## What we are not building

- **Cloud-to-cloud** integration as a device manufacturer ([Google C2C program](https://developers.home.google.com/cloud-to-cloud)).
- Silent control of locks, alarms, or garage doors without approval.
- Claiming Google Home control in chat when HA is not configured.

---

## Near-term implementation slices

1. **Tank:** surface HA configuration status in `/health` or chat errors when unset.
2. **iOS Home tab:** read-only device list from Tank (`list_home_devices` via API) — no Google SDK yet.
3. **Activity:** show home control proposals with entity name, service, and route (Local/Tank).
4. **Docs:** keep this file updated when the first Google-linked device is verified on a real home network.

---

## References

- Product: [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §11  
- Tank tools: [`docs/TOOL_EXPANSION.md`](TOOL_EXPANSION.md)  
- Apple + HA layering: [`docs/WWDC26_IMPACT.md`](WWDC26_IMPACT.md) §8, [`docs/NOBS_Apple_Integration_Map.md`](NOBS_Apple_Integration_Map.md)  
- Google Home developers: [developers.home.google.com](https://developers.home.google.com/)  
- Home Assistant Nest: [home-assistant.io/integrations/nest](https://www.home-assistant.io/integrations/nest/)
