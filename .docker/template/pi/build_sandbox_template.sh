#!/usr/bin/env bash

TEMPLATE_NAME="pi"
CURRENT_FILE_PATH="$(realpath "${BASH_SOURCE[0]}")"
DOCKER_TEMPLATE_DIR="$(dirname "$CURRENT_FILE_PATH")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pi-docker-build.XXXXXX")"
TEMPLATE_TAR_PATH="$TEMP_DIR/${TEMPLATE_NAME}.tar"

docker build -t ${TEMPLATE_NAME} "$DOCKER_TEMPLATE_DIR"
docker image save ${TEMPLATE_NAME} -o "$TEMPLATE_TAR_PATH"
sbx template load "$TEMPLATE_TAR_PATH"
