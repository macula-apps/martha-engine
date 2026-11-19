#!/usr/bin/env bash
# the_evidence_keeps_the_model_log.sh <evidence>: fails by name unless the run's trial evidence holds the model
# server's own log (macula-io/martha#822), which the checks upload as the trial-evidence artifact.
#
# serve_the_trial_model.sh writes that log inside the evidence directory, and martha-engine-checks.yml uploads the
# directory whole, so the artifact carries the log whenever this check passes. The log's file name is TRIAL_SERVER_LOG
# in pins.env, its one place. Without the log a line cut at its cap and a request the model never answered read alike:
# the proxy sees both as silence, and only the server's own log says which one happened.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
evidence="${1:?usage: the_evidence_keeps_the_model_log.sh <evidence>}"
[[ -d "${evidence}" ]] \
  || { echo "::error::${evidence} is not a directory, so there is no evidence to keep a log beside (macula-io/martha#822)" >&2; exit 1; }
log="${evidence%/}/${TRIAL_SERVER_LOG}"
[[ -f "${log}" ]] || {
  echo "::error::the evidence holds no ${TRIAL_SERVER_LOG}: the model server's log was written outside ${evidence}, so the trial-evidence artifact would be uploaded without it (macula-io/martha#822)" >&2
  exit 1
}
[[ -s "${log}" ]] || {
  echo "::error::${log} is empty: the model server wrote nothing to it, so the artifact would carry no log of what it answered (macula-io/martha#822)" >&2
  exit 1
}
echo "the evidence keeps ${TRIAL_SERVER_LOG} ($(wc -c < "${log}") bytes)"
