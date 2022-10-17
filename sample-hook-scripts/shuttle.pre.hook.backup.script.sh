#!/bin/bash


export SHUTTLE_HOME=${SHUTTLE_HOME:-/data/shuttle/home}
export REPOSITORIES_FOLDER=${REPOSITORIES_FOLDER:-${SHUTTLE_HOME}/repositories}
export DUMPS_FOLDER=${DUMPS_FOLDER:-${SHUTTLE_HOME}/dumps}

export DUMPS_KEEP=${DUMPS_KEEP:-0}

# DUMPS_FOLDER is /data/shuttle/home/dumps


# this allow to dump shuttle FS repository in FS mode
if [ ! -d "${REPOSITORIES_FOLDER}" ]; then
  echo "this shuttle have no FS repositories"
  exit 0
fi


if [ ! -d "${DUMPS_FOLDER}" ]; then
  echo "this shuttle have no dumps folder"
  exit -1
fi



if [ -f ${DUMPS_FOLDER}/dumpin.txt ]; then
  echo "shuttle dump fs still in progress ..."
  exit -1
fi


# keep only DUMPS_KEEP previous tgz
nbTar=$(ls -rt ${DUMPS_FOLDER}/*.tgz| wc -l)
nbToRemove=$((nbTar - DUMPS_KEEP))
echo remove previous tgz
ls -lrt ${DUMPS_FOLDER}/*.tgz | head -n $nbToRemove
ls -rt ${DUMPS_FOLDER}/*.tgz | head -n $nbToRemove | xargs rm -f


rm -f  ${DUMPS_FOLDER}/dumpout.txt

# trigger backup
echo "repositories/" > ${DUMPS_FOLDER}/dumpin.txt

echo start shuttle dump FS
while [ ! -f ${DUMPS_FOLDER}/dumpout.txt ]; do
    echo -n "."
    sleep 5
done

echo " done"
echo $(cat ${DUMPS_FOLDER}/dumpout.txt)
