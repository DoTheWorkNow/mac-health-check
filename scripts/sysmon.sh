#!/bin/bash
# Native fallback. Preserve probe failures; never fabricate a health score.
set -u
probe() {
  local label="$1" output
  shift
  echo "## $label"
  if output=$("$@" 2>&1) && [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  else
    printf 'WARNING: %s unavailable: %s\n' "$label" "$output"
  fi
}
echo '=== MAC SYSTEM HEALTH (native fallback; partial evidence) ==='
probe 'Memory bytes' sysctl -n hw.memsize
probe 'VM pages (page size in header; swap counters cumulative since boot)' vm_stat
probe 'Swap (current dynamic allocation)' sysctl vm.swapusage
probe 'Memory pressure (read-only query)' memory_pressure -Q
probe 'CPU / load' top -l 1 -n 0
echo '## Processes (top 5 CPU and top 5 RSS; %CPU can exceed 100 per process)'
if processes=$(ps -axo pid=,ppid=,%cpu=,rss=,comm= 2>&1) && [[ -n "$processes" ]]; then
  echo 'PID PPID CPU% RSS_KiB COMMAND (CPU order)'
  printf '%s\n' "$processes" | sort -k3,3nr | head -5
  echo 'PID PPID CPU% RSS_KiB COMMAND (RSS order)'
  printf '%s\n' "$processes" | sort -k4,4nr | head -5
else
  printf 'WARNING: process data unavailable: %s\n' "$processes"
fi
probe 'Data volume (KiB; APFS available is shared)' df -k /System/Volumes/Data
probe 'Uptime' uptime
probe 'Battery' pmset -g batt
