#!/usr/bin/env bash


cd "$(dirname "${BASH_SOURCE}")";

./.local/bin/udot apply --base-dir="$(dirname "${BASH_SOURCE}")"
