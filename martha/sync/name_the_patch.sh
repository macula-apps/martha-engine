#!/usr/bin/env bash
# name_the_patch.sh <tag> <file>...: names the fork's own patches that touch these files.
#
# The fork's whole difference from upstream is its patch set, one purpose per commit (macula-io/martha#547). When a
# sync stops, on a conflict or on a red check, this says which of those patches is involved, so the person who picks
# it up starts from the patch and not from the whole merge. A patch is a commit on HEAD that neither the upstream tag
# nor upstream's main holds: the fork's main sits on upstream's main, which carries commits a release tag (cut on a
# release branch) does not, and those are upstream's, not the fork's. Merges are left out, since a sync is not a patch.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
tag="${1:?usage: name_the_patch.sh <tag> <file>...}"
shift
(( $# > 0 )) || { echo "name_the_patch: no files to look at"; exit 0; }

git fetch --quiet --no-tags "${UPSTREAM_URL}" "+refs/heads/main:refs/remotes/upstream/main"
patches="$(git log --no-merges --format='%h %s' HEAD --not "refs/tags/${tag}" refs/remotes/upstream/main -- "$@")"
if [[ -z "${patches}" ]]; then
  echo "No patch of the fork touches these files: the change is upstream's alone."
else
  echo "The fork's patches involved:"
  echo "${patches}"
fi
