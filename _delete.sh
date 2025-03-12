#!/bin/sh
set -e

cd docker-nextjs-server && sh _delete.sh && cd ..
cd deploy-same-container && sh _delete.sh && cd ..
cd docker-nextjs-app && sh _delete.sh && cd ..










