#!/bin/bash
set -euo pipefail

TARGET_REPO="$1"
if [ -z "$TARGET_REPO" ]; then
    echo "Target repo is mandatory" && exit 1
fi

DOCKER_REPO=$(grep "^export DOCKER_REPO=" build.sh | cut -d'=' -f2- | tr -d '"')
IMAGE_BUILD=$(grep "^export IMAGE_BUILD=" build.sh | cut -d'=' -f2- | tr -d '"')
PG_VERSIONS=$(grep "^PG_VERSIONS=" build.sh | cut -d'=' -f2- | tr -d '"')
RELEASE_MAJOR=$(grep "^RELEASE_MAJOR=" buildDockerImage.sh | cut -d'=' -f2- | tr -d '"')
RELEASE_MINOR=$(grep "^RELEASE_MINOR=" buildDockerImage.sh | cut -d'=' -f2- | tr -d '"')


TAG=${RELEASE_MAJOR}.${RELEASE_MINOR}-${IMAGE_BUILD}
    
echo "docker tag ${DOCKER_REPO}:${TAG} ${TARGET_REPO}:${TAG}"
docker tag ${DOCKER_REPO}:${TAG} ${TARGET_REPO}:${TAG}

echo "docker push ${TARGET_REPO}:${TAG}"
docker push ${TARGET_REPO}:${TAG}

echo ""

for PG_VERSION in $PG_VERSIONS; do
    TAG=${RELEASE_MAJOR}.${RELEASE_MINOR}-pg${PG_VERSION}-${IMAGE_BUILD}
    
    echo "docker tag ${DOCKER_REPO}:${TAG} ${TARGET_REPO}:${TAG}"
    docker tag ${DOCKER_REPO}:${TAG} ${TARGET_REPO}:${TAG}

    echo "docker push ${TARGET_REPO}:${TAG}"
    docker push ${TARGET_REPO}:${TAG}

    echo ""
done


