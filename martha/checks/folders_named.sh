#!/usr/bin/env bash
# Config, data and state folders sit under the fork's name, so a standalone
# install never reads or writes a separate upstream install's folders.
# Linux layout (XDG); the macOS and Windows layouts come from the same strategy.
set -euo pipefail
CHECK=folders_named
source "$(dirname "$0")/engine_name.sh"
need_engine_bin

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

info="$(env -u GOOSE_PATH_ROOT -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME \
    HOME="$home" "$ENGINE_BIN" info 2>&1)" || fail "'$ENGINE_NAME info' failed: $info"

paths="$(printf '%s\n' "$info" | awk '/^(Config dir|Config yaml|Sessions DB|Logs dir)/ { for (i = 1; i <= NF; i++) if ($i ~ /^\//) print $i }')"
count="$(printf '%s\n' "$paths" | awk 'NF' | wc -l)"
[ "$count" -eq 4 ] || fail "expected 4 paths from info, found $count in: $info"

while IFS= read -r path; do
    case "$path" in
        "$home"/*"/$ENGINE_NAME/"*|"$home"/*"/$ENGINE_NAME") ;;
        *) fail "$path is not under a $ENGINE_NAME folder in HOME" ;;
    esac
    case "$path" in
        *"/$UPSTREAM_NAME/"*|*"/$UPSTREAM_NAME") fail "$path still sits in an $UPSTREAM_NAME folder" ;;
    esac
    echo "  $path"
done <<< "$paths"

# Folders built from literals, which info does not print: the system-wide
# config and the memory extension's fallback.
for literal in "/etc/$ENGINE_NAME/config.yaml" ".config/$ENGINE_NAME/memory"; do
    command grep -a -q -F "$literal" "$ENGINE_BIN" || fail "the binary holds no '$literal'"
    echo "  holds $literal"
done
for literal in "/etc/$UPSTREAM_NAME/config.yaml" ".config/$UPSTREAM_NAME/memory"; do
    if command grep -a -q -F "$literal" "$ENGINE_BIN"; then
        fail "the binary still holds '$literal'"
    fi
    echo "  no $literal"
done
pass "all $count paths sit under $ENGINE_NAME folders; system config and memory fallback renamed"
