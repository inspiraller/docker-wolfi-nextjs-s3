#!/bin/sh

# listen-states-uploaded.sh
# This will listen for a file /build to exist in the vlm_share/build-sync folder
# When it is exists it can trigger any script you want
# The nextjs server will also listen for this file
# So this serves as a placeholder to run any bashscript or just as a debug
# once file exists it cancels the monitor.

ROOT="/app"
ROOT_VLM_DIR="$ROOT/$VLM_DIR"
MONITOR_FILE="$ROOT_VLM_DIR/$BLGREEN_SYNCED/build"
LOG_FILE="$ROOT_VLM_DIR/logs/listen-states-uploaded.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

debug() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}
if [[ -z $VLM_DIR || -z $BLGREEN_SYNCED ]]; then
  debug "Must provide VLM_DIR, BLGREEN_SYNCED"
fi

debug "Starting file monitoring script"
debug "MONITOR_FILE=$MONITOR_FILE"

monitor_file() {
  debug "Starting to monitor $MONITOR_FILE"
  WAIT=true
  while $WAIT; do
    if [[ -f "$MONITOR_FILE" ]]; then
        debug "File $MONITOR_FILE exists"
        sh "$ROOT/scripts/blue-green-deploy.sh"
        debug "build file exists. Run any script here you want!"
        WAIT=false
    else
      debug "File $MONITOR_FILE does not exist yet"
    fi
    sleep 5
  done
}

# Run in background and save PID
monitor_file > /dev/null 2>&1 &

# Log the PID so you can find/kill it later if needed
PID=$!
echo $PID > "$ROOT_VLM_DIR/logs/listen-states-uploaded.pid"
debug "Monitoring process started with PID $PID"