#!/usr/bin/env bash
# pick_the_upstream_change.sh [sync/<sha>]: prints what today's sync merges, as `sync=sync/<sha>` and `upstream=<sha>`,
# or `sync=` when there is nothing to do.
#
# This exists so the fork follows Goose's main without a person watching it (macula-io/martha#547 S2). A day is
# skipped when the fork's main already holds upstream's main (it has not moved), or while an earlier sync is not done:
# a branch sync/<sha> on the origin whose <sha> main does not yet hold. A person finishes that one first, so syncs never
# pile up. Given the name of such a branch, once a person has merged it there, it prints `merged=1` too, and the job
# checks that branch and reports it green for a member to open its pull request. Run from the fork's checkout, with
# full history and `origin` set.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
resume="${1:-}"
nothing() { echo "pick_the_upstream_change: $1" >&2; echo "sync="; exit 0; }

git fetch --quiet --no-tags "${UPSTREAM_URL}" "+refs/heads/${UPSTREAM_BRANCH}:refs/remotes/upstream/${UPSTREAM_BRANCH}"
git fetch --quiet origin '+refs/heads/sync/*:refs/remotes/origin/sync/*' '+refs/heads/main:refs/remotes/origin/main'
in_main() { git merge-base --is-ancestor "$1" origin/main; }
upstream_of() { git rev-parse --verify --quiet "${1#sync/}^{commit}"; }

if [[ -n "${resume}" ]]; then
  [[ "${resume}" =~ ^sync/[0-9a-f]{12}$ ]] || { echo "pick_the_upstream_change: '${resume}' is not sync/<12 hex>" >&2; exit 2; }
  sha="$(upstream_of "${resume}")" || { echo "pick_the_upstream_change: no upstream commit for ${resume}" >&2; exit 2; }
  git rev-parse --verify --quiet "origin/${resume}" > /dev/null || { echo "pick_the_upstream_change: ${resume} is not on the origin" >&2; exit 2; }
  git merge-base --is-ancestor "${sha}" "origin/${resume}" || nothing "${resume} does not hold upstream ${sha} yet; merge it there first"
  printf 'sync=%s\nupstream=%s\nmerged=1\n' "${resume}" "${sha}"
  exit 0
fi

sha="$(git rev-parse "refs/remotes/upstream/${UPSTREAM_BRANCH}")"
in_main "${sha}" && nothing "the fork's main already holds upstream ${UPSTREAM_BRANCH} at ${sha}"
while read -r branch; do
  [[ -n "${branch}" ]] || continue
  done_sha="$(upstream_of "${branch#origin/}")" || nothing "${branch#origin/} names no upstream commit; a person clears it"
  in_main "${done_sha}" || nothing "${branch#origin/} is not finished; a person finishes it first"
done < <(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/sync/')
printf 'sync=sync/%s\nupstream=%s\n' "${sha:0:12}" "${sha}"
