# Self-hosted GitHub Actions runners (free CI)

Use your own hardware instead of GitHub-hosted runners when billing blocks cloud minutes.

| Runner | Host | Labels | Workflows |
| --- | --- | --- | --- |
| **tank** | Ubuntu Tank | `self-hosted`, `linux`, `tank` | Backend CI (Python 3.11/3.12) |
| **macbook** | Your Mac + Xcode beta | `self-hosted`, `macOS`, `ARM64`, `testflight` | TestFlight, Backend CI (macOS) |

TestFlight **must** run on macOS with Xcode. Tank cannot build iOS binaries.

## One-time setup

### 1. Create a registration token

On a machine with `gh` authenticated to the repo:

```bash
gh api repos/acburgess25/NOBS/actions/runners/registration-token -X POST -q .token
```

Tokens expire in about one hour. Export it:

```bash
export GITHUB_RUNNER_TOKEN="<paste-token>"
```

### 2. Tank (Linux backend CI)

```bash
scp scripts/setup-github-runner-tank.sh tank:~/nobs/scripts/
ssh tank "export GITHUB_RUNNER_TOKEN='$GITHUB_RUNNER_TOKEN' && bash ~/nobs/scripts/setup-github-runner-tank.sh"
```

Requires `python3.11` and `python3.12` on Tank (`sudo apt install python3.11 python3.12 python3.11-venv python3.12-venv` if missing).

### 3. Mac (TestFlight)

```bash
bash scripts/setup-github-runner-mac.sh
```

Keeps the runner as a background service. Mac must be awake and online when TestFlight runs.

### 4. Verify

```bash
gh api repos/acburgess25/NOBS/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name]}'
```

## Run TestFlight

```bash
gh workflow run TestFlight --ref main
```

## Remove a runner

```bash
# On the host
cd ~/actions-runner && ./svc.sh stop && ./svc.sh uninstall
gh api repos/acburgess25/NOBS/actions/runners --jq '.runners[] | select(.name=="tank") | .id' \
  | xargs -I{} gh api repos/acburgess25/NOBS/actions/runners/{} -X DELETE
```
