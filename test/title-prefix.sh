#!/usr/bin/env bash
# Checks the title prefix: `new` and `rename` put it in front once, a name typed
# without it still matches, and setup writes it to crew.conf.
set -uo pipefail
crew="$(dirname "$0")/../bin/claude-host"
source <(sed -n '/^with_prefix() {/,/^}/p; /^norm_name() {/,/^}/p; /^name_matches() {/,/^}/p' "$crew")
fail() { echo "FAIL: $*"; exit 1; }

TITLE_PREFIX=""
[ "$(with_prefix "Yun Yi")" = "Yun Yi" ] || fail "an empty prefix changed the title"
TITLE_PREFIX="[VPS]"
[ "$(with_prefix "Yun Yi")" = "[VPS] Yun Yi" ] || fail "prefix not added: $(with_prefix "Yun Yi")"
[ "$(with_prefix "[VPS] Yun Yi")" = "[VPS] Yun Yi" ] || fail "prefix added twice"
[ "$(with_prefix "VPS notes")" = "[VPS] VPS notes" ] || fail "the brackets were read as a pattern"
name_matches "Yun Yi" "[VPS] Yun Yi" || fail "a name without the prefix did not match"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/work"; cp "$crew" "$tmp/bin/"
"$tmp/bin/$(basename "$crew")" setup --workdir "$tmp/work" --title-prefix "[LAB]" >/dev/null 2>&1 || fail "setup refused the prefix"
( source "$tmp/crew.conf"; [ "$TITLE_PREFIX" = "[LAB]" ] ) || fail "crew.conf does not hold the prefix"
"$tmp/bin/$(basename "$crew")" setup --title-prefix $'a\tb' >/dev/null 2>&1 && fail "a tab in the prefix was accepted"
"$tmp/bin/$(basename "$crew")" setup >/dev/null 2>&1 || fail "setup with no flags failed"
( source "$tmp/crew.conf"; [ "$TITLE_PREFIX" = "[LAB]" ] ) || fail "a bare setup dropped the prefix"
echo "ok"
