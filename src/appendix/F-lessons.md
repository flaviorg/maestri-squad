## Appendix F: Operating lessons

Lessons from real squads. Each one cost a stalled floor or a wasted cycle; apply them without being asked.

**F1. Never end a message to a working agent with "reply with an ack only".** The agent answers the ack and its turn
ends, so the floor stalls while everyone waits for it. End every message with the next action instead: "continue
with <step> now; report to Helm when done". Within a minute, `maestri check "<Agent>-<KEY>"` must show it working.

**F2. `maestri floor create` and `maestri floor delete` can time out and still complete.** Never repeat either one
blindly: run `maestri floor list` first and act on what it shows. A repeated create can make a second floor; a
repeated delete can hit the wrong one.

**F3. Codex boot dialogs block a fresh agent.** A new Codex terminal may open on an update menu or on a "hook needs
review" dialog, and a prompt sent then is swallowed. `staff_floor.sh` warms every agent up: it skips the update menu,
and with `CODEX_PRETRUST=1` in `kit.env` it trusts the floor path and approves the hook dialog itself. With the
default `CODEX_PRETRUST=0` it prints `WARM <agent> waiting: a hook needs review` and the human approves the dialog in
that terminal. Only brief an agent after its `WARM <agent> ok` line, or after `maestri check` shows it idle at a
prompt.

**F4. The terminal status bar is the truth for which model an agent runs, not the TRACE.** Agent CLIs fall back to
another model silently (quota, outage, account change) while the agent keeps writing the staffed model into its TRACE
rows. Run `$KIT/quota_watch.sh <KEY>` at every milestone and act on any non-OK row (Appendix E.4).

**F5. One consolidated ask per milestone to an agent on a scarce-quota provider.** Small follow-up asks each cost a
full context read. Batch everything that agent needs for the milestone (the brief, the evidence paths, the exact
question) into one message.

**F6. A defect in the squad's own helper scripts is fixed inline and logged as a TRACE deviation, not a STOP
cycle.** A broken comparison script, a wrong path in a helper, a flaky wrapper: fix it, log one TRACE row with
STAGE=DEVIATION (what broke, the fix, the evidence) and continue. STOP only on product evidence: a failing gate, a
failing E2E scenario, a crash, the wrong build or version running.

**F7. Refresh long-running agents in place instead of letting their context rot.** When an agent starts re-deriving
settled facts or ignoring rulings, write a HANDOFF file and swap it with `maestri recruit --replace` (Appendix E.6).
The fresh process keeps the name, role and connections, and starts from the handoff instead of hundreds of TRACE rows.
