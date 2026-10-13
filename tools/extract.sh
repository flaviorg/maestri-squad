#!/usr/bin/env bash
# Print the body of the fenced block whose first line is "# file: <file>",
# without the marker line. Usage: tools/extract.sh <md> <file>
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: extract.sh <md> <file>" >&2; exit 2; }

awk -v want="# file: $2" '
  state == 0 && $0 == "```bash" { state = 1; next }
  state == 1 { state = ($0 == want) ? 2 : 0; next }
  state == 2 && $0 == "```" { exit }
  state == 2 { print }
' "$1"
