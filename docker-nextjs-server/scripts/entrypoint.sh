#!/bin/sh

# entrypoint.sh

# This is the entrypoint for the docker container.
# It will run a script: listen-states-uploaded.sh in the background, and then forward remaining command to start nextjs-server
# nextjs-server will run in a suspended state. It's waiting for a build file to exist before it starts
# listen-states-uploaded.sh will listen for for build file to be created and just display a log message. This file is optional. 
# listen-states-uploaded.sh is optional. Warning: if you remove it, just be sure to also remove the reference in entrypoint.sh
# nextjs-server will also listen for the build file to exist, then starts

# Why this is needed:
# To avoid having to back everything into ecr docker image on every deploy
# We only have to sync the changes of the nextjs content to efs mounted on this ecs task
# This task only cares about the inactive build. 

ROOT="/app"
ROOT_VLM_DIR="$ROOT/$VLM_DIR"

LOG_FILE="$ROOT_VLM_DIR/logs/listen-states-uploaded.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

debug() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

if [[ -z $ROOT  ]]; then
   debug "Must provide ROOT .env file"
   exit 1
fi

sh $ROOT/scripts/listen-states-uploaded.sh
debug "after sh listen-states-uploaded.sh"
exec /usr/bin/dumb-init -- "$@"
