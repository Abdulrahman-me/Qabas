#!/usr/bin/env sh
set -eu
exec python3 tool/check_release_bundle.py "$@"
