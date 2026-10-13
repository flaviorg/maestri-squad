## Phase 5: Workspace roles

Create the workspace-scoped roles from `$KIT/roles/`, with the role names exactly as in Appendix B (`staff_floor.sh`
recruits with them). Every role is printed as created, existing (this kit's) or foreign:

```bash
SLUG="<project-slug>"
while IFS='|' read -r name file; do
  [ -f "$KIT/roles/$file" ] || continue # a role this area does not use (Phase 3)
  if ! cur="$(maestri role show "$name" 2> /dev/null)"; then
    maestri role create "$name" "$(cat "$KIT/roles/$file")" --scope current && echo "created: $name"
  elif printf '%s\n' "$cur" | grep -qF "Kit: $SLUG (maestri-squad)"; then
    echo "exists:  $name"
  else
    echo "FOREIGN: $name"
  fi
done <<'EOF'
Floor Captain|floor-captain.txt
Gap Hunter & Plan Auditor|gap-hunter.txt
Builder|builder.txt
Test Runtime & E2E|probe.txt
Reviewer A|reviewer-a.txt
Reviewer B|reviewer-b.txt
Solo Gate|solo-gate.txt
Shipper|shipper.txt
Arbiter|arbiter.txt
Security Auditor|security.txt
UI Builder|ui-forge.txt
UX Advisor|ux-lens.txt
Sweep Engineer|sweep.txt
EOF
```

Show the user the output. A `FOREIGN` role belongs to another project (Phase 0 step 3): replace it only when the
user chose that there, otherwise stop. Compare each `exists` role (on every run, not only on an update) with
`maestri role show "<name>"` against its file; when they differ, show the difference and, on the user's OK, replace it
with `maestri role write "<name>" "$(cat "$KIT/roles/<file>")"` (the same command replaces a `FOREIGN` role).

Then recruit Oracle, the Arbiter, once on the ground, unless `maestri list` already shows this kit's `Oracle` (Phase 0
step 3). A foreign `Oracle` the user chose to replace is re-recruited in place: add `--replace "Oracle"`, as E.4 does.
The command is the `launch:` line the Phase 3 dry run printed under `PLAN Oracle` (wrap it in single quotes):

```bash
maestri recruit "Oracle" --preset "<ARBITER preset>" --role "Arbiter" --command '<the launch: line>'
```

`staff_floor.sh` ropes every floor's Helm to Oracle. Oracle gets the kit path with each request (Appendix B).
