## Phase 1: Questions

Ask one question at a time, in the user's language, with the detected default pre-filled ("I found X; is that
right?"). Detect before you ask: a quick look at the manifests and `git` settings fills most defaults; Phase 2 then
verifies every answer with evidence. Record each answer in your working notes for `PROJECT_PROFILE.md`.

| # | Question | Answer form | Default |
|---|---|---|---|
| Q1 | Area | Front / Mobile / Backend | detected from manifests |
| Q2 | Stack | the Appendix C stacks of that area plus "Other" (→ the Generic section of the area) | detected (Appendix C detection hints) |
| Q3 | Available agents and models | multi-select from `maestri preset list`; then the model names per chosen preset; then a quota note per provider: plenty / limited / scarce | every preset found |
| Q4 | Team policies | see the list below | read from the repo where possible |

Q3 in detail:
- Offer the presets `maestri preset list` printed (skip `Shell`); the user picks one or more.
- For each chosen preset, ask which models it may run, strongest first (for example `claude-opus-5-5`,
  `claude-sonnet-5-5` for Claude Code; `gpt-6.1-sol`, `gpt-6-astra` for Codex). Use the exact names the CLI accepts.
- For each provider (vendor behind the presets), ask for its quota: plenty / limited / scarce; for limited or
  scarce, whether its roles may fall back to another provider's model. Then, across all chosen models: which is the
  strongest overall (→ ARBITER) and which gives the best coding per cost (→ BUILDER)? Default (assumed): for the
  provider with the most quota, that provider's strongest model and its best-per-cost model (else its first listed).
- For a preset without a known launch template (Phase 3), ask now for the exact command that starts that CLI with a
  given model, and store it as the template.

Q4, one item at a time:
- Tracker: Jira / Linear / GitHub Issues / none; how each chosen preset's CLI reads a ticket (MCP servers are set up
  per CLI, and Helm may run on another CLI than you): MCP server, CLI (`gh`, ...) or you paste it into the briefing;
  the key pattern as a regex (`PROJ-[0-9]+`; GitHub Issues `GH-[0-9]+`: issue `#123` becomes key `GH-123`).
- Base branch and branch pattern (detected default): `{key}` = the KEY (Phase 6 step 1), `{num}` = its number only
  (for branches like `feat/123-x`), an optional `{slug}`.
- Commit signing: yes / no. If yes: which key (its ID or file path, never a secret), `gpg.format`, and the name of the
  environment variable or file that holds a passphrase, if any. Never ask for, store or print the value.
- AI attribution in commits, PR bodies and tracker posts: allowed / forbidden (forbidden = no co-author trailer,
  no "generated with" line, no AI tool, model or agent name); does the PR template have an AI-disclosure checkbox?
- Language of commits, PRs and tracker posts (default English, whatever language this interview uses).
- Approvals: who approves pushes, merges and tracker writes. Default and minimum: the human, through you.
- `CODEX_PRETRUST` (only when Q3 includes Codex, else `0`; default `0`): "May the floor setup edit your Codex config
  (`~/.codex/config.toml`) to trust each new floor folder and approve Codex's hook-review dialogs for you? `1` = yes
  (a backup is made before each edit); `0` = no, you approve those dialogs yourself in each new Codex terminal."
