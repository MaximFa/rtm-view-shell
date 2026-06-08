# Cowork session TAKEOVER + RENAME — adopt a prior work-session's territory under a NEW slug

Paste into a FRESH Cowork session. Set the two slugs below. This MIGRATES the prior session's claims
to your new slug and RETIRES the prior — reconstruct from the .coord/ bus; do NOT start fresh.

NEW_SLUG   = <this session, e.g. devops-2-0607 | test-5-0607 | metrics-2-0607 | daytrend-2-0607>
PRIOR_SLUG = <the session you take over, e.g. devops-0606 | test4-0606 | metrics-0605 | daytrend-0606>

1. Read `.claude/skills/session-coord/session-coord.md` (current coordination protocol).
2. §0.2 integrity: `git status --short`; for prior-claimed `M` files, hash-check vs HEAD; restore truncated ones.
3. Read `.coord/sessions/<PRIOR_SLUG>.md` (claims + scope) + `.coord/inbox/<PRIOR_SLUG>.md`
   (find the latest `TAKEOVER-HANDOFF` from coordinator-0606 + skim the recent thread) + `.coord/journal.md` tail.
4. CREATE `.coord/sessions/<NEW_SLUG>.md` (Python+fsync) — status: active; fresh heartbeat; role from prior;
   **COPY the prior `files:` claims verbatim**; cc_task: none; body note "takeover of <PRIOR_SLUG>, <YYYY-MM-DD>".
   (Claims now live under NEW_SLUG — do this BEFORE retiring the prior so there is no unclaimed gap, esp.
   metrics' EXCLUSIVE ScreenEditorPage.razor.)
5. RETIRE the prior: set `.coord/sessions/<PRIOR_SLUG>.md` status: done; append body line
   "superseded by <NEW_SLUG> (takeover <YYYY-MM-DD>); claims migrated."
6. Hash-check your migrated claims `==HEAD`. Use `<NEW_SLUG>` for ALL future bus writes (/tmp/<NEW_SLUG>_*.py,
   ack files, journal lines, S4b flushes).
7. Report to the coordinator — append to `.coord/inbox/coordinator.md`:
   `## <UTC> | from: <NEW_SLUG> | to: coordinator`
   `TAKEOVER COMPLETE — adopted <PRIOR_SLUG> territory. Claims migrated: <list>. Next: <from handoff>. Ready.`
   `---`
8. AWAIT the operator. Do NOT issue any CC task until the coordinator confirms (a push barrier opens first).
