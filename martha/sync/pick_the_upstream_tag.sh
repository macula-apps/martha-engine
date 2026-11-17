#!/usr/bin/env bash
# pick_the_upstream_tag.sh [tag]: prints `tag=<the upstream release tag to sync>`, or `tag=` when there is nothing to do.
#
# This exists so the fork follows each upstream release without a person watching for it (macula-io/martha#547 S2).
# With no argument it takes upstream's newest release tag. A tag is skipped when the fork's main already holds it, or
# when a sync branch for it is already on the origin: that branch is an earlier attempt, and a person finishes it there.
# Asked for by name once a person has merged the tag on that branch, it prints `merged=1` too, and the job checks it.
# Run from the fork's checkout, with full history and `origin` set.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"

tag="${1:-}"
if [[ -z "${tag}" ]]; then
  tag="$(git ls-remote --tags --refs "${UPSTREAM_URL}" 'v*' | sed 's#.*refs/tags/##' | grep -E "${UPSTREAM_TAG_PATTERN}" | sort -V | tail -n 1)"
fi
[[ "${tag}" =~ ${UPSTREAM_TAG_PATTERN} ]] || { echo "pick_the_upstream_tag: '${tag}' is not an upstream release tag" >&2; exit 2; }

branch="sync/${tag}"
git fetch --quiet --no-tags "${UPSTREAM_URL}" "+refs/tags/${tag}:refs/tags/${tag}"
if [[ -n "$(git ls-remote --heads origin "${branch}")" ]]; then
  # A person finished the merge there (a conflict, or a push the job may not make) and asked for this tag by name:
  # the job carries on from that branch, checking it and opening the pull request, without merging again.
  git fetch --quiet origin "+refs/heads/${branch}:refs/remotes/origin/${branch}"
  if [[ -n "${1:-}" ]] && git merge-base --is-ancestor "refs/tags/${tag}" "origin/${branch}"; then
    echo "pick_the_upstream_tag: ${branch} already holds ${tag}; checking it as it is" >&2
    echo "tag=${tag}"
    echo "merged=1"
    exit 0
  fi
  echo "pick_the_upstream_tag: ${branch} is already on the origin; finish it there" >&2
  echo "tag="
  exit 0
fi
if git merge-base --is-ancestor "refs/tags/${tag}" origin/main; then
  echo "pick_the_upstream_tag: the fork's main already holds ${tag}" >&2
  echo "tag="
  exit 0
fi
echo "tag=${tag}"
