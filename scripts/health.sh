#!/bin/bash
# Read-only health snapshot; cleanup is explicitly preview-only.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEEP=0
for arg in "$@"; do
  case "$arg" in
    --deep) DEEP=1 ;;
    -h|--help) echo 'Usage: health.sh [--deep] (cleanup preview; no deletion)'; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
echo "Collected: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
fallback() {
  echo "WARNING: $1; native fallback follows. Missing probes are unknown, not healthy."
  bash "$SCRIPT_DIR/sysmon.sh"
}
if command -v mo >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  # Explicit JSON avoids a TUI when invoked from a terminal. Keep stderr visible.
  if raw=$(mo status --json) && summary=$(printf '%s\n' "$raw" | jq -er -f "$SCRIPT_DIR/status.jq"); then
    echo '=== MAC SYSTEM HEALTH (Mole) ==='
    printf '%s\n' "$summary"
  else
    fallback 'Mole failed or returned invalid/unsupported JSON'
  fi
else
  fallback 'Mole or jq unavailable'
fi
if [[ $DEEP == 1 ]]; then
  if ! command -v mo >/dev/null 2>&1; then
    echo 'WARNING: Cleanup preview unavailable: Mole not installed.'
    exit 1
  fi
  echo '=== CLEANUP PREVIEW (no deletion; Mole may write its preview list/logs) ==='
  # Preserve warnings and incomplete-scan messages, not just size totals.
  # No sudo, --yes, or interactive input. The caller must use a bounded tool run.
  mo clean --dry-run </dev/null
  result=$?
  if [[ $result != 0 ]]; then
    echo "WARNING: Cleanup preview failed/partial (exit $result); no complete total available." >&2
  fi
  exit "$result"
fi
