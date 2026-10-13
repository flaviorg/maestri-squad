#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

# sanitize_repo <dir>: a throwaway git repo holding a copy of tools/ and a FIXTURE denylist of fake tokens, so the
# tests never carry real private terms. Comments and blank lines in the list are part of the fixture on purpose.
sanitize_repo() {
  mkdir -p "$1"
  cp -R "$ROOT/tools" "$1/tools"
  printf '%s\n' '# fixture: fake ticket keys, word-bounded' '(^|[^[:alnum:]_])ACME-[0-9]+' '' \
    '# fixture: a fake forbidden word' 'forbiddenword' > "$1/tools/denylist.txt"
  printf 'clean text\n' > "$1/notes.txt"
  git -C "$1" init -q
  git -C "$1" add -A
}

# sanitize_in <dir> [private-list]: run the temp repo's sanitize gate and print its exit code; the gate's output
# goes to <dir>.out.
sanitize_in() {
  local rc=0
  SANITIZE_DENYLIST_PRIVATE="${2:-$1/.git/info/denylist}" "$1/tools/check.sh" --only sanitize > "$1.out" 2>&1 || rc=$?
  echo "$rc"
}

test_sanitize_flags_denylisted_word() {
  local tmp out rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  printf 'this mentions forbiddenword\n' > "$tmp/repo/leak.txt"
  git -C "$tmp/repo" add leak.txt
  rc="$(sanitize_in "$tmp/repo")"; out="$(cat "$tmp/repo.out")"
  assert_eq 1 "$rc" "sanitize exits 1 on a denylisted word in a tracked file"
  assert_contains "$out" "FAIL sanitize" "sanitize prints FAIL sanitize"
  assert_contains "$out" "leak.txt" "sanitize names the leaking file"
}

test_sanitize_word_bounds_ticket_keys() {
  local tmp out rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  printf 'branch feature/MYACME-123, commit fix(MYACME-123): x\n' > "$tmp/repo/ok.txt"
  git -C "$tmp/repo" add ok.txt
  rc="$(sanitize_in "$tmp/repo")"; out="$(cat "$tmp/repo.out")"
  assert_eq 0 "$rc" "sanitize accepts a key whose prefix only ends in a denylisted prefix"
  assert_contains "$out" "OK sanitize" "sanitize prints OK sanitize for MYACME-123"
  printf 'commit fix(ACME-42): x\n' > "$tmp/repo/key.txt"
  git -C "$tmp/repo" add key.txt
  rc="$(sanitize_in "$tmp/repo")"; out="$(cat "$tmp/repo.out")"
  assert_eq 1 "$rc" "sanitize flags a word-bounded denylisted key"
}

test_sanitize_skips_comments_blank_lines_and_the_list_itself() {
  local tmp out rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  rc="$(sanitize_in "$tmp/repo")"; out="$(cat "$tmp/repo.out")"
  assert_eq 0 "$rc" "a blank line or comment in the list does not match every file"
  assert_contains "$out" "OK sanitize" "the denylist file itself does not trip sanitize"
}

test_sanitize_ignores_untracked_files() {
  local tmp out rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  mkdir -p "$tmp/repo/scratch"
  printf 'forbiddenword\n' > "$tmp/repo/scratch/notes.md"
  rc="$(sanitize_in "$tmp/repo")"; out="$(cat "$tmp/repo.out")"
  assert_eq 0 "$rc" "an untracked file never trips sanitize"
}

test_sanitize_reads_the_private_list() {
  local tmp out rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  printf 'the codename is privateterm\n' > "$tmp/repo/leak.txt"
  git -C "$tmp/repo" add leak.txt
  rc="$(sanitize_in "$tmp/repo")"; out="$(cat "$tmp/repo.out")"
  assert_eq 0 "$rc" "a term in no list passes"
  printf '%s\n' '# local only' 'privateterm' > "$tmp/private.txt"
  rc="$(sanitize_in "$tmp/repo" "$tmp/private.txt")"; out="$(cat "$tmp/repo.out")"
  assert_eq 1 "$rc" "SANITIZE_DENYLIST_PRIVATE adds private terms"
  assert_contains "$out" "leak.txt" "the private hit names the file"
  cp "$tmp/private.txt" "$tmp/repo/.git/info/denylist"
  rc=0
  SANITIZE_DENYLIST_PRIVATE='' "$tmp/repo/tools/check.sh" --only sanitize > /dev/null 2>&1 || rc=$?
  assert_eq 1 "$rc" "the default private list is .git/info/denylist"
}

test_sanitize_missing_private_list_is_fine() {
  local tmp rc
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  rc="$(sanitize_in "$tmp/repo" "$tmp/does-not-exist")"
  assert_eq 0 "$rc" "a missing private list is fine"
}

test_public_denylist_is_generic() {
  local tmp out rc home="/Us""ers/someone" key="-----BEGIN RSA PRI""VATE KEY-----"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sanitize.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  sanitize_repo "$tmp/repo"
  cp "$ROOT/tools/denylist.txt" "$tmp/repo/tools/denylist.txt"
  printf 'path %s/code\n' "$home" > "$tmp/repo/a.txt"
  printf '%s\n' "$key" > "$tmp/repo/b.txt"
  git -C "$tmp/repo" add -A
  rc="$(sanitize_in "$tmp/repo" "$tmp/none")"; out="$(cat "$tmp/repo.out")"
  assert_contains "$out" "a.txt" "the public list flags a personal macOS home path"
  assert_contains "$out" "b.txt" "the public list flags a private key header"
}

test_sanitize_passes_on_repo() {
  local out rc=0
  out="$("$ROOT/tools/check.sh" --only sanitize 2>&1)" || rc=$?
  assert_eq 0 "$rc" "the tracked tree is clean"
  assert_contains "$out" "OK sanitize" "sanitize prints OK sanitize"
}

test_examples_scripts_in_sync_passes_on_repo() {
  local out rc=0
  out="$("$ROOT/tools/check.sh" --only examples_scripts_in_sync 2>&1)" || rc=$?
  assert_eq 0 "$rc" "example kit scripts match src/scripts"
  assert_contains "$out" "OK examples_scripts_in_sync" "gate prints OK examples_scripts_in_sync"
}

test_examples_scripts_in_sync_flags_drift() {
  local tmp out rc=0
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sync.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  mkdir -p "$tmp/src" "$tmp/examples"
  cp -R "$ROOT/tools" "$tmp/tools"
  cp -R "$ROOT/src/scripts" "$tmp/src/scripts"
  cp -R "$ROOT/examples/expo-kit" "$tmp/examples/expo-kit"
  printf '# drift\n' >> "$tmp/examples/expo-kit/quota_watch.sh"
  out="$("$tmp/tools/check.sh" --only examples_scripts_in_sync 2>&1)" || rc=$?
  assert_eq 1 "$rc" "gate exits 1 when an example script drifts"
  assert_contains "$out" "FAIL examples_scripts_in_sync" "gate prints FAIL on drift"
  assert_contains "$out" "quota_watch.sh" "gate names the drifted script"
}

test_check_disables_both_unreachable_codes() {
  # ShellCheck 0.9 (Ubuntu CI) reports indirectly invoked functions as SC2317; 0.10+ as SC2329.
  if grep -qF 'shellcheck disable=SC2317,SC2329' "$ROOT/tools/check.sh"; then _pass; else
    _fail "tools/check.sh disables SC2317 and SC2329 for gate_* functions"
  fi
}

run_suite
