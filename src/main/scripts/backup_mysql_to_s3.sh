#!/bin/bash
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
  echo "`date +%Y-%m-%dT%H%M%SZ` S3_REGION is not set in environment variable using $S3_REGION" | tee -a ~/action.log
fi

if [ -z "${MYSQL_HOST}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the MYSQL_HOST environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${MYSQL_USER}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the MYSQL_USER environment variable." | tee -a ~/action.log
  exit 1
fi

if [ -z "${MYSQL_PASSWORD}" ]; then
  echo "`date +%Y-%m-%dT%H%M%SZ` You need to set the MYSQL_PASSWORD environment variable or link to a container named MYSQL." | tee -a ~/action.log
  exit 1
fi

if [ -z "${GPG_PASSPHRASE}" ]; then
	echo "`date +%Y-%m-%dT%H%M%SZ` WARNING : The GPG_PASSPHRASE is empty" >&2 | tee -a ~/action.log
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${S3_REGION}

MYSQL_HOST_OPTS="-h ${MYSQL_HOST} -P ${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD}"
DUMP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")

# Multi file: yes
if [ ! -z "$(echo ${MULTI_FILES} | grep -i -E "(yes|true|1)")" ]; then
  if [ "${MYSQL_DATABASE}" == "--all-databases" ]; then
    DATABASES=`mysql ${MYSQL_HOST_OPTS} -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`
  else
    DATABASES=${MYSQL_DATABASE}
  fi

  for DB in ${DATABASES}; do
    echo "`date +%Y-%m-%dT%H%M%SZ` Creating individual dump of ${DB} from ${MYSQL_HOST}..." | tee -a ~/action.log

    DUMP_FILE="/tmp/${DB}.sql.gz"

    mysqldump ${MYSQL_HOST_OPTS} ${MYSQLDUMP_OPTIONS} --databases ${DB} | gzip > ${DUMP_FILE}

    if [ $? == 0 ]; then
      S3_FILE="${DUMP_START_TIME}.${DB}.sql.gz"

      copy_s3 ${DUMP_FILE} ${S3_FILE}
    else
      >&2 echo "`date +%Y-%m-%dT%H%M%SZ` Error creating dump of ${DB}" | tee -a ~/action.log
    fi
  done
# Multi file: no
else
  echo "`date +%Y-%m-%dT%H%M%SZ` Creating dump for ${MYSQLDUMP_DATABASE} from ${MYSQL_HOST}..." | tee -a ~/action.log

  DUMP_FILE="/tmp/dump.sql.gz"
  echo "mysqldump ${MYSQL_HOST_OPTS} ${MYSQLDUMP_OPTIONS} $MYSQLDUMP_DATABASE | gzip > ${DUMP_FILE}"
  mysqldump ${MYSQL_HOST_OPTS} ${MYSQLDUMP_OPTIONS} $MYSQLDUMP_DATABASE | gzip > ${DUMP_FILE}

  if [ $? == 0 ]; then
    S3_FILE="${DUMP_START_TIME}.dump.sql.gz"

    copy_s3 ${DUMP_FILE} ${S3_FILE}
  else
    >&2 echo "`date +%Y-%m-%dT%H%M%SZ` Error creating dump of all databases" | tee -a ~/action.log
  fi
fi

echo "`date +%Y-%m-%dT%H%M%SZ` SQL backup finished"  | tee -a ~/action.log

bin/notification_webhoock.sh
bin/notification_smtp.sh