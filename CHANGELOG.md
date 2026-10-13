# Changelog

## 1.0.0 — 2026-10-13

First public release.

### Added

- `SQUAD-BOOTSTRAP.md`, the single file you hand to your Maestro:
  - Phases 0–6: preflight, questions, project reading, kit generation, owner review, workspace roles, first floor;
  - Appendices A–G: rules, 13 role prompts, stacks, scripts, operating loop, lessons, TASK and TRACE templates.
- `staff_floor.sh`: staffs a floor from `MODEL_MAP.tsv`, validates every row before recruiting anyone, has a
  `DRY_RUN=1` check, and pre-trusts Codex only on opt-in (`CODEX_PRETRUST=1`).
- `quota_watch.sh`: checks that each agent still runs its expected model and flags quota alerts.
- Stacks: Expo / React Native (battle-tested); Flutter, React / Next.js, Node, Python and Go (starter);
  Generic Front/Mobile/Backend.
- `examples/expo-kit`: a fictional kit showing what the bootstrap generates.
- `README.md` and `README.pt-BR.md`.
- `tools/check.sh` gates: sanitize, shellcheck, tests, build_fresh, embedded_scripts, examples_scripts_in_sync.
- CI on Ubuntu and macOS.

Tested with Maestri 0.51.0, Claude Code 2.1.296, codex-cli 0.161.0.
