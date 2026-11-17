#!/usr/bin/env bash
# Self-update is compiled out: no shipped feature set builds 'update', and the
# built engine has no update subcommand. Only Martha's installer changes what
# is installed.
set -euo pipefail
CHECK=self_update_compiled_out
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

feature_absent_from_shipped_sets goose-cli update

"$ENGINE_BIN" info --help > /dev/null 2>&1 \
    || fail "control failed: '$ENGINE_NAME info --help' does not run"
if out="$("$ENGINE_BIN" update --help 2>&1)"; then
    fail "'$ENGINE_NAME update' exists: $(printf '%s' "$out" | head -1)"
fi
commands="$("$ENGINE_BIN" --help | awk '/^Commands:/ { c = 1; next } /^$/ { c = 0 } c { print $1 }')"
[ -n "$commands" ] || fail "control failed: --help lists no commands"
if printf '%s\n' "$commands" | command grep -q -x update; then
    fail "--help lists an update command"
fi
pass "no update subcommand; --help lists $(printf '%s\n' "$commands" | wc -l) commands"
