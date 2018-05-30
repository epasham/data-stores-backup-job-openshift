#!/bin/bash
set -e
set -o pipefail

copy_s3 () {
  SRC_FILE=$1
  DEST_FILE=$2

  echo "`date +%Y-%m-%dT%H%M%SZ` Uploading ${DEST_FILE} on S3..."  | tee -a ~/action.log

  if [ -z "${GPG_PASSPHRASE}" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` WARNING : GPG_PASSPHRASE is empty" | tee -a ~/action.log
    #echo "cat ${SRC_FILE}  | s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} --server-side-encryption --ssl put - s3://${S3_BUCKET}/${S3_PREFIX}/${DEST_FILE} || exit 2"
    cat ${SRC_FILE}  | \
     s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} --ssl --server-side-encryption put - s3://${S3_BUCKET}/${S3_PREFIX}/${DEST_FILE} || exit 2
  else
    echo "`date +%Y-%m-%dT%H%M%SZ` using GPG_PASSPHRASE to encrypt" | tee -a ~/action.log
    #echo "cat ${SRC_FILE}  | s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} --server-side-encryption --ssl put - s3://${S3_BUCKET}/${S3_PREFIX}/${DEST_FILE} || exit 2"
    echo "${GPG_PASSPHRASE}" | \
     gpg --batch --no-tty --yes --passphrase-fd 0 --symmetric --output - ${SRC_FILE}  | \
     s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} --ssl --server-side-encryption put - s3://${S3_BUCKET}/${S3_PREFIX}/${DEST_FILE} || exit 2
  fi                                                                                                          
  

  if [ $? != 0 ]; then
    >&2 echo "`date +%Y-%m-%dT%H%M%SZ` Error uploading ${DEST_FILE} on S3" | tee -a ~/action.log
  fi

  rm ${SRC_FILE}
}


if [ -z "${S3_ACCESS_KEY_ID}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_ACCESS_KEY_ID environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${S3_SECRET_ACCESS_KEY}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_SECRET_ACCESS_KEY environment variable." | tee -a ~/action.log
  exit 1
fi

if [  -z "${S3_BUCKET}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_BUCKET environment variable." | tee -a ~/action.log
  exit 1
fi

if [  -z "${S3_PREFIX}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_PREFIX environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${S3_REGION}" ]; then
  S3_REGION="us-west-1"
  echo "`date +%Y-%m-%dT%H%M%SZ` S3_REGION is not set in environment variable using ${S3_REGION}" | tee -a ~/action.log
fi

if [ -z "${POSTGRES_DATABASE}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the POSTGRES_DATABASE environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${POSTGRES_HOST}" ]; then
  if [ -z "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the POSTGRES_HOST environment variable." | tee -a ~/action.log
    exit 1
   else 
    POSTGRES_HOST=${POSTGRES_PORT_5432_TCP_ADDR}
    echo "`date +%Y-%m-%dT%H%M%SZ` POSTGRES_HOST is not set in environment variable using ${POSTGRES_PORT_5432_TCP_ADDR}" | tee -a ~/action.log
  fi
fi

if [ -z "${POSTGRES_PORT}" ]; then
  if [ -z "${POSTGRES_PORT_5432_TCP_PORT}" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the POSTGRES_PORT environment variable." | tee -a ~/action.log
    exit 1
   else 
    POSTGRES_PORT=${POSTGRES_PORT_5432_TCP_PORT}
    echo "`date +%Y-%m-%dT%H%M%SZ` POSTGRES_PORT is not set in environment variable using ${POSTGRES_PORT_5432_TCP_PORT}" | tee -a ~/action.log
  fi
fi

if [ -z "${POSTGRES_USER}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the POSTGRES_USER environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${POSTGRES_PASSWORD}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."  | tee -a ~/action.log
  exit 1
fi

if [ -z "${GPG_PASSPHRASE}" ]; then
	echo "`date +%Y-%m-%dT%H%M%SZ` WARNING : The GPG_PASSPHRASE is empty" >&2 | tee -a ~/action.log
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${S3_REGION}

export PGPASSWORD=${POSTGRES_PASSWORD}
POSTGRES_HOST_OPTS=" --create --blobs -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER}"
DUMP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")

echo "`date +%Y-%m-%dT%H%M%SZ` Creating dump of ${POSTGRES_DATABASE} database from ${POSTGRES_HOST}..." | tee -a ~/action.log

DUMP_FILE="/tmp/dump.sql.gz"
S3_FILE="${DUMP_START_TIME}.dump.sql.gz" 

# TODO CORRECT THE right here, there is something fuzzy
# echo "psql -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER}  ${POSTGRES_DATABASE} -c 'DROP EXTENSION IF EXISTS plpgsql;'" | tee -a ~/action.log
# psql -h ${POSTGRES_HOST} -p ${POSTGRES_PORT} -U ${POSTGRES_USER}  ${POSTGRES_DATABASE} -c 'DROP EXTENSION IF EXISTS plpgsql;' | tee -a ~/action.log


echo "pg_dump ${POSTGRES_HOST_OPTS} ${POSTGRES_DATABASE}" | tee -a ~/action.log
pg_dump ${POSTGRES_HOST_OPTS} ${POSTGRES_DATABASE} | gzip > ${DUMP_FILE}
copy_s3 ${DUMP_FILE} ${S3_FILE}


echo "`date +%Y-%m-%dT%H%M%SZ` SQL backup uploaded successfully"  | tee -a ~/action.log

bin/notification_webhoock.sh
bin/notification_smtp.sh