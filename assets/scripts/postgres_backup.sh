#!/bin/bash
# wait-for-postgres.sh
# https://serverfault.com/questions/857339/backing-up-restoring-postgres-using-pg-dumpall-split-gzip-set-on-error

[ ! -z ${DEBUG}  ] && set -x


DB_MAX_WAIT=${DB_MAX_WAIT:-30}


# postgres env
export PGHOST=${DB_HOST}
export PGPORT=${DB_PORT}
export PGDATABASE=${DB_SYSTEM_REPO}
export PGUSER=${DB_SYSTEM_USER}
export PGPASSWORD=${DB_SYSTEM_PASSWORD}

# wait database connection
COUNTER=0
until [  ${COUNTER} -ge  ${DB_MAX_WAIT} ] || psql -P pager=off -c '\l' ; do
    echo "database is unavailable - sleeping"
  sleep 1
  let COUNTER=COUNTER+1
done

if  [  ${COUNTER} -ge  ${DB_MAX_WAIT} ]; then
  echo "ERROR: database is unavailable" 1>&2
  exit -1
fi


DUMP_OPTIONS=""
if [ "${DB_SKIP_DROP}" = "false" ]; then
   DUMP_OPTIONS="${DUMP_OPTIONS} --clean"
else
    echo "skip drop order into dump"
fi




# dump all databases

rm -f ${DATA_FOLDER}/dumpall.out*


# dump all databases
if [ "${DB_DATABASES}" = "" ]; then
    echo "dump all databases"

  if [ "${DB_COMPRESS_ENABLE}" == "true" ]; then
   pg_dumpall ${DUMP_OPTIONS} | gzip -${DB_COMPRESS_LEVEL} > ${DATA_FOLDER}/dumpall.out.gz
  else
      pg_dumpall ${DUMP_OPTIONS} > ${DATA_FOLDER}/dumpall.out
  fi

else
# dump databases list
# see https://stackoverflow.com/questions/3518218/moving-a-database-with-pg-dump-and-psql-u-postgres-db-name-results-in-er
  echo "dump specific databases: ${DB_DATABASES}"

  for db in ${DB_DATABASES}; do
    if [ "${DB_COMPRESS_ENABLE}" == "true" ]; then
        # Dump schema of database
        pg_dump ${DUMP_OPTIONS} --create ${db} | gzip -${DB_COMPRESS_LEVEL} >> ${DATA_FOLDER}/dumpall.out.gz
    else
        pg_dump ${DUMP_OPTIONS} --create ${db} >> ${DATA_FOLDER}/dumpall.out
    fi
  done
fi



if [ $? -ne 0 ]; then
    echo "ERROR: backup ${DATA_FOLDER}/dumpall.out" 1>&2
    exit -1
fi
