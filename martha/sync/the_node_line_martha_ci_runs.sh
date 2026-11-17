#!/usr/bin/env bash
# the_node_line_martha_ci_runs.sh <martha checkout>: prints `node=<line>`, the Node line Martha's own CI runs on.
#
# The trial lines run Martha's driver, so they run on the Node Martha's CI tests it with (macula-io/martha#547 S2),
# read from that CI at the pinned commit rather than restated here. Fails unless every job there names the same line.
set -euo pipefail
ci="${1:?usage: the_node_line_martha_ci_runs.sh <martha checkout>}/.github/workflows/ci.yml"
mapfile -t lines < <(sed -nE "s/^[[:space:]]*node-version:[[:space:]]*['\"]?([0-9][0-9.x]*)['\"]?[[:space:]]*$/\1/p" "${ci}" | sort -u)
(( ${#lines[@]} == 1 )) || { echo "::error::${ci} names ${#lines[@]} Node lines (${lines[*]:-none}), not one" >&2; exit 1; }
echo "node=${lines[0]}"
