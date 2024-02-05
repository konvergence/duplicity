#!/bin/bash
set -euo pipefail

#export DEBUG=true


# Define BUILD_FOLDER
pushd $(dirname $0)
#BUILD_FOLDER=$PWD/../..
BUILD_FOLDER=$PWD
popd


RELEASE_MAJOR="2"
RELEASE_MINOR="2.2"
RELEASE=${RELEASE_MAJOR}.${RELEASE_MINOR}

if [ -z "${PG_VERSION}" ]
then
        DOCKER_FILENAME=$PWD/Dockerfile-filesystem
        BUILD_OPTIONS="--force-rm=true --no-cache=true"
else
        DOCKER_FILENAME=$PWD/Dockerfile-postgresql
        RELEASE=${RELEASE}-pg${PG_VERSION}
        BUILD_OPTIONS="--pull=false"
fi


# Release Build of the Docker Image
# Final Docker Image Name
IMAGE_TAG=${RELEASE}-${IMAGE_BUILD}




#-------------------------------------------------------------------------------------------------------
echo "Building image  ${DOCKER_REPO}:${IMAGE_TAG} ..."
docker build $BUILD_OPTIONS -t ${DOCKER_REPO}:${IMAGE_TAG}  \
        --build-arg RELEASE_MAJOR=${RELEASE_MAJOR} \
        --build-arg RELEASE_MINOR=${RELEASE_MINOR} \
        --build-arg RELEASE=${RELEASE} \
        --build-arg PG_VERSION=${PG_VERSION} \
        --file ${DOCKER_FILENAME} \
        ${BUILD_FOLDER}

docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:${RELEASE}

echo "Local Image created: ${DOCKER_REPO} "
docker images ${DOCKER_REPO}

echo ""
