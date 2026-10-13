#!/usr/bin/env bash
# Single gate script. Usage: tools/check.sh [--fast] [--only <gate>]
#   --fast         skip the shellcheck gate
#   --only <gate>  run just that gate (used by tests to avoid recursion)
# Gates are functions named gate_<name>; later tasks append more.
# A gate prints a reason on failure and returns non-zero.
# shellcheck disable=SC2317,SC2329  # gate_* functions are discovered via declare -F
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# patterns_of <file>: the regex lines of a denylist, without comments (#) and blank lines.
patterns_of() {
  grep -vE '^[[:space:]]*(#|$)' "$1" || true
}

# Scans tracked files only (untracked scratch never trips it) against tools/denylist.txt plus an optional private,
# untracked list: $SANITIZE_DENYLIST_PRIVATE, else .git/info/denylist. Same format: one POSIX ERE per line.
gate_sanitize() {
  local hits patterns private
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "sanitize needs a git checkout"
    return 1
  }
  private="${SANITIZE_DENYLIST_PRIVATE:-$(git rev-parse --git-path info/denylist)}"
  patterns="$(mktemp "${TMPDIR:-/tmp}/deny.XXXXXX")"
  patterns_of tools/denylist.txt > "$patterns"
  if [ -f "$private" ]; then
    patterns_of "$private" >> "$patterns"
  fi
  hits="$(git ls-files -z -- . ':!tools/denylist.txt' |
    xargs -0 grep -sInE -f "$patterns" /dev/null || true)"
  rm -f "$patterns"
  if [ -n "$hits" ]; then
    printf 'denylisted content found:\n%s\n' "$hits"
    return 1
  fi
}

gate_shellcheck() {
  command -v shellcheck >/dev/null 2>&1 || {
    echo "shellcheck not installed"
    return 1
  }
  find tools tests src/scripts -type f \( -name '*.sh' -o -path 'tests/stubs/*' \) -print0 | xargs -0 shellcheck -x
}

gate_tests() {
  local t failed=0
  for t in tests/test_*.sh; do
    [ -e "$t" ] || continue
    bash "$t" || failed=1
  done
  [ "$failed" -eq 0 ] || {
    echo "one or more test files failed"
    return 1
  }
}

gate_build_fresh() {
  local tmp rc=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/fresh.XXXXXX")"
  tools/build.sh "$tmp" || rc=1
  if [ "$rc" -eq 0 ] && ! cmp -s "$tmp" SQUAD-BOOTSTRAP.md; then
    echo "SQUAD-BOOTSTRAP.md is stale; run tools/build.sh"
    rc=1
  fi
  rm -f "$tmp"
  return "$rc"
}

gate_embedded_scripts() {
  local f name tmp rc=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/embed.XXXXXX")"
  for f in src/scripts/*.sh; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    tools/extract.sh SQUAD-BOOTSTRAP.md "$name" > "$tmp" || rc=1
    if ! cmp -s "$tmp" "$f"; then
      echo "embedded $name differs from $f"
      rc=1
    fi
  done
  rm -f "$tmp"
  return "$rc"
}

gate_examples_scripts_in_sync() {
  local s rc=0
  for s in staff_floor.sh quota_watch.sh; do
    if ! cmp -s "examples/expo-kit/$s" "src/scripts/$s"; then
      echo "examples/expo-kit/$s differs from src/scripts/$s"
      rc=1
    fi
  done
  return "$rc"
}

main() {
  local fast=0 only="" gate gates status=0 out
  while [ $# -gt 0 ]; do
    case "$1" in
      --fast) fast=1 ;;
      --only)
        [ $# -ge 2 ] || { echo "--only needs a gate name" >&2; exit 2; }
        only="$2"
        shift
        ;;
      *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
  done

  gates="$(declare -F | awk '{print $3}' | grep '^gate_' | sed 's/^gate_//')"
  if [ -n "$only" ]; then
    printf '%s\n' "$gates" | grep -qx "$only" || { echo "unknown gate: $only" >&2; exit 2; }
    gates="$only"
  fi

  for gate in $gates; do
    if [ "$fast" -eq 1 ] && [ "$gate" = shellcheck ]; then
      continue
    fi
    if out="$("gate_$gate" 2>&1)"; then
      echo "OK $gate"
    else
      status=1
      echo "FAIL $gate: $out"
    fi
  done
  exit "$status"
}

main "$@"
