# App Privacy nutrition labels (draft)

Complete the questionnaire in App Store Connect. This is the intended honest mapping for the beta build.

## Data linked to you
| Data type | Collected | Purpose | Notes |
|-----------|-----------|---------|-------|
| Name | Optional | App functionality | Onboarding display name, stored on device |
| User ID | Optional | App functionality | Sign in with Apple identifier for Tank auth |
| Calendar | Optional | App functionality | Same-day events for briefing; not uploaded to NOBS servers |
| Other user content | Optional | App functionality | Chat text; processed Local or user-configured Tank |

## Data not collected for NOBS company servers
NOBS does not operate a mandatory cloud backend in this beta. Tank is user-controlled infrastructure.

## Data used to track you
**None** — no tracking across apps or websites.

## Local network
Used only when the user configures a Tank URL to reach their private server.

## Third-party AI
When Tank is connected, chat/briefing may be processed on the user's Tank with local Ollama. No OpenAI/Anthropic by default.
