#!/bin/sh

set -eu
: "${LIVEKIT_API_KEY:?Error: LIVEKIT_API_KEY is not set}"
: "${LIVEKIT_API_SECRET:?Error: LIVEKIT_API_SECRET is not set}"

# LIVEKIT_KEYS accepts a YAML mapping. Quote single-line credentials as strings,
# including numeric-looking values, punctuation and literal apostrophes.
LIVEKIT_KEYS=$(LC_ALL=C awk '
    function quote(value) {
        if (value ~ /[[:cntrl:]]/) {
            print "LiveKit credentials must be single-line printable strings" > "/dev/stderr"
            exit 1
        }
        gsub(/\047/, "\047\047", value)
        return "\047" value "\047"
    }
    BEGIN { print quote(ENVIRON["LIVEKIT_API_KEY"]) ": " quote(ENVIRON["LIVEKIT_API_SECRET"]) }
')
export LIVEKIT_KEYS
exec /livekit-server --config /etc/livekit/livekit-config.yaml
