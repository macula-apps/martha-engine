#!/usr/bin/env bash
# The engine binary carries the fork's name, not upstream's.
set -euo pipefail
CHECK=engine_named
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

[ "$(basename "$ENGINE_BIN")" = "$ENGINE_NAME" ] \
    || fail "built binary is $(basename "$ENGINE_BIN"), expected $ENGINE_NAME"
pass "binary is $ENGINE_NAME (upstream: $UPSTREAM_NAME)"

# The container image installs the engine under its own name: the Dockerfile's
# one ENGINE_NAME is the engine's, and nothing lands at upstream's binary name.
dockerfile="$REPO_ROOT/Dockerfile"
docker_name="$(awk '/^ARG ENGINE_NAME=/ { sub(/^ARG ENGINE_NAME=/, ""); print; exit }' "$dockerfile")"
[ "$docker_name" = "$ENGINE_NAME" ] \
    || fail "Dockerfile names the engine '${docker_name}', expected $ENGINE_NAME (ARG ENGINE_NAME=)"
if command grep -n -E "/usr/local/bin/${UPSTREAM_NAME}([^-[:alnum:]_]|\$)" "$dockerfile" >&2; then
    fail "Dockerfile installs or runs the engine as /usr/local/bin/$UPSTREAM_NAME"
fi
command grep -q -F '/usr/local/bin/${ENGINE_NAME}' "$dockerfile" \
    || fail "Dockerfile does not install the engine at /usr/local/bin/\${ENGINE_NAME}"
pass "the container image installs the engine as /usr/local/bin/$ENGINE_NAME"
