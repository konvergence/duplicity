#!/bin/bash
# wait-for-postgres.sh

[ ! -z ${DEBUG}  ] && set -x


DB_MAX_WAIT=${DB_MAX_WAIT:-30}

# wait database connection
COUNTER=0
until [ ${COUNTER} -ge  ${DB_MAX_WAIT} ] || echo "exit" | mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_SYSTEM_USER}" -p"${DB_SYSTEM_PASSWORD}" &> /dev/null
do
   echo "database is unavailable - sleeping"
  sleep 1
  let COUNTER=COUNTER+1
done



if  [  ${COUNTER} -ge  ${DB_MAX_WAIT} ]; then
     echo "ERROR: database is unavailable" 1>&2
	 exit -1
fi


DUMP_OPTIONS=""
if [ "${DB_SKIP_DROP}" = "true" ]; then
  DUMP_OPTIONS="${DUMP_OPTIONS} --skip-add-drop-table"
  echo "skip drop order into dump"
fi


if [ "${DB_DATABASES}" = ""]; then
  DUMP_OPTIONS="${DUMP_OPTIONS} --all-databases"
  echo "dump all databases"
else
  DUMP_OPTIONS="${DUMP_OPTIONS} --databases ${DB_DATABASES}"
  echo "dump specific databases: ${DB_DATABASES}"
fi



# dump all databases

rm -f ${DATA_FOLDER}/dumpall.out*

if [ "${DB_COMPRESS_ENABLE}" == "true" ]; then
    mysqldump --host="${DB_HOST}" --port="${DB_PORT}" -u${DB_SYSTEM_USER} -p"${DB_SYSTEM_PASSWORD}" ${DUMP_OPTIONS} | gzip -${DB_COMPRESS_LEVEL}  > ${DATA_FOLDER}/dumpall.out.gz

else
    mysqldump --host="${DB_HOST}" --port="${DB_PORT}" -u${DB_SYSTEM_USER} -p"${DB_SYSTEM_PASSWORD}" ${DUMP_OPTIONS} > ${DATA_FOLDER}/dumpall.out
fi

if [ $? -ne 0 ]; then
  echo "ERROR: backup ${DATA_FOLDER}/dumpall.out" 1>&2
  exit -1
fi
