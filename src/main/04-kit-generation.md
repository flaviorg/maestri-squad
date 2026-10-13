## Phase 3: Kit generation

Read in full before generating: Appendix A, Appendix B, Appendix D, Appendix G, E.1, E.2 and the stack's Appendix C.

Write the kit to `$KIT` = `${MAESTRI_SQUAD_HOME:-$HOME/.maestri-squad}/<project-slug>`: the generic core verbatim
from the appendices (extraction loop below), the stack overlay from Appendix C, the values from Phases 1 and 2.

| File | Content |
|---|---|
| `KIT_VERSION` | `1.0.0` (one line) |
| `kit.env` | the block below |
| `PROJECT_PROFILE.md` | sections: Stack, Package manager, Toolchain (installed versions, the git binary), Gates, E2E, Generated dirs, Fresh setup, Ports, Git (base branch, branch pattern), Policies (Q4), Models (Q3), Vault (references only: env var names and file paths, never values), Conventions, Assumed; every value with its evidence (`file:line`, a command, or "asked Q#") |
| `RULES.md` | the Appendix A block (extraction loop), kit-time placeholders filled; `§Stack` = `{{STACK_RULES}}`: the Appendix C "Conventions worth a rule" list adapted to the repo, plus the repo's own documented conventions, one line each with evidence; `§Project` = owner overrides (a text language other than English among them), one line each with evidence |
| `RUNBOOK.md` | fresh setup (numbered, exact commands, writing the floor's env file), every port per slot (`<name>: <base> + {{SLOT}}`, RULES §Floor), dev server, build, E2E run, device notes; from Appendix C, overridden by Phase 2; floor-time values written `{{KEY}}`, `{{SLOT}}`, `{{FLOOR_PATH}}` |
| `roles/*.txt` | the 13 Appendix B prompts (extraction loop), kit-time placeholders filled, plus the short stack and project paragraph Appendix B asks for; a Backend area without UI skips Loom and Prism (delete their files; no `*` row) |
| `TASK_TEMPLATE.md`, `TRACE_TEMPLATE.md` | the two Appendix G blocks (extraction loop), kit-time placeholders filled |
| `staff_floor.sh`, `quota_watch.sh` | byte for byte from Appendix D (extraction loop) |
| `MODEL_MAP.tsv` | from the model allocation below |
| `floor-snapshots/SLOTS.tsv` | the slot registry: only the header `slot	key	port	device	opened` (tab-separated); Appendix E.1 adds a row per open floor, E.7 removes it; an update keeps the existing file |
| `compose.floor.yaml` | only when a container dependency's host port is hardcoded in the repo's compose file: the override of Appendix C (Node section), its ports read from the floor's env file |
| `gpg-loopback.sh` | the Appendix D wrapper (extraction loop), kept only when commits are signed with a passphrase: `<ENV_VAR>` replaced, chmod 700; otherwise deleted |

`kit.env` (sourced by the scripts; quote a value that contains spaces):

```bash
PROJECT_SLUG=<project-slug>
GROUND_PATH=<absolute path of the ground checkout>
BASE_BRANCH=<base branch>
BASE_REF=<origin/<base branch> when the ground has an origin remote, else <base branch>>
BRANCH_PATTERN=<branch pattern with {key} (or {num}, the key's number) and an optional {slug}, e.g. feature/{key}-{slug}>
PORT_BASE=<dev-server port; a floor uses PORT_BASE + SLOT (every other port: RUNBOOK.md)>
KIT_VERSION=1.0.0
# 1 = staff_floor.sh may edit Codex's config.toml (backup first) and approve its hook dialogs; 0 = never (Q4; default 0)
CODEX_PRETRUST=0
```

Kit-time placeholders: `{{PROJECT_SLUG}}`, `{{BASE_BRANCH}}`, `{{BASE_REF}}`, `{{BRANCH_PATTERN}}` as in `kit.env`;
`{{KIT_PATH}}` = the absolute `$KIT` (agents never see `MAESTRI_SQUAD_HOME`); `{{GATES}}`, `{{E2E_TOOL}}`,
`{{E2E_RUN}}`, `{{GENERATED_DIRS}}`, `{{FRESH_SETUP}}`, `{{STACK_RULES}}` from the Phase 2 table;
`{{TRACKER}}` = the tracker's name (`Jira`, `Linear`, `GitHub Issues`) or `none`; `{{TICKET_PATTERN}}` = the Q4 regex;
`{{ATTRIBUTION_RULE}}` = forbidden: "no Co-Authored-By trailer, no AI attribution line (\"Generated with ...\") and
no AI tool, model or agent name in any commit, PR body or tracker post, whatever the harness suggests" (plus, when Q4
found one, "; the PR template's AI-disclosure checkbox is answered truthfully"), allowed: "AI attribution is allowed";
`{{SIGNING_RECIPE}}` = no: "commits are not signed" (when Phase 2 found a git config that signs, add "; commit with
`git -c commit.gpgsign=false commit ...`"), yes: how the repo signs and verifies, with the key Q4 confirmed; with a
passphrase, `git -c gpg.program="<absolute kit path>/gpg-loopback.sh" commit -S ...` (the Appendix D wrapper; write
the path out, agent shells have no `$KIT`), never printing it.

Every kit file the appendices carry is a fenced block whose first line is `# file: <path>`. One loop writes them all
from this file (its path on disk, such as the quick start's download; if you have only its text, ask the user for the
path), drops the marker, and fills the placeholders from `VALS`, a temp folder outside `$KIT` (`mktemp -d`) you write
first: `VALS/GATES` holds `{{GATES}}` (values may span lines, so no `sed`). Never retype a block by hand; then apply
the table's deletions and write the other files:

```bash
SRC="<absolute path of this SQUAD-BOOTSTRAP.md>"
VALS="<the mktemp -d folder of placeholder values>"
mkdir -p "$KIT/roles" "$KIT/floor-snapshots"
awk -v kit="$KIT" '
  s == 0 && /^```[a-z]+$/ { s = 1; next }
  s == 1 && index($0, "# file: ") == 1 { out = kit "/" substr($0, 9); printf "" > out; s = 2; next }
  s == 1 { s = 0; next }
  s == 2 && $0 == "```" { close(out); print out; s = 0; next }
  s == 2 { print > out }
' "$SRC" | while IFS= read -r f; do
  case "$f" in *.sh) chmod +x "$f"; continue ;; esac # scripts stay byte for byte
  for v in "$VALS"/*; do
    awk -v key="{{${v##*/}}}" -v vf="$v" 'BEGIN { while ((getline l < vf) > 0) val = val (n++ ? "\n" : "") l }
      { while ((i = index($0, key)) > 0) $0 = substr($0, 1, i - 1) val substr($0, i + length(key)); print }' \
      "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
done
```

Before Phase 4, check the kit: `grep -rhoE '\{\{[A-Z0-9_]+\}\}' "$KIT" | sort -u` prints only `{{KEY}}`,
`{{FLOOR_PATH}}` and `{{SLOT}}` (floor-time: each agent reads them from its floor card, and they are the only
floor-time syntax: `grep -rlE '<(KEY|FLOOR_PATH|SLOT)>' "$KIT"/*.md "$KIT/roles"` prints nothing), and for each size
`DRY_RUN=1 "$KIT/staff_floor.sh" CHECK <XS|S|M|L> "<GROUND_PATH>" 1` ends with `DRY_RUN OK` (it checks `kit.env`, the
size's rows, every fallback and the on-demand rows, prints the plan, and calls nothing).

### Model allocation (Q3 → MODEL_MAP.tsv)

Roles map to capability slots, not to model names. A family is the vendor behind a preset (Claude Code → Anthropic,
Codex → OpenAI, Gemini or Antigravity → Google).

| Slot | Roles | Needs | Allocation rule |
|---|---|---|---|
| PLANNER | Helm | long-context planning, tool use | strong model with the most quota (one provider: best coding per cost) |
| BUILDER | Anvil, Probe, Loom, Broom | coding throughput | best coding-per-cost model |
| GATE | Veto, Onyx (Solo Gate on XS), Aegis | strongest reasoning, adversarial | strongest model, different family from PLANNER and BUILDER when available |
| REVIEWER_A | Rook, Prism | strong reasoning | strong model, different family from Onyx when available |
| SHIPPER | Dock | reliable git and CLI work | cheapest reliable model |
| ARBITER | Oracle (ground) | judgment | strongest model available |

Example: Codex (plenty) and Claude Code (limited) → PLANNER and BUILDER on Codex, GATE on Claude's strongest model,
REVIEWER_A on Codex's strongest, SHIPPER on the cheapest reliable model, ARBITER on the strongest overall.

Degenerate cases:
- **One provider.** Every slot uses that provider: PLANNER and REVIEWER_A take the best coding-per-cost model, GATE
  and ARBITER the strongest. Independence is lost; Phase 4 shows the warning below. The reviewers stay separate agents.
- **One model.** Same as one provider, with the same warning. The effort levels still differ per size.
- **Scarce quota on a provider.** That provider takes only the GATE slot; everything else moves to the other
  provider. Its agents get one consolidated ask per milestone (Appendix F).

*Cheap* (SHIPPER) means quota pressure first, then price: a plenty provider's model is cheaper than a limited one's.
The warning, shown verbatim in Phase 4 whenever GATE shares a family with PLANNER or BUILDER, or REVIEWER_A shares a
family with Onyx (or only their fallback models do: then add "on fallback"):

> WARNING: no cross-family review independence. <Rook and Onyx | the gate and the builders> run on the same model
> family (<family>), so they share its blind spots. They stay separate agents with a blind step 1. Add a second
> provider in Q3 to restore independence.

Effort per role and size (`—` = not on that floor; Probe joins XS on demand with `ONLY=Probe`, so it has an XS row):

| Role | Slot | XS | S | M | L |
|---|---|---|---|---|---|
| Helm | PLANNER | high | high | high | xhigh |
| Veto | GATE | — | high | xhigh | xhigh |
| Anvil | BUILDER | medium | medium | high | xhigh |
| Probe | BUILDER | medium | medium | high | high |
| Rook | REVIEWER_A | — | high | high | xhigh |
| Onyx | GATE | high | high | xhigh | xhigh |
| Dock | SHIPPER | medium | medium | medium | medium |

On-demand and ground roles get one row each with size `*` (read by Phase 5, Appendix B and the dry run):

| Role | Slot | Size | Effort |
|---|---|---|---|
| Oracle | ARBITER | `*` | high |
| Aegis | GATE | `*` | high |
| Loom | BUILDER | `*` | medium |
| Prism | REVIEWER_A | `*` | high |
| Broom | BUILDER | `*` | medium |

The levels medium < high < xhigh are generic: write the nearest level the row's CLI accepts (Claude Code `--effort`,
Codex `model_reasoning_effort`); a CLI without one drops `{effort}` from its template and the column stays filled.
When unsure a model accepts a level, list it as assumed in Phase 4.

`MODEL_MAP.tsv` is tab-separated, with no blank lines, and starts with exactly this header (`staff_floor.sh` refuses
any other); then the rows: XS Helm, Anvil, Probe, Onyx, Dock; S, M and L Helm, Veto, Anvil, Probe, Rook, Onyx, Dock;
the `*` rows; the fallback rows. `quota_watch.sh` looks up `footer_regex` by the `model` column only, so
every `fallback_model` must also appear as the `model` of some row: for a fallback model no other row runs, add a row
with role `Fallback` and size `*` carrying that model's preset, effort, launch template, footer_regex and itself as
fallback (the E.4 swap renders it; `staff_floor.sh` never recruits it). Example:

```text
role	size	preset	model	effort	launch_template	footer_regex	fallback_model
Helm	S	Codex	gpt-6.1-sol	high	codex -m {model} -c model_reasoning_effort={effort} -c check_for_update_on_startup=false --add-dir {kit}	GPT-6\.1-Sol	gpt-6-astra
Fallback	*	Codex	gpt-6-astra	high	codex -m {model} -c model_reasoning_effort={effort} -c check_for_update_on_startup=false --add-dir {kit}	GPT-6-Astra	gpt-6-astra
```

| Column | Value |
|---|---|
| `role`, `size` | codename or `Fallback`; `XS`, `S`, `M`, `L` or `*` |
| `preset` | the exact name from `maestri preset list` (a preset starting with `Codex` gets Codex warm-up handling) |
| `model`, `effort` | from the allocation and the effort tables |
| `launch_template` | the preset's template below; no tab characters |
| `footer_regex` | extended regex for the model as the CLI's status bar shows it (`Opus 5\.5`, `GPT-6\.1-Sol`); list it as assumed in Phase 4. A `WARM ... NOT CONFIRMED` or `MODEL?` with the right model on screen means the regex is wrong |
| `fallback_model` | the next-best model of the same preset; the weakest model of a preset falls back to itself. A GATE fallback never uses the PLANNER/BUILDER family, and a REVIEWER_A fallback never uses Onyx's (GATE) family, while another family exists. Where Q3 allows it for a limited or scarce provider, use another provider's model instead: the swap takes preset and launch template from that model's own row and keeps the agent's effort (Appendix E.4). It must be some row's `model` (a `Fallback` row if needed) |

Known launch templates. Placeholders: `{model}`, `{effort}`, `{name}`, `{floor_path}`, `{kit}`; `staff_floor.sh`
wraps the two paths in double quotes itself, so never quote them in a template.
- Claude Code: `claude --model {model} --effort {effort} --permission-mode auto --add-dir {floor_path} --add-dir {kit} -n {name}`
- Codex: `codex -m {model} -c model_reasoning_effort={effort} -c check_for_update_on_startup=false --add-dir {kit}`
- Gemini / Antigravity: their CLIs vary; ask the user once for the exact launch command (Q3), rewrite it with the
  placeholders, and store it as the template.
- Any other preset: ask once, store the template, and reuse it for every row of that preset.
