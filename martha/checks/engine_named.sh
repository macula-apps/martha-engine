#!/usr/bin/env bash
# The engine binary carries the fork's name, not upstream's.
set -euo pipefail
CHECK=engine_named
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

[ "$(basename "$ENGINE_BIN")" = "$ENGINE_NAME" ] \
    || fail "built binary is $(basename "$ENGINE_BIN"), expected $ENGINE_NAME"
pass "binary is $ENGINE_NAME (upstream: $UPSTREAM_NAME)"
