#!/bin/sh
set -e

cd docker-nextjs-app && sh _create.sh && cd ..
cd docker-nextjs-server && sh _create.sh && cd ..
cd emulate-deploy && sh _create.sh && cd ..










