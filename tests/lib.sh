#!/usr/bin/env bash
# Minimal test helpers. Source this file, define test_* functions, call run_suite.

PASS_COUNT=0
FAIL_COUNT=0

_pass() { PASS_COUNT=$((PASS_COUNT + 1)); }
_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

assert_eq() {
  if [ "$1" = "$2" ]; then _pass; else _fail "$3 (expected '$1', got '$2')"; fi
}

assert_contains() {
  case "$1" in
    *"$2"*) _pass ;;
    *) _fail "$3 (missing '$2')" ;;
  esac
}

# assert_exit <code> <msg> -- <cmd...>
assert_exit() {
  local expected="$1" msg="$2" actual=0
  shift 2
  [ "${1:-}" = "--" ] && shift
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$expected" = "$actual" ]; then _pass; else _fail "$msg (expected exit $expected, got $actual)"; fi
}

# Runs every function named test_* defined in the calling shell.
run_suite() {
  local fn
  for fn in $(declare -F | awk '{print $3}' | grep '^test_'); do
    "$fn"
  done
  printf 'PASS %d / FAIL %d\n' "$PASS_COUNT" "$FAIL_COUNT"
  [ "$FAIL_COUNT" -eq 0 ]
}
