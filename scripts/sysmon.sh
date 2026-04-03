#!/bin/bash
# Mac System Monitor - Compact output for LLM consumption

# --- Memory ---
mem_raw=$(vm_stat 2>/dev/null)
page_size=$(pagesize 2>/dev/null || echo 16384)
total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
total_gb=$(echo "scale=1; $total_bytes / 1073741824" | bc)

get_pages() { echo "$mem_raw" | awk "/$1/"'{gsub(/\./,""); print $NF}'; }
pages_free=$(get_pages "Pages free")
pages_active=$(get_pages "Pages active")
pages_inactive=$(get_pages "Pages inactive")
pages_wired=$(get_pages "Pages wired down")
pages_compressed=$(get_pages "Pages occupied by compressor")
pages_speculative=$(get_pages "Pages speculative")
swapins=$(get_pages "Swapins")
swapouts=$(get_pages "Swapouts")

: ${pages_compressed:=0}
: ${pages_speculative:=0}

used_pages=$((pages_active + pages_wired + pages_compressed + pages_speculative))
free_pages=$((pages_free + pages_inactive))
to_gb() { echo "scale=1; $1 * $page_size / 1073741824" | bc; }

echo "=== MAC SYSTEM HEALTH ==="
echo "## Memory"
echo "Total: ${total_gb}GB | Used: $(to_gb $used_pages)GB | Free: $(to_gb $free_pages)GB | Pressure: $(echo "scale=0; $used_pages * 100 / ($used_pages + $free_pages)" | bc)%"
echo "Wired: $(to_gb $pages_wired)GB | Compressed: $(to_gb $pages_compressed)GB"
echo "Swap in/out: ${swapins}/${swapouts}"

# --- CPU & Load (single top call) ---
top_header=$(top -l 1 -n 0 2>/dev/null)
echo ""
echo "## CPU"
echo "$top_header" | grep "CPU usage"
echo "$top_header" | grep "Load Avg"
echo "Cores: $(sysctl -n hw.ncpu 2>/dev/null)"

# --- Top processes by memory (>50MB RSS) ---
echo ""
echo "## Top Processes (RSS>50MB)"
echo "PID|RSS_MB|%CPU|COMMAND"
ps -Amr -o pid=,rss=,%cpu=,comm= 2>/dev/null | awk '
{
  rss_mb = $2/1024
  if(rss_mb < 50) next
  n = split($4, parts, "/")
  base = parts[n]
  gsub(/--type=.*/, "", base)
  if(length(base) > 50) base = substr(base, 1, 50) "..."
  printf "%s|%.0f|%s|%s\n", $1, rss_mb, $3, base
  if(++count >= 15) exit
}'

# --- Disk ---
echo ""
echo "## Disk"
df -H /System/Volumes/Data 2>/dev/null | awk 'NR==2{printf "Data: %s total, %s used, %s free (%s used)\n", $2, $3, $4, $5}'

# --- System ---
echo ""
echo "## System"
echo "Uptime: $(uptime 2>/dev/null | sed 's/.*up/up/' | sed 's/,.*load.*//') | Processes: $(ps -e | wc -l | tr -d ' ')"

# --- Battery ---
batt=$(pmset -g batt 2>/dev/null | grep -o '[0-9]*%' | head -1)
if [ -n "$batt" ]; then
  source=$(pmset -g batt 2>/dev/null | grep -o 'AC Power\|Battery Power' | head -1)
  echo ""
  echo "## Battery"
  echo "Level: $batt | Source: $source"
fi

echo ""
echo "=== END ==="
