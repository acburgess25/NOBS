# Scripts

Forty scripts live here. Almost all of them are operational tooling you will
never need. Grouped below so you can tell which is which.

## Start here

`scripts/dev.py` is the only script most contributors run. It is the
cross-platform entrypoint for the backend and works on macOS, Linux, and
Windows without a shell of its own.

```bash
python3 scripts/dev.py setup    # create .venv and install dependencies
python3 scripts/dev.py check    # tests, lint, and formatting
python3 scripts/dev.py format   # apply formatting
python3 scripts/dev.py run      # serve the API with reload
```

`setup.sh` and `setup.ps1` are one-line conveniences that call
`dev.py setup` for you; `make install` does the same.

## Development and local AI

| Script | Purpose |
|---|---|
| `dev.py` | Cross-platform backend entrypoint (setup, test, lint, format, run, check) |
| `setup.sh` / `setup.ps1` | Thin wrappers around `dev.py setup` for shell and PowerShell |
| `setup-local-ai.sh` / `setup-local-ai.ps1` | Pull Ollama models and install Open WebUI + Aider into local venvs |
| `pairing.py` | Generate a device token and print a pairing QR code |
| `analyze_tank_logs.py` | Summarize a Tank API log through a local Ollama model |
| `create_test_schedule.py` | Insert a briefing schedule row directly for testing |
| `test_trigger.py` | Fire the autonomous idea trigger against a local store |
| `generate_app_icons.py` | Generate the app icon set and website favicons |
| `build_stack_docs.py` | Regenerate `docs/research/STACK.md` from `stack.json` (`--check` in tests) |

## Tank operation and deployment

| Script | Purpose |
|---|---|
| `deploy-tank.sh` | Deploy the backend to the Linux Tank from this checkout |
| `deploy-dream-team.sh` | Deploy the Dream Team Sandbox to Tank |
| `deploy-nobsdash.sh` | Build and deploy the public website to its Tank origin |
| `reset-tank-fresh.sh` | Reset a Tank to clean first-run state |
| `install-tank-launchagent.sh` | Install the macOS LaunchAgent that runs the local Tank API |
| `setup-kiosk-host.sh` | One-time host setup so Tank's display boots into the dashboard |
| `start-dashboard-kiosk.sh` | Wait for the API, then open the dashboard in kiosk mode |
| `launch-dashboard-mac.sh` | Open the dashboard on macOS once the backend is up |
| `run_research.py` | Trigger one system-wide research and proposal cycle |
| `research_team.py` | Run one shift of the local research team |

## iOS build and test

| Script | Purpose |
|---|---|
| `build-ios-simulator.sh` | Build for the iOS Simulator without code signing |
| `test-ios.sh` | Run NOBSTests on the iOS Simulator without code signing |
| `stage-testflight-ipa.sh` | Build a release IPA and stage it for the upload-only workflow |

## Apple signing and App Store Connect

These automate certificate, profile, and capability management through the App
Store Connect API. They touch a real Apple Developer account — read before running.

| Script | Purpose |
|---|---|
| `validate-asc-api.py` | Validate App Store Connect API credentials |
| `ci-prepare-keychain.sh` | Create or reuse the persistent CI keychain |
| `ci-ensure-signing-certs.sh` | Ensure the CI keychain holds Development + Distribution identities |
| `ci-check-distribution-cert.py` | Exit 0 if a Distribution certificate still exists |
| `ci-create-app-store-profiles.py` | Create and install App Store provisioning profiles |
| `ci-refresh-provisioning-profiles.sh` | Recreate provisioning profiles for all targets |
| `refresh-app-store-connect-signing.sh` | Re-sync signing assets without a manual `.p12` export |
| `ci-enable-bundle-capabilities.py` | Enable the bundle capabilities profiles require |
| `ci-revoke-development-certs.py` | Revoke Apple Development certificates |
| `ci-revoke-distribution-certs.py` | Revoke Apple Distribution certificates |
| `ci-cleanup-apple-account.py` | Remove non-NOBS signing assets from the account |

## Repository and infrastructure

| Script | Purpose |
|---|---|
| `setup-github-runner-mac.sh` | Install a self-hosted Actions runner on a Mac |
| `setup-github-runner-tank.sh` | Install a self-hosted Actions runner on Tank |
| `github-deep-clean.sh` | Clean stale branches, workflow runs, and Actions caches |
| `setup_stripe_support_links.py` | Create Stripe test payment links for the website |
