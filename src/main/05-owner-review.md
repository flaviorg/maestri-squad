## Phase 4: Owner review

Show the user a one-screen summary, in their language, and wait for an explicit OK ("OK", "yes, go ahead").
Silence, a question or a partial answer is not an OK. Apply every correction to the kit files, then show the summary
again; repeat until the OK. On a kit update (Phase 0), mark what changed since the old kit.

```text
SQUAD KIT — <project-slug> (v1.0.0) at <$KIT>
Stack: <area> / <stack> (<battle-tested | starter>) · package manager <pm> · base <BASE_BRANCH> · branches <BRANCH_PATTERN>
Gates: <lint> · <typecheck> · <test> · <format check> · <build>
E2E: <tool> — <how it runs per floor> · ports per slot n: dev server <PORT_BASE> + n, <name> <base> + n, ... · app env <env | single>
Toolchain: <tool and installed version, each> · git binary <path>
Missing tools: <each MISSING tool with its install hint, or "none"; no floor opens while one is missing>
Generated dirs (never hand-edited): <list>
Fresh setup: <one line per step, short>
Models (role → preset model/effort):
  XS: Helm <..> · Anvil <..> · Onyx (Solo Gate) <..> · Dock <..> · Probe on demand <..>
  S:  Helm <..> · Veto <..> · Anvil <..> · Probe <..> · Rook <..> · Onyx <..> · Dock <..>
  M:  <same layout>          L: <same layout>
  On demand: Oracle <..> · Aegis <..> · Loom <..> · Prism <..> · Broom <..>
WARNING: no cross-family review independence. <rest of the Phase 3 warning, verbatim; this line only when it applies>
Policies: tracker <..> (<key pattern>) · signing <..> · AI attribution <allowed | forbidden> · pushes, merges and
  tracker writes approved by <the human, through the Maestro> · text in <English | ..> · CODEX_PRETRUST=<0|1>
Assumed (not confirmed by the repo or by you): <each item, or "nothing">
Next: create the workspace roles (Phase 5), then open the first floor (Phase 6).
```

Only an explicit OK moves you to Phase 5.
