#!/bin/sh

set -a; source ../.env; set +a
set -e

echo -e "$BG_START Start: deploy-same-container/_create.sh $RESET"
echo "Description: updates /states/uploaded/" # This is an emulation of what you would do to sync your new content to s3. See README.md"

if [[ -z $VLM_DIR || -z $NEXTJS_BUILD || -z $BLGREEN_SYNCED  ]]; then
   echo "Must provide VLM_DIR, NEXTJS_BUILD, BLGREEN_SYNCED from .env file"
   exit 1
fi

buildDir="../$NEXTJS_BUILD"
vlmDirBuild="../$VLM_DIR/${BLGREEN_SYNCED}" 

mkdir -p "$vlmDirBuild" "$buildDir"

if [[ ! -w "$vlmDirBuild/" ]]; then
  echo "Error: No write permission in $vlmDirBuild";
  exit 1
fi

if [[ ! -d "$buildDir" ]]; then
  echo "Error: No dir $buildDir";
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

localSyncWindows "$buildDir" "$vlmDirBuild"



echo -e "$BG_END Finish: deploy-same-container/_create.sh $RESET"