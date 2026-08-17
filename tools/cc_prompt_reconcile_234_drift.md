# CC TASK — 234 drift reconcile plan (regenerate baseline from 234 + apply 2 + ledger-mark 2)  [⛔v3 · DBA · DB-setup]

> Authored by dba-0625 for coordinator §4-bless. DIRECTION APPROVED (operator): repo baseline is STALE; 234 is authoritative (NEVER drop/alter 234). Probes: P1 all 24 tables exist; P2 owner=ccdashboard_user (not reader-artifact); P3 NGC_Get* exist (signature drift). This prompt does the CC-COMMITTABLE-NOW pieces + specifies the operator/234 steps + the follow-up baseline-swap. NOTHING applied to 234 by CC (§43 no access). NO push.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE + §C VERIFY.
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §38.5 (align advisory), §38a (ledger self-record), §39 (db module + Export-All), §43 (external-server ops), §33.8 (prokind).

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # v3 object-store; M hash-verify vs HEAD
sync
```
S1: if `.coord/push/request.md` active → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_reconcile_234_drift.md | status: open
### DIRECTIVE (spec->CC): create staging/234_ledger_mark.sql + staging/234_reconcile_runbook.md. claim: staging/234_ledger_mark.sql, staging/234_reconcile_runbook.md. gate: files created. NO 234 apply. NO push.
```

## 3. CLAIM
- `staging/234_ledger_mark.sql` (NEW), `staging/234_reconcile_runbook.md` (NEW). §0.7 staging. No source/code.

## 4. TASK
### 4.1 Create `staging/234_ledger_mark.sql` (ASCII) — ledger-mark the 2 already-applied (do NOT re-run them)
```sql
-- 234: mark as applied in db_patch_history the 2 migrations PROVEN applied by probe (2026-07-03):
--   20260605_004_metrics_dedup      (RTSGrid_Cell.Value renames done: old_refs=0)
--   20260606_008_daytrend_fn_bu_scope (server fn sig == _008 CREATE sig)
-- These are NOT re-applied (objects already correct); the ledger row stops Compare flagging UNKNOWN.
INSERT INTO public.db_patch_history (migration_name) VALUES
  ('20260605_004_metrics_dedup'),
  ('20260606_008_daytrend_fn_bu_scope')
ON CONFLICT (migration_name) DO NOTHING;
SELECT migration_name FROM public.db_patch_history
 WHERE migration_name IN ('20260605_004_metrics_dedup','20260606_008_daytrend_fn_bu_scope') ORDER BY 1;
```

### 4.2 Create `staging/234_reconcile_runbook.md` — the full operator sequence (234, as postgres)
Document in STRICT order. NEVER drop/alter real 234 objects.
**STEP 0 - HARD FAIL-STOP BACKUP before ANY change (before steps 2-3):** `pg_dump -Fc -h localhost -U postgres -d rtmviewdb -f C:\RTMView-Ops\backup\rtmviewdb_pre_reconcile_<ts>.dump`. If pg_dump fails OR any later step errors -> STOP + restore from THIS backup (pg_restore) + escalate; do NOT improvise.
1. **Regenerate baseline from 234** (fixes Dim-A + [A-R] at root): operator runs on 234 as postgres —
   `db\tools\Export-All.ps1 -DBHost localhost -DBPort 5432 -DBUser postgres -Password <pg> -DryRun`  (inspect),
   then without -DryRun to (re)generate `db/schema.sql`, `db/functions/*.sql`, `db/data/02_metrics.sql` (etc.) from 234 reality. This auto-includes the typo metrics (QueueNumAbandonef*) in db/data/02_metrics.sql → Dim-C = 0 (no separate step). The regen writes INTO the repo checkout ON 234 (call it 234-BaselineDir).
2. **Apply the 2 genuinely-unapplied DB migrations** (idempotent) as postgres on 234:
   `psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db\migrations\20260604_001_add_agent_state_pct_metrics.sql`
   `psql ... -f db\migrations\20260606_005_history_unavailable_metrics.sql`  (history_metrics exists — confirmed).
3. **Ledger-mark the 2 applied**: `psql ... -f staging\234_ledger_mark.sql`.
4. **Re-Compare ON 234 AGAINST THE JUST-REGENERATED baseline** (db/tools Compare-ToBaseline; `-BaselineDir` MUST point at the 234-BaselineDir\db that Export-All regenerated in step 1 - NOT the stale package/repo baseline, else 'clean' is meaningless) → confirm A/[A-R]/D = 0.
5. **Only after step 4 = clean:** return the regenerated db/ files to the DEV repo (staging/regen234/) for the follow-up commit (§4.3).
NOTE: the regenerated baseline files must come from 234 (CC has no 234 access §43). CC's follow-up (§4.3) only COMMITS what the operator returns.

### 4.3 FOLLOW-UP (separate CC, after operator returns regen files) — NOT this run
Once staging/regen234/{schema.sql,functions/*,data/02_metrics.sql} present: swap into db/, `git add` the changed db/ files, commit `db: regenerate baseline from 234 reality (drift reconcile)`. (Authored as a follow-up prompt when files land.)

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-07-04 · 234 recurring E1 drift (Dim-A 24 CC tables 'missing' + [A-R] 46/115 routines) = STALE repo baseline, NOT reader-artifact (P2 owner=ccdashboard_user). §38.5 direction = regenerate db/schema.sql+db/functions from the authoritative live server (Export-All as postgres), never apply align Dim-A/[A-R] (would CREATE existing / DROP real objects). Regen auto-fixes Dim-C metrics too. Ledger-mark probe-proven-applied migrations (don't re-run). · SOURCE: 234 delta 20260704-113216 + probes P1/P2/P3 · status: active
```

## 6. Acceptance
- staging/234_ledger_mark.sql (2 INSERT + verify) + staging/234_reconcile_runbook.md created.
- role-dba §B lesson added.
- NO 234 apply; NO baseline swap in this run (follow-up); NO code change; NO push.

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5x60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add staging/234_ledger_mark.sql staging/234_reconcile_runbook.md` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`.
- Prefix `db:` — `db: 234 drift reconcile plan (ledger-mark script + runbook) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . staging/234_ledger_mark.sql + staging/234_reconcile_runbook.md . status done . verified: object-store
```
