#!/usr/bin/env bash
# The cases of the_evidence_keeps_the_model_log.sh (macula-io/martha#822). Run with no arguments: every evidence
# directory and every planted pins.env is built in a temporary folder, removed on the way out, whatever the outcome.
#
# The cases a weaker check passes are the ones that matter: evidence that holds no log at all (the artifact uploaded
# without it), a log the server opened and wrote nothing into, a path that is not a directory, and a log named by
# pins.env rather than by a word the check itself carries.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
check="${here}/the_evidence_keeps_the_model_log.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

failures=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$(( failures + 1 )); }

out=''
rc=0
run_check() {
  rc=0
  out="$("$@" 2>&1)" || rc=$?
}

expect_ok() {             # expect_ok <name> <text the message must hold>
  if (( rc == 0 )) && [[ "${out}" == *"$2"* ]]; then pass "$1"; else fail "$1 (rc=${rc}, said: ${out})"; fi
}

expect_fail() {           # expect_fail <name> <text the message must hold>
  if (( rc != 0 )) && [[ "${out}" == *"$2"* ]]; then pass "$1"; else fail "$1 (rc=${rc}, said: ${out})"; fi
}

evidence="${tmp}/trial"
mkdir -p "${evidence}/line-1"
# The name is a word of this case's own, never read back from the pins the check reads: a rename that moves one
# place and not the other turns this case red instead of passing on both sides of the same constant.
the_log='ollama-serve.log'
printf 'line 1: a request the model answered\n' > "${evidence}/${the_log}"

run_check "${check}" "${evidence}"
expect_ok 'the evidence holds the server log' 'the evidence keeps ollama-serve.log'

# The case the package exists for: the evidence is there and the server's log is not.
rm "${evidence}/${the_log}"
run_check "${check}" "${evidence}"
expect_fail 'an evidence directory without the log fails by name' 'uploaded without it'
(( rc != 0 )) && [[ "${out}" == *'ollama-serve.log'* ]] && pass 'the failure names the log it looked for' \
  || fail "the failure names the log it looked for (said: ${out})"

# A log the server opened and wrote nothing into is not a log of what it answered.
: > "${evidence}/ollama-serve.log"
run_check "${check}" "${evidence}"
expect_fail 'an empty server log fails by name' 'is empty'

# A path that is not a directory cannot be evidence at all.
run_check "${check}" "${tmp}/not-there"
expect_fail 'a missing evidence directory fails by name' 'is not a directory'

# The log's name is pins.env's, not the check's own word: a copy of the check beside a pins.env that names it
# otherwise looks for that name, so a rename moves the name in one place.
elsewhere="${tmp}/elsewhere"
mkdir -p "${elsewhere}"
cp "${check}" "${elsewhere}/"
printf 'TRIAL_SERVER_LOG=the-models-own-words.log\n' > "${elsewhere}/pins.env"
printf 'the name this pins.env gives it\n' > "${evidence}/the-models-own-words.log"
run_check "${elsewhere}/the_evidence_keeps_the_model_log.sh" "${evidence}"
expect_ok 'the log name is read from pins.env beside the check' 'the evidence keeps the-models-own-words.log'
rm "${evidence}/the-models-own-words.log"
run_check "${elsewhere}/the_evidence_keeps_the_model_log.sh" "${evidence}"
expect_fail 'with the name moved, a log of the old name does not satisfy it' 'the-models-own-words.log'

if (( failures == 0 )); then
  echo "the_evidence_keeps_the_model_log: every case holds"
else
  echo "the_evidence_keeps_the_model_log: ${failures} case(s) failed"
  exit 1
fi
