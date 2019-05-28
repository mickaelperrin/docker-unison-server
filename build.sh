#!/usr/bin/env bash
set -e

ACTION=${ACTION:-build}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="registry.gitlab.com/dkod-docker"
IMAGE=unison

VERSION="1.0.2"

build () {
	# Run build
  docker build -t ${REGISTRY}/${IMAGE}:${VERSION}-${CI_COMMIT_REF_SLUG} ${DIR}
  docker push  ${REGISTRY}/${IMAGE}:${VERSION}-${CI_COMMIT_REF_SLUG}
}

release() {
  docker pull ${REGISTRY}/${IMAGE}:${VERSION}-${CI_COMMIT_REF_SLUG}
  docker tag ${REGISTRY}/${IMAGE}:${VERSION}-${CI_COMMIT_REF_SLUG} ${REGISTRY}/${IMAGE}:${VERSION}
  docker tag ${REGISTRY}/${IMAGE}:${VERSION}-${CI_COMMIT_REF_SLUG} ${REGISTRY}/${IMAGE}:latest
  docker push ${REGISTRY}/${IMAGE}:${VERSION}
  docker push ${REGISTRY}/${IMAGE}:latest
}

echo "VERSION: $VERSION"
$ACTION
