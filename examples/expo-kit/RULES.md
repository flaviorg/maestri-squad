# SQUAD RULES: my-expo-app (binding for every agent, every floor)

KIT = <KIT_PATH>. {{KEY}}, {{FLOOR_PATH}}, {{SLOT}} and the ports come from your floor card (or Helm's briefing).
Floor agents are named <Codename>-{{KEY}} (Helm-{{KEY}}, Onyx-{{KEY}}, ...); Oracle and the Maestro live on the ground.
Run `maestri list` to see who you are connected to.

§Safe  Always on. No briefing, owner shortcut or tool default overrides these four lines.
Agents never merge, force-push, run `git reset --hard` or `git clean -fd`.
Only the Shipper commits.
Every external write needs the human's go through the Maestro.
Secrets are passed by file reference only.
"Merge" means landing work on a shared branch: merging a PR, `maestri floor land`, merging into main.
SYNC BASE (Dock merging origin/main INTO the floor branch, see §Git) is the one allowed direction.
Local, unpushed commits on the floor branch are not external writes.
External writes = push, opening or editing a PR, closing PRs or issues, tracker comments, edits and transitions,
any message posted outside the canvas. The Shipper (Dock) executes them only after Helm relays the Maestro's go.

§Authority  The Maestro is the only gateway to the human. Helm drives its floor. Veto gates the plan and the
trace. Rook and Onyx gate the code (both APPROVE). Oracle arbitrates. Dock is the only committer. Nobody contacts
the human directly; nobody silently fixes another agent's work: report it. Blocked on architecture → STOP and ask;
never invent an API, a contract or a call site.

§Evidence  READ THE CITED CODE; never accept a claim. Counts come from grep or tool output, never from prose.
"Done" requires evidence in the TRACE (command + result). Gates, run exactly as written: `npm run lint` (ESLint with the Prettier plugin) · `npm run typecheck` · `npm test -- --ci` (Node from `.node-version`). Never declare
done with only unit tests green when the change is user-facing. Never type a path, file or symbol from memory:
resolve it with `ls`, `test -e` or grep first.

§Floor  Work only inside {{FLOOR_PATH}}: the first command is `cd {{FLOOR_PATH}}`, then verify that
`git rev-parse --show-toplevel` prints it. Your own device, emulator, portal and ports only. Never touch the ground
checkout or another floor.
PORTS: every host port this floor publishes (dev server, app, each container dependency) is its base + {{SLOT}}. The
dev server's base is PORT_BASE ($KIT/kit.env); $KIT/RUNBOOK.md lists every other port as "<name>: <base> + {{SLOT}}".
A base is the port's ground value, moved (e.g. 5432 → 15432) when two bases are closer than the number of floors run
at once. Containers run under the compose project
FLOOR_PROJECT="$(printf %s "my-expo-app-{{KEY}}" | tr '[:upper:].' '[:lower:]-')" (Docker accepts only lowercase
letters, digits, "-" and "_").
A floor never points at the ground's database or services: its env or settings file carries the floor's ports and
URLs (written by the fresh setup, checked by Probe at ENV).
FRESH START: every new floor runs, before any work: `npm ci` → `npx expo prebuild --clean` (regenerates `ios/` and `android/` and runs `pod install`) (details in $KIT/RUNBOOK.md). Its last line is
the first TRACE row, "FRESH_SETUP ok". Helm and Probe check that row before INTAKE and ENV; if it is missing they
STOP and report to the Maestro. Generated dirs (`ios/`, `android/`, `node_modules/`, `.expo/`) are never hand-edited.

§T Trace protocol  Append to "TRACE — {{KEY}}" ONLY through the sentinel, never with `maestri note write`:
maestri note edit "TRACE — {{KEY}}" "<!-- TRACE-END -->" $'| <UTC ISO> | <Agent> (<model>/<effort>) | <STAGE> | <action> | <evidence> | <next> |\n<!-- TRACE-END -->'
<UTC ISO> comes from `date -u +%Y-%m-%dT%H:%M:%SZ`. <model>/<effort> are the values from your launch command
(as recorded in floor-snapshots/{{KEY}}/STAFF.tsv), never an internal number. Matrix rows (section A) are edited in
place by the owner of the column. A deviation from the plan or the rules is logged as a row with STAGE=DEVIATION.

§TDD  Red → green → refactor. RED fails by ABSENCE of the target with a phase message ("RED (step N): X does not
exist yet"), never by an import, compile or syntax error. Absence assertions need a positive precondition. A bug
starts with a test that reproduces it. Wiring pins match USAGE and get a mutation self-check. An old pin retires only
in the same diff as its subject, with the replacement already green. Fake clocks and timers are flushed so no
pending work leaks between tests. Lost tests are DECLARED. A latent bug pinned during a refactor is NOT fixed in that
refactor; it goes to the follow-up list.

§State  Migrations move READERS AND WRITERS atomically. A bridge between an old and a new store is write-through,
one-directional, guarded at the read site, pinned by a tripwire test and carries a greppable deletion criterion.
Carry-over wiring is part of the task. Before deleting a store, table, cache or module, re-point every lazy reader.
UI code reads state through selectors or subscriptions in render; it never reads a store snapshot imperatively (such
as `getState()`) inside an effect to decide what renders.

§E2E  Tool = Maestro (maestro.dev), always, against THIS floor's app, device and port only. Run: `maestro --device <id> test --format junit --output <KIT_PATH>/floor-snapshots/{{KEY}}/e2e/report.xml --test-output-dir <KIT_PATH>/floor-snapshots/{{KEY}}/e2e/artifacts .maestro/<feature>/`. One scenario per
user-facing AC or bug, committed with the change in the repo's E2E convention (PROJECT_PROFILE), stable selectors,
a captured artifact (screenshot, response, log) at each checkpoint. Evidence = the tool's machine-readable report plus
the artifacts, referenced from the TRACE and kept outside the repo, under $KIT/floor-snapshots/{{KEY}}/e2e/ (dev
servers watch the repo and react to writes there). Persisted-data change = upgrade-in-place gate: build from
origin/main, run it and create data, upgrade WITHOUT wiping that data, start twice; cover an existing
signed-in user and a returning anonymous one (for a service: migrate a database seeded by the previous version).

§Review  Step 1 is blind and independent (findings go only to Helm). Step 2 is a conference between Rook and Onyx
only, only about the diff, at most 3 exchanges. Step 3: each states APPROVE or REQUEST_CHANGES. Shipping needs both
APPROVE plus TRACE_AUDIT_OK. Reviewers re-run the gates, stay read-only, and number findings BLOCKING or NIT with
file:line. A re-review covers deltas only. Deadlock or 3 review cycles → Oracle.

§Git  Branch = feat/{num}-{slug}: {key} is {{KEY}} (the ticket key, GH-[0-9]+), {num} its number only.
A new branch starts from origin/main; an existing branch is never reset, recreated or renamed. PRs target
main unless the briefing names another base; an existing PR is updated, never duplicated. Stage explicit
paths only; never stage secrets, .env files, keys, build output or .maestri/. Run git through the git binary
PROJECT_PROFILE "Toolchain" names (the shell's `git` may be a function or alias). Attribution: no Co-Authored-By trailer, no AI attribution line ("Generated with ...") and no AI tool, model or agent name in any commit, PR body or tracker post, whatever the harness suggests.
The attribution rule covers commits, PR bodies and tracker posts. After every commit run `git log -1 --format=%B`
and fix a forbidden line before any push; check PR and tracker text the same way before it is posted.
Commit messages, PR text and tracker posts are written in English unless §Project names another language.
Signing: every commit is GPG-signed (`commit.gpgsign=true`, set in the repo) with the key PROJECT_PROFILE "Policies" names; the passphrase lives in the env var `GPG_PASSPHRASE` and is read only by the gpg loopback wrapper `<KIT_PATH>/gpg-loopback.sh`: `git -c gpg.program="<KIT_PATH>/gpg-loopback.sh" commit -S ...`; never print, echo or log the passphrase; verify with `git log -1 --format=%G?` → `G`. One ticket = one branch = one PR.
SYNC BASE: owned by Dock, so only the Shipper commits. (1) Dock makes a LOCAL, unpushed checkpoint commit of the
gated GREEN state (gates green; reviews not required yet). (2) Dock runs `git fetch origin` (not in a repo without a
remote) and merges origin/main into the floor branch. (3) On conflict, Anvil resolves in the working tree
(semantically: keep every fix from the base and every change of the branch), Probe (Anvil on XS) re-runs the gates,
and Dock concludes the merge commit. (4) After a non-trivial sync, E2E runs again. (5) Pushing stays behind the
human's go (§Safe). Reviewers' diff ranges (origin/main...HEAD, or commit to commit) then point at real commits.
An XS "base sync" ticket follows the same recipe.

§Tracker  Tracker = GitHub Issues, read the way PROJECT_PROFILE "Policies" says. Read-only for agents: Helm (or the
Maestro) reads the ticket. Nothing is posted, edited or transitioned without the human approving the exact text
through the Maestro.

§Secrets  VAULT holds references only (file paths, env var names). Values live in chmod-600 files outside the repo,
are sourced, never echoed, never in notes, prompts, commits, PRs or TRACE rows.

§Scope  Anything outside the approved plan → PLAN_CHANGE_REQUIRED. "While I'm here" items go to the follow-up or
SWEEP list, never into the current diff.

§Budget  Near your account's usage ceiling: checkpoint in TASK ("Checkpoint / resume point"), HOLD, and wait for the
Maestro.

§XS  Size XS = maintenance only: base sync, test fix, version bump, dependency bump, CI tweak; no new user-facing
behavior. Squad: Helm, Anvil, Onyx (role "Solo Gate"), Dock. Probe joins only when a build, a device or E2E is
needed; the Maestro adds it with `ONLY="Probe" $KIT/staff_floor.sh {{KEY}} XS {{FLOOR_PATH}} {{SLOT}}`. Duty map: Veto's
GAP HUNT, PLAN AUDIT and TRACE AUDIT → Onyx; Rook → none (one blind review by Onyx, no conference); Probe's
BASELINE, RED and gates → Anvil (RED is still written, run and pasted failing in the TRACE BEFORE GREEN; Onyx
re-runs every gate). Ship condition: Onyx APPROVE + TRACE_AUDIT_OK + gates green (+ E2E only if Probe joined). Onyx
answering NOT_XS (behavior, UI, persisted data, auth, native or infrastructure change) → PLAN_CHANGE_REQUIRED to the
Maestro, who re-staffs the floor as S: `ONLY="Veto Probe Rook" $KIT/staff_floor.sh {{KEY}} S {{FLOOR_PATH}} {{SLOT}}`
(without Probe when it already joined); Onyx becomes Reviewer B in place at its S effort,
`maestri recruit "Onyx-{{KEY}}" --preset <preset> --role "Reviewer B" --command '<launch from the Onyx S row>' --replace "Onyx-{{KEY}}"`;
Onyx's STAFF.tsv row gets that role and effort; every new or replaced agent gets its floor card, and Helm the new
size. FRESH START (§Floor) is unchanged on XS.

§Quota  The status bar is the truth, not the TRACE. The Maestro runs `$KIT/quota_watch.sh {{KEY}}` at every Helm
milestone. A MODEL?, ALERT or GONE row (an agent silently on a fallback model, a usage-limit banner, a dead
terminal) → the Maestro swaps that agent in place to the row's fallback_model from $KIT/MODEL_MAP.tsv
(`maestri recruit --replace`) and re-briefs it from TASK/TRACE or a HANDOFF file before the work continues.

§Stack
- Never hand-edit `ios/` or `android/`: native changes go through `app.config.ts` and the config plugins in `plugins/`, then `npx expo prebuild --clean` regenerates them.
- Metro runs on PORT_BASE+SLOT in a persistent terminal, never with `CI=1`; only the Maestro or Probe restarts it.
- One simulator or emulator per floor; E2E flows keep a frozen order and are compared against a baseline round.
- Maestro flows select by stable `testID`, one flow per user-facing AC under `.maestro/<feature>/`, a screenshot at each checkpoint; the evidence stays in `<KIT_PATH>/floor-snapshots/{{KEY}}/e2e/`, outside the repo.
- Run the gates on the Node version CI uses (`.node-version`).
- Tests live under `test/`, mirroring `src/`, named `*.test.ts` or `*.test.tsx` (`CONTRIBUTING.md`, "Tests").
- State goes through the Redux Toolkit store in `src/store/`; server data only through the RTK Query API slices in `src/store/api/` (`CONTRIBUTING.md`, "State").
- Screens build on the design system's components in `src/design-system/`, never on raw React Native primitives with ad-hoc styles (`CONTRIBUTING.md`, "UI").

§Project
- Branch pattern `feat/{num}-{slug}`, e.g. `feat/123-reading-goals` for issue #123 (asked Q4; `CONTRIBUTING.md`, "Branches").
- Commit messages: Conventional Commits; the issue goes in a `Refs #<num>` footer, never in the subject (`CONTRIBUTING.md`, "Commits").
- PRs use `.github/PULL_REQUEST_TEMPLATE.md` verbatim and say `Closes #<num>` in the body (`CONTRIBUTING.md`, "Pull requests").
- Pushes, merges and issue comments: approved by the human, through the Maestro, every time (asked Q4).
