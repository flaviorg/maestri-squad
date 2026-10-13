## Appendix G: TASK and TRACE templates

The Phase 3 loop writes the first block to `$KIT/TASK_TEMPLATE.md` and the second to `$KIT/TRACE_TEMPLATE.md`, with
the kit-time placeholders filled. `{{KEY}}`, `{{FLOOR_PATH}}` and `{{SLOT}}` stay literal; Helm fills them from its
floor card and briefing when it creates the floor notes at BOOT. The `<...>` items (branch, size, risk, stage, ...)
are form fields Helm fills at BOOT and keeps current, not placeholders. The TRACE must end with the sentinel line
`<!-- TRACE-END -->`: every append goes through it (RULES §T).

```markdown
# file: TASK_TEMPLATE.md
# TASK — {{KEY}}
Floor {{KEY}} · branch <branch> · SLOT {{SLOT}} · KIT {{KIT_PATH}} · Size <XS|S|M|L> · Risk <LOW|MEDIUM|HIGH> · Stage <...>
!! MUST NOT <action> WITHOUT <gate>   (pending critical gates, one per line)

## Tracking (Helm updates at every transition; read this first)
Mode: PIPELINE | WORKBENCH · Now: <what is running> by <agent> · Next: <step>
Blockers / waiting on owner: <none | Q#/B#>
- [ ] Intake  - [ ] Gaps  - [ ] Plan approved  - [ ] Env up  - [ ] RED  - [ ] GREEN
- [ ] E2E ({{E2E_TOOL}})  - [ ] Sync {{BASE_BRANCH}}  - [ ] Review A  - [ ] Review B  - [ ] Trace audit
- [ ] Ready to ship (owner go)  - [ ] Shipped (SHA/PR)

## Branch state (WORKBENCH)
commits vs {{BASE_REF}} · behind {{BASE_BRANCH}} by <n> · PR <url|none>

## Ticket snapshot (verbatim from {{TRACKER}}, read by Helm on <date>)
## Acceptance criteria (normalized, verifiable)
- AC-1: ...
## Product gaps (Veto; Onyx on XS)
- G1 [BLOCKER|MAJOR|MINOR] [TYPE] — what — evidence — recommendation — default assumption
## Questions for the owner (work proceeds on the stated assumption unless BLOCKER)
- Q1 (from G#): ... → assumption: ...
## Implementation plan — Status: DRAFT | PLAN_APPROVED (round n) | PLAN_REJECTED
| Step | Owner | Files / call sites | RED tests | Done |
## E2E scenarios
## Review rounds (sealed step-1 reports pasted by Helm AFTER all return)
### R1 — Rook step 1 / Onyx step 1 / Conference / Final verdicts
## Owner requests (bugs / adjustments)
| B# | Type | Description | Repro evidence | RED test | Fix SHA | Review | Status |
## Decision log (dated)
## Follow-up / SWEEP list
## Checkpoint / resume point
## Delivery report
```

```markdown
# file: TRACE_TEMPLATE.md
# TRACE — {{KEY}}
floor {{KEY}} · path {{FLOOR_PATH}} · branch <branch> · slot {{SLOT}} · size/risk <..>
state: <STAGE> · last SHA: — · PR: —

## A. Traceability matrix (AC → evidence)
| AC | Gaps | Tests (file::name) | RED proof | GREEN | E2E scenario + evidence | Review | Status |
|----|------|--------------------|-----------|-------|-------------------------|--------|--------|

## B. Gates
| Gate | Command | Result (counts) | Baseline delta | By | UTC |
|------|---------|-----------------|----------------|----|-----|

## C. Event log (append-only, via the sentinel)
| UTC | Agent (model/effort) | Stage | Action | Evidence | Next |
|-----|----------------------|-------|--------|----------|------|
<!-- TRACE-END -->
```
