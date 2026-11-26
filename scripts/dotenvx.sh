#!/bin/sh
set -eu
if [ ! -x ./node_modules/.bin/dotenvx ]; then
  echo 'Local dotenvx is missing. Run npm ci in the repository root.' >&2
  exit 1
fi
exec ./node_modules/.bin/dotenvx "$@"
