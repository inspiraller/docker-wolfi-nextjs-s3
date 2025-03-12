#!/bin/sh



ROOT="/app"
ROOT_VLM_DIR="$ROOT/$VLM_DIR"
MONITOR_DIR="$ROOT_VLM_DIR/states"
MONITOR_FILE=$MONITOR_DIR/uploaded

LOG_FILE="$ROOT/$VLM_DIR/logs/listen-states-uploaded.log"

# if NOT file exists, create it
if [[ ! -e "$LOG_FILE" ]]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
fi

debug() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

if [[ -z $VLM_DIR || -z $BLGREEN_SYNCED ]]; then
  debug "Must provide VLM_DIR, BLGREEN_SYNCED"
fi



debug "Starting file monitoring script"
debug "MONITOR_DIR=$MONITOR_DIR"
debug "MONITOR_FILE=$MONITOR_FILE"


monitor_file() {
  debug "Ensuring monitor directory exists"
  mkdir -p "$MONITOR_DIR"
  
  if [ ! -w "$MONITOR_DIR" ]; then
    debug "No write access to $MONITOR_DIR. Exiting."
    exit 1
  fi

  debug "Start monitoring $MONITOR_FILE"
  
  while true; do
    # Using inotifywait in a more resilient way
    if inotifywait -q -e create,modify,move,close_write "$MONITOR_FILE" 2>> "$LOG_FILE"; then
      current_time=$(date +"%H:%M:%S")
      debug "File $MONITOR_FILE modified"
      sh "$ROOT/scripts/sync.sh"
      debug "After execute sync.sh"
    else
      debug "inotifywait command failed, waiting before retry..."
      sleep 5
    fi
  done
}

# Run the monitoring function in the background with nohup to keep it running
# after the parent process exits
nohup monitor_file > /dev/null 2>&1 &

# Log the PID so you can find/kill it later if needed
PID=$!
echo $PID > "$ROOT_VLM_DIR/logs/listen-states-uploaded.pid"
debug "Monitoring process started with PID $PID"

# Exit successfully so the entrypoint.sh can continue
# exit 0