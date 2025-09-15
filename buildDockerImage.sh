#!/bin/bash
set -euo pipefail

#export DEBUG=true


# Define BUILD_FOLDER
pushd $(dirname $0)
#BUILD_FOLDER=$PWD/../..
BUILD_FOLDER=$PWD
popd


RELEASE_MAJOR="3"
RELEASE_MINOR="0.5.1"
RELEASE=${RELEASE_MAJOR}.${RELEASE_MINOR}

if [ ! -z "${PG_VERSION}" ]; then

        DOCKER_FILENAME=$PWD/Dockerfile-postgresql
        RELEASE=${RELEASE}-pg${PG_VERSION}
        BUILD_OPTIONS="--pull=false"

elif [ ! -z "${MYSQL_VERSION}" ]; then

        DOCKER_FILENAME=$PWD/Dockerfile-mysql
        MYSQL_RELEASE_VERSION=$(echo "$MYSQL_VERSION" | tr -d '.')
        RELEASE=${RELEASE}-mysql${MYSQL_RELEASE_VERSION}
        BUILD_OPTIONS="--pull=false"

else

        DOCKER_FILENAME=$PWD/Dockerfile-base
        #BUILD_OPTIONS="--force-rm=true --no-cache=true"
        BUILD_OPTIONS=""

        
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
        --build-arg MYSQL_VERSION=${MYSQL_VERSION} \
        --file ${DOCKER_FILENAME} \
        ${BUILD_FOLDER}

docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:${RELEASE}

echo "Local Image created: ${DOCKER_REPO} "
docker images ${DOCKER_REPO}

echo ""
