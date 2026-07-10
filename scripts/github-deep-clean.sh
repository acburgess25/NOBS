#!/usr/bin/env bash
# Deep-clean GitHub repo state: stale branches, workflow runs, and Actions caches.
# Usage: GITHUB_REPO=owner/name bash scripts/github-deep-clean.sh [--execute]
set -euo pipefail

REPO="${GITHUB_REPO:-acburgess25/NOBS}"
EXECUTE=false
if [[ "${1:-}" == "--execute" ]]; then
  EXECUTE=true
fi

log() { printf '%s\n' "$*"; }
run() {
  if $EXECUTE; then
    "$@"
  else
    log "[dry-run] $*"
  fi
}

log "=== GitHub deep clean for ${REPO} ==="
log "Mode: $($EXECUTE && echo EXECUTE || echo dry-run)"
log ""

MERGED_BRANCHES=(
  claude/ios-visual-polish
  human/ios-approval-live-activity
  human/ios-external-config-sync
)

STALE_OPEN_BRANCHES=(
  human/backend-platform
  human/docs-brainstorm
  human/docs-qa-framework
  human/ios-coordinators-refactor
  human/ios-day-rescue
  human/ios-pairing-code
  human/ios-product-features
  human/ios-tank-connectivity
  human/tank-ops-hardening
  human/tank-unified-briefing
)

CLOSE_COMMENT=$'Closed during repo deep-clean: branch is stale (50+ commits behind main).\n\nRe-open from a fresh branch when you are ready to ship this work.'

log "== Close stale open PRs =="
for branch in "${STALE_OPEN_BRANCHES[@]}"; do
  pr="$(gh pr list --repo "$REPO" --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null || true)"
  if [[ -n "$pr" && "$pr" != "null" ]]; then
    run gh pr close "$pr" --repo "$REPO" --comment "$CLOSE_COMMENT"
    log "Closed PR #${pr} (${branch})"
  fi
done

log ""
log "== Delete merged remote branches =="
for branch in "${MERGED_BRANCHES[@]}"; do
  if gh api "repos/${REPO}/git/ref/heads/${branch}" >/dev/null 2>&1; then
    run gh api --method DELETE "repos/${REPO}/git/refs/heads/${branch}"
    log "Deleted merged branch ${branch}"
  fi
done

log ""
log "== Delete stale feature branches =="
for branch in "${STALE_OPEN_BRANCHES[@]}"; do
  if gh api "repos/${REPO}/git/ref/heads/${branch}" >/dev/null 2>&1; then
    run gh api --method DELETE "repos/${REPO}/git/refs/heads/${branch}"
    log "Deleted stale branch ${branch}"
  fi
done

log ""
log "== Purge Actions caches =="
if $EXECUTE; then
  if gh cache list --repo "$REPO" --limit 100 --json id -q 'length' 2>/dev/null | grep -qv '^0$'; then
    gh cache delete --all --repo "$REPO" || true
    log "Purged Actions caches"
  else
    log "No Actions caches to purge"
  fi
else
  count="$(gh api "repos/${REPO}/actions/caches" -q '.total_count' 2>/dev/null || echo 0)"
  log "[dry-run] Would purge ${count} Actions cache entries"
fi

log ""
log "== Delete workflow runs (failed, cancelled, then remaining) =="
delete_runs() {
  local status="$1"
  local deleted=0
  while true; do
    ids="$(gh run list --repo "$REPO" --limit 100 --status "$status" --json databaseId -q '.[].databaseId' 2>/dev/null || true)"
    [[ -z "$ids" ]] && break
    for id in $ids; do
      if $EXECUTE; then
        gh run delete "$id" --repo "$REPO" >/dev/null 2>&1 || true
      fi
      deleted=$((deleted + 1))
    done
    $EXECUTE || break
  done
  log "${status}: ${deleted} run(s)"
}

for status in failure cancelled success; do
  delete_runs "$status"
done

log ""
log "Done."
