#!/bin/sh

timestamp_nice=$(date '+%Y-%m-%d %H:%M:%S') # $(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Do stuff before forwarding to task definition/compose.yaml cmd $timestamp_nice"
exec /usr/bin/dumb-init -- "$@"