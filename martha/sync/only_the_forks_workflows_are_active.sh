#!/usr/bin/env bash
# only_the_forks_workflows_are_active.sh <owner/repo>: fails while any workflow outside FORK_WORKFLOWS is active.
#
# Upstream ships about forty workflows, and most of them publish (releases, images, packages, pages) or move main
# (dependabot-auto-merge). On the fork they stay off, so a sync never publishes Goose's artifacts under the fork's name
# (macula-io/martha#547 S2). GitHub's own dynamic workflows (Dependabot, Pages) are not files and are not counted.
# Needs GH_TOKEN with actions: read.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
repo="${1:?usage: only_the_forks_workflows_are_active.sh <owner/repo>}"

# A failed listing stops the script here (set -e), so it never reads as "nothing active".
listing="$(gh api --paginate "repos/${repo}/actions/workflows" \
  --jq '.workflows[] | select(.state == "active") | .path | select(startswith(".github/workflows/")) | ltrimstr(".github/workflows/")')"
mapfile -t active <<< "${listing}"
read -r -a allowed <<< "${FORK_WORKFLOWS}"

extra=()
for workflow in "${active[@]}"; do
  [[ " ${allowed[*]} " == *" ${workflow} "* ]] || extra+=("${workflow}")
done
if (( ${#extra[@]} > 0 )); then
  echo "::error::${#extra[@]} workflow(s) outside the fork's own are active on ${repo}; turn them off:"
  printf '  %s\n' "${extra[@]}"
  exit 1
fi
echo "only the fork's workflows are active on ${repo}: ${active[*]}"
