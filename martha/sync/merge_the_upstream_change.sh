#!/usr/bin/env bash
# merge_the_upstream_change.sh <sync/sha> <sha>: makes the branch from the fork's main and merges upstream's <sha>.
#
# A sync never rebases and never force-pushes (macula-io/martha#547): upstream comes in by `git merge`, onto a branch
# of its own, and main moves only when that branch's pull request lands. On a conflict the merge is undone, the branch
# is left at main for a person to merge by hand, and the conflicted files and the fork's patches that touch them are
# named. A clean merge names any workflow file upstream added, since only the fork's own workflows may run on it.
# Exit: 0 merged, 1 conflicted. Run from the fork's checkout after pick_the_upstream_change.sh fetched upstream.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
branch="${1:?usage: merge_the_upstream_change.sh <sync/sha> <sha>}"
sha="${2:?usage: merge_the_upstream_change.sh <sync/sha> <sha>}"

git switch --quiet -c "${branch}" origin/main
if git merge --quiet --no-ff --no-edit -m "Merge upstream main at ${sha:0:12} into the fork" "${sha}"; then
  echo "merged upstream ${sha} into ${branch}"
  # A workflow upstream adds is active on the fork once main moves; the person who lands the sync turns it off first.
  added="$(git diff --name-only --diff-filter=A HEAD^1 HEAD -- .github/workflows)"
  [[ -z "${added}" ]] || { echo "Upstream workflows this merge adds (active once main moves unless turned off):"; echo "${added}"; }
  exit 0
fi

mapfile -t conflicted < <(git diff --name-only --diff-filter=U)
git merge --abort
echo "The merge of upstream ${sha} conflicts in ${#conflicted[@]} file(s):"
printf '  %s\n' "${conflicted[@]}"
"${here}/name_the_patch.sh" "${conflicted[@]}"
exit 1
