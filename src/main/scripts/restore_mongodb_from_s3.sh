#! /bin/bash

set -e
set -o pipefail

cat <<EOF >~/.s3cfg
[default]
EOF

if [ a$http_proxy != 'a' ] ; then
  proxy_host=`echo $http_proxy | sed -e 's@http://@@' -e 's/:.*$//'`
  proxy_port=`echo $http_proxy | sed -e 's/^.*://' -e 's@/$@@'`

  cat <<EOF >> ~/.s3cfg
proxy_host = $proxy_host
proxy_port = $proxy_port
EOF
fi

if [ -z "${S3_ACCESS_KEY_ID}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_ACCESS_KEY_ID environment variable."  | tee -a ~/action.log
  exit 1
fi

if [ -z "${S3_SECRET_ACCESS_KEY}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_SECRET_ACCESS_KEY environment variable."  | tee -a ~/action.log
  exit 1
fi

if [ -z "${S3_BUCKET}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the S3_BUCKET environment variable."  | tee -a ~/action.log
  exit 1
fi

if [ -z "${S3_REGION}" ]; then
  S3_REGION="us-west-1"
  echo "`date +%Y-%m-%dT%H%M%SZ` S3_REGION is not set in environment variable using $S3_REGION"  | tee -a ~/action.log
fi

if [ -z "${MONGODB_VERBOSE}" ]; then
  MONGODB_VERBOSE="0"
  echo "`date +%Y-%m-%dT%H%M%SZ` MONGODB_VERBOSE is not set in environment variable using ${MONGODB_VERBOSE}" | tee -a ~/action.log
fi

if [ -z "${MONGODB_HOST}" ]; then
  MONGODB_HOST="mongodb"
  echo "`date +%Y-%m-%dT%H%M%SZ` MONGODB_HOST is not set in environment variable using $MONGODB_HOST"  | tee -a ~/action.log
fi

if [ -z "${MONGODB_DATABASE}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the MONGODB_DATABASE environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${MONGODB_USER}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the MONGODB_USER environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${MONGODB_PASSWORD}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the MONGODB_PASSWORD environment variable or link to a container named MONGODB."  | tee -a ~/action.log
  exit 1
fi

if [ -z "${GPG_PASSPHRASE}" ]; then
	echo "`date +%Y-%m-%dT%H%M%SZ` WARN : The GPG_PASSPHRASE is empty" >&2
fi


# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

MONGODB_HOST_OPTS="  --verbose=${MONGODB_VERBOSE} --host=${MONGODB_HOST} --port=${MONGODB_PORT} --username=${MONGODB_USER} --password=${MONGODB_PASSWORD} --batchSize=1 "

if [ ! -z "${ID_BUCKET_RESTORE}" ]; then
    echo "`date +%Y-%m-%dT%H%M%SZ` Finding id bucket ${ID_BUCKET_RESTORE} "  | tee -a ~/action.log
    BUCKET_RESTORE=$ID_BUCKET_RESTORE
else
    echo "`date +%Y-%m-%dT%H%M%SZ` Finding latest backup"  | tee -a ~/action.log
    echo "s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} \
	  --ssl --server-side-encryption ls s3://$S3_BUCKET/$S3_PREFIX/"
    BUCKET_RESTORE=$(s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} \
	  --ssl --server-side-encryption ls s3://$S3_BUCKET/$S3_PREFIX/ | sort | tail -n 1 | awk '{ print $4 }')
fi

echo "`date +%Y-%m-%dT%H%M%SZ` Fetching ${BUCKET_RESTORE} from S3" | tee -a ~/action.log

if [ -z "${GPG_PASSPHRASE}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` WARNING : GPG_PASSPHRASE is empty" | tee -a ~/action.log
	s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} \
	  --ssl --skip-existing --server-side-encryption get ${BUCKET_RESTORE} dump.raw
else
  echo "`date +%Y-%m-%dT%H%M%SZ` using GPG_PASSPHRASE for encryption" | tee -a ~/action.log
  s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} \
	  --ssl --skip-existing --server-side-encryption get ${BUCKET_RESTORE} dump.raw.gpg
  echo "$GPG_PASSPHRASE" | gpg --batch --no-tty --yes --passphrase-fd 0 --decrypt -o dump.raw dump.raw.gpg
  rm dump.raw.gpg
fi
echo "`date +%Y-%m-%dT%H%M%SZ` Restoring ${BUCKET_RESTORE}" | tee -a ~/action.log

echo "Restoring ${BUCKET_RESTORE}"

echo "mongorestore ${MONGODB_HOST_OPTS} --authenticationDatabase=${MONGODB_DATABASE} --archive=\"dump.raw\" " | tee -a ~/action.log
mongorestore ${MONGODB_HOST_OPTS} --authenticationDatabase=${MONGODB_DATABASE} --archive="dump.raw" | tee -a ~/action.log

echo "`date +%Y-%m-%dT%H%M%SZ` Restore complete" | tee -a ~/action.log

rm dump.raw

bin/notification_webhoock.sh
bin/notification_smtp.sh