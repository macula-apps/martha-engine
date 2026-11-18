#!/usr/bin/env bash
# only_the_forks_workflows_are_active.sh <owner/repo> [checkout root]: fails while any workflow file in the checkout
# outside FORK_WORKFLOWS is unknown to GitHub, or is registered and active.
#
# Upstream ships about forty workflows, and most of them publish (releases, images, packages, pages) or move main
# (dependabot-auto-merge). On the fork they stay off, so a sync never publishes Goose's artifacts under the fork's name
# (macula-io/martha#547 S2). GitHub's own dynamic workflows (Dependabot, Pages) are not files and are not counted.
#
# Since macula-io/martha#616 the check reads the workflow FILES in the checkout and asks GitHub about each of them. The
# earlier version asked only the Actions API which workflows were active, and GitHub lists a workflow only after an
# event has triggered it: a file that had never run was outside that check's view, and it ran once before anyone saw
# it (take.yml did, on 2026-11-17). For every file outside FORK_WORKFLOWS the check now answers:
#   - registered and disabled (any `disabled_*` state): fine, it stays off;
#   - registered and active: fails, as before, and names it;
#   - not registered: fails by name and says what the file triggers on, so a person decides before its first trigger.
#     The owner decided on 2026-11-18 ("(a) Delete as a patch"): such a file is deleted from the fork's main as a
#     named patch, and name_the_patch.sh names the fork's patches that touch a conflicted file.
# A registered workflow whose file is gone is not a failure: a patch that deletes a file leaves its register entry.
# Needs GH_TOKEN with actions: read, and a checkout that holds .github/workflows (martha-engine-checks.yml keeps both).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
repo="${1:?usage: only_the_forks_workflows_are_active.sh <owner/repo> [checkout root]}"
root="${2:-.}"
workflows="${root%/}/.github/workflows"

# A checkout without the workflow files would pass this check without reading anything, so it is refused by name.
if [[ ! -d "${workflows}" ]]; then
  echo "::error::${workflows} is not in this checkout; this check reads the workflow files, so the checkout must keep them"
  exit 1
fi

# Every workflow GitHub knows, one "state<TAB>path" per line: one listing, so a file cannot read as registered here
# and unknown there. A failed listing stops the script at this line (set -e), so it never reads as "nothing active".
registered="$(gh api --paginate "repos/${repo}/actions/workflows" \
  --jq '.workflows[] | "\(.state)\t\(.path)"')"
declare -A state_of=()
while IFS=$'\t' read -r state path; do
  [[ -n "${path}" ]] && state_of["${path}"]="${state}"
done <<< "${registered}"

shopt -s nullglob
files=()
for file in "${workflows}"/*.yml "${workflows}"/*.yaml; do
  files+=("$(basename "${file}")")
done
if (( ${#files[@]} == 0 )); then
  echo "::error::no workflow file under ${workflows}; a check that reads none cannot pass"
  exit 1
fi

# The events a workflow's `on:` key names, in the three forms YAML writes it: a block mapping, a block sequence, or a
# value on the key's own line. Read from the file itself, so a file the check cannot read says so instead of guessing.
triggers_of() {
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function add(event) {
      event = trim(event); gsub(quotes, "", event)
      if (event != "") seen = seen (seen == "" ? "" : ", ") event
    }
    # Both quote characters a key may carry, built here so this program holds neither of them as a literal.
    BEGIN { quotes = "[" sprintf("%c", 39) "\"]" }
    { sub(/\r$/, "") }
    !inside && $0 ~ ("^" quotes "?on" quotes "?[ \t]*:") {
      value = $0
      sub(("^" quotes "?on" quotes "?[ \t]*:[ \t]*"), "", value)
      value = trim(value)
      if (value ~ /^\[/) {                         # on: [push, pull_request]
        gsub(/[][ \t]/, "", value)
        count = split(value, events, ",")
        for (i = 1; i <= count; i++) add(events[i])
        exit
      }
      if (value != "" && value !~ /^#/) { add(value); exit }   # on: push
      inside = 1; level = -1; next
    }
    inside {
      if ($0 ~ /^[ \t]*(#|$)/) next
      match($0, /^[ \t]*/); indent = RLENGTH
      if (indent == 0) exit                        # a key back at the left margin ends the on: block
      if (level < 0) level = indent                # an event sits at the block level itself
      if (indent != level) next                    # anything deeper is a value under an event
      event = substr($0, indent + 1)
      sub(/^-[ \t]*/, "", event)                   # on:\n  - push
      sub(/:.*/, "", event)
      add(event)
      next
    }
    END { print (seen == "" ? "an on: key this check could not read" : seen) }
  ' "$1"
}

read -r -a allowed <<< "${FORK_WORKFLOWS}"
active_on=()
active_extra=()
unregistered=()
other_state=()
for file in "${files[@]}"; do
  path=".github/workflows/${file}"
  state="${state_of[${path}]:-}"
  if [[ " ${allowed[*]} " == *" ${file} "* ]]; then
    [[ "${state}" == active ]] && active_on+=("${file}")
    continue
  fi
  case "${state}" in
    '')        unregistered+=("${file}") ;;
    active)    active_extra+=("${file}") ;;
    disabled*) : ;;
    *)         other_state+=("${file} (${state})") ;;
  esac
done

status=0
if (( ${#active_extra[@]} > 0 )); then
  echo "::error::${#active_extra[@]} workflow(s) outside the fork's own are active on ${repo}; turn them off:"
  printf '  %s\n' "${active_extra[@]}"
  status=1
fi
if (( ${#unregistered[@]} > 0 )); then
  echo "::error::${#unregistered[@]} workflow file(s) outside the fork's own are in this tree and GitHub has not registered them yet, so nothing had turned them off before their first trigger:"
  for file in "${unregistered[@]}"; do
    printf '  %s triggers on %s\n' "${file}" "$(triggers_of "${workflows}/${file}")"
  done
  echo "Delete each of them from the fork's main as a named patch (the owner's decision of 2026-11-18, \"(a) Delete as a patch\"); name_the_patch.sh names the fork's patches that touch a conflicted file."
  status=1
fi
if (( ${#other_state[@]} > 0 )); then
  echo "::error::${#other_state[@]} workflow file(s) outside the fork's own are neither active nor disabled on ${repo}:"
  printf '  %s\n' "${other_state[@]}"
  status=1
fi
(( status == 0 )) || exit 1
echo "only the fork's workflows are active on ${repo}: ${active_on[*]:-none}, and every other workflow file in this tree is off"
