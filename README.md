# What is this repo for? - partial blue green deployment
If you have an existing custom nextjs server and you want to deploy new content changes (excluding package.json dependencies), then this is a blue green deployment solution within same ec2/ecs container. It's fast, reduces downtime, reduces transport of new data and focuses just on alternating between old and new folder by way of a symlink on detecting a file states/uploaded changes.

# What this repo can't do? - complete blue green deployment
This is not a complete blue green deployment implementation, because if you want to update any package dependencies then you'd also have to update the custom next server package dependencies as well. 

## There are several options for complete blue green deployment:
1. **Don't use custom nextjs server. Use standalone output.**
Have a persistent node server running to keep the ecs task live, and just alternate the new standalone server with old one and expose on necessary port.
We'd have to increase the ec2 capacity to hold 2 running servers at a time. 

This is the simplest solution

2. **Keep the custom nextjs server. Install npm packages in situ**
Detect new dependencies and install those in situ on the ecs task in separate folder. Alternate the build in blue green deployment.

**Problems:**
- We'd have to ensure npm is available on ecs, increasing the dependencies on our nice restrictive Chainguard Wolfi base image which shouldn't be allowing npm to run. 
- We'd still have to update the ECR docker image, task definition, lambdas which depend on the task definition and ensure consistency between blue green installation in situ, adding complexity synchronization risk.
We need to increase capacity of ec2 instance to allow npm and future installation.
We'd have to increase the ec2 capacity to hold 2 running servers at a time. 

3. **Keep the custom nextjs server. Duplicate everything - ec2, ecs, loadbalancer and alternate dns record between blue green**
Detect new dependencies and install those in situ on the ecs task in separate folder. Alternate the build in blue green deployment.

This is a complex solution, but the advantage is it completely separates and encapsulates the blue green deployment implementation and makes it more reliable for reverting. 

It also is pretty much needed for all other server types anyway. 

# So why this repo and not just implement complete solution? 
The only reason for this repo (partial blue green deployment) is to speed up content changes without having the overhead of the entire architecture when we only need to change content. 

# How it would work with AWS?
1. myComputer create nextjs-build --(s3 sync)--> s3
2. S3 update --(Notification subscription)--> lambda listen s3
3. Lambda listen s3 --(sms message)--> ec2 local script.sh 
4. ec2 local script.sh --(s3 sync bucket )--> ec2/ecs shared volume
5. inotifywait or poll --(listen on file states/uploaded)--> alternate between new folder and old folder for blue green deployment

# Aws services
The use case for this is running the following:
- 1 ec2 instance (with AWS cli for s3 sync for pulling changes from s3 bucket to the shared volume)
- 1 ecs service task
(share volume between ec2 and ecs, using volume mount on task definition)
- 1 s3 bucket
- 1 notification subscription to lambda
- 1 lambda (listen to s3)
- Cloudwatch log groups for debugging
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
- dumb-init (for running nodejs in entrypoint without npm. Part of the Chainguard principles is to improve security)
- pm2 for production, debugging and restarting
- inotifywait
- healthcheck
- entrypoint for any custom functionality before the compose.yaml or task definition runs
- Bind mount nextjs-build into /vlm_share/build0
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

# How to redeploy - to test blue green depllyment
1. Modify docker-nextjs-app/nextjs-app (without changing package.json)
2. `cd ../ && sh _update.sh`
3. reload browser: localhost:3000


# debug
- vlm_share/*.log
- docker-nextjs-server/compose.yaml - uncomment cmd commands to test server.

# Disclaimer
While this enables fast blue green deployment, any change to package.json will need to also update the nextjs server package.json file
So if using this in your Task definition image you would have to rebuild the ECR image to aws when changing that.

A future solution is to create a pipeline or series of bash scripts to detect changes in your nextjs application to promote your ecr update, then restart the service before alternating to green deployment. This is a todo.



