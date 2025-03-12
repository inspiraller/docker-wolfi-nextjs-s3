#!/bin/sh


docker-compose down 
docker image rm docker-wolfi-nextjs-s3
docker image prune