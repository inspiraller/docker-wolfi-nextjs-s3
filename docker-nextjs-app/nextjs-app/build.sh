#!/bin/sh
set -e
echo "Build docker image of nextjs"
name=nextjs-bucket
bucketPath="./bucket"

# docker stop $name 2>/dev/null || true
# docker rm $name 2>/dev/null || true
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
echo $timestamp >> .${bucketPath}/states/uploaded








