## Phase 2: Project reading

Read the repo (read-only) and record every finding in your draft of `PROJECT_PROFILE.md` with its evidence as
`file:line` (or the command and its output). Start from the matching Appendix C section; the repo overrides it.

Read:
- the manifest (`package.json`, `pubspec.yaml`, `go.mod`, `pyproject.toml`, ...), the lockfile and package manager,
  and the runtime pins (`.nvmrc`, `.tool-versions`, `.ruby-version`, ...);
- the CI workflows (the commands CI really runs are the strongest evidence for the gates);
- `CLAUDE.md` / `AGENTS.md`, any contributor guide, and the PR template;
- the base branch, by precedence: the Q4 answer, then the contributor guide, then CI PR triggers, then `origin/HEAD`
  (ask when two disagree; no remote is normal: confirm the current branch); the branch naming in `git branch -a`;
- signing: `git config --show-origin --get commit.gpgsign` (and `user.signingkey`): set by the repo or globally;
- per chosen preset, whether its CLI reaches the tracker (its MCP servers, `gh auth status`); the PLANNER's must,
  or the Maestro pastes each ticket into the briefing;
- the machine, for the profile's Toolchain section: every tool the gates, fresh setup, E2E and shipping call
  (runtime, package manager, each gate tool, E2E CLI, `gh auth status`, signing, `git-lfs`, ...), each recorded as
  its installed version or `MISSING` with an install hint; and `type -a git`: if the shell's `git` is a function or
  alias, record the real binary path (e.g. `/usr/bin/git`) for the kit to use.

Resolve, each with evidence:

| Profile field | Feeds |
|---|---|
| gate commands: lint, typecheck, test, format check, build (`none` when the repo has no such gate) | `{{GATES}}` |
| E2E tool already in use, how it runs per floor | `{{E2E_TOOL}}`, `{{E2E_RUN}}` |
| generated directories that must never be hand-edited | `{{GENERATED_DIRS}}` |
| fresh-setup recipe for a new floor | `{{FRESH_SETUP}}`, `RUNBOOK.md` |
| every host port a floor publishes: the dev server (→ `PORT_BASE`) and each container dependency (compose `ports:`), each with its base (RULES §Floor); settings that default to the ground's services | `kit.env`, `RUNBOOK.md` |
| the app environment floors build and serve, when the app has several (env var, scheme, app id): ask which | `RUNBOOK.md`, `{{E2E_RUN}}` |
| base branch, and whether `git remote` lists `origin` (it sets `BASE_REF`); branch pattern with `{key}` or `{num}` and an optional `{slug}` (e.g. `feature/{key}-{slug}` or `feature/{key}`) | `{{BASE_BRANCH}}`, `{{BASE_REF}}`, `{{BRANCH_PATTERN}}` |
| stack conventions worth a rule: the Appendix C list adapted to the repo, plus the repo's own documented conventions | `{{STACK_RULES}}` |
| tracker, ticket pattern, signing, attribution, approvals, text language (Q4, checked against the repo) | `{{TRACKER}}`, `{{TICKET_PATTERN}}`, `{{SIGNING_RECIPE}}`, `{{ATTRIBUTION_RULE}}`, `§Project` |

An item you cannot resolve becomes an explicit question to the user (one at a time, as in Phase 1), never a guess.
A Q1-Q4 answer the repo contradicts is asked again, showing the evidence. A value taken from Appendix C that the
repo neither confirms nor contradicts is recorded as `assumed` and listed in Phase 4.
