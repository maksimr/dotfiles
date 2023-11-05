#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

if [ "$(command -v npx)" ]; then
  npx github:maksimr/udot use https://github.com/maksimr/dotfiles
  exit 0
fi

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
