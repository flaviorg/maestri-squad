<!-- maestri-squad v1.0.0 -->
# Maestri Squad Bootstrap

Tested with: Maestri 0.51.0, Claude Code 2.1.296, codex-cli 0.161.0.

## How to use this file

Hand this file to your Maestro agent and ask it to follow it from the top. The agent interviews you, reads your
project, generates a squad kit under `${MAESTRI_SQUAD_HOME:-$HOME/.maestri-squad}/<project-slug>`, lets you review it,
then sets up the workspace roles and opens the first floor. Nothing is written inside your project repository without
your approval. Read the phases in order; open an appendix only when a phase points to it.
