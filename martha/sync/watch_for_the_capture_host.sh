#!/usr/bin/env bash
# watch_for_the_capture_host.sh start <capture> | verdict <capture> <engine-source>
#
# Telemetry is compiled out of the fork (macula-io/martha#547 S1); this is the traffic half of S2's proof that it is.
# `start` records every DNS query the runner sends while the trial lines run, after flushing the resolver's cache so
# no lookup is answered unseen. `verdict` stops the recording and fails if PostHog's capture host was ever looked up.
# The host is read from the engine's own source (crates/goose/src/posthog.rs), never restated here.
#
# A recording that saw nothing would pass while proving nothing, so `start` also looks up a name nobody else ever
# asks for, and `verdict` fails unless the recording holds it.
set -euo pipefail
action="${1:?usage: watch_for_the_capture_host.sh start <capture> | verdict <capture> <engine-source>}"
capture="${2:?}"

if [[ "${action}" == start ]]; then
  sudo resolvectl flush-caches
  sudo tcpdump -i any -n -l 'port 53' > "${capture}" 2> "${capture}.err" &
  echo $! > "${capture}.pid"
  for _ in $(seq 30); do grep -q 'listening on' "${capture}.err" && break; sleep 1; done
  control="martha-capture-control-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n').example.com"
  echo "${control}" > "${capture}.control"
  getent ahosts "${control}" > /dev/null || true
  echo "recording DNS queries into ${capture}; control lookup ${control}"
  exit 0
fi

posthog="${3:?}/crates/goose/src/posthog.rs"
sleep 2
sudo kill "$(cat "${capture}.pid")" || true
host="$(grep -E 'POSTHOG_CAPTURE_URL' "${posthog}" | grep -oE 'https://[^/"]+' | sed 's#https://##' | head -n 1)"
[[ -n "${host}" ]] || { echo "::error::no capture host found in ${posthog}, so its traffic cannot be told"; exit 1; }
control="$(cat "${capture}.control")"
grep -qF "${control}" "${capture}" \
  || { echo "::error::the DNS recording does not hold its own control lookup, so it saw nothing"; exit 1; }
if grep -F "${host}" "${capture}"; then
  echo "::error::the runner looked up PostHog's capture host ${host} while the trial ran"
  exit 1
fi
echo "$(wc -l < "${capture}") DNS packet(s) recorded, the control lookup among them, none for ${host}"
