#!/bin/sh

if [[ -z $VLM_DIR  ]]; then
   echo "Must provide VLM_DIR .env file"
   exit 1
fi

vlmDir="../$VLM_DIR" 

rm -rf "$vlmDir"
