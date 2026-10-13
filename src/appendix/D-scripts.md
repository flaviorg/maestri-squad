## Appendix D: Scripts

Copy each script below verbatim into the kit root and make it executable. Each one reads `kit.env` and
`MODEL_MAP.tsv` from its own directory (override with `KIT=<kit root>`).

`staff_floor.sh` recruits a floor's squad on the canvas: it checks that `MODEL_MAP.tsv` has a row for every agent of
the size before recruiting anyone, recruits each agent with the launch command rendered from its row (placeholders
`{model}` `{effort}` `{name}` `{floor_path}` `{kit}`), ropes Helm to every squad member, Anvil to Probe, Rook to Onyx
and Helm to Oracle, warms every agent up and appends the squad to `floor-snapshots/<KEY>/STAFF.tsv`. Codex
pre-trust is opt-in: with `CODEX_PRETRUST=1` in `kit.env` it trusts the floor path in Codex's `config.toml` (after
a backup), copies the ground's hook-trust hash when the floor's `.codex/hooks.json` is identical, and approves
hook-review dialogs at warm-up; with the default `0` it never touches Codex's config and leaves a hook dialog for
the human. Call it as
`staff_floor.sh <KEY> <XS|S|M|L> <FLOOR_PATH> <SLOT> [LOW|MEDIUM|HIGH]`; add one agent to a running floor with
`ONLY=Probe staff_floor.sh ...`. Its last line is
`STAFFED <KEY> size=<S> squad=[...] path=<FLOOR_PATH> manifest=<file> warm_fail=<0|1>`; on `warm_fail=1`, run
`maestri check` on each agent it names as NOT CONFIRMED. With `DRY_RUN=1` it only checks the kit: the `kit.env`
fields, every row the size needs (Probe's on XS), that each `fallback_model` is the model of a complete row, and the
`*` rows of Oracle and of every on-demand role whose file is in `roles/`; it prints one `PLAN` line and the rendered
launch command per agent and ends with `DRY_RUN OK <KEY> size=<S> squad=[...]`. A dry run makes no maestri call,
edits no config and writes nothing. Phase 3 runs it for every size.

@@include src/scripts/staff_floor.sh@@

`quota_watch.sh <KEY>` is the Maestro's milestone check: for every agent in `floor-snapshots/<KEY>/STAFF.tsv` it reads
the last 8 non-blank lines of the terminal (the footer is the truth) and prints one row `AGENT STAFFED STATUS FOOTER`.
STATUS is `OK`; `MODEL?` when the footer does not show the staffed model (matched with that model's `footer_regex`
from `MODEL_MAP.tsv`; a model missing from the map is always `MODEL?`); `ALERT` on a system usage-limit phrase in the
footer; or `GONE` when `maestri check` fails. It exits 1 if any row is not `OK`, then apply the row's `fallback_model`
from `MODEL_MAP.tsv`.

@@include src/scripts/quota_watch.sh@@

`gpg-loopback.sh` comes out of the Phase 3 extraction loop with the other kit files; keep it (chmod 700, outside every
repo) only when commits are signed with a passphrase. Replace `<ENV_VAR>` with the variable Q4 named; for a passphrase
file, replace the process substitution with `3< "<file>"`, where `<file>` is an absolute path (a `~` inside quotes
never expands). Dock signs through it with `git -c gpg.program="<absolute kit path>/gpg-loopback.sh" commit -S ...`
and checks that `git log -1 --format=%G?` prints `G`. The wrapper runs on bash 3.2 and writes no temp file (`printf`
is a builtin, so the passphrase never shows in a process list); it is never printed, echoed or logged.

```bash
# file: gpg-loopback.sh
#!/usr/bin/env bash
# gpg loopback wrapper: hands the passphrase to gpg on fd 3; never prints it.
: "${<ENV_VAR>:?<ENV_VAR> is not set}"
exec gpg --batch --pinentry-mode loopback --passphrase-fd 3 "$@" 3< <(printf '%s\n' "${<ENV_VAR>}")
```
