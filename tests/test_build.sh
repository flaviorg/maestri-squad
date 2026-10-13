#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

test_build_is_deterministic() {
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  "$ROOT/tools/build.sh" "$tmp/a.md"
  "$ROOT/tools/build.sh" "$tmp/b.md"
  assert_exit 0 "two builds are byte-identical" -- cmp "$tmp/a.md" "$tmp/b.md"
}

test_first_line_is_version() {
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  "$ROOT/tools/build.sh" "$tmp/a.md"
  assert_eq "<!-- maestri-squad v1.0.0 -->" "$(head -n 1 "$tmp/a.md")" "line 1 is the version marker"
}

test_include_roundtrip() {
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  mkdir -p "$tmp/repo"
  cp -R "$ROOT/tools" "$ROOT/src" "$tmp/repo/"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\necho "hi $1"\n\necho done\n' > "$tmp/repo/src/scripts/hello.sh"
  printf '## Fixture\n\n@@include src/scripts/hello.sh@@\n' > "$tmp/repo/src/main/99-fixture.md"
  printf '%s\n' "main/99-fixture.md" >> "$tmp/repo/src/order.txt"
  "$tmp/repo/tools/build.sh" "$tmp/out.md"
  "$tmp/repo/tools/extract.sh" "$tmp/out.md" hello.sh > "$tmp/body.sh"
  assert_exit 0 "extracted body equals source byte for byte" -- cmp "$tmp/body.sh" "$tmp/repo/src/scripts/hello.sh"
}

test_gates_detect_stale_and_drift() {
  local tmp out rc=0
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  mkdir -p "$tmp/repo"
  cp -R "$ROOT/tools" "$ROOT/src" "$tmp/repo/"
  "$tmp/repo/tools/build.sh"
  out="$("$tmp/repo/tools/check.sh" --only build_fresh 2>&1)" || rc=$?
  assert_eq 0 "$rc" "fresh build passes build_fresh"
  out="$("$tmp/repo/tools/check.sh" --only embedded_scripts 2>&1)" || rc=$?
  assert_contains "$out" "OK embedded_scripts" "no scripts passes trivially"
  printf 'x=1\n' > "$tmp/repo/src/scripts/a.sh"
  printf '@@include src/scripts/a.sh@@\n' > "$tmp/repo/src/main/99-f.md"
  printf '%s\n' "main/99-f.md" >> "$tmp/repo/src/order.txt"
  out="$("$tmp/repo/tools/check.sh" --only build_fresh 2>&1)" || rc=$?
  assert_contains "$out" "FAIL build_fresh" "stale MD is detected"
  "$tmp/repo/tools/build.sh"
  out="$("$tmp/repo/tools/check.sh" --only embedded_scripts 2>&1)" || rc=$?
  assert_contains "$out" "OK embedded_scripts" "matching embed passes"
  printf 'x=2\n' > "$tmp/repo/src/scripts/a.sh"
  out="$("$tmp/repo/tools/check.sh" --only embedded_scripts 2>&1)" || rc=$?
  assert_contains "$out" "FAIL embedded_scripts" "drifted script is detected"
}

run_suite
