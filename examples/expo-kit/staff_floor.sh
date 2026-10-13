#!/usr/bin/env bash
# staff_floor.sh: recruit a floor's squad on the Maestri canvas, driven by MODEL_MAP.tsv.
#
# usage: staff_floor.sh <KEY> <XS|S|M|L> <FLOOR_PATH> <SLOT> [LOW|MEDIUM|HIGH]
#   ONLY="Probe" staff_floor.sh ...   recruit and wire only the listed agents (e.g. add Probe to a running XS floor)
#   DRY_RUN=1 staff_floor.sh ...      check kit.env and every MODEL_MAP row the size needs (Probe on XS, each
#                                     fallback_model, the Oracle row and each on-demand row whose role file is in
#                                     $KIT/roles), print the plan; no maestri call, no config edit, nothing written
#
# Env: KIT (kit root, default: this script's directory), MAESTRI_CLI (default: maestri), ONLY, DRY_RUN,
#      WARM_TRIES (default 20), WARM_SLEEP (default 3), WARM_KEY_SLEEP (default 1), RECRUIT_SLEEP (default 2).
# Reads $KIT/kit.env and $KIT/MODEL_MAP.tsv; appends the squad to $KIT/floor-snapshots/<KEY>/STAFF.tsv.
# Every agent's MODEL_MAP row is checked before anyone is recruited: a half-staffed floor is the worst outcome.
# Codex pre-trust is opt-in: CODEX_PRETRUST=1 in kit.env lets the script edit Codex's config.toml (trust the floor
# path; copy the ground's hook-trust hash when hooks.json is identical) and approve hook-review dialogs at warm-up.
# Off (the default), Codex's config is never touched and a hook dialog is left for the human.
# Last line: STAFFED <KEY> size=<S> squad=[...] path=<FLOOR_PATH> manifest=<STAFF.tsv> warm_fail=<0|1>
#   (with DRY_RUN=1: DRY_RUN OK <KEY> size=<S> squad=[...])
set -euo pipefail

die() {
  echo "staff_floor: $*" >&2
  exit 1
}

[ $# -ge 4 ] && [ $# -le 5 ] || die "usage: staff_floor.sh <KEY> <XS|S|M|L> <FLOOR_PATH> <SLOT> [LOW|MEDIUM|HIGH]"
KEY="$1"
SIZE="$2"
FP="$3"
SLOT="$4"
RISK="${5:-MEDIUM}"
M="${MAESTRI_CLI:-maestri}"
KIT="${KIT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WARM_TRIES="${WARM_TRIES:-20}"
WARM_SLEEP="${WARM_SLEEP:-3}"
WARM_KEY_SLEEP="${WARM_KEY_SLEEP:-1}"
RECRUIT_SLEEP="${RECRUIT_SLEEP:-2}"
DRY="${DRY_RUN:-0}"
case "$DRY" in
  0 | 1) ;;
  *) die "DRY_RUN must be 0 or 1: '$DRY'" ;;
esac
ALL="Helm Veto Anvil Probe Rook Onyx Dock"
MAP="$KIT/MODEL_MAP.tsv"
MAP_HEADER="$(printf 'role\tsize\tpreset\tmodel\teffort\tlaunch_template\tfooter_regex\tfallback_model')"

# ---- arguments -------------------------------------------------------------------------------------------------
case "$KEY" in
  "" | .* | *[!A-Za-z0-9._-]*) die "KEY must use only letters, digits, '.', '_' or '-': '$KEY'" ;;
esac
case "$SIZE" in
  XS) BASE="Helm Anvil Onyx Dock" ;;
  S | M | L) BASE="$ALL" ;;
  *) die "size must be XS|S|M|L: '$SIZE'" ;;
esac
case "$SLOT" in
  "" | *[!0-9]*) die "SLOT must be a number: '$SLOT'" ;;
esac
[ "$((10#$SLOT))" -ge 1 ] || die "SLOT must be 1 or more (slot 0 is the ground's dev-server port): '$SLOT'"
case "$RISK" in
  LOW | MEDIUM | HIGH) ;;
  *) die "risk must be LOW|MEDIUM|HIGH: '$RISK'" ;;
esac
case "$FP" in
  /*) ;;
  *) die "FLOOR_PATH must be absolute: '$FP'" ;;
esac
# Paths are pasted into launch commands inside double quotes, so they must not carry shell-active characters.
for p in "$FP" "$KIT"; do
  case "$p" in
    "" | *[\"\\\$\`]*) die "paths must be non-empty and free of \" \\ \$ \`: '$p'" ;;
  esac
done

in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

REQUESTED="${ONLY:-$BASE}"
for a in $REQUESTED; do
  in_list "$a" "$ALL" || die "unknown agent '$a' in ONLY (known: $ALL)"
done
SQUAD=""
for a in $ALL; do
  in_list "$a" "$REQUESTED" && SQUAD="$SQUAD${SQUAD:+ }$a"
done
[ -n "$SQUAD" ] || die "empty squad (check ONLY)"

has() { in_list "$1" "$SQUAD"; }
on_floor() { in_list "$1" "$SQUAD" || in_list "$1" "$BASE"; }

role_name() {
  case "$1" in
    Helm) echo "Floor Captain" ;;
    Veto) echo "Gap Hunter & Plan Auditor" ;;
    Anvil) echo "Builder" ;;
    Probe) echo "Test Runtime & E2E" ;;
    Rook) echo "Reviewer A" ;;
    Onyx) if [ "$SIZE" = XS ]; then echo "Solo Gate"; else echo "Reviewer B"; fi ;;
    Dock) echo "Shipper" ;;
    Oracle) echo "Arbiter" ;;
    Aegis) echo "Security Auditor" ;;
    Loom) echo "UI Builder" ;;
    Prism) echo "UX Advisor" ;;
    Broom) echo "Sweep Engineer" ;;
  esac
}

# ---- kit files -------------------------------------------------------------------------------------------------
[ -f "$KIT/kit.env" ] || die "missing $KIT/kit.env"
[ -f "$MAP" ] || die "missing $MAP"
# shellcheck source=/dev/null
. "$KIT/kit.env"
GROUND="${GROUND_PATH:-}"
PRETRUST="${CODEX_PRETRUST:-0}"
case "$PRETRUST" in
  0 | 1) ;;
  *) die "CODEX_PRETRUST in kit.env must be 0 or 1: '$PRETRUST'" ;;
esac
[ "$(head -n 1 "$MAP" | tr -d '\r')" = "$MAP_HEADER" ] ||
  die "$MAP header must be the tab-separated columns: $(printf '%s' "$MAP_HEADER" | tr '\t' ' ')"
if [ "$DRY" = 1 ]; then
  problems=""
  for v in PROJECT_SLUG GROUND_PATH BASE_BRANCH BASE_REF BRANCH_PATTERN PORT_BASE; do
    [ -n "${!v:-}" ] || problems="$problems, $v is empty"
  done
  case "${PORT_BASE:-0}" in *[!0-9]*) problems="$problems, PORT_BASE must be a number: '$PORT_BASE'" ;; esac
  case "${BRANCH_PATTERN:-}" in
    "" | *"{key}"* | *"{num}"*) ;;
    *) problems="$problems, BRANCH_PATTERN needs {key} or {num}: '$BRANCH_PATTERN'" ;;
  esac
  [ -z "$problems" ] || die "kit.env is invalid: ${problems#, }. Nothing was staffed."
fi

# map_rows <role> <size>: every MODEL_MAP row for that pair (CR stripped).
map_rows() {
  awk -F'\t' -v r="$1" -v s="$2" 'NR > 1 { sub(/\r$/, "") } NR > 1 && $1 == r && $2 == s' "$MAP"
}
# col <row> <n>: the n-th tab-separated field (empty fields kept).
col() { printf '%s\n' "$1" | cut -f "$2"; }

# ---- validate every row before anyone is recruited -----------------------------------------------------------
missing=""
broken=""
# check_row <role> <size>: exactly one row with columns 3-7 filled; problems are added to $missing or $broken.
check_row() {
  local rows n
  rows="$(map_rows "$1" "$2")"
  if [ -z "$rows" ]; then
    missing="$missing, $1 $2"
    return 1
  fi
  if [ "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')" -ne 1 ]; then
    broken="$broken, $1 $2 (duplicate rows)"
    return 1
  fi
  for n in 3 4 5 6 7; do
    [ -n "$(col "$rows" "$n")" ] || broken="$broken, $1 $2 (empty $(col "$MAP_HEADER" "$n"))"
  done
}

CHECK="$SQUAD"
if [ "$DRY" = 1 ] && [ -z "${ONLY:-}" ] && [ "$SIZE" = XS ]; then
  CHECK="$CHECK Probe" # Probe joins XS on demand
fi
for a in $CHECK; do
  check_row "$a" "$SIZE" || continue
done
ONDEMAND=""
if [ "$DRY" = 1 ]; then # Oracle always; every other on-demand role when the kit has its role file
  for od in Oracle:arbiter.txt Aegis:security.txt Loom:ui-forge.txt Prism:ux-lens.txt Broom:sweep.txt; do
    a="${od%%:*}"
    [ "$a" = Oracle ] || [ -f "$KIT/roles/${od#*:}" ] || continue
    if check_row "$a" "*"; then ONDEMAND="$ONDEMAND $a"; fi
  done
fi
[ -z "$missing" ] || die "MODEL_MAP.tsv has no row for: ${missing#, }. Nobody was recruited; add the rows and re-run."
[ -z "$broken" ] || die "MODEL_MAP.tsv rows are invalid: ${broken#, }. Nobody was recruited."

if [ "$DRY" != 1 ]; then
  for a in $SQUAD; do
    r="$(role_name "$a")"
    "$M" role show "$r" > /dev/null 2>&1 || die "missing workspace role: $r (create the workspace roles first)"
  done
  echo "staffing $KEY size=$SIZE risk=$RISK slot=$SLOT squad=[$SQUAD] path=$FP"
fi

# ---- launch commands -----------------------------------------------------------------------------------------
# replace_all <text> <placeholder> <value>: literal replacement, safe for / & spaces and glob characters.
replace_all() {
  local rest="$1" out=""
  while :; do
    case "$rest" in
      *"$2"*)
        out="$out${rest%%"$2"*}$3"
        rest="${rest#*"$2"}"
        ;;
      *) break ;;
    esac
  done
  printf '%s' "$out$rest"
}

# render <template> <model> <effort> <name> [floor path]: paths go in double quotes so each stays one shell argument.
render() {
  local t="$1"
  t="$(replace_all "$t" "{model}" "$2")"
  t="$(replace_all "$t" "{effort}" "$3")"
  t="$(replace_all "$t" "{name}" "$4")"
  t="$(replace_all "$t" "{floor_path}" "\"${5:-$FP}\"")"
  replace_all "$t" "{kit}" "\"$KIT\""
}

is_codex() { case "$1" in Codex*) return 0 ;; esac; return 1; }

# ---- dry run: fallbacks, then the plan; no maestri call, no config edit, nothing written ----------------------
# check_fallback <label> <row>: the row's fallback_model is the model of some row with preset, effort, template and
# footer filled (the in-place swap of Appendix E.4 renders that row).
check_fallback() {
  local fb fr n
  fb="$(col "$2" 8)"
  [ -n "$fb" ] || {
    problems="$problems, $1 (empty fallback_model)"
    return 0
  }
  fr="$(awk -F'\t' -v m="$fb" 'NR > 1 { sub(/\r$/, "") } NR > 1 && $4 == m { print; exit }' "$MAP")"
  [ -n "$fr" ] || {
    problems="$problems, $1 fallback $fb (no row runs that model)"
    return 0
  }
  for n in 3 5 6 7; do
    [ -n "$(col "$fr" "$n")" ] || problems="$problems, $1 fallback $fb (empty $(col "$MAP_HEADER" "$n"))"
  done
}

# plan <codename> <size> <agent name> <floor path> [note]: one PLAN line and the rendered launch command.
plan() {
  local row
  row="$(map_rows "$1" "$2")"
  echo "PLAN $3 \"$(role_name "$1")\" $(col "$row" 3) $(col "$row" 4)/$(col "$row" 5) fallback=$(col "$row" 8)${5:+ $5}"
  echo "  launch: $(render "$(col "$row" 6)" "$(col "$row" 4)" "$(col "$row" 5)" "$3" "$4")"
}

if [ "$DRY" = 1 ]; then
  problems=""
  for a in $CHECK; do check_fallback "$a $SIZE" "$(map_rows "$a" "$SIZE")"; done
  for a in $ONDEMAND; do check_fallback "$a *" "$(map_rows "$a" "*")"; done
  [ -z "$problems" ] || die "MODEL_MAP.tsv fallbacks are invalid: ${problems#, }. Nothing was staffed."
  for a in $CHECK; do
    if has "$a"; then plan "$a" "$SIZE" "$a-$KEY" "$FP"; else plan "$a" "$SIZE" "$a-$KEY" "$FP" "(on demand)"; fi
  done
  for a in $ONDEMAND; do
    if [ "$a" = Oracle ]; then plan Oracle "*" Oracle "$GROUND" "(ground)"; else plan "$a" "*" "$a-$KEY" "$FP" "(on demand)"; fi
  done
  echo "DRY_RUN OK $KEY size=$SIZE squad=[$SQUAD]"
  exit 0
fi

# ---- Codex pre-trust (opt-in: CODEX_PRETRUST=1) ---------------------------------------------------------------
# Trusts the floor path in Codex's config.toml. The hook-trust hash is content-based, so the ground's hash is
# copied only when the floor's hooks.json is byte-identical; otherwise the warm-up clears the dialog. The config
# is backed up before any edit, and only when an edit is needed.
seed_codex_trust() {
  local cfg="${CODEX_HOME:-$HOME/.codex}/config.toml" gh="$GROUND/.codex/hooks.json" fh="$FP/.codex/hooks.json"
  local add="" pairs suffix hash
  [ -f "$cfg" ] || {
    echo "codex trust not seeded (no $cfg)"
    return 0
  }
  grep -qF "[projects.\"$FP\"]" "$cfg" || add="$(printf '\n[projects."%s"]\ntrust_level = "trusted"' "$FP")"
  if [ -z "$GROUND" ] || [ ! -f "$gh" ]; then
    echo "hook trust not seeded (no ground .codex/hooks.json)"
  elif [ -f "$fh" ] && cmp -s "$fh" "$gh"; then
    pairs="$(G="$gh" awk '
      BEGIN { p = "[hooks.state.\"" ENVIRON["G"] ":"; n = length(p) }
      /^\[/ { s = ""; if (substr($0, 1, n) == p && $0 ~ /"\]$/) { s = substr($0, n + 1); sub(/"\]$/, "", s) } next }
      s != "" && /^[[:space:]]*trusted_hash[[:space:]]*=/ { h = $0; sub(/^[^"]*"/, "", h); sub(/".*$/, "", h); print s "\t" h; s = "" }
    ' "$cfg")"
    if [ -z "$pairs" ]; then
      echo "hook trust not seeded (no ground hook hash in $cfg)"
    else
      while IFS="$(printf '\t')" read -r suffix hash; do
        grep -qF "[hooks.state.\"$fh:$suffix\"]" "$cfg" ||
          add="$add$(printf '\n[hooks.state."%s:%s"]\ntrusted_hash = "%s"' "$fh" "$suffix" "$hash")"
      done <<< "$pairs"
    fi
  else
    echo "hook trust not seeded (floor .codex/hooks.json differs from ground)"
  fi
  [ -n "$add" ] || return 0
  cp "$cfg" "$cfg.bak-staff-$KEY"
  printf '%s\n' "$add" >> "$cfg"
  echo "codex trust seeded in $cfg (backup: $cfg.bak-staff-$KEY)"
}

need_codex=0
for a in $SQUAD; do
  is_codex "$(col "$(map_rows "$a" "$SIZE")" 3)" && need_codex=1
done
if [ "$need_codex" -eq 1 ] && [ "$PRETRUST" -eq 1 ]; then
  seed_codex_trust
fi

# ---- recruit -------------------------------------------------------------------------------------------------
SNAP="$KIT/floor-snapshots/$KEY"
STAFF="$SNAP/STAFF.tsv"
mkdir -p "$SNAP"
[ -f "$STAFF" ] || printf 'name\tpreset\tmodel\teffort\trole\n' > "$STAFF"

recruited=""
for a in $SQUAD; do
  row="$(map_rows "$a" "$SIZE")"
  preset="$(col "$row" 3)"
  model="$(col "$row" 4)"
  effort="$(col "$row" 5)"
  name="$a-$KEY"
  role="$(role_name "$a")"
  cmd="$(render "$(col "$row" 6)" "$model" "$effort" "$name")"
  "$M" recruit "$name" --floor "$KEY" --preset "$preset" --role "$role" --command "$cmd" ||
    die "recruit failed for $name (already recruited:${recruited:- none})"
  recruited="$recruited $name"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$preset" "$model" "$effort" "$role" >> "$STAFF"
  sleep "$RECRUIT_SLEEP"
done

# ---- ropes ---------------------------------------------------------------------------------------------------
# rope <a> <b>: connect two agents when at least one is being recruited now and both are on the floor
# (so ONLY=Probe on a running XS floor still wires Probe to the existing Helm and Anvil).
rope() {
  if ! { has "$1" || has "$2"; } || ! on_floor "$1" || ! on_floor "$2"; then
    return 0
  fi
  "$M" connect "$1-$KEY" "$2-$KEY" || die "connect failed: $1-$KEY <-> $2-$KEY"
}
for a in Veto Anvil Probe Rook Onyx Dock; do rope Helm "$a"; done # Helm is the hub
rope Anvil Probe
rope Rook Onyx # the reviewers' only lateral channel
if has Helm; then # escalation to the ground arbiter
  "$M" connect "Helm-$KEY" "Oracle" ||
    echo "warning: could not rope Helm-$KEY to Oracle (is Oracle on the canvas?); continuing" >&2
fi

# ---- warm-up -------------------------------------------------------------------------------------------------
screen() { "$M" check "$1" 2> /dev/null | grep -v '^[[:space:]]*$' | tail -30 || true; }
key() { "$M" ask "$1" --raw "$2" > /dev/null 2>&1 || true; }

# Codex: clear the update menu (and, with CODEX_PRETRUST=1 only, approve the hook-review dialog), then prove the
# agent answers a prompt. The expected reply is never typed in the prompt, so an echoed prompt cannot fake it.
codex_warm() {
  local n="$1" re="$2" s i=0 asked=0 told=0
  while [ "$i" -lt "$WARM_TRIES" ]; do
    i=$((i + 1))
    s="$(screen "$n")"
    if grep -q "Skip until next version" <<< "$s"; then
      key "$n" "3\n"
    elif grep -q "needs review before it can run" <<< "$s" && [ "$PRETRUST" -eq 0 ]; then
      [ "$told" -eq 1 ] || echo "WARM $n waiting: a hook needs review; approve the hook dialog in $n's terminal (or set CODEX_PRETRUST=1 in kit.env)"
      told=1
    elif grep -q "needs review before it can run" <<< "$s"; then
      key "$n" "t"
      sleep "$WARM_KEY_SLEEP"
      key "$n" "\e"
      sleep "$WARM_KEY_SLEEP"
      key "$n" "\e"
      asked=0 # the dialog swallows the prompt that triggered it
    elif grep -q "WARM-READY" <<< "$s"; then
      echo "WARM $n ok"
      return 0
    elif [ "$asked" -eq 0 ] && grep -qiE -- "$re" <<< "$s"; then
      asked=1
      "$M" ask "$n" "Boot check only: reply with the word WARM and the word READY joined by a hyphen, nothing else. Do not run any command." > /dev/null 2>&1 || true
    fi
    sleep "$WARM_SLEEP"
  done
  echo "WARM $n NOT CONFIRMED - run: $M check \"$n\""
  return 1
}

# Any other agent CLI: no prompt (no tokens); clear a folder-trust dialog and wait for the model footer.
generic_warm() {
  local n="$1" re="$2" s i=0
  while [ "$i" -lt "$WARM_TRIES" ]; do
    i=$((i + 1))
    s="$(screen "$n")"
    if grep -qiE "trust (the files in )?this folder" <<< "$s" && grep -q "1\. Yes" <<< "$s"; then
      key "$n" "1\n"
    elif grep -qiE -- "$re" <<< "$s"; then
      echo "WARM $n ok"
      return 0
    fi
    sleep "$WARM_SLEEP"
  done
  echo "WARM $n NOT CONFIRMED - run: $M check \"$n\""
  return 1
}

WARM_FAIL=0
for a in $SQUAD; do
  row="$(map_rows "$a" "$SIZE")"
  if is_codex "$(col "$row" 3)"; then
    codex_warm "$a-$KEY" "$(col "$row" 7)" || WARM_FAIL=1
  else
    generic_warm "$a-$KEY" "$(col "$row" 7)" || WARM_FAIL=1
  fi
done

echo "STAFFED $KEY size=$SIZE squad=[$SQUAD] path=$FP manifest=$STAFF warm_fail=$WARM_FAIL"
