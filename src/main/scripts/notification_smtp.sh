#!/bin/bash
set -e
set -o pipefail

if [ ! -z "$EMAIL_NOTIFYCATION_DESTINATION" ]; then
  if [ -z "$EMAIL_NOTIFYCATION_SENDER" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the EMAIL_NOTIFYCATION_SENDER environment variable."  | tee -a ~/action.log
    exit 1
  fi
  if [ -z "$SMTP_HOST" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the SMTP_HOST environment variable."  | tee -a ~/action.log
    exit 1
  fi 
  if [ -z "$SMTP_PORT" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the SMTP_PORT environment variable."  | tee -a ~/action.log
    exit 1
  fi 
  if [ -z "$EMAIL_NOTIFYCATION_DESTINATION" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the EMAIL_NOTIFYCATION_DESTINATION environment variable."  | tee -a ~/action.log
    exit 1
  fi
  if [ -z "$EMAIL_SUBJECT" ]; then
    EMAIL_SUBJECT="Default actions log subject";
    echo "`date +%Y-%m-%dT%H%M%SZ` EMAIL_SUBJECT is not set in environment variable using \" $EMAIL_SUBJECT \""  | tee -a ~/action.log
  fi 
  cat ~/action.log | mailx -v  -s "$EMAIL_SUBJECT " -r "$EMAIL_NOTIFYCATION_SENDER" -S smtp="$SMTP_HOST:$SMTP_PORT" $EMAIL_NOTIFYCATION_DESTINATION
else
  echo "`date +%Y-%m-%dT%H%M%SZ` no EMAIL_NOTIFYCATION_DESTINATION " | tee -a ~/action.log
fi