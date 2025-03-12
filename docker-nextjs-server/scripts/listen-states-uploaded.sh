#!/bin/sh


ROOT="/app"
ROOT_VLM_DIR="$ROOT/$VLM_DIR"
BUILD0_DIR="$ROOT_VLM_DIR/$BLGREEN_SYNCED"
MONITOR_DIR="$BUILD0_DIR/states"
MONITOR_FILE="$MONITOR_DIR/uploaded"

LOG_FILE="$ROOT_VLM_DIR/logs/listen-states-uploaded.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"


# timestamp=$(date +%s000)
# debug $timestamp

debug() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

if [[ -z $VLM_DIR || -z $BLGREEN_SYNCED ]]; then
  debug "Must provide VLM_DIR, BLGREEN_SYNCED"
fi

debug "Starting file monitoring script"
debug "MONITOR_FILE=$MONITOR_FILE"


# Create a monitoring function that uses simple polling
monitor_file() {
  debug "Ensuring monitor directory exists"
  mkdir -p "$MONITOR_DIR"
  
  if [[ ! -d "$MONITOR_DIR" ]]; then
    debug "Monitor directory $MONITOR_DIR does not exist. Creating it."
    mkdir -p "$MONITOR_DIR"
  fi
  
  debug "Starting to monitor $MONITOR_FILE"
  
  # Initialize with a non-existent timestamp
  LAST_MODIFIED=0
  
  while true; do
    # Check if file exists
    if [[ -f "$MONITOR_FILE" ]]; then
      # Get the file's modification time in seconds since epoch
      CURRENT_MODIFIED=$(stat -c %Y "$MONITOR_FILE" 2>/dev/null || stat -f %m "$MONITOR_FILE" 2>/dev/null)
      
    
      # debug "File exists. Last: $LAST_MODIFIED, Current: $CURRENT_MODIFIED"

      # If we can't get the timestamp, use a fallback
      if [[ -z "$CURRENT_MODIFIED" ]]; then
        debug "Could not get modification time, using ls -l"
        CURRENT_MODIFIED=$(ls -l --time-style=+%s "$MONITOR_FILE" | awk '{print $6}')

      # If the file is newer than our last check
      elif [[ "$CURRENT_MODIFIED" -gt "$LAST_MODIFIED" ]]; then

        debug "File $MONITOR_FILE modified"
        LAST_MODIFIED=$CURRENT_MODIFIED
        sh "$ROOT/scripts/sync.sh"
        debug "After execute sync.sh"
      fi
    else
      debug "File $MONITOR_FILE does not exist yet"
    fi
    
    # Sleep for a short time (5 seconds) before checking again
    sleep 5
  done
}

# Run in background and save PID
monitor_file > /dev/null 2>&1 &

# Log the PID so you can find/kill it later if needed
PID=$!
echo $PID > "$ROOT_VLM_DIR/logs/listen-states-uploaded.pid"
debug "Monitoring process started with PID $PID"