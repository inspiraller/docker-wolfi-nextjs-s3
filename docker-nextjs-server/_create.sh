#!/bin/sh

set -a; source ../.env; set +a
set -e

echo -e "$BG_START Start: docker-nextjs-server/_create.sh $RESET"
echo "Description: runs docker container of custom nextjs-server, with pm2, using shared bind mount on ../vlm-dir, copying nextjs-build into vlm-dir/build0 and alternate blue green to build1 and build2"

if [[ -z $VLM_DIR || -z $PORT || -z $USER_ID ]]; then
   echo "Must provide VLM_DIR, PORT, USER_ID from .env file"
   exit 1
fi

docker-compose down

echo "Remove uplodated on first build otherwise nextjs will attempt to start"
rm -rf "../$VLM_DIR"
# rm -rf "../$VLM_DIR/states" "../$VLM_DIR/logs" "../$VLM_DIR/$BLGREEN_SYNCED" "../$VLM_DIR/$NEXT_BLGREEN_1" "../$VLM_DIR/NEXT_BLGREEN_2"

docker-compose up --build

echo -e "$BG_END Finish: emulate-deploy.sh $RESET"