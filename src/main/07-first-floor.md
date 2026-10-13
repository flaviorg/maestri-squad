## Phase 6: First floor

First re-check every tool the Phase 4 "Missing tools" line named: while a required tool is missing, open no floor
and tell the user what to install. Ask the user for the first task: a ticket URL, an issue, or free text. Read a
ticket yourself, read-only, the way `PROJECT_PROFILE.md` says (Q4). Then:

1. **Key.** `<KEY>` uses only `[A-Za-z0-9._-]` and does not start with `.` (`staff_floor.sh` refuses anything
   else). It is the ticket key (it matches `TICKET_PATTERN`); a GitHub issue number is prefixed, `#123` → `GH-123`;
   free text gets a short upper-case kebab name (`FIX-LOGIN-TIMEOUT`). For free text, save the request verbatim to
   `$KIT/floor-snapshots/<KEY>/TASK-seed.md`.
2. **Size, with a stated reason.** Tell the user the size and why, in one or two sentences, and accept a correction:
   - XS only for maintenance as defined in Appendix A §XS (base sync, test fix, version or dependency bump, CI tweak;
     no new user-facing behavior);
   - a ticket that touches one of the stack's Risk triggers (Appendix C) is never XS and weighs toward M or L; for
     auth, secrets, payments or data exposure, also plan to call Aegis;
   - otherwise S for a small change in one area, M for a change across several modules or with persisted data, L for
     a cross-cutting change or several risk triggers.
   Also state the risk (LOW, MEDIUM or HIGH), pick `<SLOT>` (the lowest number from 1 with no row in
   `$KIT/floor-snapshots/SLOTS.tsv`; 0 is the ground's port; port = `PORT_BASE + <SLOT>`) and record it (E.1 step 1).
3. **Branch.** Render `BRANCH_PATTERN` from `kit.env`: `{key}` → `<KEY>`; `{num}` → its number (`GH-123` → `123`);
   `{slug}`, when the pattern has one, → a short lower-kebab summary of the task.
4. **Floor.** Run `maestri floor list`; if no floor `<KEY>` exists, make the branch on the ground first (source
   `$KIT/kit.env`). When `BASE_REF` starts with `origin/`, run `git -C "$GROUND_PATH" fetch origin`. A new branch:
   `git -C "$GROUND_PATH" branch <branch> "$BASE_REF"`; an existing one is never reset (one only on the remote:
   `git -C "$GROUND_PATH" branch <branch> origin/<branch>`). Then run
   `maestri floor create "<KEY>" --branch <branch> --existing-branch`. It may time out yet complete: run
   `maestri floor list` before repeating anything (Appendix F). `<FLOOR_PATH>` is the absolute path `maestri floor list` shows: expand a leading `~`
   to `$HOME` (quoted launch paths never expand it), then check `test -d "<FLOOR_PATH>"` before going on.
5. **Fresh setup.** Run the fresh-setup recipe from `$KIT/RUNBOOK.md` inside `<FLOOR_PATH>`, logging to
   `$KIT/floor-snapshots/<KEY>/fresh-setup.log`. Its last line becomes the first TRACE row, `FRESH_SETUP ok`. If this
   or the floor create fails, stop: show the user the log tail and delete its row from `SLOTS.tsv`.
6. **Staff.** Run `$KIT/staff_floor.sh <KEY> <SIZE> <FLOOR_PATH> <SLOT> <RISK>` and read its last line, `STAFFED ...`.
   On `warm_fail=1`, run `maestri check` on each agent it names and clear what the terminal shows (Appendix F) first.
7. **Card and briefing.** Send every squad member its FLOOR CARD in one `maestri ask --batch` call, then Helm its
   FLOOR BRIEFING (Appendix E.2); on BOOT_OK connect the notes, send `GO`, post the floor status (Appendix E.1 5–8).

Tell the user the floor is staffed (key, size and reason, branch, floor path, squad from `floor-snapshots/<KEY>/STAFF.tsv`).
From here on, follow the operating loop in Appendix E: milestone relays, quota watch, review and TRACE gates, close.
