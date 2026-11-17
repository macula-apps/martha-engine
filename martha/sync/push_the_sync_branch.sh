#!/usr/bin/env bash
# push_the_sync_branch.sh <tag>: pushes the merged sync/<tag>, or, when GitHub refuses the push, leaves sync/<tag> at
# main for a person to finish, as a conflict does.
#
# The job pushes with GITHUB_TOKEN, and GitHub refuses a GITHUB_TOKEN push whose commits change .github/workflows: no
# workflow-level token can write workflows. Upstream changes its workflows in some releases, so those syncs cannot be
# pushed by the job (macula-io/martha#547 S2, a known limit). The branch is then pushed at main, which the next daily
# run skips, and the summary gives the person the manual path. Exit: 0 pushed merged, 1 left at main.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
tag="${1:?usage: push_the_sync_branch.sh <tag>}"
branch="sync/${tag}"

if git push --quiet origin "HEAD:refs/heads/${branch}"; then
  echo "pushed ${branch}"
  exit 0
fi
git push --quiet origin "origin/main:refs/heads/${branch}"
cat <<MANUAL
GitHub refused the job's push of ${branch} (above). When it names the workflows permission, the merge changes
.github/workflows, which GITHUB_TOKEN cannot push. ${branch} is left at main. To finish it, with a token that may
write workflows:
  git fetch origin ${branch} && git switch ${branch}
  git fetch --no-tags ${UPSTREAM_URL} +refs/tags/${tag}:refs/tags/${tag}
  git merge --no-ff -m "Merge upstream ${tag} into the fork" refs/tags/${tag} && git push origin ${branch}
  gh workflow run martha-engine-sync.yml -f tag=${tag}   # runs the checks on it and opens the pull request
MANUAL
exit 1
