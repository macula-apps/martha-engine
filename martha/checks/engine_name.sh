# Sourced by every check. Sets REPO_ROOT, ENGINE_NAME, UPSTREAM_NAME and
# ENGINE_VERSION from the sources, so no check restates them.
#
# ENGINE_NAME is the [[bin]] of goose-cli whose path is src/main.rs: the one
# place the fork names its engine for cargo. UPSTREAM_NAME is the goose crate's
# package name, which the fork keeps so upstream merges stay clean.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLI_MANIFEST="$REPO_ROOT/crates/goose-cli/Cargo.toml"

fail() {
    echo "FAIL [$CHECK]: $*" >&2
    exit 1
}

pass() {
    echo "PASS [$CHECK]: $*"
}

ENGINE_NAME="$(awk '
    /^\[\[bin\]\]/ { in_bin = 1; name = ""; next }
    /^\[/          { in_bin = 0 }
    in_bin && /^name *=/ { gsub(/.*= *"|".*/, ""); name = $0 }
    in_bin && /^path *= *"src\/main.rs"/ { print name; exit }
' "$CLI_MANIFEST")"

UPSTREAM_NAME="$(awk '
    /^\[package\]/ { in_pkg = 1; next }
    /^\[/          { in_pkg = 0 }
    in_pkg && /^name *=/ { gsub(/.*= *"|".*/, ""); print; exit }
' "$REPO_ROOT/crates/goose/Cargo.toml")"

ENGINE_VERSION="$(awk '
    /^\[workspace.package\]/ { in_ws = 1; next }
    /^\[/                    { in_ws = 0 }
    in_ws && /^version *=/   { gsub(/.*= *"|".*/, ""); print; exit }
' "$REPO_ROOT/Cargo.toml")"

[ -n "$ENGINE_NAME" ] || fail "no [[bin]] with path src/main.rs in $CLI_MANIFEST"
[ -n "$UPSTREAM_NAME" ] || fail "no package name in crates/goose/Cargo.toml"
[ -n "$ENGINE_VERSION" ] || fail "no [workspace.package] version in Cargo.toml"
[ "$ENGINE_NAME" != "$UPSTREAM_NAME" ] || fail "the engine binary is still named $UPSTREAM_NAME, upstream's name"

need_engine_bin() {
    [ -n "${ENGINE_BIN:-}" ] || fail "ENGINE_BIN is not set; run through martha/checks/run.sh"
    [ -x "$ENGINE_BIN" ] || fail "ENGINE_BIN $ENGINE_BIN is not an executable"
}

# Features cargo resolves for one package under one feature set, comma-separated.
# $1 package, $2 cargo feature arguments for goose-cli.
resolved_features() {
    local package="$1"; shift
    (cd "$REPO_ROOT" && cargo tree -p goose-cli "$@" -e features --prefix none \
        -f '{p} [{f}]' -i "$package" 2>/dev/null) \
        | awk -v pkg="$package" '$1 == pkg { sub(/.*\[/, ""); sub(/\].*/, ""); print; exit }'
}

# Fails unless the feature is absent from the package under both shipped sets.
# $1 package, $2 feature
feature_absent_from_shipped_sets() {
    local package="$1" feature="$2" set features
    for set in default portable-default; do
        if [ "$set" = default ]; then
            features="$(resolved_features "$package")"
        else
            features="$(resolved_features "$package" --no-default-features --features "$set")"
        fi
        [ -n "$features" ] || fail "cargo resolved no features for $package under $set (cargo tree failed?)"
        case ",$features," in
            *",$feature,"*) fail "$package is built with '$feature' under $set: [$features]" ;;
        esac
        echo "  $package under $set: no '$feature' in [$features]"
    done
}
