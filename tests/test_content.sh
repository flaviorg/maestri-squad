#!/usr/bin/env bash
# Content checks for the generic appendices (A rules, B roles, E operating loop, F lessons, G templates).
# Runs against a fresh build of SQUAD-BOOTSTRAP.md in a temp dir, so it tests the sources in src/.
# shellcheck disable=SC2016  # literal $KIT and backticks are the expected text, not expansions
# No pipefail here: these checks pipe large strings into readers that stop early (grep -q, head -n 1). On Linux
# the writer then dies of SIGPIPE, and pipefail would turn a match into a failure or abort the suite.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MD="$WORK/SQUAD-BOOTSTRAP.md"
"$ROOT/tools/build.sh" "$MD"

# Placeholders.
# Kit-time: the Maestro fills these once, in Phase 3, when it writes the kit files.
KIT_PLACEHOLDERS="PROJECT_SLUG KIT_PATH BASE_BRANCH BASE_REF BRANCH_PATTERN GATES E2E_TOOL E2E_RUN GENERATED_DIRS FRESH_SETUP TRACKER
TICKET_PATTERN ATTRIBUTION_RULE SIGNING_RECIPE STACK_RULES"
# Floor-time: they stay literal in the kit and in the workspace roles; each agent reads their values from the
# FLOOR BRIEFING the Maestro writes for every floor.
FLOOR_PLACEHOLDERS="KEY FLOOR_PATH SLOT"

ROLE_NAMES="Floor Captain|Gap Hunter & Plan Auditor|Builder|Test Runtime & E2E|Reviewer A|Reviewer B|Solo Gate|Shipper|Arbiter|Security Auditor|UI Builder|UX Advisor|Sweep Engineer"
CODENAMES="Helm Veto Anvil Probe Rook Onyx Onyx Dock Oracle Aegis Loom Prism Broom"

# section <heading>: the lines of one "## " section, heading excluded. Headings inside ``` fences (the templates)
# do not end a section.
section() {
  awk -v h="$1" '
    !on && $0 == h { on = 1; next }
    on && /^```/ { fence = !fence }
    on && !fence && /^## / { exit }
    on { print }
  ' "$MD"
}

# role_body <n>: the lines of the n-th "### " block of Appendix B (1-based).
role_body() {
  section "## Appendix B: Roles" | awk -v n="$1" '
    /^```/ { fence = !fence }
    !fence && /^### / { i++; next }
    i == n { print }
  '
}

# role_headings: the "### " headings of Appendix B, outside fences.
role_headings() {
  section "## Appendix B: Roles" | awk '/^```/ { f = !f } !f && /^### /'
}

test_roles_count_is_13() {
  local n
  n="$(role_headings | grep -c '^### ' || true)"
  assert_eq 13 "$n" "Appendix B has 13 role headings"
}

test_role_headings_are_exact() {
  local got want i=0 code name
  got="$(role_headings)"
  want=""
  for code in $CODENAMES; do
    i=$((i + 1))
    name="$(printf '%s\n' "$ROLE_NAMES" | awk -F'|' -v i="$i" '{ print $i }')"
    want="$want### $code — $name"$'\n'
  done
  assert_eq "${want%$'\n'}" "$got" "role headings are '### <Codename> — <Role name>' in order"
}

test_role_names_match_staff_floor() {
  local headings r
  headings="$(role_headings)"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    assert_contains "$headings" " — $r" "staff_floor.sh role '$r' has an Appendix B heading"
  done <<EOF
$(sed -n '/^role_name()/,/^}/p' "$ROOT/src/scripts/staff_floor.sh" | grep -oE 'echo "[^"]+"' | sed 's/^echo "//; s/"$//')
EOF
}

test_every_role_is_well_formed() {
  local i body words
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
    body="$(role_body "$i")"
    assert_contains "$body" "Model slot: " "role $i declares a model slot"
    if printf '%s\n' "$body" | grep -qE '^Model slot: (PLANNER|BUILDER|GATE|REVIEWER_A|SHIPPER|ARBITER)$'; then
      _pass
    else
      _fail "role $i model slot is one of the six slots"
    fi
    assert_contains "$body" '```text' "role $i prompt is in a text fence"
    assert_contains "$body" "maestri list" "role $i tells the agent to run maestri list"
    assert_contains "$body" '$KIT/RULES.md' "role $i reads the kit rules"
    words="$(printf '%s\n' "$body" | awk '/^```text$/ { on = 1; next } /^```$/ { on = 0 } on && !/^# file: /' |
      wc -w | tr -d ' ')"
    if [ "$words" -lt 400 ]; then _pass; else _fail "role $i prompt is under 400 words (got $words)"; fi
  done
}

test_every_placeholder_is_known() {
  local p allowed=" $KIT_PLACEHOLDERS $FLOOR_PLACEHOLDERS " bad=""
  allowed="$(printf '%s' "$allowed" | tr '\n' ' ')"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$allowed" in
      *" $p "*) ;;
      *) bad="$bad $p" ;;
    esac
  done <<EOF
$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$MD" | sed 's/[{}]//g' | sort -u)
EOF
  assert_eq "" "$bad" "every {{X}} placeholder belongs to the known set"
}

test_unknown_placeholder_is_caught() {
  local p allowed=" $KIT_PLACEHOLDERS $FLOOR_PLACEHOLDERS "
  allowed="$(printf '%s' "$allowed" | tr '\n' ' ')"
  p="$(printf 'x {{NOT_A_PLACEHOLDER}} y\n' | grep -oE '\{\{[A-Za-z0-9_]+\}\}' | sed 's/[{}]//g')"
  case "$allowed" in
    *" $p "*) _fail "the placeholder check rejects an unknown name" ;;
    *) _pass ;;
  esac
}

test_safe_defaults_present() {
  local s
  while IFS= read -r s; do
    if grep -qF -- "$s" "$MD"; then _pass; else _fail "safe default sentence present: $s"; fi
  done <<'EOF'
Agents never merge, force-push, run `git reset --hard` or `git clean -fd`.
Only the Shipper commits.
Every external write needs the human's go through the Maestro.
Secrets are passed by file reference only.
EOF
}

test_rules_have_every_core_section() {
  local rules s
  rules="$(section "## Appendix A: Rules")"
  for s in Authority Evidence Floor "T Trace protocol" TDD State E2E Review Git Tracker Secrets Scope Budget XS Quota; do
    assert_contains "$rules" "§$s" "Appendix A has §$s"
  done
  assert_contains "$rules" '$KIT/quota_watch.sh {{KEY}}' "§Quota runs quota_watch.sh"
  assert_contains "$rules" 'ONLY="Probe" $KIT/staff_floor.sh' "§XS adds Probe with staff_floor.sh"
}

test_appendices_are_in_order() {
  local got
  got="$(grep -E '^## Appendix ' "$MD" | sed 's/:.*//' | tr '\n' ' ')"
  assert_eq "## Appendix A ## Appendix B ## Appendix C ## Appendix D ## Appendix E ## Appendix F ## Appendix G " \
    "$got" "appendices A to G in order"
}

test_operating_loop_has_close_and_cleanup() {
  local e w
  e="$(section "## Appendix E: Maestro operating loop")"
  for w in "FLOOR BRIEFING" "quota_watch.sh" "TRACE_AUDIT_OK" "maestri floor delete" "floor-snapshots" \
    node_modules Pods DerivedData .app .apk "HANDOFF"; do
    assert_contains "$e" "$w" "Appendix E mentions $w"
  done
}

test_lessons_cover_the_six() {
  local f w
  f="$(section "## Appendix F: Operating lessons")"
  for w in "ack only" "maestri floor list" "CODEX_PRETRUST" "status bar" "consolidated ask" "TRACE deviation"; do
    assert_contains "$f" "$w" "Appendix F covers: $w"
  done
}

test_templates_present() {
  local g
  g="$(section "## Appendix G: TASK and TRACE templates")"
  assert_contains "$g" "# TASK — {{KEY}}" "TASK template header"
  assert_contains "$g" "# TRACE — {{KEY}}" "TRACE template header"
  assert_contains "$g" "Sync {{BASE_BRANCH}}" "TASK tracking syncs the base branch"
  assert_contains "$g" "<!-- TRACE-END -->" "TRACE template has the sentinel"
}

test_export_strips_note_read_framing() {
  local e
  e="$(section "## Appendix E: Maestro operating loop")"
  assert_contains "$e" 'lines total' "export drops the '[N lines total]' header of maestri note read"
  assert_contains "$e" '[0-9]+\t' "export strips the '<n><TAB>' line prefixes"
}

test_floor_card_reaches_every_agent() {
  local e a b g
  e="$(section "## Appendix E: Maestro operating loop")"
  assert_contains "$e" "FLOOR CARD" "Appendix E defines the floor card"
  assert_contains "$e" "maestri ask --batch" "the floor card goes to every squad member in one batch"
  for w in KEY= FLOOR_PATH= KIT= SLOT= PORT= CAPTAIN=; do
    assert_contains "$e" "$w" "the floor card carries $w"
  done
  a="$(section "## Appendix A: Rules")"
  b="$(section "## Appendix B: Roles")"
  g="$(section "## Appendix G: TASK and TRACE templates")"
  assert_contains "$a" "floor card (or Helm's briefing)" "rules point agents at the floor card"
  assert_contains "$b" "floor card (or Helm's briefing)" "roles point agents at the floor card"
  if printf '%s\n%s\n' "$a" "$b" | grep -qE 'from your FLOOR BRIEFING|in your FLOOR BRIEFING'; then
    _fail "no rule or role says the values come only from the FLOOR BRIEFING"
  else
    _pass
  fi
  assert_contains "$g" "KIT {{KIT_PATH}}" "the TASK header records the kit path"
}

test_sync_base_is_owned_by_the_shipper() {
  local a dock anvil helm
  a="$(section "## Appendix A: Rules")"
  assert_contains "$a" "SYNC BASE:" "§Git spells out the SYNC BASE recipe"
  assert_contains "$a" "checkpoint commit" "SYNC BASE starts from a local checkpoint commit"
  helm="$(role_body 1)"
  anvil="$(role_body 3)"
  dock="$(role_body 8)"
  assert_contains "$helm" "SYNC BASE" "Helm's pipeline has SYNC BASE"
  assert_contains "$helm" "Dock" "Helm dispatches SYNC BASE to Dock"
  assert_contains "$dock" "SYNC BASE" "Dock owns SYNC BASE"
  assert_contains "$dock" "CHECKPOINT" "Dock has checkpoint-commit preconditions"
  assert_contains "$dock" "SHIP" "Dock has ship preconditions"
  assert_contains "$anvil" "SYNC BASE" "Anvil resolves SYNC BASE conflicts"
}

STACK_NAMES="Expo / React Native|Flutter|React / Next.js|Node (Nest / Express)|Python (FastAPI / Django)|Go|Generic Front|Generic Mobile|Generic Backend"
STACK_FIELDS="Status|Detection hints|Gates|E2E|Dev server and ports|Generated directories|Fresh setup|Risk triggers|Conventions worth a rule"

# stack_headings: the "### " headings of Appendix C, outside fences.
stack_headings() {
  section "## Appendix C: Stacks" | awk '/^```/ { f = !f } !f && /^### /'
}

# stack_body <n>: the lines of the n-th "### " block of Appendix C (1-based).
stack_body() {
  section "## Appendix C: Stacks" | awk -v n="$1" '
    /^```/ { fence = !fence }
    !fence && /^### / { i++; next }
    i == n { print }
  '
}

# stack_field <n> <field>: the lines under "#### <field>" in the n-th stack, up to the next "#### ".
stack_field() {
  stack_body "$1" | awk -v h="#### $2" '
    /^```/ { fence = !fence }
    !fence && /^#### / { on = ($0 == h); next }
    on { print }
  '
}

test_nine_stack_sections() {
  local want
  want="$(printf '%s\n' "$STACK_NAMES" | tr '|' '\n' | sed 's/^/### /')"
  assert_eq "$want" "$(stack_headings)" "Appendix C has the nine stack headings in order"
}

test_every_stack_has_all_fields() {
  local i want got
  want="$(printf '%s\n' "$STACK_FIELDS" | tr '|' '\n' | sed 's/^/#### /')"
  for i in 1 2 3 4 5 6 7 8 9; do
    got="$(stack_body "$i" | awk '/^```/ { f = !f } !f && /^#### /')"
    assert_eq "$want" "$got" "stack $i has the nine fields in order"
  done
}

test_only_expo_is_battle_tested() {
  local i status first
  for i in 1 2 3 4 5 6 7 8 9; do
    status="$(stack_field "$i" Status | grep -v '^$' || true)"
    first="$(printf '%s\n' "$status" | head -n 1)"
    if [ "$i" -eq 1 ]; then
      assert_eq "battle-tested" "$first" "stack $i status is battle-tested"
      assert_contains "$status" "Run end to end by a real squad on a production app." "stack $i battle-tested sentence"
    else
      assert_eq "starter" "$first" "stack $i status is starter"
      assert_contains "$status" "not yet run end to end by a squad — verify every command in Phase 2." \
        "stack $i starter sentence"
    fi
  done
  assert_eq 1 "$(section "## Appendix C: Stacks" | grep -c '^battle-tested$' || true)" "exactly one battle-tested stack"
}

test_stack_e2e_defaults() {
  local i want
  i=0
  while IFS= read -r want; do
    i=$((i + 1))
    assert_contains "$(stack_field "$i" E2E)" "$want" "stack $i E2E default"
  done <<'EOF'
Maestro (maestro.dev)
`integration_test`
Playwright
supertest
pytest
httptest
EOF
}

test_expo_carries_the_squad_lessons() {
  local body w
  body="$(stack_body 1)"
  for w in "Never hand-edit" "expo-development-client/?url=" "CI=1" "Bonjour" "launchApp" "patch-package" \
    "PORT_BASE+SLOT" "adb -s <id> reverse" "10.0.2.2" ".nvmrc"; do
    assert_contains "$body" "$w" "Expo section mentions $w"
  done
}

test_expo_fresh_setup_spares_bare_native_dirs() {
  local fs
  fs="$(stack_field 1 "Fresh setup")"
  if printf '%s\n' "$fs" | grep -E 'Remove .*`ios/`' | grep -qF '(CNG only)'; then _pass; else
    _fail "Expo fresh setup marks the native-dir delete step (CNG only)"
  fi
  if printf '%s\n' "$fs" | grep -F 'npx expo prebuild --clean' | grep -qF '(CNG only)'; then _pass; else
    _fail "Expo fresh setup marks the prebuild step (CNG only)"
  fi
  assert_contains "$fs" "Bare React Native" "Expo fresh setup has a bare React Native line"
  assert_contains "$fs" "keep \`ios/\` and \`android/\`" "bare React Native keeps the native folders"
  assert_contains "$fs" "bundle exec pod install" "bare React Native runs pod install via bundle exec"
}

test_flutter_integration_test_screenshots_need_flutter_drive() {
  local e
  e="$(stack_field 2 E2E)"
  assert_contains "$e" "flutter drive --driver=test_driver/integration_test.dart" "screenshots via flutter drive"
  assert_contains "$e" "integrationDriver(onScreenshot:" "screenshots need an onScreenshot handler"
  assert_contains "$e" "convertFlutterSurfaceToImage()" "Android needs convertFlutterSurfaceToImage"
  assert_contains "$e" "reportData" "takeScreenshot bytes go to reportData"
  if printf '%s\n' "$e" | grep -qF 'binding.takeScreenshot` in'; then
    _fail "no claim that takeScreenshot under flutter test writes files"
  else
    _pass
  fi
}

PHASES="## Phase 0: Preflight|## Phase 1: Questions|## Phase 2: Project reading|## Phase 3: Kit generation|## Phase 4: Owner review|## Phase 5: Workspace roles|## Phase 6: First floor"

test_phases_in_order() {
  local want got i h n
  want="$(printf '%s\n' "$PHASES" | tr '|' '\n')"
  got="$(awk '/^```/ { f = !f } !f && /^## Phase /' "$MD")"
  assert_eq "$want" "$got" "the H2 phases are Phase 0 to Phase 6, in order"
  for i in 1 2 3 4 5 6 7; do
    h="$(printf '%s\n' "$PHASES" | awk -F'|' -v i="$i" '{ print $i }')"
    n="$(section "$h" | grep -cv '^[[:space:]]*$' || true)"
    if [ "$n" -ge 5 ]; then _pass; else _fail "$h has a body (got $n non-blank lines)"; fi
  done
  got="$(grep -nE '^## (Phase 6|Appendix A):' "$MD" | cut -d: -f1 | tr '\n' ' ')"
  if [ "$(echo "$got" | awk '{ print ($1 < $2) }')" = 1 ]; then _pass; else _fail "the phases come before the appendices"; fi
}

test_q1_to_q4_present() {
  local q w
  q="$(section "## Phase 1: Questions")"
  for w in "| Q1 | Area |" "| Q2 | Stack |" "| Q3 | Available agents and models |" "| Q4 | Team policies |" \
    "one question at a time" "in the user's language" "detected default pre-filled" "maestri preset list" \
    "plenty / limited / scarce" "CODEX_PRETRUST" "Jira / Linear / GitHub Issues / none"; do
    assert_contains "$q" "$w" "Phase 1 has: $w"
  done
}

test_degenerate_cases_documented() {
  local k r w
  k="$(section "## Phase 3: Kit generation")"
  for w in "One provider" "One model" "Scarce quota" PLANNER BUILDER GATE REVIEWER_A SHIPPER ARBITER \
    "different family from PLANNER and BUILDER" "different family from Onyx"; do
    assert_contains "$k" "$w" "model allocation covers: $w"
  done
  r="$(section "## Phase 4: Owner review")"
  assert_contains "$r" "WARNING: no cross-family review independence" "Phase 4 shows the independence warning"
  assert_contains "$k" "WARNING: no cross-family review independence" "the allocation names the same warning"
}

test_model_map_header_matches_script() {
  local fmt want got
  fmt="$(sed -n "s/^MAP_HEADER=\"\$(printf '\(.*\)')\"\$/\1/p" "$ROOT/src/scripts/staff_floor.sh")"
  [ -n "$fmt" ] || _fail "staff_floor.sh defines MAP_HEADER with printf"
  # shellcheck disable=SC2059  # the format string is the script's own header
  want="$(printf "$fmt")"
  got="$(section "## Phase 3: Kit generation" | grep -E '^role[[:space:]]size[[:space:]]' || true)"
  assert_eq "$want" "$got" "the MODEL_MAP.tsv header in Phase 3 is byte-identical to staff_floor.sh's"
}

test_model_map_rows_cover_every_squad() {
  local k row
  k="$(section "## Phase 3: Kit generation")"
  while IFS= read -r row; do
    assert_contains "$k" "$row" "effort table row: $row"
  done <<'EOF'
| Helm | PLANNER | high | high | high | xhigh |
| Veto | GATE | — | high | xhigh | xhigh |
| Anvil | BUILDER | medium | medium | high | xhigh |
| Probe | BUILDER | medium | medium | high | high |
| Rook | REVIEWER_A | — | high | high | xhigh |
| Onyx | GATE | high | high | xhigh | xhigh |
| Dock | SHIPPER | medium | medium | medium | medium |
EOF
  for row in Oracle Aegis Loom Prism Broom; do
    if printf '%s\n' "$k" | grep -qE "^\| $row \| [A-Z_]+ \| \`\*\` "; then _pass; else
      _fail "on-demand row for $row with size \`*\`"
    fi
  done
}

test_kit_files_and_launch_templates() {
  local k w
  k="$(section "## Phase 3: Kit generation")"
  for w in PROJECT_SLUG GROUND_PATH BASE_BRANCH BRANCH_PATTERN PORT_BASE KIT_VERSION CODEX_PRETRUST "1.0.0" \
    '${MAESTRI_SQUAD_HOME:-$HOME/.maestri-squad}' "Appendix A" "Appendix B" "Appendix C" "Appendix D" "Appendix G" \
    'claude --model {model} --effort {effort} --permission-mode auto --add-dir {floor_path} --add-dir {kit} -n {name}' \
    'codex -m {model} -c model_reasoning_effort={effort} -c check_for_update_on_startup=false --add-dir {kit}' \
    "Antigravity" "# file: "; do
    assert_contains "$k" "$w" "Phase 3 has: $w"
  done
}

test_phases_drive_the_cli() {
  local p0 p2 p4 p5 p6 w
  p0="$(section "## Phase 0: Preflight")"
  for w in "maestri list" "maestri preset list" '${MAESTRI_SQUAD_HOME:-$HOME/.maestri-squad}' KIT_VERSION \
    "update" "keep" "start over" "PROJECT_PROFILE.md"; do
    assert_contains "$p0" "$w" "Phase 0 has: $w"
  done
  p2="$(section "## Phase 2: Project reading")"
  assert_contains "$p2" "file:line" "Phase 2 records evidence as file:line"
  assert_contains "$p2" "never a guess" "Phase 2 turns unresolved items into questions"
  p4="$(section "## Phase 4: Owner review")"
  assert_contains "$p4" "explicit OK" "Phase 4 waits for an explicit OK"
  p5="$(section "## Phase 5: Workspace roles")"
  for w in 'maestri role create "$name"' "--scope current" "maestri role show" \
    'maestri recruit "Oracle" --preset' '--role "Arbiter"' "Sweep Engineer|sweep.txt" "Solo Gate|solo-gate.txt"; do
    assert_contains "$p5" "$w" "Phase 5 has: $w"
  done
  p6="$(section "## Phase 6: First floor")"
  for w in 'maestri floor create "<KEY>" --branch' "maestri floor list" \
    'staff_floor.sh <KEY> <SIZE> <FLOOR_PATH> <SLOT>' "FLOOR CARD" "FLOOR BRIEFING" "Appendix E" "§XS" \
    "Risk triggers"; do
    assert_contains "$p6" "$w" "Phase 6 has: $w"
  done
}

test_placeholder_check_matches_every_placeholder() {
  local k re p
  k="$(section "## Phase 3: Kit generation")"
  re="$(printf '%s\n' "$k" | sed -n "s/.*grep -rhoE '\([^']*\)'.*/\1/p" | head -n 1)"
  [ -n "$re" ] || _fail "Phase 3 has a grep -rhoE placeholder check"
  for p in $KIT_PLACEHOLDERS $FLOOR_PLACEHOLDERS; do
    if printf '{{%s}}\n' "$p" | grep -qE -- "$re"; then _pass; else
      _fail "the Phase 3 placeholder check regex '$re' matches {{$p}}"
    fi
  done
}

test_key_charset_matches_staff_floor() {
  local cs p6
  cs="$(sed -n 's/^  "" | \.\* | \*\[!\([^]]*\)\]\*).*/\1/p' "$ROOT/src/scripts/staff_floor.sh")"
  [ -n "$cs" ] || _fail "staff_floor.sh enforces a KEY charset"
  p6="$(section "## Phase 6: First floor")"
  assert_contains "$p6" "[$cs]" "Phase 6 documents the KEY charset staff_floor.sh enforces"
  assert_contains "$p6" '`#123` → `GH-123`' "Phase 6 maps a GitHub issue number to a valid KEY"
  if printf '%s\n' "$(section "## Phase 1: Questions")" | grep -qF '`#[0-9]+`'; then
    _fail "Phase 1 no longer suggests a #-prefixed key pattern"
  else
    _pass
  fi
}

test_floor_path_is_expanded_and_checked() {
  local p6
  p6="$(section "## Phase 6: First floor")"
  assert_contains "$p6" 'leading `~`' "Phase 6 expands a leading ~ in the floor path"
  assert_contains "$p6" 'test -d "<FLOOR_PATH>"' "Phase 6 verifies the floor path exists"
}

test_fallback_models_have_their_own_row() {
  local k
  k="$(section "## Phase 3: Kit generation")"
  assert_contains "$k" 'every `fallback_model` must also appear as the `model` of some row' "fallback rule"
  assert_contains "$k" 'role `Fallback` and size `*`' "fallback rows use role Fallback, size *"
  if printf '%s\n' "$k" | grep -qE "^Fallback	\*	Codex	gpt-6-astra	"; then _pass; else
    _fail "the example has a Fallback row for gpt-6-astra"
  fi
}

# ---- Cold dry run hardening (findings F1-F20, restored details D5-D41) ----------------------------------------

# main_body: every line before the Appendix A heading.
main_body() {
  awk '/^## Appendix A:/ { exit } { print }' "$MD"
}

test_main_body_stays_short() {
  local n
  n="$(main_body | wc -l | tr -d ' ')"
  if [ "$n" -le 410 ]; then _pass; else _fail "the main body (before Appendix A) is at most 410 lines (got $n)"; fi
}

test_branch_slug_is_optional() {
  local p2 p3 p6
  p2="$(section "## Phase 2: Project reading")"
  p3="$(section "## Phase 3: Kit generation")"
  p6="$(section "## Phase 6: First floor")"
  assert_contains "$p2" 'an optional `{slug}`' "F1: Phase 2 says {slug} is optional"
  assert_contains "$p2" '`feature/{key}`' "F1: Phase 2 shows a pattern without {slug}"
  assert_contains "$p3" 'optional {slug}' "F1: kit.env comment says {slug} is optional"
  assert_contains "$p6" 'when the pattern has one' "F1: Phase 6 renders {slug} only when present"
}

test_stack_rules_source_is_consistent() {
  local s="plus the repo's own documented conventions" h
  for h in "## Phase 2: Project reading" "## Phase 3: Kit generation" "## Appendix A: Rules" "## Appendix C: Stacks"; do
    assert_contains "$(section "$h")" "$s" "F2: $h defines {{STACK_RULES}} the same way"
  done
}

test_q3_asks_a_cross_provider_ranking() {
  local q
  q="$(section "## Phase 1: Questions")"
  assert_contains "$q" "strongest overall" "F3: Q3 asks for the strongest model across presets"
  assert_contains "$q" "best coding per cost" "F3: Q3 asks for the best coding-per-cost model"
}

test_fallback_may_cross_providers() {
  local k e
  k="$(section "## Phase 3: Kit generation")"
  e="$(section "## Appendix E: Maestro operating loop")"
  assert_contains "$k" "another provider's model" "D16: a fallback may point to another provider's model"
  assert_contains "$k" "falls back to itself" "F4: the weakest model of a preset has a defined fallback"
  assert_contains "$e" "another provider" "D16: the E.4 swap handles a fallback on another provider"
  assert_contains "$e" "the fallback model's own row" "D16: the swap renders the fallback model's row"
}

test_signing_wrapper_is_defined() {
  local k d
  k="$(section "## Phase 3: Kit generation")"
  d="$(section "## Appendix D: Scripts")"
  assert_contains "$k" 'gpg-loopback.sh' "F5: Phase 3 names the signing wrapper file"
  assert_contains "$d" '--pinentry-mode loopback' "F5: Appendix D carries the wrapper text"
  assert_contains "$d" '--passphrase-fd 3' "F5: the wrapper passes the passphrase on a file descriptor"
  assert_contains "$d" 'gpg.program=' "F5: Appendix D shows how git uses the wrapper"
}

test_attribution_rule_covers_names_and_pr_text() {
  local q k a dock
  q="$(section "## Phase 1: Questions")"
  k="$(section "## Phase 3: Kit generation")"
  a="$(section "## Appendix A: Rules")"
  dock="$(role_body 8)"
  assert_contains "$q" "AI-disclosure checkbox" "F6: Q4 asks about a PR-template AI checkbox"
  assert_contains "$k" "no AI tool, model or agent name" "D27: the forbidden rule names tools, models and agents"
  assert_contains "$k" "AI-disclosure checkbox" "F6: the forbidden rule carries the checkbox exception"
  assert_contains "$a" "The attribution rule covers commits, PR bodies and tracker posts." "D27: §Git scope"
  assert_contains "$dock" "PR body" "D27: Dock checks the PR body against the attribution rule"
}

test_external_text_language_is_asked() {
  local q a dock
  q="$(section "## Phase 1: Questions")"
  a="$(section "## Appendix A: Rules")"
  dock="$(role_body 8)"
  assert_contains "$q" "Language of commits, PRs and tracker posts" "F7: Q4 asks the language of external text"
  assert_contains "$a" "in English unless §Project names another language" "D24: §Git defaults external text to English"
  assert_contains "$dock" "language RULES §Git sets" "D24: Dock writes in the language the rules set"
}

test_expo_e2e_carries_the_maestro_lessons() {
  local e a probe w
  e="$(stack_field 1 E2E)"
  for w in "--test-output-dir" "takeScreenshot" "helpers/" "config.yaml" "-e NAME=value" "testID" \
    "one flow per user-facing AC" "maestri portal snapshot" "outside the repo"; do
    assert_contains "$e" "$w" "D7/D8/F9: Expo E2E has: $w"
  done
  a="$(section "## Appendix A: Rules")"
  assert_contains "$a" 'outside the repo, under $KIT/floor-snapshots/{{KEY}}/' "F9: §E2E keeps evidence outside the repo"
  probe="$(role_body 4)"
  assert_contains "$probe" "maestri portal snapshot" "D8: Probe reads the live screen before writing a scenario"
}

test_phase2_checks_the_machine() {
  local p2 k a dock
  p2="$(section "## Phase 2: Project reading")"
  k="$(section "## Phase 3: Kit generation")"
  a="$(section "## Appendix A: Rules")"
  dock="$(role_body 8)"
  assert_contains "$p2" "installed version" "D35: Phase 2 records installed tool versions"
  assert_contains "$p2" "type -a git" "D34: Phase 2 checks whether git is a function or alias"
  assert_contains "$p2" "real binary path" "D34: Phase 2 records the real git binary"
  assert_contains "$k" "Toolchain" "D35: PROJECT_PROFILE has a Toolchain section"
  assert_contains "$a" "git binary" "D34: §Git uses the recorded git binary"
  assert_contains "$dock" "git binary" "D34: Dock uses the recorded git binary"
}

test_app_environment_is_asked() {
  local p2 dev
  p2="$(section "## Phase 2: Project reading")"
  dev="$(stack_field 1 "Dev server and ports")"
  assert_contains "$p2" "app environment" "D5/F13: Phase 2 resolves the app environment floors run"
  assert_contains "$p2" "ask which" "D5/F13: Phase 2 asks instead of guessing the environment"
  assert_contains "$dev" "APP_ENV" "F13: the Expo dev server line shows the environment variable"
}

test_slot_registry() {
  local k p6 e
  k="$(section "## Phase 3: Kit generation")"
  p6="$(section "## Phase 6: First floor")"
  e="$(section "## Appendix E: Maestro operating loop")"
  assert_contains "$k" "floor-snapshots/SLOTS.tsv" "D41: Phase 3 creates the slot registry"
  assert_contains "$p6" "SLOTS.tsv" "F15: Phase 6 picks the slot from the registry"
  assert_contains "$(printf '%s\n' "$e" | sed -n '/^### E.1/,/^### E.2/p')" "SLOTS.tsv" "F15: E.1 records the slot"
  assert_contains "$(printf '%s\n' "$e" | sed -n '/^### E.7/,$p')" "SLOTS.tsv" "F15: E.7 frees the slot"
}

test_restored_duty_details() {
  local a helm onyx
  a="$(section "## Appendix A: Rules")"
  helm="$(role_body 1)"
  onyx="$(role_body 6)"
  assert_contains "$a" 'getState()' "D23: §State reads state through selectors in render, not snapshots in effects"
  assert_contains "$helm" "comments, links, attachments and the parent epic" "D25: Helm's INTAKE reads everything"
  assert_contains "$helm" '"blocked"' "D25: Helm re-checks old blocked notes against the code"
  assert_contains "$onyx" "animations and gestures" "D26: Onyx reviews animations and gestures"
}

test_cosmetic_findings() {
  local b fs g k
  b="$(section "## Appendix B: Roles")"
  fs="$(stack_field 1 "Fresh setup")"
  g="$(stack_field 1 Gates)"
  k="$(section "## Phase 3: Kit generation")"
  assert_contains "$b" '--scope current' "F16: Appendix B's role create uses --scope current"
  assert_contains "$fs" ".java-version" "F11: Expo fresh setup pins the JDK"
  assert_contains "$fs" "git status --porcelain" "F12: Expo fresh setup checks the lockfile stays unchanged"
  assert_contains "$g" 'write `none`' "F19: Expo gates say how to fill a missing build gate"
  assert_contains "$k" "the tracker's name" "F14: {{TRACKER}} is a name, not a sentence"
}

# ---- Fix round 1: slot base, signing recipe, fallback swap ---------------------------------------------------

test_slots_start_at_one() {
  local p6 e1
  p6="$(section "## Phase 6: First floor")"
  e1="$(section "## Appendix E: Maestro operating loop" | sed -n '/^### E.1/,/^### E.2/p')"
  assert_contains "$p6" "the lowest number from 1 with no row" "Phase 6 numbers slots from 1"
  assert_contains "$e1" "the lowest number from 1 with no row" "E.1 numbers slots from 1"
  assert_contains "$p6" "delete its row from" "Phase 6 frees the slot when the floor fails to open"
}

test_signing_recipe_uses_the_absolute_kit_path() {
  local k
  k="$(section "## Phase 3: Kit generation")"
  assert_contains "$k" 'agent shells have no `$KIT`' "the signing recipe renders the absolute kit path"
}

test_signing_wrapper_is_portable() {
  local d w
  d="$(section "## Appendix D: Scripts")"
  if printf '%s\n' "$d" | grep -qF '3<<<'; then _fail "the wrapper uses no here-string (temp file on old bash)"; else _pass; fi
  assert_contains "$d" "3< <(printf '%s\n' \"\${<ENV_VAR>}\")" "the wrapper feeds fd 3 from printf"
  assert_contains "$d" ': "${<ENV_VAR>:?' "the wrapper stops when the variable is unset"
  assert_contains "$d" "absolute path" "the file variant needs an absolute path"
  w="$WORK/gpg-loopback.sh"
  printf '%s\n' "$d" | awk '/^```bash$/ { f = 1; b = ""; next } /^```$/ { f = 0 } f { b = b $0 "\n" } END { printf "%s", b }' | sed 's/<ENV_VAR>/GPG_PASSPHRASE/g' > "$w"
  assert_contains "$(cat "$w")" "--pinentry-mode loopback" "the wrapper block is extracted"
  assert_exit 0 "the wrapper parses under bash -n" -- bash -n "$w"
}

test_fallback_swap_keeps_effort_and_warns() {
  local k e
  k="$(section "## Phase 3: Kit generation")"
  e="$(section "## Appendix E: Maestro operating loop")"
  assert_contains "$k" "keeps the agent's effort" "Phase 3: a cross-provider swap keeps the effort"
  assert_contains "$e" "nearest level the new CLI accepts" "E.4 maps the effort to the new CLI"
  assert_contains "$e" "WARNING: no cross-family review independence" "E.4 reports a swap that breaks independence"
}

test_q3_default_names_models() {
  local q
  q="$(section "## Phase 1: Questions")"
  assert_contains "$q" "that provider's strongest model" "the Q3 default names the ARBITER model"
  assert_contains "$q" "its best-per-cost model" "the Q3 default names the BUILDER model"
}

test_readme_q3_example_has_ranking_and_fallback() {
  local r="" p=""
  [ -f "$README" ] && r="$(cat "$README")"
  [ -f "$README_PT" ] && p="$(cat "$README_PT")"
  assert_contains "$r" "strongest overall \`claude-opus-5-5\`" "README Q3 example names the strongest overall"
  assert_contains "$r" "Claude fallback to Codex: no" "README Q3 example answers the fallback question"
  assert_contains "$p" "mais forte no geral \`claude-opus-5-5\`" "README.pt-BR Q3 example names the strongest overall"
  assert_contains "$p" "fallback do Claude para o Codex: não" "README.pt-BR Q3 example answers the fallback question"
}

# ---- Cold runs: workspace guard, missing tools, slug, area roles (task 10a) ------------------------------------

test_roles_name_their_kit() {
  local i body
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
    body="$(role_body "$i" | awk '/^```text$/ { on = 1; next } /^```$/ { on = 0 } on')"
    if printf '%s\n' "$body" | grep -qxF 'Kit: {{PROJECT_SLUG}} (maestri-squad)'; then _pass; else
      _fail "role $i prompt carries the line 'Kit: {{PROJECT_SLUG}} (maestri-squad)'"
    fi
  done
}

test_phase0_guards_the_workspace() {
  local p0
  p0="$(section "## Phase 0: Preflight")"
  for w in "maestri role list" 'Kit: <project-slug> (maestri-squad)' "Oracle" "different Maestri workspace" \
    "Never reuse them silently" '`repo`, `app`, `web`, `api`, `src`, `project`' "another \`GROUND_PATH\`"; do
    assert_contains "$p0" "$w" "Phase 0 has: $w"
  done
}

test_phase5_flags_foreign_roles() {
  local p5
  p5="$(section "## Phase 5: Workspace roles")"
  for w in 'FOREIGN: $name' 'grep -qF "Kit: $SLUG (maestri-squad)"' '[ -f "$KIT/roles/$file" ] || continue' \
    "on every run"; do
    assert_contains "$p5" "$w" "Phase 5 has: $w"
  done
}

test_missing_tools_block_floors() {
  assert_contains "$(section "## Phase 2: Project reading")" '`MISSING`' "Phase 2 marks a missing tool"
  assert_contains "$(section "## Phase 4: Owner review")" "Missing tools:" "Phase 4 shows the missing tools"
  assert_contains "$(section "## Phase 6: First floor")" "while a required tool is missing" \
    "Phase 6 opens no floor while a tool is missing"
}

test_area_specific_on_demand_roles() {
  local probe env
  assert_contains "$(section "## Phase 3: Kit generation")" "skips Loom and Prism" \
    "Phase 3 drops the UI roles for an area without UI"
  probe="$(role_body 4)"
  env="$(printf '%s\n' "$probe" | grep '^ENV+BASELINE' || true)"
  if [ -n "$env" ] && [ "$(printf '%s' "$env" | awk '{ print (index($0, "service") < index($0, "simulator")) }')" = 1 ]
  then _pass; else _fail "Probe's ENV step opens area-neutral (services before simulators)"; fi
}

test_phase3_checks_the_kit_with_a_dry_run() {
  local k d
  k="$(section "## Phase 3: Kit generation")"
  d="$(section "## Appendix D: Scripts")"
  assert_contains "$k" 'DRY_RUN=1 "$KIT/staff_floor.sh"' "Phase 3 validates the kit with a staff_floor.sh dry run"
  assert_contains "$k" "DRY_RUN OK" "Phase 3 expects the dry run's last line"
  assert_contains "$d" "DRY_RUN=1" "Appendix D documents the dry run"
  assert_contains "$d" "no maestri call" "Appendix D says the dry run calls nothing"
  assert_contains "$(cat "$README")" "DRY_RUN=1" "README documents the dry run"
  assert_contains "$(cat "$README_PT")" "DRY_RUN=1" "README.pt-BR documents the dry run"
}

test_floors_isolate_ports_and_data() {
  local a i f
  a="$(section "## Appendix A: Rules")"
  assert_contains "$a" "every host port this floor publishes" "§Floor offsets every published port"
  assert_contains "$a" "its base + " "§Floor states the one port scheme"
  assert_contains "$a" 'FLOOR_PROJECT="$(printf %s "{{PROJECT_SLUG}}-{{KEY}}"' "§Floor names the per-floor compose project"
  assert_contains "$a" "never points at the ground's database or services" "§Floor keeps floors off the ground's data"
  assert_contains "$(section "## Phase 2: Project reading")" "each container dependency" "Phase 2 lists every published port"
  assert_contains "$(section "## Phase 3: Kit generation")" "every port per slot" "RUNBOOK lists every port per slot"
  assert_contains "$(role_body 4)" "its base + {{SLOT}}" "Probe starts everything on the floor's ports"
  for i in 4 5 6; do
    f="$(stack_body "$i")"
    assert_contains "$f" "never edit the repo's compose file" "stack $i gives the compose port recipe"
    assert_contains "$f" "base + SLOT" "stack $i offsets the dependency ports"
  done
  assert_contains "$(stack_field 5 "Fresh setup")" "overrides every connection URL" \
    "the Python fresh setup keeps settings off the ground's database"
  assert_contains "$(cat "$README")" "its base + SLOT" "README states the port scheme"
  assert_contains "$(cat "$README_PT")" "sua base + SLOT" "README.pt-BR states the port scheme"
}

# rules_block: the RULES.md block of Appendix A (inside its fence).
rules_block() {
  section "## Appendix A: Rules" | awk '/^```markdown$/ { on = 1; next } /^```$/ { on = 0 } on'
}

test_every_kit_file_is_extracted() {
  local k loop kit="$WORK/x kit" vals="$WORK/vals" want got
  k="$(section "## Phase 3: Kit generation")"
  loop="$(printf '%s\n' "$k" | awk '/^```bash$/ { on = 1; b = ""; next } /^```$/ { if (on && b ~ /# file: /) { printf "%s", b; exit } on = 0 } on { b = b $0 "\n" }')"
  assert_contains "$loop" '"# file: "' "Phase 3 has one extraction loop keyed on the # file: marker"
  mkdir -p "$kit" "$vals"
  printf 'demo-app\n' > "$vals/PROJECT_SLUG"
  printf '`make lint`\n`make test`\n' > "$vals/GATES"
  printf '%s\n' "$loop" | sed -e "s|^SRC=.*|SRC=\"$MD\"|" -e "s|^VALS=.*|VALS=\"$vals\"|" > "$WORK/loop.sh"
  KIT="$kit" bash "$WORK/loop.sh" > "$WORK/loop.out" 2>&1 || _fail "the Phase 3 loop runs: $(cat "$WORK/loop.out")"
  want="RULES.md TASK_TEMPLATE.md TRACE_TEMPLATE.md gpg-loopback.sh quota_watch.sh roles/arbiter.txt roles/builder.txt roles/floor-captain.txt roles/gap-hunter.txt roles/probe.txt roles/reviewer-a.txt roles/reviewer-b.txt roles/security.txt roles/shipper.txt roles/solo-gate.txt roles/sweep.txt roles/ui-forge.txt roles/ux-lens.txt staff_floor.sh"
  got="$(cd "$kit" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' ')"
  assert_eq "$want" "${got% }" "the loop extracts every marked kit file"
  assert_exit 0 "staff_floor.sh is extracted byte for byte" -- cmp "$kit/staff_floor.sh" "$ROOT/src/scripts/staff_floor.sh"
  assert_exit 0 "quota_watch.sh is extracted byte for byte" -- cmp "$kit/quota_watch.sh" "$ROOT/src/scripts/quota_watch.sh"
  assert_exit 0 "staff_floor.sh is executable" -- test -x "$kit/staff_floor.sh"
  assert_eq "# SQUAD RULES: demo-app (binding for every agent, every floor)" "$(head -n 1 "$kit/RULES.md" 2> /dev/null)" \
    "RULES.md starts with its title, slug filled"
  assert_contains "$(cat "$kit/roles/builder.txt" 2> /dev/null)" $'`make lint`\n`make test`' "a multi-line value is filled"
  assert_eq "" "$(grep -rl '^# file: ' "$kit" || true)" "no marker line is left in a kit file"
}

test_one_floor_placeholder_syntax() {
  local r g oracle
  r="$(rules_block)"
  if printf '%s\n' "$r" | grep -qE '<(KEY|FLOOR_PATH|SLOT)>'; then
    _fail "RULES.md uses {{KEY}}, {{FLOOR_PATH}} and {{SLOT}}, never <KEY>, <FLOOR_PATH> or <SLOT>"
  else _pass; fi
  assert_contains "$r" "KIT = {{KIT_PATH}}." "RULES.md names the absolute kit path"
  if printf '%s\n' "$r" | grep -qF 'MAESTRI_SQUAD_HOME'; then _fail "RULES.md carries no env expression"; else _pass; fi
  g="$(section "## Appendix G: TASK and TRACE templates")"
  assert_contains "$g" "form fields" "Appendix G says the <...> fields are filled by Helm, not placeholders"
  oracle="$(role_body 9)"
  if printf '%s\n' "$oracle" | grep -qF '{{KEY}}'; then _fail "Oracle's prompt has no floor placeholder"; else _pass; fi
  assert_contains "$(section "## Phase 3: Kit generation")" "<(KEY|FLOOR_PATH|SLOT)>" \
    "the Phase 3 check catches the old floor-placeholder syntax"
}

test_phase3_starts_with_a_reading_list() {
  local first
  first="$(section "## Phase 3: Kit generation" | grep -v '^$' | head -n 1)"
  assert_contains "$first" "Read in full before generating" "Phase 3 opens with its reading list"
  assert_contains "$first" "Appendix A" "the reading list names Appendix A"
  assert_contains "$first" "Appendix G" "the reading list names Appendix G"
}

test_signing_reads_the_config_scope() {
  local q p2 k
  q="$(section "## Phase 1: Questions")"
  p2="$(section "## Phase 2: Project reading")"
  k="$(section "## Phase 3: Kit generation")"
  assert_contains "$q" "which key" "Q4 confirms the signing key"
  assert_contains "$p2" "git config --show-origin --get commit.gpgsign" "Phase 2 reads where signing is configured"
  assert_contains "$p2" "user.signingkey" "Phase 2 reads the signing key"
  assert_contains "$k" "git -c commit.gpgsign=false commit" "no signing overrides a config that signs"
}

test_base_branch_precedence() {
  local q p2
  q="$(section "## Phase 1: Questions")"
  p2="$(section "## Phase 2: Project reading")"
  assert_contains "$q" "Base branch and branch pattern" "Q4 asks the base branch and branch pattern"
  assert_contains "$p2" "the Q4 answer, then the contributor guide, then CI PR triggers, then \`origin/HEAD\`" \
    "Phase 2 states the base-branch precedence"
  assert_contains "$p2" "no remote is normal" "Phase 2 handles a repo without a remote"
}

test_branch_key_or_number() {
  local q k p6 a
  q="$(section "## Phase 1: Questions")"
  k="$(section "## Phase 3: Kit generation")"
  p6="$(section "## Phase 6: First floor")"
  a="$(rules_block)"
  assert_contains "$q" '`{num}`' "Q4 offers {num} for branches that use the bare number"
  assert_contains "$k" "{num}" "kit.env documents {num}"
  assert_contains "$p6" '`{num}` → its number' "Phase 6 renders {num}"
  assert_contains "$a" "{num}" "§Git explains {key} and {num}"
}

test_model_allocation_definitions() {
  local k
  k="$(section "## Phase 3: Kit generation")"
  assert_contains "$k" "quota pressure first, then price" "Phase 3 defines cheap"
  assert_contains "$k" "PLANNER and REVIEWER_A take the best coding-per-cost model" "single-provider tiering"
  assert_contains "$k" "A GATE fallback never uses the PLANNER/BUILDER family, and a REVIEWER_A fallback never uses Onyx's (GATE) family, while another family exists." \
    "the fallback independence rule matches the warning"
  assert_contains "$k" "on fallback" "the warning has an on-fallback variant"
  assert_contains "$k" "unsure a model accepts a level" "an uncertain effort level is listed as assumed"
}

test_ticket_reader_per_preset() {
  local q p2
  q="$(section "## Phase 1: Questions")"
  p2="$(section "## Phase 2: Project reading")"
  assert_contains "$q" "how each chosen preset's CLI reads a ticket" "Q4 asks how each preset's CLI reads a ticket"
  assert_contains "$p2" "the PLANNER's" "Phase 2 checks the PLANNER's CLI can read the tracker"
}

test_nextjs_pack_tuning() {
  local g e fs
  g="$(stack_field 3 Gates)"
  e="$(stack_field 3 E2E)"
  fs="$(stack_field 3 "Fresh setup")"
  assert_contains "$fs" '`.node-version`' "Next.js fresh setup pins Node from .node-version too"
  assert_contains "$fs" '`engines.node`' "Next.js fresh setup pins Node from engines"
  assert_contains "$e" "--output <evidence dir>/artifacts" "Playwright artifacts go to the evidence dir"
  assert_contains "$e" "PLAYWRIGHT_JUNIT_OUTPUT_FILE=<evidence dir>/report.xml" "the JUnit report goes to the evidence dir"
  assert_contains "$e" "PLAYWRIGHT_HTML_OUTPUT_DIR=<evidence dir>/html" "the HTML report goes to the evidence dir"
  assert_contains "$g" "(not in CI)" "a gate the repo defines but CI skips is kept and marked"
  assert_contains "$g" 'otherwise `none`' "a gate the repo lacks is none"
  assert_contains "$(stack_field 4 "Fresh setup")" '`.node-version`' "the Node pack pins Node too"
}

test_python_pack_tuning() {
  local g e fs c
  g="$(stack_field 5 Gates)"
  e="$(stack_field 5 E2E)"
  fs="$(stack_field 5 "Fresh setup")"
  c="$(stack_field 5 "Conventions worth a rule")"
  assert_contains "$g" "through the project runner" "Python gates run through uv run or poetry run"
  assert_contains "$g" "alembic check" "Alembic has a migration gate"
  assert_contains "$fs" "uv sync --locked" "uv installs with --locked"
  assert_contains "$fs" "uv python install" "uv provisions the pinned Python"
  assert_contains "$fs" "git status --porcelain <lockfile>" "the lockfile must stay unchanged"
  assert_contains "$e" "-m e2e" "DB-backed tests are told apart by a marker or a folder"
  assert_contains "$e" "git archive" "the upgrade-in-place recipe builds the base without touching the repo"
  assert_contains "$c" "alembic check" "the migration convention covers Alembic"
}

test_floor_compose_project_is_valid() {
  local r cmd i c e7
  r="$(rules_block)"
  cmd="$(printf '%s\n' "$r" | grep -o 'FLOOR_PROJECT="[^"]*"[^`]*' | head -n 1 || true)"
  assert_contains "$cmd" "tr '[:upper:].' '[:lower:]-'" "§Floor lowercases the KEY for the compose project"
  cmd="$(printf '%s\n' "$r" | grep -o '\$(printf %s "{{PROJECT_SLUG}}-{{KEY}}" | tr [^)]*)' | head -n 1 || true)"
  cmd="${cmd//\{\{PROJECT_SLUG\}\}/demo}"
  cmd="${cmd//\{\{KEY\}\}/PROJ-12.a}"
  assert_eq "demo-proj-12-a" "$(eval "printf '%s' \"$cmd\"" 2> /dev/null)" "the documented command yields a valid compose name"
  c="$(section "## Appendix C: Stacks")"
  if printf '%s\n' "$c" | grep -qE '<KEY>|<project-slug>'; then
    _fail "Appendix C uses {{KEY}} and FLOOR_PROJECT, never <KEY> or <project-slug>"
  else _pass; fi
  for i in 4 5 6 9; do
    assert_contains "$(stack_body "$i")" 'docker compose -p "$FLOOR_PROJECT"' "stack $i uses the floor compose project"
  done
  assert_contains "$(stack_body 4)" "compose.floor.yaml" "the Node pack names the override file"
  assert_contains "$(stack_body 4)" "--env-file" "the override's ports come from the floor env file"
  assert_contains "$(section "## Phase 3: Kit generation")" '| `compose.floor.yaml` |' "Phase 3 lists the override as a kit file"
  assert_contains "$(cat "$README")" "compose.floor.yaml" "README lists the override file"
  assert_contains "$(cat "$README_PT")" "compose.floor.yaml" "README.pt-BR lists the override file"
  e7="$(section "## Appendix E: Maestro operating loop" | sed -n '/^### E.7/,$p')"
  assert_contains "$e7" 'docker compose -p "$(printf %s "<project-slug>-<KEY>" | tr '"'[:upper:].' '[:lower:]-'"')" down' \
    "E.7 stops the floor's containers with the RULES §Floor project name inlined"
  assert_contains "$e7" "only on the human's go" "E.7 removes volumes only on the human's go"
}

test_foreign_ground_oracle() {
  local p0 p5
  p0="$(section "## Phase 0: Preflight")"
  p5="$(section "## Phase 5: Workspace roles")"
  assert_contains "$p0" "unless the \`Arbiter\` role carries this kit's" "Phase 0 treats an Oracle as foreign by default"
  assert_contains "$p0" "no \`Arbiter\` role counts too" "an Oracle without an Arbiter role is foreign"
  assert_contains "$p5" '--replace "Oracle"' "Phase 5 re-recruits a foreign Oracle in place"
  if printf '%s\n' "$p5" | grep -qF "checked it is this kit's"; then _fail "Phase 5 drops the false parenthetical"; else _pass; fi
}

test_fix_round_1_tidy() {
  local dev e k q a
  dev="$(stack_field 3 "Dev server and ports")"
  e="$(stack_field 3 E2E)"
  k="$(section "## Phase 3: Kit generation")"
  q="$(section "## Phase 1: Questions")"
  a="$(rules_block)"
  assert_contains "$dev" "npm run dev -- -p <PORT_BASE+SLOT>" "the Next.js dev command passes the port through npm"
  assert_contains "$e" "PLAYWRIGHT_HTML_REPORT" "the Playwright env vars are hedged for older versions"
  assert_contains "$k" '(`mktemp -d`)' "VALS is a temp folder outside the kit"
  assert_contains "$q" '`{key}` = the KEY (Phase 6 step 1)' "{key} is the floor KEY"
  if printf '%s\n' "$a" | grep -qx 'only. A new branch starts from'; then _fail "§Git has no stray short line"; else _pass; fi
}

test_floor_branches_start_from_a_defined_base_ref() {
  local p2 p3 p6 e a helm dock brief
  p2="$(section "## Phase 2: Project reading")"
  p3="$(section "## Phase 3: Kit generation")"
  p6="$(section "## Phase 6: First floor")"
  e="$(section "## Appendix E: Maestro operating loop")"
  a="$(rules_block)"
  helm="$(role_body 1)"
  dock="$(role_body 8)"
  assert_contains "$p2" '`BASE_REF`' "Phase 2 records whether the ground has a remote (BASE_REF)"
  assert_contains "$p3" 'BASE_REF=<origin/<base branch> when the ground has an origin remote, else <base branch>>' \
    "kit.env defines BASE_REF once"
  assert_contains "$p3" '`{{BASE_REF}}`' "BASE_REF is a kit-time placeholder"
  for t in "$p6" "$e"; do
    assert_contains "$t" 'git -C "$GROUND_PATH" fetch origin' "the ground fetches origin first when it has a remote"
    assert_contains "$t" 'git -C "$GROUND_PATH" branch <branch> "$BASE_REF"' "a new branch is created on the ground from BASE_REF"
    assert_contains "$t" 'maestri floor create "<KEY>" --branch <branch> --existing-branch' \
      "the floor is created on the existing branch"
  done
  assert_contains "$a" "A new branch starts from {{BASE_REF}}" "RULES §Git names the base ref"
  assert_contains "$helm" "A NEW branch starts at {{BASE_REF}}" "Helm checks the branch against the base ref"
  assert_contains "$dock" 'merge {{BASE_REF}} into the floor branch' "Dock syncs from the base ref"
  assert_contains "$dock" '`git fetch origin` (skip without a remote)' "Dock skips the fetch without a remote"
  brief="$(printf '%s\n' "$e" | grep '^KEY=<KEY>')"
  assert_contains "$brief" "NEW from <BASE_REF>" "the briefing names the base ref"
  if grep -qF 'origin/{{BASE_BRANCH}}' "$MD"; then _fail "no hardcoded origin/{{BASE_BRANCH}} remains"; else _pass; fi
}

test_readme_safety_is_honest_about_enforcement() {
  local en pt
  en="$(file_section "$README" "## Safety defaults")"
  pt="$(file_section "$README_PT" "## Padrões de segurança")"
  assert_contains "$en" "instructed rules the Maestro checks, not a sandbox" "the safety section says rules are not a sandbox"
  assert_contains "$en" "branch protection" "the safety section keeps branch protection on shared branches"
  assert_contains "$en" "permission modes in \`MODEL_MAP.tsv\`" "the safety section points at the CLIs' permission modes"
  assert_contains "$pt" "regras instruídas que o Maestro confere, não um sandbox" "pt-BR: not a sandbox"
  assert_contains "$pt" "proteção de branch" "pt-BR: branch protection"
  assert_contains "$pt" "modos de permissão no \`MODEL_MAP.tsv\`" "pt-BR: permission modes"
}

test_changelog_records_the_first_release() {
  local c w
  c="$(cat "$ROOT/CHANGELOG.md")"
  for w in "## 1.0.0 — 2026-10-13" "First public release" "### Added" "Phases 0–6" "Appendices A–G" "13 role prompts" \
    "staff_floor.sh" "DRY_RUN=1" "quota_watch.sh" "Expo / React Native (battle-tested)" "Generic Front/Mobile/Backend" \
    "examples/expo-kit" "README.pt-BR.md" "tools/check.sh" "CI on Ubuntu and macOS" \
    "Tested with Maestri 0.51.0, Claude Code 2.1.296, codex-cli 0.161.0."; do
    assert_contains "$c" "$w" "CHANGELOG 1.0.0 lists: $w"
  done
  if printf '%s\n' "$c" | grep -q unreleased; then _fail "CHANGELOG 1.0.0 is dated, not unreleased"; else _pass; fi
}

test_final_review_minors() {
  local a e p0 p5 dock b e3 e5 en pt c
  a="$(rules_block)"
  e="$(section "## Appendix E: Maestro operating loop")"
  p0="$(section "## Phase 0: Preflight")"
  p5="$(section "## Phase 5: Workspace roles")"
  dock="$(role_body 8)"
  b="$(section "## Appendix B: Roles")"
  en="$(cat "$README")"
  pt="$(cat "$README_PT")"
  # XS -> S escalation recipe
  assert_contains "$a" 'ONLY="Veto Probe Rook" $KIT/staff_floor.sh {{KEY}} S {{FLOOR_PATH}} {{SLOT}}' "§XS re-staffs as S"
  assert_contains "$a" '--role "Reviewer B"' "§XS turns Onyx into Reviewer B"
  assert_contains "$a" "--replace \"Onyx-{{KEY}}\"" "§XS replaces Onyx in place"
  assert_contains "$a" "STAFF.tsv" "§XS updates STAFF.tsv"
  assert_contains "$a" "floor card" "§XS sends the new floor cards"
  assert_contains "$en" 'ONLY="Veto Probe Rook"' "README documents the XS to S re-staff"
  assert_contains "$pt" 'ONLY="Veto Probe Rook"' "README.pt-BR documents the XS to S re-staff"
  # Aegis blocks shipping
  e5="$(printf '%s\n' "$e" | sed -n '/^### E.5/,/^### E.6/p')"
  assert_contains "$e5" "Aegis CRITICAL or HIGH" "E.5 checks open Aegis findings"
  assert_contains "$dock" "no open Aegis CRITICAL or HIGH finding" "Dock refuses to ship over an open Aegis finding"
  # on-demand recruits are watched
  assert_contains "$b" 'append its row to `floor-snapshots/<KEY>/STAFF.tsv`' "on-demand recruits join STAFF.tsv"
  assert_contains "$e" "its STAFF.tsv row" "E.1 adds the on-demand recruit's STAFF.tsv row"
  # Phase 0 keep path, Phase 5 quoting
  assert_contains "$p0" "or \`maestri list\` shows no \`Oracle\` of this kit" "keep re-recruits a missing Oracle"
  assert_contains "$p5" "--command '<the launch: line>'" "Phase 5 example uses the single quotes its text asks for"
  if printf '%s\n' "$p5" | grep -qF -- '--command "<rendered template>"'; then _fail "Phase 5 has no double-quoted example"; else _pass; fi
  # E.3 subject
  e3="$(printf '%s\n' "$e" | sed -n '/^### E.3/,/^### E.4/p')"
  assert_contains "$e3" "Messages the human types into a floor agent's terminal" "E.3: the human types owner instructions"
  # stack staleness
  c="$(section "## Appendix C: Stacks")"
  if printf '%s\n' "$c" | grep -qF '`next lint`'" or"; then _fail "Next.js lint no longer suggests next lint"; else _pass; fi
  assert_contains "$(stack_field 3 Gates)" "npx eslint ." "Next.js lints with ESLint directly"
  assert_contains "$(stack_field 5 "Fresh setup")" "poetry sync" "Poetry 2 installs with poetry sync"
  assert_contains "$(stack_field 1 "Fresh setup")" "yarn install --frozen-lockfile" "Yarn 1 uses --frozen-lockfile"
  assert_contains "$(stack_field 1 "Fresh setup")" "Yarn 2+" "Yarn Berry uses --immutable"
  # README odds and ends
  for t in "$en" "$pt"; do
    assert_contains "$t" "[\`examples/expo-kit/\`](examples/expo-kit/)" "README links the example kit"
    assert_contains "$t" "| \`examples/\` |" "README Contributing layout lists examples/"
    assert_contains "$t" "build_fresh, embedded_scripts, examples_scripts_in_sync" "README lists all six gates"
    assert_contains "$t" "TASK-seed.md" "README kit tree has TASK-seed.md"
    assert_contains "$t" "e2e/" "README kit tree has the e2e evidence dir"
  done
  if awk 'length > 120 && /Safety defaults\]\(#safety-defaults\)\)\. If/' "$README" | grep -q .; then
    _fail "README troubleshooting line is wrapped"
  else _pass; fi
}

# ---- Example kit ---------------------------------------------------------------------------------------------------
EXAMPLE="$ROOT/examples/expo-kit"

test_example_kit_is_clearly_fictional() {
  local w hits
  assert_contains "$(cat "$EXAMPLE/README.md")" "a fictional kit showing what the bootstrap generates" \
    "the example README calls the kit fictional"
  if grep -qF "on a real" "$EXAMPLE/README.md"; then _fail "the example README claims no real-app origin"; else _pass; fi
  for w in "BASE_BRANCH=main" "BASE_REF=origin/main" "BRANCH_PATTERN=feat/{num}-{slug}" 'GROUND_PATH="/path/to/my-expo-app"'; do
    assert_contains "$(cat "$EXAMPLE/kit.env")" "$w" "example kit.env has $w"
  done
  assert_exit 0 "example kit.env is valid shell" -- bash -c 'set -eu; . "$1"' _ "$EXAMPLE/kit.env"
  assert_contains "$(cat "$EXAMPLE/PROJECT_PROFILE.md")" "GitHub Issues" "the example tracks work in GitHub Issues"
  assert_contains "$(cat "$EXAMPLE/PROJECT_PROFILE.md")" "Redux Toolkit" "the example uses its own state stack"
  assert_contains "$(cat "$EXAMPLE/PROJECT_PROFILE.md")" "test/" "the example keeps tests under test/"
  for w in "__tests__" "Zustand" "TanStack" "corepack" ".ruby-version" "AI-assisted" "rm -rf node_modules ios android" \
    "codegen" "src/generated" "not in CI" "useFlag" "reportError" "feature/{key}" "MYAPP"; do
    hits="$(grep -rlF -- "$w" "$EXAMPLE" | grep -v '\.sh$' || true)"
    assert_eq "" "$hits" "the example kit no longer mentions '$w'"
  done
}

test_example_kit_passes_a_dry_run() {
  local size out rc
  for size in XS S M L; do
    rc=0
    out="$(DRY_RUN=1 KIT="$EXAMPLE" MAESTRI_CLI=false bash "$EXAMPLE/staff_floor.sh" CHECK "$size" /path/to/my-expo-app 1 2>&1)" || rc=$?
    assert_eq 0 "$rc" "the example kit passes DRY_RUN for $size"
    assert_contains "$out" "DRY_RUN OK CHECK size=$size" "the example dry run for $size ends OK"
  done
}

# ---- READMEs ----------------------------------------------------------------------------------------------------
README="$ROOT/README.md"
README_PT="$ROOT/README.pt-BR.md"
README_SECTIONS="Why|How it works|Requirements|Quick start|What Maestro will ask you|The generated kit|The squad|Task sizes|Model allocation|The pipeline|Supported stacks|Safety defaults|Updating|Troubleshooting|FAQ|Contributing|License"
RAW_URL="https://raw.githubusercontent.com/flaviorg/maestri-squad/v1.0.0/SQUAD-BOOTSTRAP.md"
QUICK_START_PROMPT="Download the bootstrap with curl -fsSL $RAW_URL -o /tmp/SQUAD-BOOTSTRAP.md, read /tmp/SQUAD-BOOTSTRAP.md in full, and follow it for this project."
LOCAL_PROMPT="Read ./SQUAD-BOOTSTRAP.md and follow it for this project."

# h2s <file>: the "## " headings of a Markdown file, outside fences (empty when the file is missing).
h2s() {
  [ -f "$1" ] || return 0
  awk '/^```/ { f = !f } !f && /^## /' "$1"
}

# file_section <file> <heading>: the lines of one "## " section of a Markdown file, heading excluded.
# The prompts sit in fences indented under list items, so callers strip leading whitespace before an exact match.
file_section() {
  [ -f "$1" ] || return 0
  awk -v h="$2" '
    !on && $0 == h { on = 1; next }
    on && /^```/ { fence = !fence }
    on && !fence && /^## / { exit }
    on { print }
  ' "$1"
}

test_readme_sections_in_order() {
  local want
  want="$(printf '%s\n' "$README_SECTIONS" | tr '|' '\n' | sed 's/^/## /')"
  assert_eq "$want" "$(h2s "$README")" "README.md has the 17 H2 sections in order"
}

test_readme_pt_br_has_the_same_sections() {
  local n
  n="$(h2s "$README_PT" | grep -c '^## ' || true)"
  assert_eq 17 "$n" "README.pt-BR.md has 17 H2 sections, like README.md"
}

test_readme_quick_start_prompt_exact() {
  local qs
  qs="$(file_section "$README" "## Quick start" | sed 's/^[[:space:]]*//')"
  if printf '%s\n' "$qs" | grep -qxF -- "$QUICK_START_PROMPT"; then _pass; else
    _fail "README Quick start has the exact URL prompt on its own line"
  fi
  if printf '%s\n' "$qs" | grep -qxF -- "$LOCAL_PROMPT"; then _pass; else
    _fail "README Quick start has the local-file prompt on its own line"
  fi
  if [ -f "$README_PT" ] && sed 's/^[[:space:]]*//' "$README_PT" | grep -qxF -- "$QUICK_START_PROMPT"; then _pass; else
    _fail "README.pt-BR.md has the exact URL prompt on its own line"
  fi
  assert_contains "$RAW_URL" "/v$(sed -n '1s/^<!-- maestri-squad v\([0-9.]*\) -->$/\1/p' "$MD")/" \
    "the quick-start download is pinned to the bootstrap's own version tag"
  assert_contains "$qs" "git clone --branch v1.0.0 https://github.com/flaviorg/maestri-squad.git" \
    "the clone recipe stays as the alternative, pinned to the same tag"
}

test_readmes_link_each_other() {
  if [ -f "$README" ] && grep -qF '](README.pt-BR.md)' "$README"; then _pass; else
    _fail "README.md links to README.pt-BR.md"
  fi
  if [ -f "$README_PT" ] && grep -qF '](README.md)' "$README_PT"; then _pass; else
    _fail "README.pt-BR.md links back to README.md"
  fi
}

test_readme_mermaid_blocks() {
  local f n
  for f in "$README" "$README_PT"; do
    n=0
    [ -f "$f" ] && n="$(grep -c '^```mermaid$' "$f" || true)"
    if [ "$n" -ge 2 ]; then _pass; else _fail "$(basename "$f") has at least 2 Mermaid blocks (got $n)"; fi
  done
}

test_readme_matches_the_product() {
  local r="" r_pt="" name s
  [ -f "$README" ] && r="$(cat "$README")"
  [ -f "$README_PT" ] && r_pt="$(cat "$README_PT")"
  for s in "Maestri 0.51.0" "Claude Code 2.1.296" "codex-cli 0.161.0" \
    "https://github.com/flaviorg/maestri-squad/actions/workflows/ci.yml/badge.svg" "img.shields.io" \
    "CODEX_PRETRUST" "quota_watch.sh" "MAESTRI_SQUAD_HOME" "KIT_VERSION" "MODEL_MAP.tsv" "tools/check.sh" \
    "tools/build.sh" "battle-tested" "starter"; do
    assert_contains "$r" "$s" "README mentions $s"
    assert_contains "$r_pt" "$s" "README.pt-BR mentions $s"
  done
  while IFS= read -r name; do
    assert_contains "$r" "$name" "README squad table names role '$name'"
  done <<EOF
$(printf '%s\n' "$ROLE_NAMES" | tr '|' '\n')
EOF
  while IFS= read -r name; do
    assert_contains "$r" "| $name |" "README stacks table lists '$name'"
    assert_contains "$r_pt" "| $name |" "README.pt-BR stacks table lists '$name'"
  done <<EOF
$(printf '%s\n' "$STACK_NAMES" | tr '|' '\n')
EOF
  while IFS= read -r s; do
    assert_contains "$r" "$s" "README states the safe default: $s"
  done <<'EOF'
Agents never merge, force-push, run `git reset --hard` or `git clean -fd`.
Only the Shipper commits.
Every external write needs the human's go through the Maestro.
Secrets are passed by file reference only.
EOF
  assert_contains "$r" 'a direct `kit.env` edit lasts only until the next update' \
    "README says a hand edit of CODEX_PRETRUST in kit.env does not survive an update"
  assert_contains "$r_pt" 'uma edição direta no `kit.env` vale só até o próximo update' \
    "README.pt-BR says a hand edit of CODEX_PRETRUST in kit.env does not survive an update"
  if printf '%s\n%s\n' "$r" "$r_pt" | grep -qiE 'generated with|co-authored-by'; then
    _fail "the READMEs carry no AI attribution line"
  else
    _pass
  fi
}

run_suite
