## Phase 0: Preflight

You are the Maestro. Run these checks from the ground terminal, in the project's checkout, before asking anything.

1. Run `maestri list` and `maestri preset list`. If either fails, stop and tell the user: "Maestri in Maestro Mode is
   required. Open this project as a Maestri workspace, make this terminal the Maestro, and hand me this file again."
   Keep the preset list: it seeds Q3. If a command in this file is rejected later, read `maestri <command> --help`
   (this file was tested with the Maestri version in its header) and adapt the flags, never the intent.
2. Resolve the project:
   - `GROUND_PATH` = `git rev-parse --show-toplevel` (not a git repository → stop and say so);
   - `<project-slug>` = the repo directory name in lower-kebab:
     `basename "$GROUND_PATH" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'`;
   - `$KIT` = `${MAESTRI_SQUAD_HOME:-$HOME/.maestri-squad}/<project-slug>`. The path must not contain `"`, `\`, `$`
     or a backtick (`staff_floor.sh` refuses it); otherwise ask the user for a `MAESTRI_SQUAD_HOME` without them.
   - Show the user the slug. When it is generic (`repo`, `app`, `web`, `api`, `src`, `project`) or `$KIT/kit.env`
     names another `GROUND_PATH` (another project's kit), ask for a better one (offer the manifest's project name).
3. Check the workspace: run `maestri role list`; every Appendix B role name it shows must carry the line
   `Kit: <project-slug> (maestri-squad)` in `maestri role show "<name>"`. A role with another `Kit:` line or none
   belongs to another project, and so does an `Oracle` on the canvas unless the `Arbiter` role carries this kit's
   line (no `Arbiter` role counts too): stop and ask the user to replace them in this workspace (Phase 5 does it) or
   to use a different Maestri workspace for this repo (recommended). Never reuse them silently.
4. Look for an existing kit at `$KIT` (none: go to Phase 1).
   - One exists: compare `$KIT/KIT_VERSION` with this file's version (first line, `maestri-squad v1.0.0` → `1.0.0`),
     tell the user both, and offer three choices:
     - **update**: regenerate every kit file from this file (Phase 3), keeping the answers and evidence in
       `PROJECT_PROFILE.md` and everything under `floor-snapshots/`; Phase 1 asks only what the profile lacks, and
       Phase 4 shows what changed;
     - **keep**: use the kit as it is; run Phase 5 only if a workspace role is missing
       or `maestri list` shows no `Oracle` of this kit (Phase 5 recruits it), then go to Phase 6;
     - **start over**: move the old kit aside to `$KIT.bak-<YYYYMMDD>` (never delete it), then go to Phase 1.
5. Nothing is written inside the project repository during Phases 0 to 5. The kit lives in `$KIT` only.
