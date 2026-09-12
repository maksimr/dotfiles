#!/usr/bin/env bash
# Update pi and dotfiles shared by all pix sandboxes, using a throwaway
# updater container:
#   - pi-bin volume:   pi itself (npm install into /opt/pi)
#   - pi-agent volume: pi packages/extensions (~/.pi)
#   - ~/.dotfiles:     git pull on the host clone (mounted rw here, ro in sandboxes)
# Sandboxes pick the updates up on their next pi session; no recreation needed.
set -e

docker run --rm --entrypoint bash \
  -v pi-bin:/opt/pi \
  -v pi-agent:/home/agent/.pi \
  -v "$HOME/.dotfiles:/home/agent/.dotfiles:ro" \
  pi -c '
    set -e
    udot apply --only=.pi --only=.local/bin
    pi update
    pi update --extensions
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    rtk init -g --agent pi
  '
