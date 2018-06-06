#!/bin/bash
#
# This script is only create for testing this job
#
#
#

# https://dev.to/thiht/shell-scripts-matter
#
set -euo pipefail
IFS=$'\n\t'

#/ Usage: ./test_monododg_back-up.sh
#/ Description: will start a mongodb ephemeral database, fill it, backup it, change it, and restore it
#/ Examples: ./test_monododg_back-up.sh
#/ Options:
#/   --help: Display this help message
usage() { grep '^#/' "$0" | cut -c4- ; exit 0 ; }
expr "$*" : ".*--help" > /dev/null && usage

readonly LOG_FILE="/tmp/$(basename "$0").log"
info()    { echo "[INFO]    $*" | tee -a "$LOG_FILE" >&2 ; }
warning() { echo "[WARNING] $*" | tee -a "$LOG_FILE" >&2 ; }
error()   { echo "[ERROR]   $*" | tee -a "$LOG_FILE" >&2 ; }
fatal()   { echo "[FATAL]   $*" | tee -a "$LOG_FILE" >&2 ; exit 1 ; }

cleanup() {
    # Remove temporary files
    # Restart services
    # ...
    echo "";
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  
   # just to make sure the job is not there
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mongodb-backup;
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mongodb-restore;
   # check that services are ok
   true
   EXPECTED_RES_00="true";
   EXPECTED_RES_01="12134";
   EXPECTED_RES_02="1875";
   EXPECTED_RES_03="9511";
   EXPECTED_RES_04="{\"nInserted\":0,\"nUpserted\":0,\"nMatched\":0,\"nModified\":0,\"nRemoved\":5332}";
   EXPECTED_RES_05="0";
   EXPECTED_RES_06="4179";
   
   # @ todo seperate it into several sub function
   info "initiate sample database and collection";
   
   JOB_SCRIPT_PATH=${JOB_SCRIPT_PATH:-"src/test/resources"};
   info "`date +%Y-%m-%dT%H%M%SZ` JOB_SCRIPT_PATH is  ${JOB_SCRIPT_PATH}";
   JOB_BACKUP=${JOB_BACKUP:-"jobs-backup-mongodb.single.dtb.test.camp.yaml"};
   info "`date +%Y-%m-%dT%H%M%SZ` JOB_BACKUP is  ${JOB_BACKUP}";
   JOB_RESTORE=${JOB_RESTORE:-"jobs-restore-mongodb.test.camp.yaml"};
   info "`date +%Y-%m-%dT%H%M%SZ` JOB_RESTORE is  ${JOB_RESTORE}";
   TMP_MONGODB_DATABASENAME=${TMP_MYSQL_DATABASENAME:-"sampledb"};
   info "`date +%Y-%m-%dT%H%M%SZ` TMP_MYSQL_DATABASENAME is  ${TMP_MONGODB_DATABASENAME}";
   
   TMP_MONGODB_COLLECTION=${TMP_DUMP:-"restaurants"};
   info "`date +%Y-%m-%dT%H%M%SZ` TMP_MONGODB_COLLECTION is  ${TMP_MONGODB_COLLECTION}";
   
   TMP_DUMP=${TMP_DUMP:-"src/test/resources/sample-primer-dataset.json"};
   info "`date +%Y-%m-%dT%H%M%SZ` TMP_DUMP is  ${TMP_DUMP}";
   
   
   TMP_POD=$(oc get po | grep "mongodb" | grep "Running" | cut -d " " -f 1) &&
   TMP_MONGODB_USER=$(oc exec $TMP_POD -- bash -c 'echo -n $MONGODB_USER') &&
   TMP_MONGODB_PASSWORD=$(oc exec $TMP_POD -- bash -c 'echo -n $MONGODB_PASSWORD') &&
   TMP_MONGODB_SERVICE_HOST=$(oc exec $TMP_POD -- bash -c 'echo -n $MONGODB_SERVICE_HOST') &&
   TMP_MONGODB_SERVICE_PORT_MONGO=$(oc exec $TMP_POD -- bash -c 'echo -n $MONGODB_SERVICE_PORT_MONGO') &&
   
   RES_00=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.drop();\" " | tr -d ' ' );
   info "--$(echo -ne ${RES_00%?})--";
   #exit 0
   cat $TMP_DUMP | oc exec -ti $TMP_POD -- /opt/rh/rh-mongodb32/root/bin/mongoimport --username=$TMP_MONGODB_USER --password=$TMP_MONGODB_PASSWORD --collection=$TMP_MONGODB_COLLECTION --db=$TMP_MONGODB_DATABASENAME;
   
   #oc exec -ti $TMP_POD -- mongo --username=$MONGODB_USER --host=$MONGODB_SERVICE_HOST --port=$MONGODB_SERVICE_PORT_MONGO --password=$MONGODB_PASSWORD $MONGODB_DATABASE --eval "db.restaurants.find({'borough':'Manhattan'}).size();"
   #RES_01=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough':'Manhattan'}).size();\" ");
   RES_01=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({}).size();\" ");
   info $RES_01;
   RES_02=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough':'Manhattan','grades':{\\\$size: 5 }}).size();\" ");
   info $RES_02;
   RES_03=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough': {\\\$ne :'Brooklyn'}}).size();\" ");
   info $RES_03;
   if [[ "${EXPECTED_RES_00}" != "${RES_00%?}" ]]; then
     warn "expected \"${EXPECTED_RES_00}\" and it was \"${RES_00%?}\" this could happen if the collection was empty";
   fi
   if [[ "${EXPECTED_RES_01}" != "${RES_01%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_01}\" and it was \"${RES_01%?}\"";
   fi
   if [[ "${EXPECTED_RES_02}" != "${RES_02%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_02}\" and it was \"${RES_02%?}\"";
   fi
   if [[ "${EXPECTED_RES_03}" != "${RES_03%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_03}\" and it was \"${RES_03%?}\"";
   fi
   
   info "launch back-up job";
   
   S3_JSON=$(oc get secrets s3-mongodb -o json);
   info $(echo ${S3_JSON}| jq -r .data.\"gpg-passphrase\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-access-key-id\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-bucket\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-prefix\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-secret-access-key\" | base64 -D);
   
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mongodb-backup;
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mongodb-restore;
   
   oc create -f ${JOB_SCRIPT_PATH}/${JOB_BACKUP};
   
   while [ -z $(oc get po -l app=bck-mongodb --no-headers | grep 'Completed') ] ; do 
     echo waiting;
     sleep 5;
   done
   
   
   RES_04=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"JSON.stringify(db.restaurants.remove({'borough':'Manhattan'}));\" ");
   info $RES_04;
   RES_05=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough':'Manhattan','grades':{\\\$size: 5 }}).size();\" ");
   info $RES_05;
   RES_06=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough': {\\\$ne :'Brooklyn'}}).size();\" ");
   info $RES_06;
   
   if [[ "${EXPECTED_RES_04}" != "${RES_04%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_04}\" and it was \"${RES_04%?}\"";
   fi
   if [[ "${EXPECTED_RES_05}" != "${RES_05%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_05}\" and it was \"${RES_05%?}\"";
   fi
   if [[ "${EXPECTED_RES_06}" != "${RES_06%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_06}\" and it was \"${RES_06%?}\"";
   fi
   
   oc create -f ${JOB_SCRIPT_PATH}/${JOB_RESTORE};

   while [ -z $(oc get po -l app=rst-mongodb --no-headers | grep 'Completed') ] ; do 
     echo waiting;
     sleep 5;
   done
   
   RES_07=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({}).size();\" ");
   info $RES_07;
   RES_08=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough':'Manhattan','grades':{\\\$size: 5 }}).size();\" ");
   info $RES_08;
   RES_09=$(oc exec -ti $TMP_POD -- bash -c " mongo --quiet --username=\$MONGODB_USER --host=\$MONGODB_SERVICE_HOST --port=\$MONGODB_SERVICE_PORT_MONGO --password=\$MONGODB_PASSWORD \$MONGODB_DATABASE --eval \"db.restaurants.find({'borough': {\\\$ne :'Brooklyn'}}).size();\" ");
   info $RES_09;
   
   if [[ "${EXPECTED_RES_01}" != "${RES_07%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_01}\" and it was \"${RES_07%?}\"";
   fi
   if [[ "${EXPECTED_RES_02}" != "${RES_08%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_02}\" and it was \"${RES_08%?}\"";
   fi
   if [[ "${EXPECTED_RES_03}" != "${RES_09%?}" ]]; then
     fatal "expected \"${EXPECTED_RES_03}\" and it was \"${RES_09%?}\"";
   fi
   
fi ;

