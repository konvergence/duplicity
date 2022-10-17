#!/bin/bash


export SHUTTLE_HOME=${SHUTTLE_HOME:-/data/shuttle/home}
export REPOSITORIES_FOLDER=${REPOSITORIES_FOLDER:-${SHUTTLE_HOME}/repositories}
export DUMPS_FOLDER=${DUMPS_FOLDER:-${SHUTTLE_HOME}/dumps}

export DUMPS_KEEP=${DUMPS_KEEP:-0}

# DUMPS_FOLDER is /data/shuttle/home/dumps



if [ ! -d "${DUMPS_FOLDER}" ]; then
  echo "this shuttle have no dumps folder"
  exit 0
fi


if [ -f ${DUMPS_FOLDER}/dumpin.txt ]; then
  echo "shuttle dump fs still in progress ..."
  exit -1
fi

if [ ! -f ${DUMPS_FOLDER}/dumpout.txt ]; then
  echo "no file ${DUMPS_FOLDER}/dumpout.txt ..."
  exit -1
fi


# keep only DUMPS_KEEP previous tgz
nbTar=$(ls -rt ${DUMPS_FOLDER}/*.tgz| wc -l)
nbToRemove=$((nbTar - DUMPS_KEEP))
dumpout=$(cat ${DUMPS_FOLDER}/dumpout.txt)

echo remove previous tgz except $dumpout
ls -lrt ${DUMPS_FOLDER}/*.tgz | grep -v $dumpout | head -n $nbToRemove
ls -rt ${DUMPS_FOLDER}/*.tgz | grep -v $dumpout | head -n $nbToRemove | xargs rm -f
