#!/bin/sh

if [[ -z $VLM_DIR || -z $PORT || -z $USER_ID ]]; then
   echo "Must provide VLM_DIR, PORT, USER_ID from .env file"
   exit 1
fi


docker-compose down 

rm -rf "../$VLM_DIR"
docker image rm docker-wolfi-nextjs-s3
docker image prune