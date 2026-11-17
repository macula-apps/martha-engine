#!/usr/bin/env bash
# --version, the usage line and the engine's user agent carry the fork's name,
# and --version says the engine is built on Goose.
set -euo pipefail
CHECK=names_carry_name
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

version="$("$ENGINE_BIN" --version)"
case "$version" in
    "$ENGINE_NAME $ENGINE_VERSION"*) ;;
    *) fail "--version reads '$version', expected it to start with '$ENGINE_NAME $ENGINE_VERSION'" ;;
esac
case "$version" in
    *"built on Goose"*) ;;
    *) fail "--version reads '$version' and does not say it is built on Goose" ;;
esac
echo "  --version: $version"

usage="$("$ENGINE_BIN" --help | awk '/^Usage:/ { print; exit }')"
case "$usage" in
    "Usage: $ENGINE_NAME"*) ;;
    *) fail "usage line reads '$usage'" ;;
esac
echo "  $usage"

ua_ours="$(command grep -a -c -F "$ENGINE_NAME/$ENGINE_VERSION" "$ENGINE_BIN" || true)"
ua_upstream="$(command grep -a -c -F "$UPSTREAM_NAME/$ENGINE_VERSION" "$ENGINE_BIN" || true)"
[ "$ua_ours" -gt 0 ] || fail "no '$ENGINE_NAME/$ENGINE_VERSION' user agent in the binary"
[ "$ua_upstream" -eq 0 ] || fail "the binary still carries a '$UPSTREAM_NAME/$ENGINE_VERSION' user agent"
echo "  user agent: '$ENGINE_NAME/$ENGINE_VERSION' present, '$UPSTREAM_NAME/$ENGINE_VERSION' absent"
pass "names users see carry $ENGINE_NAME"
