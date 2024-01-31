#!/bin/bash

#export DEBUG=true


# Define RELEASE_FOLDER
pushd $(dirname $0)
BUILD_FOLDER=$PWD
ALL_RELEASES_FOLDER=${BUILD_FOLDER}/releases
popd



# Release Build of the Docker Image
# Final Docker Image Name
export IMAGE_BUILD="r0"
export DOCKER_REPO=konvergence/duplicity




#RELEASE_FOLDER=$1


#----------------------------------------------------------------------------------------------------------
# ask release is needed
#----------------------------------------------------------------------------------------------------------
#if [ -z "${RELEASE_FOLDER}" ]; then
#	echo available releases folder :
#	ls ${ALL_RELEASES_FOLDER}
#	read -p "release folder:" RELEASE_FOLDER
#fi

PG_VERSIONS="12 14 15"

#${ALL_RELEASES_FOLDER}/${RELEASE_FOLDER}/buildDockerImage.sh
for PG_VERSION in ${PG_VERSIONS}; do
    export PG_VERSION
    echo "Building image with PG_VERSION=$PG_VERSION"
    ./buildDockerImage.sh
done
