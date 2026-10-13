#!/usr/bin/env bash
# Tests for src/scripts/staff_floor.sh, driven through the stub maestri CLI in tests/stubs/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

SCRIPT="$ROOT/src/scripts/staff_floor.sh"
STUB="$ROOT/tests/stubs/maestri"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# setup <fixture>: fresh temp dir $T holding a copy of the fixture kit at "$T/my kit" (a path with a space).
setup() {
  T="$(mktemp -d "$WORK/t.XXXXXX")"
  KITDIR="$T/my kit"
  cp -R "$ROOT/tests/fixtures/$1" "$KITDIR"
  mkdir -p "$T/home" "$T/screens"
  : > "$T/log"
}

# staff <args...>: runs the script against the stub; sets RC, OUT, ERR. Prefix assignments (ONLY=...) pass through.
staff() {
  RC=0
  env -u CODEX_HOME HOME="$T/home" KIT="$KITDIR" MAESTRI_CLI="$STUB" \
    STUB_LOG="$T/log" STUB_SCREENS="$T/screens" \
    WARM_TRIES=2 WARM_SLEEP=0 WARM_KEY_SLEEP=0 RECRUIT_SLEEP=0 \
    bash "$SCRIPT" "$@" > "$T/out" 2> "$T/err" || RC=$?
  OUT="$(cat "$T/out")"
  ERR="$(cat "$T/err")"
}

# The stub log with the \x1f separators turned into spaces.
log_text() { tr '\037' ' ' < "$T/log"; }

# Names recruited, in order, space-joined.
recruits() { awk -F'\037' '$1 == "recruit" { printf "%s%s", sep, $2; sep = " " }' "$T/log"; }

# Value following <flag> on the recruit line of <name>.
recruit_arg() {
  awk -F'\037' -v n="$1" -v f="$2" '$1 == "recruit" && $2 == n { for (i = 3; i < NF; i++) if ($i == f) { print $(i + 1); exit } }' "$T/log"
}

staff_rows() { tail -n +2 "$KITDIR/floor-snapshots/K/STAFF.tsv"; }

test_staffs_s_squad_in_order() {
  setup kit-codex-claude
  staff K S "$T/floor" 1
  assert_eq 0 "$RC" "S staffing exits 0"
  assert_eq "Helm-K Veto-K Anvil-K Probe-K Rook-K Onyx-K Dock-K" "$(recruits)" "S recruit order"
  assert_eq 8 "$(wc -l < "$KITDIR/floor-snapshots/K/STAFF.tsv" | tr -d ' ')" "STAFF.tsv has header + 7 rows"
  assert_eq "$(printf 'name\tpreset\tmodel\teffort\trole')" "$(head -n 1 "$KITDIR/floor-snapshots/K/STAFF.tsv")" \
    "STAFF.tsv header"
  assert_eq "$(printf 'Veto-K\tClaude Code\tclaude-opus-5-5\thigh\tGap Hunter & Plan Auditor')" \
    "$(grep '^Veto-K' "$KITDIR/floor-snapshots/K/STAFF.tsv")" "Veto row comes from MODEL_MAP"
  assert_eq "Floor Captain" "$(recruit_arg Helm-K --role)" "Helm role name"
  assert_eq "Codex" "$(recruit_arg Helm-K --preset)" "Helm preset from MODEL_MAP"
  assert_eq "K" "$(recruit_arg Helm-K --floor)" "recruit on floor K"
}

test_xs_uses_solo_gate() {
  setup kit-codex-claude
  staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "XS staffing exits 0"
  assert_eq "Helm-K Anvil-K Onyx-K Dock-K" "$(recruits)" "XS recruits 4"
  assert_eq "Solo Gate" "$(recruit_arg Onyx-K --role)" "Onyx is the Solo Gate on XS"
  assert_eq "Solo Gate" "$(staff_rows | awk -F'\t' '$1 == "Onyx-K" { print $5 }')" "STAFF.tsv records Solo Gate"
}

test_missing_row_recruits_nobody() {
  setup kit-codex-claude
  grep -v "$(printf '^Rook\tS\t')" "$KITDIR/MODEL_MAP.tsv" > "$T/map" && cat "$T/map" > "$KITDIR/MODEL_MAP.tsv"
  staff K S "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "missing row exits non-zero"
  assert_contains "$ERR" "Rook S" "stderr names the missing pair"
  assert_eq "" "$(recruits)" "nobody is recruited"
}

test_single_provider_claude_only() {
  setup kit-claude-only
  mkdir -p "$T/ground/.codex" "$T/floor/.codex" "$T/home/.codex"
  printf '{}\n' > "$T/ground/.codex/hooks.json"
  printf '{}\n' > "$T/floor/.codex/hooks.json"
  printf 'model = "x"\n' > "$T/home/.codex/config.toml"
  printf 'GROUND_PATH="%s"\n' "$T/ground" >> "$KITDIR/kit.env"
  staff K S "$T/floor" 1
  assert_eq 0 "$RC" "claude-only staffing exits 0"
  assert_eq "0" "$(grep -ci codex "$T/log" || true)" "no codex anywhere in the maestri calls"
  assert_eq "$(printf 'model = "x"')" "$(cat "$T/home/.codex/config.toml")" "codex config untouched"
  assert_contains " $(recruits) " " Rook-K " "Rook recruited"
  assert_contains " $(recruits) " " Onyx-K " "Onyx recruited as a separate agent"
  assert_contains "$OUT" "warm_fail=0" "generic warm-up confirms every agent from its footer"
}

test_paths_with_spaces() {
  local cmd fp="/tmp/a b/floor" found_fp=0 found_kit=0 a
  setup kit-codex-claude
  staff K S "$fp" 1
  assert_eq 0 "$RC" "staffing with spaces exits 0"
  cmd="$(recruit_arg Veto-K --command)"
  assert_contains "$cmd" "--add-dir \"$fp\"" "floor path is quoted intact"
  assert_contains "$cmd" "--add-dir \"$KITDIR\"" "kit path is quoted intact"
  # A shell parsing the command must see each path as one argument.
  eval "set -- $cmd"
  for a in "$@"; do
    [ "$a" = "$fp" ] && found_fp=1
    [ "$a" = "$KITDIR" ] && found_kit=1
  done
  assert_eq "1 1" "$found_fp $found_kit" "parsed command keeps both paths as single arguments"
  assert_contains "$(recruit_arg Helm-K --command)" "--add-dir \"$KITDIR\"" "codex template quotes the kit"
  assert_contains "$OUT" "path=$fp " "STAFFED line carries the path"
}

test_only_adds_one_role() {
  setup kit-codex-claude
  staff K XS "$T/floor" 1
  : > "$T/log"
  ONLY=Probe staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "ONLY=Probe exits 0"
  assert_eq "Probe-K" "$(recruits)" "only Probe is recruited"
  assert_eq 1 "$(grep -c '^name' "$KITDIR/floor-snapshots/K/STAFF.tsv")" "no second header"
  assert_eq 5 "$(staff_rows | wc -l | tr -d ' ')" "exactly one row appended"
  assert_contains "$(log_text)" "connect Helm-K Probe-K" "Probe wired to the running Helm"
  assert_contains "$(log_text)" "connect Anvil-K Probe-K" "Probe wired to the running Anvil"
  assert_eq "0" "$(grep -c Oracle "$T/log" || true)" "Helm-Oracle rope not redone"
  assert_contains "$OUT" "squad=[Probe]" "STAFFED reports the added role"
}

test_connects_reviewers_and_oracle() {
  setup kit-codex-claude
  staff K S "$T/floor" 1
  assert_contains "$(log_text)" "connect Rook-K Onyx-K" "reviewers roped"
  assert_contains "$(log_text)" "connect Helm-K Oracle" "Helm roped to Oracle"
  assert_contains "$(log_text)" "connect Helm-K Dock-K" "Helm is the hub"
}

test_missing_oracle_only_warns() {
  setup kit-claude-only
  STUB_NO_ORACLE=1 staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "a canvas without Oracle does not fail staffing"
  assert_contains "$OUT$ERR" "Oracle" "a warning names Oracle"
  assert_contains "$(tail -n 1 "$T/out")" "STAFFED K" "staffing completes"
}

test_last_line_format() {
  setup kit-claude-only
  staff K XS "$T/floor" 2 LOW
  assert_eq "STAFFED K size=XS squad=[Helm Anvil Onyx Dock] path=$T/floor manifest=$KITDIR/floor-snapshots/K/STAFF.tsv warm_fail=0" \
    "$(tail -n 1 "$T/out")" "STAFFED line"
}

test_codex_warm_never_types_the_reply() {
  setup kit-codex-claude
  staff K XS "$T/floor" 1
  assert_contains "$(log_text)" "ask Helm-K Boot check only" "codex agent gets the boot prompt"
  assert_eq "0" "$(grep -c 'WARM-READY' "$T/log" || true)" "the expected reply is never typed"
  assert_contains "$OUT" "warm_fail=1" "an unanswered prompt is a warm failure"
  assert_contains "$OUT" "WARM Helm-K NOT CONFIRMED" "the unconfirmed agent is named"
}

test_codex_warm_confirms_and_skips_update_menu() {
  setup kit-codex-claude
  printf 'GPT-6.1-Sol\nWARM-READY\n' > "$T/screens/Helm-K"
  printf '  Skip until next version\n' > "$T/screens/Anvil-K"
  staff K XS "$T/floor" 1
  assert_contains "$OUT" "WARM Helm-K ok" "WARM-READY on screen confirms the agent"
  assert_contains "$(log_text)" 'ask Anvil-K --raw 3\n' "update menu skipped with key 3 (pre-trust off)"
  : > "$T/log"
  printf 'CODEX_PRETRUST=1\n' >> "$KITDIR/kit.env"
  ONLY=Anvil staff K XS "$T/floor" 1
  assert_contains "$(log_text)" 'ask Anvil-K --raw 3\n' "update menu skipped with key 3 (pre-trust on)"
}

test_codex_warm_leaves_hook_dialog_without_pretrust() {
  setup kit-codex-claude
  printf 'hook needs review before it can run\n' > "$T/screens/Anvil-K"
  staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "staffing exits 0"
  assert_eq "" "$(grep "^ask$(printf '\037')Anvil-K$(printf '\037')--raw" "$T/log" || true)" "no key is pressed on the hook dialog"
  assert_contains "$OUT" "approve the hook dialog in Anvil-K's terminal" "the human is told to approve it"
  assert_contains "$OUT" "WARM Anvil-K NOT CONFIRMED" "the agent stays unconfirmed"
  assert_contains "$OUT" "warm_fail=1" "warm failure reported"
}

test_codex_warm_approves_hook_dialog_with_pretrust() {
  setup kit-codex-claude
  printf 'CODEX_PRETRUST=1\n' >> "$KITDIR/kit.env"
  printf 'hook needs review before it can run\n' > "$T/screens/Anvil-K"
  staff K XS "$T/floor" 1
  assert_contains "$(log_text)" "ask Anvil-K --raw t" "hook dialog trusted with t"
  assert_contains "$(log_text)" 'ask Anvil-K --raw \e' "hook dialog closed with escape"
}

test_codex_warm_footer_is_case_insensitive() {
  setup kit-codex-claude
  printf 'model: gpt-6.1-sol\n' > "$T/screens/Helm-K"
  printf 'model: gpt-6.1-sol\nWARM-READY\n' > "$T/screens/Helm-K.reply"
  staff K XS "$T/floor" 1
  assert_contains "$(log_text)" "ask Helm-K Boot check only" "a lowercase footer counts as ready"
  assert_contains "$OUT" "WARM Helm-K ok" "the agent warms up"
}

test_generic_warm_footer_is_case_insensitive() {
  setup kit-claude-only
  printf 'opus 5.5\n' > "$T/screens/Onyx-K"
  staff K XS "$T/floor" 1
  assert_contains "$OUT" "WARM Onyx-K ok" "a lowercase footer confirms the agent"
}

test_codex_config_untouched_without_pretrust() {
  local cfg
  setup kit-codex-claude
  mkdir -p "$T/ground/.codex" "$T/floor/.codex" "$T/home/.codex"
  printf '{"hooks":1}\n' > "$T/ground/.codex/hooks.json"
  printf '{"hooks":1}\n' > "$T/floor/.codex/hooks.json"
  cfg="$T/home/.codex/config.toml"
  printf '[hooks.state."%s/.codex/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:abc"\n' "$T/ground" > "$cfg"
  cp "$cfg" "$T/orig.toml"
  printf 'GROUND_PATH="%s"\n' "$T/ground" >> "$KITDIR/kit.env"
  staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "staffing exits 0"
  assert_exit 0 "config.toml byte-identical" -- cmp "$T/orig.toml" "$cfg"
  assert_eq "" "$(find "$T/home/.codex" -name 'config.toml.bak-staff-*')" "no backup file written"
}

test_pretrust_without_ground_hooks_trusts_project() {
  local cfg
  setup kit-codex-claude
  mkdir -p "$T/home/.codex"
  cfg="$T/home/.codex/config.toml"
  printf 'model = "x"\n' > "$cfg"
  printf 'CODEX_PRETRUST=1\n' >> "$KITDIR/kit.env"
  staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "staffing exits 0"
  assert_contains "$(cat "$cfg")" "$(printf '[projects."%s"]\ntrust_level = "trusted"' "$T/floor")" "floor path trusted"
  assert_eq "0" "$(grep -c 'hooks.state' "$cfg" || true)" "no hook hash written"
  assert_exit 0 "backup holds the original" -- cmp "$cfg.bak-staff-K" <(printf 'model = "x"\n')
}

test_codex_trust_seeded_when_hooks_identical() {
  local cfg
  setup kit-codex-claude
  mkdir -p "$T/ground/.codex" "$T/fl oor/.codex" "$T/home/.codex"
  printf '{"hooks":1}\n' > "$T/ground/.codex/hooks.json"
  printf '{"hooks":1}\n' > "$T/fl oor/.codex/hooks.json"
  cfg="$T/home/.codex/config.toml"
  printf '[hooks.state."%s/.codex/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:abc"\n' "$T/ground" > "$cfg"
  cp "$cfg" "$T/orig.toml"
  printf 'GROUND_PATH="%s"\nCODEX_PRETRUST=1\n' "$T/ground" >> "$KITDIR/kit.env"
  staff K XS "$T/fl oor" 1
  assert_eq 0 "$RC" "staffing with seeding exits 0"
  assert_exit 0 "config backed up before editing" -- cmp "$T/orig.toml" "$cfg.bak-staff-K"
  assert_contains "$(cat "$cfg")" "[projects.\"$T/fl oor\"]" "floor path trusted"
  assert_contains "$(cat "$cfg")" "trust_level = \"trusted\"" "trust level set"
  assert_contains "$(cat "$cfg")" "$(printf '[hooks.state."%s/.codex/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:abc"' "$T/fl oor")" \
    "ground hook hash copied to the floor"
  staff K XS "$T/fl oor" 1
  assert_eq 1 "$(grep -cF "[projects.\"$T/fl oor\"]" "$cfg")" "re-running does not duplicate the trust entry"
}

test_codex_hash_not_copied_when_hooks_differ() {
  local cfg
  setup kit-codex-claude
  mkdir -p "$T/ground/.codex" "$T/floor/.codex" "$T/home/.codex"
  printf '{"hooks":1}\n' > "$T/ground/.codex/hooks.json"
  printf '{"hooks":2}\n' > "$T/floor/.codex/hooks.json"
  cfg="$T/home/.codex/config.toml"
  printf '[hooks.state."%s/.codex/hooks.json:pre_tool_use:0:0"]\ntrusted_hash = "sha256:abc"\n' "$T/ground" > "$cfg"
  printf 'GROUND_PATH="%s"\nCODEX_PRETRUST=1\n' "$T/ground" >> "$KITDIR/kit.env"
  staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "staffing exits 0"
  assert_eq "0" "$(grep -cF "$T/floor/.codex/hooks.json" "$cfg" || true)" "no hook hash for a different hooks.json"
  assert_contains "$OUT" "hook trust not seeded" "the skip is reported"
}

test_bad_arguments_recruit_nobody() {
  setup kit-codex-claude
  staff K XL "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "unknown size exits non-zero"
  ONLY=Ghost staff K S "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "unknown ONLY agent exits non-zero"
  staff K S "$T/fl\"oor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "a double quote in the floor path exits non-zero"
  assert_eq "" "$(recruits)" "nobody is recruited"
}

test_relative_floor_path_is_refused() {
  setup kit-codex-claude
  staff K S "relative/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "a relative floor path exits non-zero"
  assert_contains "$ERR" "FLOOR_PATH must be absolute: 'relative/floor'" "the relative floor path is named"
  assert_eq "" "$(recruits)" "nobody is recruited"
}

test_slot_zero_is_refused() {
  setup kit-codex-claude
  staff K S "$T/floor" 0
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "SLOT 0 exits non-zero"
  assert_contains "$ERR" "SLOT must be 1 or more" "SLOT 0 is refused with a clear message"
  staff K S "$T/floor" 00
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "SLOT 00 exits non-zero"
  assert_eq "" "$(recruits)" "nobody is recruited"
}

# ---- DRY_RUN=1: validate the kit and print the plan, no maestri call ----------------------------------------

# dry <args...>: like staff, with DRY_RUN=1 and a ground path in kit.env.
dry() {
  grep -q '^GROUND_PATH=.' "$KITDIR/kit.env" || printf 'GROUND_PATH="%s"\n' "$T/ground" >> "$KITDIR/kit.env"
  DRY_RUN=1 staff "$@"
}

# drop_row <role> <size>: remove that MODEL_MAP row.
drop_row() {
  awk -F'\t' -v r="$1" -v s="$2" '!($1 == r && $2 == s)' "$KITDIR/MODEL_MAP.tsv" > "$T/map"
  cat "$T/map" > "$KITDIR/MODEL_MAP.tsv"
}

test_dry_run_prints_the_plan_and_calls_nothing() {
  local cfg
  setup kit-codex-claude
  mkdir -p "$T/home/.codex"
  cfg="$T/home/.codex/config.toml"
  printf 'model = "x"\n' > "$cfg"
  printf 'CODEX_PRETRUST=1\n' >> "$KITDIR/kit.env"
  dry K S "$T/floor" 1
  assert_eq 0 "$RC" "a dry run of a complete kit exits 0"
  assert_eq "" "$(cat "$T/log")" "a dry run makes no maestri call"
  assert_exit 0 "a dry run leaves Codex's config untouched" -- cmp "$cfg" <(printf 'model = "x"\n')
  assert_eq "" "$(find "$T/home/.codex" -name 'config.toml.bak-*')" "a dry run writes no config backup"
  assert_exit 1 "a dry run writes no floor snapshot" -- test -e "$KITDIR/floor-snapshots/K"
  assert_contains "$OUT" 'PLAN Helm-K "Floor Captain" Codex gpt-6.1-sol/high fallback=gpt-6-astra' "the plan names each agent"
  assert_contains "$OUT" "launch: codex -m gpt-6.1-sol -c model_reasoning_effort=high" "the plan shows the launch command"
  assert_contains "$OUT" 'PLAN Oracle "Arbiter" Claude Code claude-opus-5-5/high' "the plan covers the ground Oracle"
  assert_eq "DRY_RUN OK K size=S squad=[Helm Veto Anvil Probe Rook Onyx Dock]" "$(tail -n 1 "$T/out")" \
    "the last line reports a valid kit"
}

test_dry_run_xs_checks_probe_on_demand() {
  setup kit-codex-claude
  drop_row Probe XS
  dry K XS "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "a dry run of XS needs Probe's XS row"
  assert_contains "$ERR" "Probe XS" "the missing on-demand Probe row is named"
  staff K XS "$T/floor" 1
  assert_eq 0 "$RC" "real XS staffing still works without a Probe XS row"
}

test_dry_run_checks_every_fallback() {
  setup kit-codex-claude
  awk -F'\t' 'BEGIN { OFS = "\t" } $1 == "Helm" && $2 == "S" { $8 = "gpt-9-nowhere" } { print }' \
    "$KITDIR/MODEL_MAP.tsv" > "$T/map" && cat "$T/map" > "$KITDIR/MODEL_MAP.tsv"
  dry K S "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "an unresolved fallback fails the dry run"
  assert_contains "$ERR" "Helm S fallback gpt-9-nowhere" "the unresolved fallback is named"
  setup kit-codex-claude
  drop_row Fallback '*'
  dry K S "$T/floor" 1
  assert_contains "$ERR" "fallback gpt-6-astra" "a fallback model without its own row is named"
}

test_dry_run_checks_on_demand_rows() {
  setup kit-codex-claude
  drop_row Oracle '*'
  dry K S "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "a dry run needs the Oracle row"
  assert_contains "$ERR" "Oracle *" "the missing Oracle row is named"
  setup kit-codex-claude
  drop_row Loom '*'
  dry K S "$T/floor" 1
  assert_eq 0 "$RC" "no Loom row is fine when the kit has no Loom role file"
  mkdir -p "$KITDIR/roles"
  printf 'x\n' > "$KITDIR/roles/ui-forge.txt"
  dry K S "$T/floor" 1
  assert_contains "$ERR" "Loom *" "a Loom role file needs its Loom row"
}

test_dry_run_checks_kit_env() {
  setup kit-codex-claude
  DRY_RUN=1 staff K S "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "an empty GROUND_PATH fails the dry run"
  assert_contains "$ERR" "GROUND_PATH" "the empty field is named"
  setup kit-codex-claude
  printf 'PORT_BASE=abc\n' >> "$KITDIR/kit.env"
  dry K S "$T/floor" 1
  assert_contains "$ERR" "PORT_BASE" "a non-numeric PORT_BASE is named"
  setup kit-codex-claude
  printf 'BRANCH_PATTERN=feature/x\n' >> "$KITDIR/kit.env"
  dry K S "$T/floor" 1
  assert_contains "$ERR" "BRANCH_PATTERN" "a branch pattern without {key} or {num} is named"
  setup kit-codex-claude
  printf 'BASE_REF=\n' >> "$KITDIR/kit.env"
  dry K S "$T/floor" 1
  assert_contains "$ERR" "BASE_REF is empty" "an empty BASE_REF is named"
}

test_dry_run_value_is_validated() {
  setup kit-codex-claude
  DRY_RUN=true staff K S "$T/floor" 1
  assert_eq 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)" "DRY_RUN=true exits non-zero"
  assert_contains "$ERR" "DRY_RUN must be 0 or 1: 'true'" "the bad DRY_RUN value is named"
  assert_eq "" "$(cat "$T/log")" "a bad DRY_RUN value makes no maestri call"
  assert_exit 1 "a bad DRY_RUN value writes no floor snapshot" -- test -e "$KITDIR/floor-snapshots/K"
}

test_dry_run_claude_only_fixture_is_complete() {
  setup kit-claude-only
  mkdir -p "$KITDIR/roles"
  for f in arbiter security ui-forge ux-lens sweep; do printf 'x\n' > "$KITDIR/roles/$f.txt"; done
  dry K S "$T/floor" 1
  assert_eq 0 "$RC" "the claude-only fixture passes a dry run with every on-demand role"
  assert_contains "$OUT" 'PLAN Broom-K "Sweep Engineer" Claude Code claude-opus-5-5/medium' "the Broom row is well formed"
}

run_suite
