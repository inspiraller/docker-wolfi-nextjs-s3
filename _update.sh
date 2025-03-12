#!/bin/sh
set -e

cd docker-nextjs-app && sh _create.sh && cd ..
cd deploy-same-container && sh _create.sh && cd ..










