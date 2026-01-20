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

PG_VERSIONS="12 14 15 16 17"

for PG_VERSION in ${PG_VERSIONS}; do
    export PG_VERSION


# tags : * the tag will be [java-major-version].[tomcat-major-version].[tomcat-minor-version](-[tomcat-patch])(_[dockerfile-release](_(vendor-release)))
DOCKER_IMAGE=duplicity
DOCKER_RELEASE_TAG=${DUPLICITY_RELEASE}-pg${PG_VERSION}


# example: 21.9.0-98-temurin-jammy-r98, 21.9.0-98-temurin-jammy, 21.9.0-98, 21.9.0
TAG1=${DOCKER_RELEASE_TAG}-r${DOCKERFILE_RELEASE}
TAG2=${DOCKER_RELEASE_TAG}

BUILD_TAGS=()
BUILD_TAGS+=("${TAG1}")
BUILD_TAGS+=("${TAG2}")
printf "%s\n" "${BUILD_TAGS[@]}" > pg${PG_VERSION}_build_tags.txt

# Dockerfile ARGs for build
>pg${PG_VERSION}_build_args.txt
echo ARG_KSHUTTLE_COPYRIGHT=Copyright $(date "+%Y") kShuttle - All rights reserved >> pg${PG_VERSION}_build_args.txt
echo ARG_PG_RELEASE=${PG_VERSION} >> pg${PG_VERSION}_build_args.txt
echo ARG_RELEASE_TAG=${DOCKER_RELEASE_TAG} >> pg${PG_VERSION}_build_args.txt
echo ARG_RELEASE_FULL_TAG=${TAG1} >> pg${PG_VERSION}_build_args.txt


envsubst '${PG_VERSION}'  < tekton-builder-dockerhub.dist > tekton-builder-pg${PG_VERSION}_dockerhub.yaml
done