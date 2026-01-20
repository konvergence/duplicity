#!/usr/bin/env bash

#exit on error
set -e

# FROMIMAGE ensubst variable

DUPLICITY_RELEASE=3.0.7
UBUNTU_RELEASE=jammy
DOCKERFILE_RELEASE=1

# generate Dockerfile
#FROM_REGISTRY=docker.io/library
FROM_REGISTRY=lab-k8s-harbor.shuttle-cloud.com/library
export FROMIMAGE=${FROM_REGISTRY}/duplicity:${DUPLICITY_RELEASE}-r${DOCKERFILE_RELEASE}
envsubst '${FROMIMAGE}'  < Dockerfile.dist > Dockerfile

MYSQL_VERSIONS="8.0"


for MYSQL_VERSION in ${MYSQL_VERSIONS}; do

    export MYSQL_VERSION
    export MYSQL_TAG_VERSION=${MYSQL_VERSION//./}


# tags : * the tag will be [java-major-version].[tomcat-major-version].[tomcat-minor-version](-[tomcat-patch])(_[dockerfile-release](_(vendor-release)))
DOCKER_IMAGE=duplicity
DOCKER_RELEASE_TAG=${DUPLICITY_RELEASE}-mysql${MYSQL_TAG_VERSION}


# example: 21.9.0-98-temurin-jammy-r98, 21.9.0-98-temurin-jammy, 21.9.0-98, 21.9.0
TAG1=${DOCKER_RELEASE_TAG}-r${DOCKERFILE_RELEASE}
TAG2=${DOCKER_RELEASE_TAG}

BUILD_TAGS=()
BUILD_TAGS+=("${TAG1}")
BUILD_TAGS+=("${TAG2}")
printf "%s\n" "${BUILD_TAGS[@]}" > mysql${MYSQL_TAG_VERSION}_build_tags.txt

# Dockerfile ARGs for build
>mysql${MYSQL_TAG_VERSION}_build_args.txt
echo ARG_KSHUTTLE_COPYRIGHT=Copyright $(date "+%Y") kShuttle - All rights reserved >> mysql${MYSQL_TAG_VERSION}_build_args.txt
echo ARG_MYSQL_RELEASE=${MYSQL_VERSION} >> mysql${MYSQL_TAG_VERSION}_build_args.txt
echo ARG_MYSQL_TAG_VERSION=${MYSQL_TAG_VERSION} >> mysql${MYSQL_TAG_VERSION}_build_args.txt
echo ARG_RELEASE_TAG=${DOCKER_RELEASE_TAG} >> mysql${MYSQL_TAG_VERSION}_build_args.txt
echo ARG_RELEASE_FULL_TAG=${TAG1} >> mysql${MYSQL_TAG_VERSION}_build_args.txt


envsubst '${MYSQL_TAG_VERSION}'  < tekton-builder-dockerhub.dist > tekton-builder-mysql${MYSQL_TAG_VERSION}_dockerhub.yaml
done