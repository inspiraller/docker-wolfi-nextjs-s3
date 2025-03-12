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

if [[ -z $ROOT  ]]; then
   debug "Must provide ROOT .env file"
   exit 1
fi

debug "start sh listen-states-uploaded.sh"
sh $ROOT/scripts/listen-states-uploaded.sh


debug "after sh listen-states-uploaded.sh"
exec /usr/bin/dumb-init -- "$@"
