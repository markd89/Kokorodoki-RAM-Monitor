#!/usr/bin/env bash
set -euo pipefail

SERVICE="kokorodoki.service"
THRESHOLD_GB=4
IDLE_MINUTES=5
COOLDOWN_MINUTES=10
COOLDOWN_FILE="/tmp/kokorodoki_monitor_last_restart"

# --- get current memory in bytes ---
MEM_BYTES=$(systemctl show -p MemoryCurrent "$SERVICE" | cut -d= -f2)
MEM_GB=$(( MEM_BYTES / 1024 / 1024 / 1024 ))

# --- check memory threshold ---
if (( MEM_GB < THRESHOLD_GB )); then
    echo "Memory below threshold (${MEM_GB}GB < ${THRESHOLD_GB}GB)."
    exit 0
fi

# --- get last log entry (epoch + text) ---
LAST_LOG_LINE=$(journalctl -u "$SERVICE" -n 1 --no-pager --output short-unix -q || true)
LAST_LOG_TS=$(awk '{print int($1)}' <<< "$LAST_LOG_LINE")
LAST_LOG_TEXT=$(awk '{$1=""; sub(/^ /,""); print}' <<< "$LAST_LOG_LINE")

# --- check if service recently started new playback thread ---
#if grep -q "Started new playback thread" <<< "$LAST_LOG_TEXT"; then
#    echo "Active playback detected; skipping restart."
#    logger -t kokorodoki_monitor "Skip restart: active playback detected (mem=${MEM_GB}GB)."
#    exit 0
#fi

# --- check if playback has completed --- The previous method above could interrupt playback if we had done something like paused, resumed, changed speed as the last log line. Now we explicitly require Playback complete to initiate the restart.
if ! grep -q "Playback complete" <<< "$LAST_LOG_TEXT"; then
    echo "Playback not complete; skipping restart."
    logger -t koko_monitor "Skip restart: playback not complete (mem=${MEM_GB}GB)."
    exit 0
fi

# --- compute idle time ---
NOW_TS=$(date +%s)
IDLE_SEC=$(( NOW_TS - LAST_LOG_TS ))
IDLE_MIN=$(( IDLE_SEC / 60 ))

if (( IDLE_MIN < IDLE_MINUTES )); then
    echo "Last log ${IDLE_MIN}m ago (<${IDLE_MINUTES}m). No action."
    exit 0
fi

# --- check cooldown ---
if [[ -f "$COOLDOWN_FILE" ]]; then
    LAST_RESTART_TS=$(cat "$COOLDOWN_FILE")
    SINCE_RESTART_MIN=$(( (NOW_TS - LAST_RESTART_TS) / 60 ))
    if (( SINCE_RESTART_MIN < COOLDOWN_MINUTES )); then
        echo "Cooldown active (${SINCE_RESTART_MIN}m < ${COOLDOWN_MINUTES}m). No restart."
        exit 0
    fi
fi

# --- restart service ---
echo "Restarting $SERVICE (mem=${MEM_GB}GB, idle=${IDLE_MIN}m)."
logger -t kokorodoki_monitor "Restarting $SERVICE (mem=${MEM_GB}GB, idle=${IDLE_MIN}m)."
systemctl restart "$SERVICE"
date +%s > "$COOLDOWN_FILE"
