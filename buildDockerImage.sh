#!/bin/bash
#export DEBUG=true


# Define BUILD_FOLDER
pushd $(dirname $0)
DOCKER_FILENAME=$PWD/Dockerfile
#BUILD_FOLDER=$PWD/../..
BUILD_FOLDER=$PWD
popd


RELEASE_MAJOR="2"
RELEASE_MINOR="2.2"
RELEASE=${RELEASE_MAJOR}.${RELEASE_MINOR}-pg${PG_VERSION}




# Release Build of the Docker Image
# Final Docker Image Name
IMAGE_TAG=${RELEASE}-${IMAGE_BUILD}




#-------------------------------------------------------------------------------------------------------
echo "Building image  ${DOCKER_REPO}:${IMAGE_TAG} ..."
#BUILD_OPTIONS="--force-rm=true --no-cache=true"
docker build $BUILD_OPTIONS -t ${DOCKER_REPO}:${IMAGE_TAG}  \
        --build-arg RELEASE_MAJOR=${RELEASE_MAJOR} \
        --build-arg RELEASE_MINOR=${RELEASE_MINOR} \
        --build-arg RELEASE=${RELEASE} \
        --build-arg PG_VERSION=${PG_VERSION} \
        --file ${DOCKER_FILENAME} \
        ${BUILD_FOLDER}

        if [ $? -eq 0 ]; then
	       docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:${RELEASE}
	       docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:${RELEASE_MAJOR}.${RELEASE_MINOR}
           docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:latest
		else
		    echo docker builld return error code $?
        fi
	echo "Local Image created: ${DOCKER_REPO} "
	docker images ${DOCKER_REPO}
