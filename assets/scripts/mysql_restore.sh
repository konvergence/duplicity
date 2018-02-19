#!/bin/bash
# wait-for-postgres.sh

[ ! -z $DEBUG  ] && set -x


DB_MAX_WAIT=${DB_MAX_WAIT:-30}


# wait database connection
COUNTER=0
until [ $COUNTER -ge  ${DB_MAX_WAIT} ] || echo "exit" | mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_SYSTEM_USER}" -p"${DB_SYSTEM_PASSWORD}" &> /dev/null
do
   echo "database is unavailable - sleeping"
  sleep 1
  let COUNTER=COUNTER+1 
done



if  [  $COUNTER -ge  ${DB_MAX_WAIT} ]; then
     echo "ERROR: database is unavailable" 1>&2
	 exit -1
fi



# restore all databases
mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_SYSTEM_USER}" -p"${DB_SYSTEM_PASSWORD}" < ${DATA_FOLDER}/dumpall.out
if [ $? -ne 0 ]; then
  echo "ERROR: restore ${DATA_FOLDER}/dumpall.out" 1>&2
  exit -1
fi


