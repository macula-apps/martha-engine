#!/usr/bin/env bash
# run_the_trial_lines.sh <engine> <engine-source> <martha> <evidence>: runs the #541 trial lines against the built
# engine and fails unless every line passes.
#
# The lines are Martha's own (trial_the_goose_host/drive_the_trial.ts in <martha>, at the pinned MARTHA_SHA), so the
# fork is held to exactly what macula-io/martha#541 proved on Goose. Each line is one launch, stopped at the owner's
# ten minutes; every line launches once, within the two launches a check may use. Each line's result.json and strace
# land under <evidence>.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
engine="$(realpath "${1:?usage: run_the_trial_lines.sh <engine> <engine-source> <martha> <evidence>}")"
source_dir="$(realpath "${2:?}")"
driver="$(realpath "${3:?}")/trial_the_goose_host/drive_the_trial.ts"
evidence="$(realpath -m "${4:?}")"
mkdir -p "${evidence}/owner-home"

failed=0
IFS=, read -r -a lines <<< "${TRIAL_LINES}"
for line in "${lines[@]}"; do
  HOME="${evidence}/owner-home" timeout --kill-after=30s "${TRIAL_MINUTES_PER_LAUNCH}m" \
    node "${driver}" --goose "${engine}" --goose-source "${source_dir}" --model "${TRIAL_MODEL}" \
    --evidence "${evidence}" --line "${line}" || echo "line ${line}: the launch ended with status $?"
  result="${evidence}/line-${line}/result.json"
  verdict="$( [[ -f "${result}" ]] && jq -r '.verdict' "${result}" || echo 'no result.json' )"
  [[ "${verdict}" == pass ]] || { failed=$((failed + 1)); echo "::error::trial line ${line}: ${verdict}"; }
done

echo "${#lines[@]} trial line(s) run, ${failed} not passed"
(( failed == 0 ))
