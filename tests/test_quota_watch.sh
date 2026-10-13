#!/usr/bin/env bash
# Tests for src/scripts/quota_watch.sh, driven through the stub maestri CLI in tests/stubs/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

SCRIPT="$ROOT/src/scripts/quota_watch.sh"
STUB="$ROOT/tests/stubs/maestri"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# setup <rows...>: fresh kit with the codex-claude map and a STAFF.tsv for key K holding the given
# "name:model" rows.
setup() {
  T="$(mktemp -d "$WORK/t.XXXXXX")"
  KITDIR="$T/kit"
  cp -R "$ROOT/tests/fixtures/kit-codex-claude" "$KITDIR"
  mkdir -p "$T/screens" "$KITDIR/floor-snapshots/K"
  : > "$T/log"
  printf 'name\tpreset\tmodel\teffort\trole\n' > "$KITDIR/floor-snapshots/K/STAFF.tsv"
  local r
  for r in "$@"; do
    printf '%s\tp\t%s\thigh\tr\n' "${r%%:*}" "${r#*:}" >> "$KITDIR/floor-snapshots/K/STAFF.tsv"
  done
}

screen() { cp "$ROOT/tests/fixtures/screens/$2" "$T/screens/$1"; }

watch() {
  RC=0
  env KIT="$KITDIR" MAESTRI_CLI="$STUB" STUB_LOG="$T/log" STUB_SCREENS="$T/screens" \
    bash "$SCRIPT" "$@" > "$T/out" 2> "$T/err" || RC=$?
  OUT="$(cat "$T/out")"
}

row() { grep "^$1 " <<< "$OUT" || true; }

test_ok_when_footer_matches() {
  setup Veto-K:claude-opus-5-5
  screen Veto-K ok
  watch K
  assert_eq 0 "$RC" "exit 0 when all OK"
  assert_contains "$(row Veto-K)" " OK " "row is OK"
  assert_contains "$OUT" "AGENT" "header printed"
}

test_alert_on_limit_phrase() {
  setup Veto-K:claude-opus-5-5
  screen Veto-K alert
  watch K
  assert_eq 1 "$RC" "exit 1 on alert"
  assert_contains "$(row Veto-K)" " ALERT " "row is ALERT"
}

test_gone_when_check_fails() {
  setup Veto-K:claude-opus-5-5 Anvil-K:gpt-6.1-sol
  watch_gone
  assert_eq 1 "$RC" "exit 1 when an agent is gone"
  assert_contains "$(row Veto-K)" " GONE " "row is GONE"
  assert_contains "$(row Anvil-K)" " OK " "later row still printed"
}

watch_gone() {
  RC=0
  env KIT="$KITDIR" MAESTRI_CLI="$STUB" STUB_LOG="$T/log" STUB_SCREENS="$T/screens" STUB_GONE="Veto-K" \
    bash "$SCRIPT" K > "$T/out" 2> "$T/err" || RC=$?
  OUT="$(cat "$T/out")"
}

test_prose_quota_is_not_alert() {
  setup Veto-K:claude-opus-5-5
  screen Veto-K prose
  watch K
  assert_eq 0 "$RC" "prose mentioning quota does not alert"
  assert_contains "$(row Veto-K)" " OK " "row is OK"
}

test_wrong_model_footer_is_flagged() {
  setup Veto-K:claude-sonnet-5-5
  screen Veto-K ok
  watch K
  assert_eq 1 "$RC" "exit 1 on model mismatch"
  assert_contains "$(row Veto-K)" " MODEL? " "row is MODEL?"
}

test_unknown_model_is_flagged() {
  setup Veto-K:gpt-9.9+x Anvil-K:gpt-6.1-sol
  screen Veto-K ok
  watch K
  assert_eq 1 "$RC" "exit 1 on unknown model"
  assert_contains "$(row Veto-K)" " MODEL? " "unknown model is MODEL?"
  assert_contains "$(row Anvil-K)" " OK " "later row still printed"
}

test_missing_manifest_exits_2() {
  setup
  rm "$KITDIR/floor-snapshots/K/STAFF.tsv"
  watch K
  assert_eq 2 "$RC" "exit 2 without manifest"
}

run_suite
