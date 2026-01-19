#!/usr/bin/env bash

#exit on error
set -e

# FROMIMAGE ensubst variable


# generate Dockerfile
FROM_REGISTRY=docker.io/library
export FROMIMAGE=ubuntu:22.04
envsubst '${FROMIMAGE}' < Dockerfile.dist > Dockerfile

DUPLICITY_RELEASE=3.0.7
UBUNTU_RELEASE=jammy
DOCKERFILE_RELEASE=1


DOCKER_IMAGE=duplicity
DOCKER_RELEASE_TAG=${DUPLICITY_RELEASE}



TAG1=${DOCKER_RELEASE_TAG}-r${DOCKERFILE_RELEASE}
TAG2=${DOCKER_RELEASE_TAG}

BUILD_TAGS=()
BUILD_TAGS+=("${TAG1}")
BUILD_TAGS+=("${TAG2}")
printf "%s\n" "${BUILD_TAGS[@]}" > build_tags.txt

# Dockerfile ARGs for build
>build_args.txt
echo ARG_KSHUTTLE_COPYRIGHT=Copyright $(date "+%Y") kShuttle - All rights reserved >> build_args.txt
echo ARG_DUPLICITY_RELEASE=${DUPLICITY_RELEASE} >> build_args.txt
echo ARG_RELEASE_TAG=${DOCKER_RELEASE_TAG} >> build_args.txt
echo ARG_RELEASE_FULL_TAG=${TAG1} >> build_args.txt
