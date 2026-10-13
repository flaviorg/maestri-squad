# TASK — {{KEY}}
Floor {{KEY}} · branch <branch> · SLOT {{SLOT}} · KIT <KIT_PATH> · Size <XS|S|M|L> · Risk <LOW|MEDIUM|HIGH> · Stage <...>
!! MUST NOT <action> WITHOUT <gate>   (pending critical gates, one per line)

## Tracking (Helm updates at every transition; read this first)
Mode: PIPELINE | WORKBENCH · Now: <what is running> by <agent> · Next: <step>
Blockers / waiting on owner: <none | Q#/B#>
- [ ] Intake  - [ ] Gaps  - [ ] Plan approved  - [ ] Env up  - [ ] RED  - [ ] GREEN
- [ ] E2E (Maestro (maestro.dev))  - [ ] Sync main  - [ ] Review A  - [ ] Review B  - [ ] Trace audit
- [ ] Ready to ship (owner go)  - [ ] Shipped (SHA/PR)

## Branch state (WORKBENCH)
commits vs origin/main · behind main by <n> · PR <url|none>

## Ticket snapshot (verbatim from GitHub Issues, read by Helm on <date>)
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
