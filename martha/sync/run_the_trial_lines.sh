#!/usr/bin/env bash
# run_the_trial_lines.sh <engine> <engine-source> <martha> <evidence>: runs the #541 trial lines against the built
# engine and fails unless every line passes.
#
# The lines are Martha's own (trial_the_goose_host/drive_the_trial.ts in <martha>, at the pinned MARTHA_SHA), so the
# fork is held to exactly what macula-io/martha#541 proved on Goose. Each launch is stopped at the owner's ten minutes.
# A line whose launch observed nothing ("not-observed": the small model made no call the line needs) launches again,
# up to TRIAL_LAUNCHES_PER_LINE; a "fail" is never launched again. Each launch's result.json and strace land under
# <evidence>/line-<n>, an earlier launch's under <evidence>/line-<n>-launch-<k>.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
engine="$(realpath "${1:?usage: run_the_trial_lines.sh <engine> <engine-source> <martha> <evidence>}")"
source_dir="$(realpath "${2:?}")"
driver="$(realpath "${3:?}")/trial_the_goose_host/drive_the_trial.ts"
evidence="$(realpath -m "${4:?}")"
mkdir -p "${evidence}/owner-home"

launch_the_line() {
  HOME="${evidence}/owner-home" timeout --kill-after=30s "${TRIAL_MINUTES_PER_LAUNCH}m" \
    node "${driver}" --goose "${engine}" --goose-source "${source_dir}" --model "${TRIAL_MODEL}" \
    --evidence "${evidence}" --line "$1" >&2 || echo "line $1: the launch ended with status $?" >&2
  local result="${evidence}/line-$1/result.json"
  if [[ -f "${result}" ]]; then jq -r '.verdict' "${result}"; else echo 'no result.json'; fi
}

failed=0
IFS=, read -r -a lines <<< "${TRIAL_LINES}"
for line in "${lines[@]}"; do
  launch=1
  verdict="$(launch_the_line "${line}")"
  while [[ "${verdict}" == not-observed ]] && (( launch < TRIAL_LAUNCHES_PER_LINE )); do
    mv "${evidence}/line-${line}" "${evidence}/line-${line}-launch-${launch}"
    launch=$((launch + 1))
    echo "line ${line}: launch ${launch} of ${TRIAL_LAUNCHES_PER_LINE}, the last one observed nothing"
    verdict="$(launch_the_line "${line}")"
  done
  [[ "${verdict}" == pass ]] || { failed=$((failed + 1)); echo "::error::trial line ${line}: ${verdict}"; }
done

echo "${#lines[@]} trial line(s) run, ${failed} not passed"
(( failed == 0 ))
