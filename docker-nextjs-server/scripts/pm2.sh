#!/bin/sh

ROOT="/app"
ROOT_VLM_DIR="$ROOT/$VLM_DIR"
LOG_FILE="$ROOT_VLM_DIR/logs/pm2-sh.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

debug() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}
if [[ -z $VLM_DIR || -z $BLGREEN_SYNCED ]]; then
  debug "Must provide VLM_DIR, BLGREEN_SYNCED"
fi

ROOT_NODEMODULES_DIR="${ROOT}/node_modules"
if [[ ! -d $ROOT_NODEMODULES_DIR ]]; then
  debug "No dir: $ROOT_NODEMODULES_DIR"
fi

ROOT_PM2="$ROOT_NODEMODULES_DIR/pm2/lib/binaries/CLI.js"
if [[ ! -e $ROOT_PM2 ]]; then
  debug "No file for pm2: $ROOT_PM2"
fi

debug "Starting pm2 script at $ROOT_PM2. pwd=$PWD"
# node_modules exists at the root because we copied it from first stage of Dockerfile to
node $ROOT_PM2 "$@"
debug "After Starting pm2 script"
