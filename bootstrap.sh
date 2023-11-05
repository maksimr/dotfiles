#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

function doIt() {
  rsync \
    --exclude ".git/" \
    --exclude ".gitignore" \
    --exclude ".DS_Store" \
    --exclude ".osx" \
    --exclude ".dotignore" \
    --exclude "bootstrap.sh" \
    --exclude "README.md" \
    -avh --no-perms . "$HOME";
}

doIt;
unset doIt;
