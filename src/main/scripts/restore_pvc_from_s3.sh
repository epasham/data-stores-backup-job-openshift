#! /bin/bash

set -e
set -o pipefail

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

if [ -z "${LOCAL_FILEPATH}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the LOCAL_FILEPATH environment variable." | tee -a ~/action.log
  exit 1
fi

#if [ -z "${PVC_NAME}" ]; then
#  PVC_NAME=$RANDOM
#  echo "`date +%Y-%m-%dT%H%M%SZ` PVC_NAME is not set in environment variable using $PVC_NAME" | tee -a ~/action.log
#fi

if [ -z "${GPG_PASSPHRASE}" ]; then
	echo "`date +%Y-%m-%dT%H%M%SZ` WARN : The GPG_PASSPHRASE is empty" >&2
fi


# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

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
	  --ssl --server-side-encryption get ${BUCKET_RESTORE} dump.tar.gz
else
  echo "`date +%Y-%m-%dT%H%M%SZ` using GPG_PASSPHRASE for encryption" | tee -a ~/action.log
  s3cmd --access_key=${S3_ACCESS_KEY_ID} --secret_key=${S3_SECRET_ACCESS_KEY} \
	  --ssl --server-side-encryption get ${BUCKET_RESTORE} dump.tar.gz.gpg
  echo "$GPG_PASSPHRASE" | gpg --batch --no-tty --yes --passphrase-fd 0 --decrypt -o dump.tar.gz dump.tar.gz.gpg
  rm dump.tar.gz.gpg
fi

echo "`date +%Y-%m-%dT%H%M%SZ` Restoring ${BUCKET_RESTORE}" | tee -a ~/action.log

rm -rf ${LOCAL_FILEPATH}/*
tar -xzvf dump.tar.gz -C /

rm dump.tar.gz

echo "`date +%Y-%m-%dT%H%M%SZ` Restore complete" | tee -a ~/action.log

bin/notification_webhoock.sh
bin/notification_smtp.sh