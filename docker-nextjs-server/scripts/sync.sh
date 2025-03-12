#!/bin/sh

ROOT="/app"
ROOT_VLM_DIR="$ROOT/$VLM_DIR"
LOG_FILE="$ROOT_VLM_DIR/logs/sync.log"

BUILD0_DIR="${ROOT_VLM_DIR}/$BLGREEN_SYNCED"
SYMLINK="$ROOT_VLM_DIR/$BLGREEN_SYMLINK"
SCRIPTS="$ROOT/scripts"

# These folders are going to get created in the container.
BUILD1_DIR="${ROOT_VLM_DIR}/${BLGREEN_BUILD1}"
BUILD2_DIR="${ROOT_VLM_DIR}/${BLGREEN_BUILD2}"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

debug() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}
debug_reset() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" > "$LOG_FILE"
}

if [[ -z $VLM_DIR || -z $BLGREEN_SYMLINK || -z $BLGREEN_SYNCED || -z $BLGREEN_BUILD1 || -z $BLGREEN_BUILD2 || -z $PM2_SERVER_NAME ]]; then
   debug "Must provide VLM_DIR, BLGREEN_SYMLINK, BLGREEN_SYNCED, BLGREEN_BUILD1, BLGREEN_BUILD2, PM2_SERVER_NAME from .env file"
   exit 1
fi

debug -e "$BG_START Start: scripts/sync.sh $RESET"
debug "Description: This would be equivalent of aws s3 sync. For emulation purposes, this is just a straight copy"

createSymLinkIfNotExist() {
  if [ ! -L "${SYMLINK}" ]; then
    ln -sf "${BUILD1_DIR}" "${SYMLINK}"
  fi
}
localSyncLinux() {
  folder1=$1
  folder2=$2

  debug "Clearing destination folder ${folder2}"
  rm -rf "$folder2"/*
  mkdir -p "$folder2"

  debug "Copying files from ${folder1} to ${folder2}"
  cp -r -v $folder1/* $folder2 2>&1 | tee $LOG_FILE
  if ls -A "$folder1"/.[!.]* >/dev/null 2>&1; then
    cp -r "$folder1"/.[!.]* "$folder2" 2>> "$LOG_FILE"
  fi
}

getInactiveDir() {
  INACTIVE_ENV=
  if [ -L "${SYMLINK}" ]; then
    CURRENT_TARGET=$(readlink "${SYMLINK}")
    if [ "${CURRENT_TARGET}" = "${BUILD1_DIR}" ]; then
      INACTIVE_ENV="${BLGREEN_BUILD2}"
    else
      INACTIVE_ENV="${BLGREEN_BUILD1}"
    fi
  else
    INACTIVE_ENV="${BLGREEN_BUILD2}"
  fi
  echo "${ROOT_VLM_DIR}/${INACTIVE_ENV}"
}

from="$BUILD0_DIR" # shared directory
to="$(getInactiveDir)"

debug "Going to deploy to $to"
createSymLinkIfNotExist

mkdir -p "${BUILD1_DIR}" "${BUILD2_DIR}"


# Sync from shared directory to green dir
# aws s3 sync "s3://${S3_BUCKET}" "${to}/" --delete

debug "localSync $from $to"
# rsync -v --delete $from "${to}/"
localSyncLinux "$from" "$to"

debug_reset "Sync new build location completed=$to"

# Validate the new build
if [[ ! -f "${to}/next.config.js" || ! -d "${to}/.next" ]]; then
  debug "ERROR: Invalid build content in ${to}"
  ls -la "${to}" >> "$LOG_FILE" 2>&1
  exit 1
fi

# Switch symlink atomically
debug "Switching symlink to ${to}..."
ln -sf "${to}" "${SYMLINK}.new"
mv -Tf "${SYMLINK}.new" "${SYMLINK}"


debug "Restarting Next.js application..."
sh "$SCRIPTS/pm2.sh" stop $PM2_SERVER_NAME || true
# 3 seconds offline...
sleep 3
sh "$SCRIPTS/pm2.sh" start $PM2_SERVER_NAME --update-env
# sh "$SCRIPTS/pm2.sh" reload $PM2_SERVER_NAME --update-env

sleep 2
sh "$SCRIPTS/pm2.sh" ls >> "$LOG_FILE" 2>&1
debug "Deployment completed successfully!"

debug -e "$BG_END Finish: scripts/sync.sh"