#!/bin/sh

if [[ -z $NEXTJS_BUILD  ]]; then
   echo "Must provide NEXTJS_BUILD from .env file"
   exit 1
fi

rm -rf ../$NEXTJS_BUILD






