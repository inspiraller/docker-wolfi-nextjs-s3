#!/bin/sh


# port=
# for arg in "$@"; do
#     case $arg in
#         --port=*) port="${arg#*=}";; # Extract value after --port=
#         *) ;; #echo "Unknown option: $arg"; exit 1;;
#     esac
# done

if [[ -z "$PORT" ]]; then 
  echo "Error: PORT is required"
  exit 1
fi

log() {
  echo $1 >> /proc/1/fd/1
}
createFile() {
  echo $1 > $2
}

# This will check if the file: healthcheck-init exists.
# If it does not exist, it will create the file and write the timestamp to it and send a logof "init" to Cloudwatch
# If it does not exist, it will send a log of "still ok" vto Cloudwatch
# We can subscripe to the Cloudwatch log to invoke a lambda in a ci chain on deployments or other services.

getHealthLog() {
  log "healthcheck: test"

  # Constants
  WDIR="/app"
  SCRIPTS_DIR="${WDIR}/scripts"
  HEALTH_CHECK_FILE="$SCRIPTS_DIR/healthcheck-init"

  HEALTH_STATE_CREATED="Server initialized."
  HEALTH_STATE_UPDATE="Server check. Still ok."

  # dynamic variable
  health_state_state=
 
  # dynamic output
  timestamp=$(date +%s000)
  timestamp_nice=$(date '+%Y-%m-%d %H:%M:%S')
  awsEc2InstanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

  # HEALTHCHECK CMD curl -sf localhost:3000 -o /dev/null || (echo "No server!" && exit 1)
  if curl -sf "localhost:$PORT" -o /dev/null; then
      if [ ! -f "$HEALTH_CHECK_FILE" ]; then
        if [[ ! -w "$SCRIPTS_DIR" ]]; then
          log "Error: No write permission in $SCRIPTS_DIR"
          exit 1
        fi
        health_state_log=$HEALTH_STATE_CREATED
        createFile $timestamp "$HEALTH_CHECK_FILE"
      else
        health_state_log=$HEALTH_STATE_UPDATE
      fi
      log "$timestamp_nice - $health_state_log instanceId=$awsEc2InstanceId" # useful for capturing in Cloudwatch. Can subscribe lambda to log for ci architecture
      exit 0
  else
      log "Error: Server not reachable on PORT $PORT."
      exit 1
  fi
}

getHealthLog