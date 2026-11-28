#!/bin/sh
set -eu

: "${LIVEKIT_API_KEY:?LIVEKIT_API_KEY is required}"
: "${LIVEKIT_API_SECRET:?LIVEKIT_API_SECRET is required}"

# mktemp creates a mode-0600 file. Only publish a complete configuration.
config=$(mktemp /run/livekit-config/config.XXXXXX)
trap 'rm -f "$config"' EXIT
LC_ALL=C awk '
    function scalar(value) {
        if (value ~ /[[:cntrl:]]/) {
            print "LiveKit credentials must be single-line printable strings" > "/dev/stderr"
            exit 1
        }
        gsub(/\047/, "\047\047", value)
        return "\047" value "\047"
    }
    BEGIN {
        key = scalar(ENVIRON["LIVEKIT_API_KEY"])
        secret = scalar(ENVIRON["LIVEKIT_API_SECRET"])
    }
    {
        line = $0
        # The replacement is already YAML-quoted, so consume any template quotes.
        while (match(line, /"?\$\{LIVEKIT_API_(KEY|SECRET)\}"?/)) {
            token = substr(line, RSTART, RLENGTH)
            gsub(/"/, "", token)
            printf "%s%s", substr(line, 1, RSTART - 1), (token == "${LIVEKIT_API_KEY}" ? key : secret)
            line = substr(line, RSTART + RLENGTH)
        }
        print line
    }
' /etc/livekit-config.template.yaml > "$config"
mv "$config" /run/livekit-config/config.yaml
trap - EXIT
unset LIVEKIT_API_KEY LIVEKIT_API_SECRET
exec "$@"
