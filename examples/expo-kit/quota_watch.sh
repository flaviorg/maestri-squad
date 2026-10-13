#!/usr/bin/env bash
# quota_watch.sh: check that every floor agent still runs the model it was staffed with and has no usage-limit
# warning. The Maestro runs it at every milestone.
#
# usage: quota_watch.sh <KEY>
# Env: KIT (kit root, default: this script's directory), MAESTRI_CLI (default: maestri).
# Reads $KIT/floor-snapshots/<KEY>/STAFF.tsv and $KIT/MODEL_MAP.tsv (footer_regex, looked up by model).
# Prints one row per agent: AGENT STAFFED STATUS FOOTER. STATUS is OK, MODEL? (footer does not show the staffed
# model, or the model is not in MODEL_MAP.tsv), ALERT (usage-limit phrase in the footer) or GONE (check failed).
# The footer is the last 8 non-blank lines of the terminal; prose higher up never counts.
# Exit: 0 all OK, 1 any row not OK, 2 no manifest. On 1, apply the MODEL_MAP fallback_model with a replace-recruit.
set -uo pipefail

M="${MAESTRI_CLI:-maestri}"
KEY="${1:?usage: quota_watch.sh <KEY>}"
KIT="${KIT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
STAFF="$KIT/floor-snapshots/$KEY/STAFF.tsv"
MAP="$KIT/MODEL_MAP.tsv"
[ -f "$STAFF" ] || { echo "no manifest: $STAFF"; exit 2; }
[ -f "$MAP" ] || { echo "no model map: $MAP"; exit 2; }

# System phrases only: a bare 'quota' matches agents' own prose.
ALERT='usage limit|rate limit|limit reached|hit your|out of credits|quota reached|switched to'
NEVER='a^' # matches nothing: an unknown model can never look OK

# footer_regex <model>: footer_regex of the first MODEL_MAP row with that model, else a regex that never matches.
footer_regex() {
  local re
  re="$(awk -F'\t' -v m="$1" 'NR > 1 { sub(/\r$/, "") } NR > 1 && $4 == m { print $7; exit }' "$MAP")"
  printf '%s' "${re:-$NEVER}"
}

BAD=0
printf '%-16s %-18s %-8s %s\n' AGENT STAFFED STATUS FOOTER
while IFS=$'\t' read -r name _preset model _effort _role; do
  [ "$name" = name ] && continue
  [ -n "$name" ] || continue
  if ! screen="$("$M" check "$name" 2> /dev/null)"; then
    printf '%-16s %-18s %-8s %s\n' "$name" "$model" GONE "-"
    BAD=1
    continue
  fi
  re="$(footer_regex "$model")"
  tail8="$(grep -v '^[[:space:]]*$' <<< "$screen" | tail -n 8 || true)"
  foot="$(grep -iE -- "$re|7d:" <<< "$tail8" | tail -n 1 | tr -s ' ' | cut -c1-110 || true)"
  st=OK
  grep -qiE -- "$re" <<< "$tail8" || st="MODEL?"
  grep -qiE -- "$ALERT" <<< "$tail8" && st=ALERT
  [ "$st" = OK ] || BAD=1
  printf '%-16s %-18s %-8s %s\n' "$name" "$model" "$st" "${foot:--}"
done < "$STAFF"
exit "$BAD"
