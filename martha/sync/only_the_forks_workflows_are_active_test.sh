#!/usr/bin/env bash
# The cases of only_the_forks_workflows_are_active.sh (macula-io/martha#616). Run with no arguments: every checkout and
# every listing it needs is built in a temporary folder, with a stub gh answering the one listing the check asks for,
# and the folder is removed on the way out, whatever the outcome.
#
# The cases a weaker check passes are the ones that matter: a file GitHub has not registered (the file that had never
# run and ran once anyway), a workflow whose `on:` is written on the key's own line or as a list, a `.yaml` file, and an
# `on:` the check cannot read. Each of those is named here with the words the check must say.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
check="${here}/only_the_forks_workflows_are_active.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

failures=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$(( failures + 1 )); }

# A stub gh answers the listing from a file the case writes. Only the listing is faked: the check's own arguments are
# not read here, so a case writes plain "state<TAB>path" lines.
mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/gh" <<'STUB'
#!/usr/bin/env bash
cat "${GH_STUB_LISTING:?}"
STUB
chmod 755 "${tmp}/bin/gh"
export PATH="${tmp}/bin:${PATH}"

dir=''
out=''
rc=0

new_checkout() {           # new_checkout <name>: a checkout holding .github/workflows, and an empty listing
  dir="${tmp}/$1"
  mkdir -p "${dir}/.github/workflows"
  : > "${dir}/listing"
}
workflow_file() {          # workflow_file <name> <text>: one file in the case's checkout
  printf '%s\n' "$2" > "${dir}/.github/workflows/$1"
}
registered() {             # registered <state> <path>: one workflow GitHub knows
  printf '%s\t%s\n' "$1" "$2" >> "${dir}/listing"
}
run_check() {              # run_check: runs the check against the case's checkout, sets out and rc
  rc=0
  out="$(GH_STUB_LISTING="${dir}/listing" "${check}" test/fork "${dir}" 2>&1)" || rc=$?
}

expect_ok() {              # expect_ok <name> <text the message must hold>
  if (( rc == 0 )) && [[ "${out}" == *"$2"* ]]; then
    pass "$1"
  else
    fail "$1: expected exit 0 and '$2', got exit ${rc}:"
    printf '%s\n' "${out}"
  fi
}

expect_fail() {            # expect_fail <name> <text>...: a failure that holds every text
  local name="$1" text
  shift
  if (( rc == 0 )); then
    fail "${name}: expected a failure, got exit 0:"
    printf '%s\n' "${out}"
    return
  fi
  for text in "$@"; do
    if [[ "${out}" != *"${text}"* ]]; then
      fail "${name}: the message does not hold '${text}':"
      printf '%s\n' "${out}"
      return
    fi
  done
  pass "${name}"
}

new_checkout a-registered-disabled
workflow_file ci.yml 'on: push'
workflow_file build-acp.yml 'on: workflow_dispatch'
registered active .github/workflows/ci.yml
registered disabled_manually .github/workflows/build-acp.yml
run_check
expect_ok "a registered, disabled file outside the fork's own passes" "only the fork's workflows are active on test/fork: ci.yml"

new_checkout b-registered-active
workflow_file ci.yml 'on: push'
workflow_file release.yml 'on:
  push:
    tags:
      - v[0-9]+'
registered active .github/workflows/ci.yml
registered active .github/workflows/release.yml
run_check
expect_fail "a registered, active file outside the fork's own fails by name" \
  "1 workflow(s) outside the fork's own are active on test/fork" "release.yml"

new_checkout c-disabled-fork
workflow_file ci.yml 'on: push'
workflow_file minor-release.yaml 'on:
  schedule:
    - cron: 0 9 * * 1'
registered active .github/workflows/ci.yml
registered disabled_fork .github/workflows/minor-release.yaml
run_check
expect_ok "a file GitHub disabled on the fork itself passes" "every other workflow file in this tree is off"

new_checkout d-unregistered
workflow_file ci.yml 'on: push'
workflow_file take.yml 'on:
  issue_comment:'
registered active .github/workflows/ci.yml
run_check
expect_fail "an unregistered file fails by name and says what it triggers on" \
  "1 workflow file(s) outside the fork's own are in this tree and GitHub has not registered them yet" \
  "take.yml triggers on issue_comment" \
  '(a) Delete as a patch'

new_checkout e-unregistered-inline-list
workflow_file ci.yml 'on: push'
workflow_file take.yml 'on: [push, pull_request]'
registered active .github/workflows/ci.yml
run_check
expect_fail "an unregistered file whose on: is one line is read as a list" "take.yml triggers on push, pull_request"

new_checkout f-unregistered-block-sequence
workflow_file ci.yml 'on: push'
workflow_file take.yml 'on:
  - push
  - issue_comment'
registered active .github/workflows/ci.yml
run_check
expect_fail "an unregistered file whose on: is a block sequence is read as its events" \
  "take.yml triggers on push, issue_comment"

new_checkout g-unregistered-yaml-extension
workflow_file ci.yml 'on: push'
workflow_file update-release-pr.yaml 'on: pull_request'
registered active .github/workflows/ci.yml
run_check
expect_fail "a .yaml file is read like a .yml one" "update-release-pr.yaml triggers on pull_request"

new_checkout h-unreadable-on
workflow_file ci.yml 'on: push'
workflow_file broken.yml 'name: broken'
registered active .github/workflows/ci.yml
run_check
expect_fail "an on: the check cannot read says so rather than guessing" \
  "broken.yml triggers on an on: key this check could not read"

new_checkout i-file-gone-from-the-tree
workflow_file ci.yml 'on: push'
registered active .github/workflows/ci.yml
registered disabled_manually .github/workflows/martha-engine-push-proof.yml
run_check
expect_ok "a registered workflow whose file a patch deleted is not a failure" "only the fork's workflows are active"

new_checkout j-fork-own-unregistered
workflow_file ci.yml 'on:
  pull_request:
    branches:
      - main'
run_check
expect_ok "the fork's own file may be unregistered: it registers when its own event triggers it" \
  "only the fork's workflows are active on test/fork: none"

dir="${tmp}/k-no-checkout"
mkdir -p "${dir}"
: > "${dir}/listing"
run_check
expect_fail "a checkout without .github/workflows is refused, never silently passed" \
  ".github/workflows is not in this checkout"

new_checkout m-nested-keys-under-events
workflow_file ci.yml 'on: push'
workflow_file take.yml 'on:
  push:
    branches:
      - main
  issue_comment:
    types: [created]'
registered active .github/workflows/ci.yml
run_check
expect_fail "the events under on: are read, and not the keys nested inside them" \
  "take.yml triggers on push, issue_comment"

new_checkout l-both-kinds
workflow_file ci.yml 'on: push'
workflow_file release.yml 'on: push'
workflow_file take.yml 'on: issue_comment'
registered active .github/workflows/ci.yml
registered active .github/workflows/release.yml
run_check
expect_fail "an active file and an unregistered one are both named" "release.yml" "take.yml triggers on issue_comment"

echo
if (( failures > 0 )); then
  echo "${failures} case(s) failed"
  exit 1
fi
echo "every case passed"
