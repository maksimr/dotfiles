#!/usr/bin/env bash


cd "$(dirname "${BASH_SOURCE}")";

if [ "$(command -v npx)" ]; then
  npx -y github:maksimr/udot apply --base-dir="$(dirname "${BASH_SOURCE}")"
  exit 0
fi

function doIt() {
  rsync \
    --exclude ".git/" \
    --exclude ".gitignore" \
    --exclude ".DS_Store" \
    --exclude ".osx" \
    --exclude ".ignore" \
    --exclude "bootstrap.sh" \
    --exclude "README.md" \
    -avh --no-perms . "$HOME";
}

doIt;
unset doIt;
