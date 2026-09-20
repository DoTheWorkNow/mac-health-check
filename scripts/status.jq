# Mole 1.54.0 snapshot. Null is not zero, process freshness is explicit.
def value: if . == null or . == "" then "unknown" else tostring end;
def gib: if type == "number" then (. / 1073741824 * 10 | round / 10 | tostring) + " GiB" else "unknown" end;
def mib: if type == "number" then (. / 1048576 * 10 | round / 10 | tostring) + " MiB" else "unknown" end;
def metric: if type == "number" then (. * 10 | round / 10 | tostring) else value end;
def positive: if type == "number" and . > 0 then tostring else "unavailable/zero reading" end;
if type != "object" then error("Expected snapshot object")
elif (.memory | type) != "object" or (.cpu | type) != "object" then error("Missing CPU/memory objects")
else
  "Snapshot: \(.collected_at | value) | Score (Mole heuristic): \(.health_score | value) — \(.health_score_msg | value)",
  "Hardware: \(.hardware.model | value) · \(.hardware.cpu_model | value) · \(.hardware.os_version | value)",
  "Uptime: \(.uptime | value) | Processes: \(.procs | value)",
  "## Memory",
  "Total: \(.memory.total | gib) | Used: \(.memory.used | gib) (\(.memory.used_percent | metric)%) | Cached: \(.memory.cached | gib)",
  "Pressure (reported): \(.memory.pressure | value)",
  "Swap used: \(.memory.swap_used | gib) | Currently allocated: \(.memory.swap_total | gib) (dynamic allocation; not a pressure score)",
  "## CPU",
  "Usage: \(.cpu.usage | metric)% | Load: \(.cpu.load1 | metric) / \(.cpu.load5 | metric) / \(.cpu.load15 | metric) | Cores: \(.cpu.core_count | value)",
  "## Disk (APFS mounts can share a container; do not add them)",
  (if (.disks // [] | length) == 0 then "Disk data unavailable" else
    .disks[] | "\(.mount) — \(.used | gib)/\(.total | gib) (\(.used_percent | metric)%)\(if .external then " [external]" else "" end)" end),
  "## Battery",
  (if (.batteries // [] | length) == 0 then "No battery data (absent or unavailable)" else
    .batteries[] | "Level: \(.percent | value)% \(.status | value) | Health: \(.health | value) | Cycles: \(.cycle_count | value) | Capacity: \(.capacity | value)%" end),
  "## Thermal",
  "Battery °C: \(.thermal.battery_temp | positive) | CPU °C: \(.thermal.cpu_temp | positive) | Fan rpm: \(.thermal.fan_speed | positive)",
  "## Top Processes",
  "Freshness: \(if .process_stale == true then "STALE — do not use for current attribution" elif .process_stale == false then "current" else "unknown" end) | Process sample: \(.process_collected_at | value)",
  (if (.top_processes // [] | length) == 0 then "Process data unavailable/empty; does not prove inactivity" else
    .top_processes[:5][] | "\(.name) (PID \(.pid), PPID \(.ppid | value)) — CPU \(.cpu | metric)% | MEM \(.memory | metric)% | RSS \(.memory_bytes | mib)" end),
  ((.process_alerts // [])[] | "Process alert (see freshness above): \(. | tostring)"),
  ((.bluetooth // [])[] | select(.battery != null and .battery != "") | "Bluetooth: \(.name): \(.battery)")
end
