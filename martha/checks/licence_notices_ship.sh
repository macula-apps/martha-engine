#!/usr/bin/env bash
# Goose's Apache-2.0 LICENSE stays, and a NOTICE names the upstream work and
# lists the fork's changes, as upstream's CUSTOM_DISTROS.md asks.
set -euo pipefail
CHECK=licence_notices_ship
source "$(dirname "$0")/engine_name.sh"

license="$REPO_ROOT/LICENSE"
notice="$REPO_ROOT/NOTICE"
[ -f "$license" ] || fail "LICENSE is missing"
command grep -q -F "Apache License" "$license" || fail "LICENSE is not the Apache License"
command grep -q -F "Version 2.0" "$license" || fail "LICENSE is not version 2.0"
[ -f "$notice" ] || fail "NOTICE is missing"

upstream_repo="$(awk '/^\[workspace.package\]/ { w = 1; next } /^\[/ { w = 0 } w && /^repository *=/ { gsub(/.*= *"|".*/, ""); print; exit }' "$REPO_ROOT/Cargo.toml")"
[ -n "$upstream_repo" ] || fail "no [workspace.package] repository in Cargo.toml"
command grep -q -F "$upstream_repo" "$notice" || fail "NOTICE does not name the upstream work at $upstream_repo"
command grep -q -F "Apache License, Version 2.0" "$notice" || fail "NOTICE does not name the licence"
command grep -q -F "$ENGINE_NAME" "$notice" || fail "NOTICE does not name $ENGINE_NAME"
changes="$(awk '/^## Changes/ { c = 1; next } /^## / { c = 0 } c && /^- / { n++ } END { print n + 0 }' "$notice")"
[ "$changes" -gt 0 ] || fail "NOTICE lists no changes under '## Changes'"
pass "LICENSE is Apache-2.0; NOTICE names $upstream_repo and lists $changes changes"
