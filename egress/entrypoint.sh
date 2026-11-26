#!/bin/sh

set -eu
: "${LIVEKIT_API_KEY:?Error: LIVEKIT_API_KEY is not set}"
: "${LIVEKIT_API_SECRET:?Error: LIVEKIT_API_SECRET is not set}"

# The image initializes its own PulseAudio runtime and reads credentials from env.
exec /tini -- /entrypoint.sh
