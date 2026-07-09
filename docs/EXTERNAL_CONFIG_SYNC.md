# iCloud config folder sync

Owner-only settings sync: edit JSON files in an iCloud Drive folder on your Mac; the iPhone app re-reads them on launch and when returning to the foreground.

## Setup

1. In **Files** or Finder, create a folder in iCloud Drive, e.g. `NOBS-Config`.
2. Copy the examples from [`docs/config-examples/`](config-examples/):
   - `profile.json` — name, tone, proactivity, working hours, onboarding flag
   - `tank.json` — Tank base URL only (`address`)
3. On iPhone: **Privacy → iCloud config folder → Choose iCloud folder** → select `NOBS-Config`.
4. Tap **Sync now** or background the app and reopen to pick up changes.

## Security

- **Never** put `device_token` or passwords in these files.
- Tank pairing still uses Keychain + QR / Privacy screen.
- Files sync via your personal iCloud account; treat the folder like private settings.

## Agent workflow (Cursor)

On your Mac, edit:

`~/Library/Mobile Documents/com~apple~CloudDocs/NOBS-Config/profile.json`

(or wherever you created the folder). After iCloud syncs, open NOBS on iPhone or tap **Sync now**.

## Optional fields in `profile.json`

All keys are optional; only present keys are applied.

| Key | Values |
|-----|--------|
| `displayName` | string |
| `preferredTone` | `neutral`, `warm`, `direct`, `witty` |
| `proactivityLevel` | `quiet`, `balanced`, `proactive` |
| `privacyComfort` | `localFirst`, `tankPreferred`, `cloudOk` |
| `workingHoursStart` / `workingHoursEnd` | `HH:mm` |
| `completeOnboarding` | `true` skips onboarding UI |
| `accessibilityPreferences.responseLength` | `brief`, `standard`, `detailed` |
