#!/bin/bash
set -e
set -o pipefail

if [ ! -z "$WEBHOOCK_NOTIFYCATION" ]; then
  curl -ik $WEBHOOCK_NOTIFYCATION | tee -a ~/action.log
else
  echo "`date +%Y-%m-%dT%H%M%SZ` no WEBHOOCK_NOTIFYCATION " | tee -a ~/action.log
fi
