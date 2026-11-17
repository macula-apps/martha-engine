#!/usr/bin/env bash
# Telemetry is compiled out: no shipped feature set builds the 'telemetry'
# feature, and the built engine holds neither PostHog's capture host nor key.
# Both are read from posthog.rs, the only place they are defined.
set -euo pipefail
CHECK=telemetry_compiled_out
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

feature_absent_from_shipped_sets "$UPSTREAM_NAME" telemetry
feature_absent_from_shipped_sets goose-cli telemetry

posthog="$REPO_ROOT/crates/goose/src/posthog.rs"
[ -f "$posthog" ] || fail "$posthog is gone; re-aim this check at where the sender now lives"
key="$(awk -F'"' '/const POSTHOG_API_KEY/ { print $2; exit }' "$posthog")"
capture_url="$(awk -F'"' '/const POSTHOG_CAPTURE_URL/ { print $2; exit }' "$posthog")"
capture_host="$(printf '%s' "$capture_url" | awk -F/ '{ print $3 }')"
[ -n "$key" ] || fail "could not read POSTHOG_API_KEY from posthog.rs"
[ -n "$capture_host" ] || fail "could not read the capture host from POSTHOG_CAPTURE_URL in posthog.rs"

# The scan must see strings the binary does hold, or a broken scan passes.
control="$(command grep -a -c -F "$ENGINE_NAME" "$ENGINE_BIN" || true)"
[ "$control" -gt 0 ] || fail "control failed: the scan finds no '$ENGINE_NAME' in the binary"

hits_key="$(command grep -a -c -F "$key" "$ENGINE_BIN" || true)"
hits_host="$(command grep -a -c -F "$capture_host" "$ENGINE_BIN" || true)"
[ "$hits_key" -eq 0 ] || fail "the binary holds PostHog's key ($hits_key hits)"
[ "$hits_host" -eq 0 ] || fail "the binary holds PostHog's capture host $capture_host ($hits_host hits)"
pass "no PostHog key or capture host ($capture_host) in the binary; control found $control"
