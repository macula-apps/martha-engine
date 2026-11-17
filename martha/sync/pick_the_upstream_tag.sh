#!/usr/bin/env bash
# pick_the_upstream_tag.sh [tag]: prints `tag=<the upstream release tag to sync>`, or `tag=` when there is nothing to do.
#
# This exists so the fork follows each upstream release without a person watching for it (macula-io/martha#547 S2).
# With no argument it takes upstream's newest release tag. A tag is skipped when the fork's main already holds it, or
# when a sync branch for it is already on the origin: that branch is an earlier attempt, and a person finishes it there.
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
if [[ -n "$(git ls-remote --heads origin "${branch}")" ]]; then
  echo "pick_the_upstream_tag: ${branch} is already on the origin; finish it there" >&2
  echo "tag="
  exit 0
fi
git fetch --quiet --no-tags "${UPSTREAM_URL}" "+refs/tags/${tag}:refs/tags/${tag}"
if git merge-base --is-ancestor "refs/tags/${tag}" origin/main; then
  echo "pick_the_upstream_tag: the fork's main already holds ${tag}" >&2
  echo "tag="
  exit 0
fi
echo "tag=${tag}"
