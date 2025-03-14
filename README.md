# What is this repo for? - Blue Green deployment for incremental updates
This is part of a chain of steps to implement an incremental blue green deployment of nextjs content.

## If we have the following setup:
- vpn, subnets, security groups
- ec2
- Docker image push to ecr
- Task definition configured to use Docker image
- S3 which contain the content for latest nextjs build (not standalone. Can be standalone but this shows how to make it work with custom server)
- S3 notification to triger Lambda 1 (lambda-listen-s3)
- EFS mount
  - sync folder
  - build 1 folder
  - build 2 folder
- Lambda (lambda-listen-s3) 
  - alternates blue green deployment build to either build 1 or build 2 and syncs to efs
- Cloudwatch log group on ecs task
- Cloudwatch log group subscription - triggers Lambda (healthcheck ok)
- Lambda (healthcheck ok) 
  - updates target group listener to new green deployment 
  -  kills old service
  - removes build file from efs
- Route 53 - hosting zone - dns record - Load balancer dns name
- Load balancer - target group pointing to ecs service

## How blue greend deployment works with incremental changes?
Existing ecs task uses build 1 folder for server content

**On blue green deployment**:
- Local computer - aws cli sync local nextjs build to s3
- local computer - after sync cps file states/uploaded to trigger lambda
- s3 notification - on file states/uploaded invokes lambda 1
- Lambda 1 - syncs s3 to efs sync folder with only new updates
- Cloudwatch log on efs triggers lambda 2 when it detects file states/uploaded
- Lambda 2 - Update service with new task (to be green)
- New ecs task - mounts to efs listens on sync folder for file /uploaded on first load only then copies sync to empty build folder: build 1 or build 2 (alternating blue green) then uses new build and starts server from it. (Ecs task is using Docker image to run in a suspended state with bash or node, to listen to updates in efs, and then start up server entirely, ie not having nextjs start up on initialisation)
- Task def Healthcheck - As per standard new deployments. On healthcheck ok of new service, loadbalancer stops old ecs task, but in addition, removes data from old folder in efs build!
- Cloudwatch - on healthcheck ok. Loadbalancer stops old ecs task (removing data from old folder in efs build)

# How it would work with AWS?
1. myComputer script (or pipeline)
- create nextjs-build 
-  --(s3 sync)--> s3
- --(s3 cp states/uploaded)--> s3

2. S3 update --(Notification subscription)--> lambda listen s3
3. Lambda listen s3 --(syncs s3)--> to efs inactive build folder and creates file build with reference to the new build folder.
4. Cloudwatch --(listens on efs file - build) --> lambda healthcheck ok
5. Lambda healthcheck ok --(Update listener desired tasks)--> start service
6. This repo expects the file 'build' and a reference to the target build folder to start nextjs server


# Dependencies on host:
- Gitbash terminal
- Node/npm
- Nextjs
- Docker (Docker image used - Restricted Chainguard wolfi base, with nodejs and pm2)

# Dependencies in container
- nodejs
- shell
- curl for healthcheck
- shadow (for changing your user id to share with volume from container to host with explicit permissions using chmod/chown)
- dumb-init (for running nodejs in entrypoint without npm. Part of the Chainguard principles is to improve security)
- pm2 for production, debugging and restarting
- healthcheck
- entrypoint for any custom functionality before the compose.yaml or task definition runs
- Bind mount nextjs-build into /vlm_share/build[1 or 2]
  - public/
  - .next/
  - states/uploaded (for nodejs to listen when to start server)
  - next.config.js
  - imageLoader.js (
     Transpiled from typescript to javascript file, so next.config.js can read it for 
     for allowing image optimization to work with nextjs for external api calls)

# Can you run this example without AWS? 
Yes. This is just an architectural blueprint of the entire chain. You can test this locally without having to use any aws services.

# How to run this?
1. `cp .env.example .env`
- change .env to your desire
2. Create or edit docker-nextjs-app/nextjs-app
3. Copy merge-with-nextjs-app-before-build/* into your nextjs-app and modify accordingly
- These files are merely to enable transpiling imageLoader.js for next.config.js to Image optimization
  - imageLoader.js (
     Transpiled from typescript to javascript file, so next.config.js can read it for 
     for allowing image optimization to work with nextjs for external api calls)
4. `cd ../ && sh _create.sh`  
5. Load in browser
localhost:3000


# debug
- vlm_share/*.log
- docker-nextjs-server/compose.yaml - uncomment cmd commands to test server.

# Disclaimer
While this enables fast blue green deployment, any change to package.json will need to also update the nextjs server package.json file
So if using this in your Task definition image you would have to rebuild the ECR image to aws when changing that.

A future solution is to create a pipeline or series of bash scripts to detect changes in your nextjs application to promote your ecr update, then restart the service before alternating to green deployment. This is a todo.



