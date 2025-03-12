#!/bin/sh

set -a; source ../.env; set +a
set -e

echo -e "$BG_START Start: docker-nextjs-app/_create.sh $RESET"
echo "Description: Creates dist/ 
  .next
  public
  states/
    uploaded
  imageLoader.js
  next.config.js
"

if [[ -z $CONTAINER_SHARED_PATH  ]]; then
   echo "Must provide CONTAINER_SHARED_PATH from .env file"
   exit 1
fi

name=nextjs-bucket
bucketPath="../$CONTAINER_SHARED_PATH" # generate at the root of this repo

docker stop $name 2>/dev/null || true
docker rm $name 2>/dev/null || true
docker build . -t $name
docker run --name $name -d $name
rm -rf ${bucketPath}
mkdir -p ${bucketPath}/states

docker cp $name:/usr/src/app/.next ${bucketPath}
docker cp $name:/usr/src/app/public ${bucketPath}

# need this for nextjs image optimisation
docker cp $name:/usr/src/app/imageLoader.js ${bucketPath}
docker cp $name:/usr/src/app/next.config.js ${bucketPath}

timestamp=$(date +%s000)
echo $timestamp > ${bucketPath}/states/uploaded

echo -e "$BG_END Finish: docker-nextjs-app.sh $RESET. Created ./$CONTAINER_SHARED_PATH with next build content"







