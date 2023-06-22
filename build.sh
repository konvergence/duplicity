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


#${ALL_RELEASES_FOLDER}/${RELEASE_FOLDER}/buildDockerImage.sh
./buildDockerImage.sh
