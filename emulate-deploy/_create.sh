#!/bin/sh

# emulate-deploy/_create.sh
# This emulates what the lambda would do. The lambda that syncs s3 to efs inactive build folder and then populate /build referencing the to green build folder
# In this file we just creating a build folder for BLGREEN_BUILD1
# Inside the docker image will be a script in the entrypoint.sh - see docker-nextjs-server/scripts/listen-states-uploaded.sh
# That script will listen on thie file /build to exist and then execute the next step - sh blud-green-deploy.sh to start up nextjs server


set -a; source ../.env; set +a
set -e

echo -e "$BG_START Start: emulate-deploy/_create.sh $RESET"
echo "Description: updates /states/uploaded/" # This is an emulation of what you would do to sync your new content to s3. See README.md"

if [[ -z $VLM_DIR || -z $NEXTJS_BUILD || -z $BLGREEN_SYNCED || -z $BLGREEN_BUILD1 || -z $BLGREEN_BUILD2 ]]; then
   echo "Must provide VLM_DIR, NEXTJS_BUILD, BLGREEN_SYNCED, BLGREEN_BUILD1, BLGREEN_BUILD2 from .env file"
   exit 1
fi


buildDir="../$NEXTJS_BUILD"



vlmBuildSyncDir="../$VLM_DIR/$BLGREEN_SYNCED" 
vlmBuild1="../$VLM_DIR/$BLGREEN_BUILD1" 
vlmBuild2="../$VLM_DIR/$BLGREEN_BUILD2" 

build_to=$BLGREEN_BUILD1
vlmBuildToDir="../$VLM_DIR/$build_to" 

mkdir -p  $vlmBuildSyncDir $vlmBuild1 $vlmBuild2


if [[ ! -d "$buildDir" ]]; then
  echo "Error: No nextjs build exist in $buildDir";
  exit 1
fi

if [[ ! -w "$vlmBuildToDir/" ]]; then
  echo "Error: No write permission in $vlmBuildToDir";
  exit 1
fi

# update timestamp
timestamp=$(date +%s000)
echo $timestamp > "${buildDir}/states/uploaded"

localSyncWindows() {
  folder1=$1
  folder2=$2
  rm -rf "$folder2/*"
  cp -r $folder1/{*,.[^.]*} $folder2
}

localSyncWindows "$buildDir" "$vlmBuildToDir"

echo $build_to > "$vlmBuildSyncDir/build"


echo -e "$BG_END Finish: emulate-deploy/_create.sh $RESET"