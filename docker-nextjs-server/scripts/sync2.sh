#!/bin/bash

# Deploy updated code to the inactive environment
if [ "$(pm2 jlist | jq '[.[] | select(.name == "nextjs-proxy")][0].pm2_env.env.ACTIVE_SERVER')" = "blue" ]; then
  DEPLOY_TARGET="green"
  CURRENT="blue"
else
  DEPLOY_TARGET="blue"
  CURRENT="green"
fi

echo "Deploying to $DEPLOY_TARGET environment..."

# Update code for the target environment
# ...your deployment steps here...

# Start/restart the target environment
pm2 restart nextjs-$DEPLOY_TARGET

# Health check
echo "Performing health check on $DEPLOY_TARGET environment..."
MAX_RETRIES=10
RETRY_COUNT=0
HEALTH_CHECK_URL="http://localhost:$([ "$DEPLOY_TARGET" = "blue" ] && echo "3001" || echo "3002")/api/health"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_CHECK_URL)
  if [ "$HEALTH_STATUS" = "200" ]; then
    echo "Health check passed!"
    # Switch traffic to the newly deployed environment
    pm2 sendSignal SIGUSR2 nextjs-proxy
    pm2 send nextjs-proxy switch:$DEPLOY_TARGET
    
    # Update the active server in the PM2 environment
    pm2 setenv nextjs-proxy ACTIVE_SERVER $DEPLOY_TARGET
    
    # Stop the previous environment after a brief delay
    sleep 5 # Allow in-flight requests to complete
    pm2 stop nextjs-$CURRENT
    
    echo "Deployment complete! Traffic now routing to $DEPLOY_TARGET environment."
    exit 0
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Health check failed, retry $RETRY_COUNT of $MAX_RETRIES..."
  sleep 2
done

echo "Deployment failed! Health check did not pass."
pm2 stop nextjs-$DEPLOY_TARGET
exit 1