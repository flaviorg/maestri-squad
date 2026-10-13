# Example kit: Expo / React Native

This is a fictional kit showing what the bootstrap generates: the squad kit of `my-expo-app`, an invented
reading-list app built with Expo / React Native, as a Maestro would write it to
`${MAESTRI_SQUAD_HOME:-$HOME/.maestri-squad}/<project-slug>/` after the owner review (Phases 0 to 4 of
`SQUAD-BOOTSTRAP.md` v1.0.0).

Do not use it as-is. Hand `SQUAD-BOOTSTRAP.md` to your own Maestro and let it generate a kit from your repository.

- **Generic text is unchanged:**
  - the rules core, the role prompts and the TASK and TRACE templates are the bootstrap's own text, written by the
    Phase 3 extraction loop with the kit-time placeholders filled; each role prompt opens with
    `Kit: my-expo-app (maestri-squad)`, which ties the workspace roles to this kit;
  - `staff_floor.sh` and `quota_watch.sh` are byte-for-byte copies of the scripts embedded in `SQUAD-BOOTSTRAP.md`
    (`tools/check.sh` gate `examples_scripts_in_sync`).
- **`/path/to/my-expo-app` and `<KIT_PATH>`** stand for the absolute ground checkout and kit paths, written out in a
  real kit (agent shells have no `$KIT` and no `MAESTRI_SQUAD_HOME`, so `RULES.md`, `RUNBOOK.md` and the signing
  recipe carry the absolute kit path). `{{KEY}}`, `{{FLOOR_PATH}}` and `{{SLOT}}` stay literal: each agent reads them from its floor
  card.
- **Project values are illustrative:** stack choices, helpers, paths, commands, policies and models. The cited files
  exist in no real repository.
- **`floor-snapshots/`** holds only `SLOTS.tsv`, the slot registry (its header line), until the first floor.

| File | What it is |
|---|---|
| `KIT_VERSION`, `kit.env` | kit version, slug, ground path, base branch and base ref, branch pattern, port base, Codex pre-trust switch |
| `PROJECT_PROFILE.md` | the answers from Phase 1 and the evidence from Phase 2 |
| `RULES.md` | the Appendix A rules, with the stack and project sections filled in |
| `RUNBOOK.md` | fresh setup, ports and dev server per slot, device builds, E2E run, device notes, signing |
| `MODEL_MAP.tsv` | each role and size mapped to a preset, model, effort, launch template, footer regex and fallback |
| `roles/*.txt` | the 13 role prompts, each with a paragraph about the project |
| `TASK_TEMPLATE.md`, `TRACE_TEMPLATE.md` | templates for the floor notes |
| `staff_floor.sh`, `quota_watch.sh` | staffs a floor (`DRY_RUN=1` only checks the kit and prints the plan) and runs the quota watch |
| `gpg-loopback.sh` | the signing wrapper from Appendix D, with `GPG_PASSPHRASE` filled in |
| `floor-snapshots/SLOTS.tsv` | which open floor holds which slot, port and device |
