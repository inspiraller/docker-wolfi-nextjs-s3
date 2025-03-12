# What is this repo for?
Small scale blue green deployment for nextjs server, that alternates between new folder and old folder on same ecs container.

# How it would work with AWS?
1. myComputer nextjs build --(s3 sync)--> s3
2. S3 update --(Notification subscription)--> lambda listen s3
3. Lambda listen s3 --(sms message)--> ec2 local script.sh 
4. ec2 local script.sh --(s3 sync bucket )--> ec2/ecs shared volume
5. inotifywait --(listen on file states/uploaded)--> alternate between new folder and old folder for blue green deployment

# Aws services
The usecase for this is running the following:
- 1 ec2 instance (with AWS cli for s3 sync for pulling changes from s3 bucket to the shared volume)
- 1 ecs service task
(share volume between ec2 and ecs, using volume mount on task definition)
- 1 s3 bucket
- 1 notification subscription to lambda
- 1 lambda (listen to s3)
- Cloudwatch loggroups for debugging
- Optional: Loadbalancer + EC2 Nat Instance 
Note: If using loadbalancer then you need task definition network mode: AWSVPC which puts the ecs tasks into private subnet that can't access the internet, so you can't make external api calls unless you have a NAT instance or NAT gateway.

# Larger scale deployments
For larger scale, more capacity it is advisable instead to use separate ec2 instances. 
One solution might be to alternate the dns record to point to the new ec2 instance load balancer, but that is outside the scope of this repo.

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
- dumb-init (for running nodejs in entrypoint without npm. Part of the chainguard principles is to improve security)
- pm2 for production, debugging and restarting
- inotifywait
- healthcheck
- entrypoint for any custom functionality before the compose.yaml or task definition runs
- nextjs build into /bucket 
  - public/
  - .next/
  - states/uploaded (for nodejs to listen when to start server)
  - next.config.js
  - imageLoader.js (
     Traspiled from typescript to javascript file, so next.config.js can read it for 
     for allowing image optimisation to work with nextjs for external api calls)

# Can you run this example without AWS? 
Yes. This is just an architectural blueprint of the entire chain. You can test this locally without having to use any aws services.

# How to run this?
1. `cp .env.example .env`
- change .env to your desire
2. `cd docker-nextjs-app && npx create-next-app --nextjs-app`
 Create your next production build (leaving: output mode blank - ie not standalone)
3. Copy merge-with-nextjs-app-before-buildsh/* into your nextjs-app and modify accordingly
- These files are merely to enable transpiling imageLoader.js for next.config.js to Image optimisation
  - imageLoader.js (
     Traspiled from typescript to javascript file, so next.config.js can read it for 
     for allowing image optimisation to work with nextjs for external api calls)
4. From root of this repo: `sh _create.sh`
5. Load in browser
localhost:3000


# debug
- dist/*.log
- docker-nextjs-server/compose.yaml - uncomment cmd commands to test server.

# Disclaimer
While this enables fast blue green deployment, any change to package.json will need to also update the nextjs server package.json file
So if using this in your Task definition image you would have to rebuild the ECR image to aws when changing that.

A future solution is to create a pipeline or series of bash scripts to detect changes in your nextjs application to promote your ecr update, then restart the service before alternating to green deployment. This is a todo.



