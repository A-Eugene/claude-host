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

# A changed prefix retitles running, saved and matching stopped conversations.
source <(sed -n '/^retitle_all() {/,/^}/p' "$crew")
declare -A SESS_OF_CONV=([run1]=S1 [self]=S2) TITLES=([run1]="[VPS] Alpha" [self]="[VPS] Me" [saved1]="Beta" [stop1]="[VPS] Gamma" [busy]="[VPS] Busy")
ST_ORDER=(saved1 busy); SELF_SESS=S2
scan_sessions() { :; }; detect_self() { :; }; state_read() { :; }
list_convs() { printf '%s\t%s\n' stop1 "[VPS] Gamma" other "Unrelated"; }
conv_title() { printf '%s' "${TITLES[$1]:-}"; }
cmd_rename() { [ "$1" = busy ] && { echo "crew: busy" >&2; exit 1; }; echo "renamed $1 to $2"; }
TITLE_PREFIX="[LAB]"; out=$(retitle_all "[VPS]")
grep -q 'renamed run1 to \[LAB\] Alpha' <<<"$out" || fail "running session: $out"
grep -q 'renamed saved1 to \[LAB\] Beta' <<<"$out" || fail "saved session without the earlier prefix: $out"
grep -q 'renamed stop1 to \[LAB\] Gamma' <<<"$out" || fail "stopped conversation: $out"
grep -q 'other' <<<"$out" && fail "an unrelated conversation was renamed"
grep -q 'not renamed: "\[VPS\] Me" is the session you are running in. Type: /rename \[LAB\] Me' <<<"$out" || fail "own session: $out"
grep -q 'not renamed: "\[VPS\] Busy": crew: busy' <<<"$out" || fail "busy session: $out"
grep -q 'prefix: renamed 3, left 2' <<<"$out" || fail "count: $out"
TITLE_PREFIX=""; SELF_SESS=""; out=$(retitle_all "[VPS]")
grep -q 'renamed run1 to Alpha' <<<"$out" || fail "clearing the prefix: $out"
echo "ok"
