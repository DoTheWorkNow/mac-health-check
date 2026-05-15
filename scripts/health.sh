#!/bin/bash
# Mac Health Check orchestrator.
# Prefers Mole (mo status) for rich data; falls back to sysmon.sh otherwise.
# Usage: health.sh [--deep]
#   --deep : also run `mo clean --dry-run` and append cleanup summary

set -u

DEEP=0
[[ "${1:-}" == "--deep" ]] && DEEP=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v mo >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  # Fallback: legacy sysmon (no Mole or no jq)
  echo "=== MAC SYSTEM HEALTH (legacy sysmon) ==="
  echo "Note: install mole (brew install tw93/tap/mole) + jq for richer output"
  echo ""
  bash "$SCRIPT_DIR/sysmon.sh"
  exit 0
fi

raw=$(mo status 2>/dev/null)
if [[ -z "$raw" ]]; then
  echo "mo status returned empty, falling back to sysmon"
  bash "$SCRIPT_DIR/sysmon.sh"
  exit 0
fi

echo "=== MAC SYSTEM HEALTH (Mole) ==="
echo "$raw" | jq -r '
  def gb: . / 1073741824 | . * 10 | round / 10;

  "## Snapshot",
  "Score: \(.health_score) — \(.health_score_msg)",
  "Hardware: \(.hardware.model) · \(.hardware.cpu_model) · \(.hardware.os_version)",
  "Uptime: \(.uptime) | Processes: \(.procs)",
  (if .proxy.enabled then "Proxy: \(.proxy.type) \(.proxy.host)" else empty end),
  "",
  "## Memory",
  "Total: \(.memory.total | gb)GB | Used: \(.memory.used | gb)GB (\(.memory.used_percent | floor)%) | Cached: \(.memory.cached | gb)GB",
  "Swap: \(.memory.swap_used | gb)GB / \(.memory.swap_total | gb)GB (\(if .memory.swap_total > 0 then (.memory.swap_used / .memory.swap_total * 100 | floor) else 0 end)%)",
  "",
  "## CPU",
  "Usage: \(.cpu.usage | floor)% | Load: \(.cpu.load1 * 100 | round / 100) / \(.cpu.load5 * 100 | round / 100) / \(.cpu.load15 * 100 | round / 100) | Cores: \(.cpu.core_count) (\(.cpu.p_core_count)P + \(.cpu.e_core_count)E)",
  "",
  "## Disk",
  (.disks[] | "  \(.mount) — \(.used | gb)/\(.total | gb)GB (\(.used_percent | floor)%)\(if .external then " [external]" else "" end)"),
  "",
  "## Battery",
  (.batteries[] | "Level: \(.percent)% \(.status) | Health: \(.health) | Cycles: \(.cycle_count) | Capacity: \(.capacity)%\(if .time_left then " | Remaining: \(.time_left)" else "" end)"),
  "",
  "## Thermal",
  "Battery temp: \(.thermal.battery_temp)°C\(if .thermal.cpu_temp > 0 then " | CPU: \(.thermal.cpu_temp)°C" else "" end)\(if .thermal.fan_speed > 0 then " | Fan: \(.thermal.fan_speed) rpm" else "" end)",
  "",
  "## Top Processes",
  (.top_processes[] | "  \(.name) (PID \(.pid)) — CPU \(.cpu)% | MEM \(.memory)%")
'

# Bluetooth: only show items with battery info (e.g., AirPods charge alerts)
bt_summary=$(echo "$raw" | jq -r '.bluetooth[] | select(.battery != "" and .battery != null) | "  \(.name): \(.battery)"')
if [[ -n "$bt_summary" ]]; then
  echo ""
  echo "## Bluetooth"
  echo "$bt_summary"
fi

# Process alerts (Mole's own watcher)
alerts=$(echo "$raw" | jq -r '.process_alerts // [] | length')
if [[ "$alerts" != "0" ]]; then
  echo ""
  echo "## Process Alerts"
  echo "$raw" | jq -r '.process_alerts[]'
fi

if [[ $DEEP == 1 ]]; then
  echo ""
  echo "=== CLEANUP PREVIEW (mo clean --dry-run) ==="
  # Strip ANSI color codes so grep can match plainly. Mole tags every cleanable
  # item with a trailing "dry" — that's our anchor.
  mo_out=$(mo clean --dry-run 2>&1 | sed $'s/\033\\[[0-9;]*[a-zA-Z]//g')
  # Categories actually carrying space (sorted big→small, top 15)
  echo "$mo_out" | grep -E 'dry$' \
    | awk '{
        # The size token is the second-last word, e.g. "60.1MB" or "402KB" or "1.2GB"
        n = NF; size = $(n-1)
        unit = substr(size, length(size)-1)
        num = substr(size, 1, length(size)-2) + 0
        if (unit == "GB") mb = num * 1024
        else if (unit == "MB") mb = num
        else if (unit == "KB") mb = num / 1024
        else mb = 0
        printf "%10.2f|%s\n", mb, $0
      }' \
    | sort -t'|' -k1 -rn | head -15 | cut -d'|' -f2-
  echo ""
  echo "$mo_out" | grep -E '(Potential space|Detailed file list)' | head -2
fi
