#!/bin/bash


export SHUTTLE_HOME=${SHUTTLE_HOME:-/data/shuttle/home}
export REPOSITORIES_FOLDER=${REPOSITORIES_FOLDER:-${SHUTTLE_HOME}/repositories}
export DUMPS_FOLDER=${DUMPS_FOLDER:-${SHUTTLE_HOME}/dumps}

if [ ! -d "${DUMPS_FOLDER}" ]; then
  echo "this shuttle have no dumps folder"
  exit -1
fi

# this allow to dump shuttle FS repository in FS mode
[ ! -d "${REPOSITORIES_FOLDER}" ] && mkdir -p ${REPOSITORIES_FOLDER}



if [ ! -f ${DUMPS_FOLDER}/dumpout.txt ]; then
  echo "no dumpout.txt file"
  exit -1
fi

tgzFile=$(cat ${DUMPS_FOLDER}/dumpout.txt)
if [ ! -f ${DUMPS_FOLDER}/${tgzFile} ]; then
  echo  dump ${DUMPS_FOLDER}/${tgzFile}  not exist
  exit -1
fi


echo clear folder "${REPOSITORIES_FOLDER}"
rm -rf ${REPOSITORIES_FOLDER}/*

cd ${SHUTTLE_HOME}
tar -zxvf ${DUMPS_FOLDER}/${tgzFile}
