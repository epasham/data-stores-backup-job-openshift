#!/bin/bash
#
# This script is only create for testing this job
#
#
#
#
#

# https://dev.to/thiht/shell-scripts-matter
#
set -euo pipefail
IFS=$'\n\t'

#/ Usage: ./test_mysql_back-up.sh
#/ Description: will start a mysql ephemeral database, fill it, backup it, change it, and restore it
#/ Examples: ./run-tail.sh
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
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mysql-backup;
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mysql-restore;
   # check that services are ok
   EXPECTED_RES_01="100";
   EXPECTED_RES_02="100";
   EXPECTED_RES_03="Marshall";
   EXPECTED_RES_04="103";
   EXPECTED_RES_05="105";
   EXPECTED_RES_06="Paris";
   EXPECTED_RES_07="100";
   EXPECTED_RES_08="100";
   EXPECTED_RES_09="Marshall";
   #
   # @ todo seperate it into several sub function
   info "initiate smaple dtb";
   TMP_MYSQL_DATABASENAME="sampledb"
   TMP_DUMP="src/test/resources/sampledtb.sql"
   TMP_POD=$(oc get po | grep "mysql" | grep "Running" | cut -d " " -f 1) &&
   TMP_MYSQL_USER=$(oc exec $TMP_POD -- bash -c 'echo -n $MYSQL_USER') &&
   TMP_MYSQL_PASSWORD=$(oc exec $TMP_POD -- bash -c 'echo -n $MYSQL_PASSWORD') &&
   
   cat $TMP_DUMP | oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME;
   RES_01=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT COUNT(Sample01.id) FROM Sample01" | grep '|' | cut -d ' ' -f 2);
   info $RES_01;
   RES_02=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT COUNT(Sample02.id) FROM Sample02" | grep '|' | cut -d ' ' -f 2); 
   info $RES_02;
   RES_03=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT Sample01.REGION FROM Sample01 WHERE Sample01.NAME='Lillith'" | grep '|' | cut -d ' ' -f 2);
   info $RES_03;
   
   if [[ "${EXPECTED_RES_01}" != "${RES_01}" ]]; then
     fatal "expected \"${EXPECTED_RES_01}\" and it was \"${RES_01}\"";
   fi
   if [[ "${EXPECTED_RES_02}" != "${RES_02}" ]]; then
     fatal "expected \"${EXPECTED_RES_02}\" and it was \"${RES_02}\"";
   fi
   if [[ "${EXPECTED_RES_03}" != "${RES_03}" ]]; then
     fatal "expected \"${EXPECTED_RES_03}\" and it was \"${RES_03}\"";
   fi
   
   info "launch back-up job";
   
   S3_JSON=$(oc get secrets s3-mysql -o json);
   info $(echo ${S3_JSON}| jq -r .data.\"gpg-passphrase\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-access-key-id\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-bucket\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-prefix\" | base64 -D);
   info $(echo ${S3_JSON}| jq -r .data.\"s3-secret-access-key\" | base64 -D);
   
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mysql-backup;
   oc delete jobs -l io.shyrka.erebus.tooling-info/role=mysql-restore;
   oc create -f src/test/resources/jobs-backup-mysql.single.dtb.test.yaml;
   
   while [ -z $(oc get po -l app=bck-mysql --no-headers | grep 'Completed') ] ; do 
     echo waiting;
     sleep 5;
   done
   
   oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="UPDATE Sample01 SET Sample01.REGION='Paris' WHERE Sample01.NAME='Lillith'; INSERT INTO Sample02 (id,COMPANY,STREET,CITY,SIRET,PHONE,MOBILE) VALUES (101,'Duis A Mi Company','587-2233 Molestie. Rd.','Elversele','568137491','16930505 4653','173028 4757'),(102,'Convallis Dolor Corp.','Ap #371-7040 Imperdiet St.','Albiano','575868088','16210821 9474','333830 0605'),(103,'Mauris Limited','3250 Turpis St.','Moen','190065078','16670721 8597','804684 6302'),(104,'Vel Pede Blandit Limited','806-2901 Duis Rd.','Pollein','190069120','16291219 4939','036339 4313'),(105,'Sit Amet Inc.','P.O. Box 567, 3660 Fusce Road','Sylvan Lake','798227773','16740905 2169','339288 7992');INSERT INTO Sample01 (id,NAME,REGION,STREET,SIRET,PHONE,MOBILE) VALUES (161,'Duncan','Ifeoma','5626 Est. Road','162277750','16021030 7872','258240 2216'),(162,'Signe','Julie','Ap #604-4023 Eu Rd.','557020260','16830101 4372','748446 9635'),(163,'Kalia','Wing','648-6424 Adipiscing, Av.','896976610','16021120 2171','277007 0601')";
   
   RES_04=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT COUNT(Sample01.id) FROM Sample01" | grep '|' | cut -d ' ' -f 2);
   info $RES_04;
   RES_05=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT COUNT(Sample02.id) FROM Sample02" | grep '|' | cut -d ' ' -f 2); 
   info $RES_05;
   RES_06=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT Sample01.REGION FROM Sample01 WHERE Sample01.NAME='Lillith'" | grep '|' | cut -d ' ' -f 2);
   info $RES_06;
   
   if [[ "${EXPECTED_RES_04}" != "${RES_04}" ]]; then
     fatal "expected \"${EXPECTED_RES_04}\" and it was \"${RES_04}\"";
   fi
   if [[ "${EXPECTED_RES_05}" != "${RES_05}" ]]; then
     fatal "expected \"${EXPECTED_RES_05}\" and it was \"${RES_05}\"";
   fi
   if [[ "${EXPECTED_RES_06}" != "${RES_06}" ]]; then
     fatal "expected \"${EXPECTED_RES_06}\" and it was \"${RES_06}\"";
   fi
   
   oc create -f src/test/resources/jobs-restore-mysql.test.yaml;

   while [ -z $(oc get po -l app=rst-mysql --no-headers | grep 'Completed') ] ; do 
     echo waiting;
     sleep 5;
   done
   
   RES_07=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT COUNT(Sample01.id) FROM Sample01" | grep '|' | cut -d ' ' -f 2);
   info $RES_07;
   RES_08=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT COUNT(Sample02.id) FROM Sample02" | grep '|' | cut -d ' ' -f 2); 
   info $RES_08;
   RES_09=$(oc exec -ti $TMP_POD -- /opt/rh/rh-mysql57/root/bin/mysql --skip-column-names --user=$TMP_MYSQL_USER --password=$TMP_MYSQL_PASSWORD --database=$TMP_MYSQL_DATABASENAME --execute="SELECT Sample01.REGION FROM Sample01 WHERE Sample01.NAME='Lillith'" | grep '|' | cut -d ' ' -f 2);
   info $RES_09;
   
   if [[ "${EXPECTED_RES_01}" != "${RES_07}" ]]; then
     fatal "expected \"${EXPECTED_RES_01}\" and it was \"${RES_07}\"";
   fi
   if [[ "${EXPECTED_RES_02}" != "${RES_08}" ]]; then
     fatal "expected \"${EXPECTED_RES_02}\" and it was \"${RES_08}\"";
   fi
   if [[ "${EXPECTED_RES_03}" != "${RES_09}" ]]; then
     fatal "expected \"${EXPECTED_RES_03}\" and it was \"${RES_09}\"";
   fi
   
fi ;

