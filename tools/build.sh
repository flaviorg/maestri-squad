#!/usr/bin/env bash
# Assemble SQUAD-BOOTSTRAP.md from src/. Usage: tools/build.sh [output-file]
# src/order.txt lists source files (relative to src/), one per line.
# A line "@@include src/scripts/<file>@@" is replaced by a fenced bash block:
#   ```bash / "# file: <file>" / file bytes / ```
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/SQUAD-BOOTSTRAP.md}"

emit_source() {
  local src="$1" line inc name
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "@@include "*"@@")
        inc="${line#@@include }"
        inc="${inc%@@}"
        [ -f "$ROOT/$inc" ] || { echo "build: missing include $inc" >&2; return 1; }
        [ -z "$(tail -c 1 "$ROOT/$inc")" ] || { echo "build: $inc lacks a trailing newline" >&2; return 1; }
        name="${inc#src/scripts/}"
        printf '```bash\n# file: %s\n' "$name"
        cat "$ROOT/$inc"
        printf '```\n'
        ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$src"
}

build() {
  local entry first=1
  while IFS= read -r entry || [ -n "$entry" ]; do
    [ -n "$entry" ] || continue
    [ -f "$ROOT/src/$entry" ] || { echo "build: missing source src/$entry" >&2; return 1; }
    [ "$first" -eq 1 ] || printf '\n'
    first=0
    emit_source "$ROOT/src/$entry" || return 1
  done < "$ROOT/src/order.txt"
}

tmp="$(mktemp "${TMPDIR:-/tmp}/build.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
build > "$tmp"
cat "$tmp" > "$OUT"
