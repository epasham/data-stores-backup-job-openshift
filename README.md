# 

This project should provide :
 S3 :
 - backup / restore to S3 for mysql
 - backup / restore to S3 for posgresql
 - backup / restore to S3 for mongodb
 - backup / restore to S3 for pvc  (using RWX)
 @todo
 - backup / restore to S3 for rsync not through (oc rsh)
    - the rsync sidecare ?
 sftp :
 - backup / restore to S3 for mysql
 - backup / restore to S3 for posgresql
 - backup / restore to S3 for mongodb
 - backup / restore to S3 for pvc  (using RWX)
 ftp :
 - backup / restore to S3 for mysql
 - backup / restore to S3 for posgresql
 - backup / restore to S3 for mongodb
 - backup / restore to S3 for pvc  (using RWX)



    
    
# build

oc new-build --name='bck-tools' --binary=true && \
oc get bc bck-tools -o json | jq -e '(.spec.strategy.dockerStrategy.dockerfilePath |= . + "./src/main/dockerfiles/Dockerfile")' | oc replace bc backup-job -f - && \
oc start-build bck-tools --from-dir=. && sleep 5 && oc log -f bc/bck-tools

oc delete jobs bck-mongodb ; oc start-build bck-tools --from-dir=. -F && oc create -f src/main/ose-tools/jobs-backup-mongodb.yaml
    
# run as job :


# run as a cronjob :

# testing strategy:



0 - build image

1.1 - start mysql ephemeral

1.2 - import data into mysql ephemeral

1.3 - check data from mysql ephemeral

1.4 - backup mysql ephemeral

1.5 - modify some data

1.6 - check data are modified

1.7 - restore mysql ephemeral

src/test/test-scripts/test_mysql_back-up.sh



1.3 - backup mysql ephemeral
1.1 - start mysql ephemeral
1.1 - start mysql ephemeral
1.1 - start mysql ephemeral

# data

for posgresql : http://www.postgresqltutorial.com/postgresql-sample-database/
for mongodb : https://docs.mongodb.com/getting-started/shell/import-data/

# 
PERSISTENT_DATASTORE=mongodb && oc delete dc/${PERSISTENT_DATASTORE} svc/${PERSISTENT_DATASTORE} pvc/${PERSISTENT_DATASTORE} secret/${PERSISTENT_DATASTORE}