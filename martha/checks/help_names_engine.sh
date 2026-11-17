#!/usr/bin/env bash
# Every help page of the engine (the top level and each subcommand, walked from
# --help) names the engine by its own name, and the completion script it
# generates completes the engine's command by default.
#
# Upstream's name may still appear where it names something real that is not
# the engine: the @goose shell alias, .goose folders, GOOSE_* settings, Goose
# Desktop, a goose session export, and "built on Goose".
set -euo pipefail
CHECK=help_names_engine
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

allowed="@${UPSTREAM_NAME}|\\.${UPSTREAM_NAME}|${UPSTREAM_NAME^^}_[A-Z_]+|Goose Desktop|built on Goose|${UPSTREAM_NAME} session export"

pages=0
offending=()
walk() {
    local text
    text="$("$ENGINE_BIN" "$@" --help 2>&1)" || fail "'$ENGINE_NAME $* --help' failed"
    pages=$((pages + 1))
    local hits
    hits="$(printf '%s\n' "$text" | sed -E "s/${allowed}//g" | command grep -n -i -w "$UPSTREAM_NAME" || true)"
    [ -z "$hits" ] || offending+=("$ENGINE_NAME $* --help: $(printf '%s' "$hits" | head -3 | tr '\n' ' ')")
    local sub
    for sub in $(printf '%s\n' "$text" \
            | awk '/^Commands:/ { c = 1; next } /^[^ ]/ { c = 0 } c && /^  [a-z]/ { print $1 }' \
            | command grep -v -x help); do
        walk "$@" "$sub"
    done
}
walk

if [ ${#offending[@]} -gt 0 ]; then
    printf '  %s\n' "${offending[@]}" >&2
    fail "${#offending[@]} of $pages help pages name $UPSTREAM_NAME for the engine"
fi
echo "  $pages help pages walked, none names $UPSTREAM_NAME for the engine"

completion="$("$ENGINE_BIN" completion bash)"
printf '%s\n' "$completion" | command grep -q -E "complete .*[[:space:]]${ENGINE_NAME}\$" \
    || fail "'completion bash' does not complete $ENGINE_NAME by default"
if printf '%s\n' "$completion" | command grep -q -E "complete .*[[:space:]]${UPSTREAM_NAME}\$"; then
    fail "'completion bash' completes $UPSTREAM_NAME by default"
fi
echo "  completion bash completes $ENGINE_NAME by default"
pass "help pages and completion name $ENGINE_NAME"
