#!/bin/sh

set -a; source ../.env; set +a
set -e

echo -e "$BG_START Start: docker-nextjs-app/_create.sh $RESET"
echo "Description: Creates nextjs-build/ 
  .next
  public
  states/
    uploaded
  imageLoader.js
  next.config.js
"

if [[ -z $NEXTJS_BUILD  ]]; then
   echo "Must provide NEXTJS_BUILD from .env file"
   exit 1
fi

ROOT="/usr/src/app"
name=$NEXTJS_BUILD
buildPath="../$NEXTJS_BUILD" # generate relative host folder

docker stop $name 2>/dev/null || true
docker rm $name 2>/dev/null || true
docker build . -t $name
docker run --name $name -d $name
rm -rf ${buildPath}
mkdir -p ${buildPath}/states

docker cp $name:$ROOT/.next ${buildPath}
docker cp $name:$ROOT/public ${buildPath}

# need this for nextjs image optimisation
docker cp $name:$ROOT/imageLoader.js ${buildPath}
docker cp $name:$ROOT/next.config.js ${buildPath}

timestamp=$(date +%s000)
echo $timestamp > ${buildPath}/states/uploaded

echo -e "$BG_END Finish: docker-nextjs-app.sh $RESET. Created ./$NEXTJS_BUILD with next build content"







