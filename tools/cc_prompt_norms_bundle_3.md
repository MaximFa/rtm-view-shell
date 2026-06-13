# CC task - norms bundle #3 (ONE pass, ONE cache-bump) - LAND AFTER 45 CLOSES
> Author: curator-0611. Executor: native CC, RTM repo. docs: commit, NO push. Python+fsync. §4-review first.
> SEQUENCING (coordinator-0612): land at the next CALM point, AFTER server-45 closes; do NOT churn the skill + bump sessions mid-deploy.
> Then cache-bump #3 (re-read note to all active inboxes + operator коорд: входящие). UNIFORM: AD already has items 1-3 (B-21); AD folds 4-5.

## 1. L-SC-27 - auto-inbox-hook is BEST-EFFORT (CLAUDE.md §42.8 + skill L-SC-13)
Add: the turn-start auto-peek runs ONLY on a turn (LLM, no daemon, no poll); it does NOT replace the explicit `коорд: входящие`/
`коорд: статус` triggers - those are the RELIABLE delivery path. The operator stays the scheduler. A block arriving while a session
has no turn is not seen until the next poke - a message missed without a poke is the EXPECTED behaviour, not an anomaly. No session
(incl. the coordinator) may assume the auto-peek caught everything.

## 2. NORM-CUR-06b - concurrency-safe inbox archival (re-land + clause)
Re-land tools/inbox_archive.py v3 (re-read-before-write keeps concurrent appends + atomic temp+os.replace) - supersedes v2 in 21cf075.
In the L-SC-25 clause + the `коорд: чистка` verb: the CALLER MUST hold .coord/locks/commit.lock (serialize vs commits + other archival, L-SC-09).

## 3. NORM-CUR-08 - anti-staleness / freshness-audit (CLAUDE.md §38/§39 + the sweep)
Add: any artifact mirroring live/generated state (db/functions, schema.sql, deploy docs) is GENERATED from the authoritative source
(not hand-maintained) + carries a 'generated from X at <ts>' provenance line. A freshness-audit (folded into `коорд: разбери`/`проверь
шину`) compares mirrors to their source and FLAGS drift; a clean from-scratch rebuild is the truth-test; verify env facts from the
SERVER not the doc. Lessons L-DEPLOY-01/02/03 (PD-008).

## 4. NORM-CUR-09a - trigger-list parallelism annotation (skill §10 command-dispatch)
The coordinator annotates each entry of a trigger-list: '||' parallel (independent), '->' sequential (output-dependency OR shared
exclusive claim/commit.lock). Default '->' when unsure.

## 5. NORM-CUR-09b - operator convention п.N == §N (CLAUDE.md operator-convention note + skill)
`п.N` is the semantic equivalent of `§N` (operator keyboard has no §). Treat identical in commands/messages.

## Commit / acceptance
ONE docs: commit; journal; NO push; re-sync. Verify each anchor by object store. Curator confirms RTM<->AD parity after AD folds 4-5.

## 6. NORM-CUR-10 - mandatory documentation by the Tech Writer (CLAUDE.md sec42.7/sec26.5 doc-gov + skill)
NORM-CUR-10 - Mandatory documentation by the Tech Writer (PERMANENT operator rule). Any decision, change, or addition -
protocol norm, code/feature, deploy/DB change, ADR, architecture, registry/command change - is ALWAYS documented by the Tech
Writer. Nothing is "done/complete" until its documentation is updated and current. The norm log (discipline-lessons.md) captures
protocol norms live; the Tech Writer synthesizes ALL changes into the project docs (runbook, ADRs, SRS, user/admin/ops docs) and
keeps them current. Enforced BOTH at the push-barrier doc-sync gate (TW READY/HOLD, sec42.7/sec26.5) AND as a standing between-
barrier duty. The coordinator routes every decision/change to the Tech Writer; the curator verifies doc-coverage at filing. UNIFORM both projects.

## 7. NORM-CUR-07d - §4-review must CHECK binding presence (skill §4 review-checklist + coordinator §4 duty)
NORM-CUR-07d (§4-review must check binding presence). Every CC-prompt §4 review MUST verify the NORM-CUR-07 binding is in the
prompt: (a) PREAMBLE opens a BINDING block to .coord/cc/<role>.md (status: open, directive ref); (b) POSTAMBLE writes the RESULT
to the binding on commit (commits/build-test/files/status/blockers, object-store-verified) + cc_post_commit. Binding ABSENT or
PARTIAL -> §4 verdict = REVISE, not PASS. Enforces NORM-CUR-07c at REVIEW time, not by assumption.
