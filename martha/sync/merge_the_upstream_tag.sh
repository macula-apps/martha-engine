#!/usr/bin/env bash
# merge_the_upstream_tag.sh <tag>: makes the branch sync/<tag> from the fork's main and merges the upstream tag into it.
#
# A sync never rebases and never force-pushes (macula-io/martha#547): the tag comes in by `git merge`, onto a branch of
# its own, and main moves only when that branch's pull request lands. On a conflict the merge is undone, the branch is
# left at main for a person to merge by hand, and the conflicted files and the fork's patches that touch them are named.
# A clean merge names any workflow file upstream added, since only the fork's own workflows may run on it.
# Exit: 0 merged, 1 conflicted. Run from the fork's checkout after pick_the_upstream_tag.sh fetched the tag.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tag="${1:?usage: merge_the_upstream_tag.sh <tag>}"
branch="sync/${tag}"

git switch --quiet -c "${branch}" origin/main
if git merge --quiet --no-ff --no-edit -m "Merge upstream ${tag} into the fork" "refs/tags/${tag}"; then
  echo "merged ${tag} into ${branch}"
  # A workflow upstream adds is active on the fork once main moves; the person who lands the sync turns it off first.
  added="$(git diff --name-only --diff-filter=A HEAD^1 HEAD -- .github/workflows)"
  [[ -z "${added}" ]] || { echo "Upstream workflows this merge adds (active once main moves unless turned off):"; echo "${added}"; }
  exit 0
fi

mapfile -t conflicted < <(git diff --name-only --diff-filter=U)
git merge --abort
echo "The merge of ${tag} conflicts in ${#conflicted[@]} file(s):"
printf '  %s\n' "${conflicted[@]}"
"${here}/name_the_patch.sh" "${tag}" "${conflicted[@]}"
exit 1
