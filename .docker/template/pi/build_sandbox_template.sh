#!/usr/bin/env bash

TEMPLATE_NAME="pi"
CURRENT_FILE_PATH="$(realpath "${BASH_SOURCE[0]}")"
DOCKER_TEMPLATE_DIR="$(dirname "$CURRENT_FILE_PATH")"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pi-docker-build.XXXXXX")"
TEMPLATE_TAR_PATH="$TEMP_DIR/${TEMPLATE_NAME}.tar"

docker build -t ${TEMPLATE_NAME} "$DOCKER_TEMPLATE_DIR"

# Refresh the shared pi install (pi-bin volume) from the freshly built image so
# existing sandboxes pick up the new pi without being recreated.
docker run --rm -u root --entrypoint bash -v pi-bin:/mnt/pi-bin ${TEMPLATE_NAME} \
  -c 'find /mnt/pi-bin -mindepth 1 -delete && cp -a /opt/pi/. /mnt/pi-bin/ && chown agent:agent /mnt/pi-bin'

# Initialize dotfiles (pi-agent volume) and install required deps.
bash "$DOCKER_TEMPLATE_DIR/../../../.pi/scripts/update_pix.sh"

if [[ -x "$(command -v sbx)" ]]; then
    docker image save ${TEMPLATE_NAME} -o "$TEMPLATE_TAR_PATH"
    sbx template load "$TEMPLATE_TAR_PATH"
fi
