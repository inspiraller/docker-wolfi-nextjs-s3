#!/bin/sh
set -e

# Create dist/ 
cd docker-nextjs-app && sh _create.sh && cd ..

# Run Dockerfile
cd docker-nextjs-server && sh _create.sh && cd ..









