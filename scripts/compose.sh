#!/bin/sh
set -eu
target=$1
shift
# P is a whitespace-separated list of service names. Keep it out of shell source.
set -f
set -- ${P:-}
for service do
  case "$service" in
    -*|*[!a-zA-Z0-9._-]*) echo 'Invalid Compose service name in P.' >&2; exit 1 ;;
  esac
done
if [ "$target" = exec ]; then
  if [ "$#" -ne 1 ]; then echo 'Usage: make exec P=<service>' >&2; exit 1; fi
  set -- exec "$1" bash
else
  if [ "$#" -eq 0 ]; then
    printf 'Run %s on ALL services? [y/N] ' "$target"
    read -r answer || exit 1
    case "$answer" in y|Y|yes|YES) ;; *) echo 'Aborted'; exit 1 ;; esac
  fi
  case "$target" in
    up) set -- up -d "$@" ;;
    up-f) set -- up -d --force-recreate "$@" ;;
    logs) set -- logs -f "$@" ;;
    ps) set -- ps -a "$@" ;;
    stop|restart) set -- "$target" "$@" ;;
    *) exit 2 ;;
  esac
fi
exec ./scripts/dotenvx.sh run -- docker compose "$@"
