#!/usr/bin/env bash
# Runs every check of the fork's patch set and exits non-zero naming each
# failed check.
#
#   martha/checks/run.sh [--bin <path to the built engine>]
#
# Given --bin it builds nothing. Without it, it builds goose-cli's engine
# binary with the shipped feature set (portable-default) into CARGO_TARGET_DIR.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
CHECK=run
source "$here/engine_name.sh"

ENGINE_BIN=""
while [ $# -gt 0 ]; do
    case "$1" in
        --bin) ENGINE_BIN="${2:-}"; shift 2 ;;
        *) fail "unknown argument '$1'; usage: run.sh [--bin <path>]" ;;
    esac
done

if [ -z "$ENGINE_BIN" ]; then
    target="${CARGO_TARGET_DIR:-$REPO_ROOT/target}"
    (cd "$REPO_ROOT" && cargo build --locked -p goose-cli --bin "$ENGINE_NAME" \
        --no-default-features --features portable-default) \
        || fail "building $ENGINE_NAME failed"
    ENGINE_BIN="$target/debug/$ENGINE_NAME"
fi
export ENGINE_BIN="$(cd "$(dirname "$ENGINE_BIN")" && pwd)/$(basename "$ENGINE_BIN")"

checks=(engine_named folders_named names_carry_name help_names_engine licence_notices_ship
        telemetry_compiled_out self_update_compiled_out)
failed=()
for check in "${checks[@]}"; do
    "$here/$check.sh" || failed+=("$check")
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "FAILED: ${failed[*]} (${#failed[@]} of ${#checks[@]})" >&2
    exit 1
fi
echo "ALL PASS: ${#checks[@]} checks"
