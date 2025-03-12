#!/bin/sh

set -a; source ../.env; set +a
set -e

echo -e "$BG_START Start: docker-nextjs-server/_create.sh $RESET"
echo "Description: runs docker container of custom nextjs-server, with pm2, using shared bind mount on ../dist folder for the content of nextjs"

if [[ -z $CONTAINER_SHARED_PATH || -z $PORT || -z $USER_ID ]]; then
   echo "Must provide CONTAINER_SHARED_PATH, PORT, USER_ID from .env file"
   exit 1
fi

docker-compose up --build -d