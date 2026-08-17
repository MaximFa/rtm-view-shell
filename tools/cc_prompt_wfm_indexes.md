# CC Task — WFM Phase 1 (A): index DDL migration (db/) for the 30s WFM loop

> Adds the composite/covering indexes the WFM hosted loop needs so λ/AHT/N do NOT full-scan RTSData_Interaction
> every 30s. dba's DDL (spec §6, §4-blessed). Can land independently of the loop. Territory: **db**. NO push. Prefix `db:`.

## STEP 0 — §0.6a integrity (branch v3). §40 reads. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock (§42.4).
## STEP 1 — Sync slug backend-0626. Claims:
##   - db/migrations/20260721_001_wfm_indexes.sql   (new)
## STEP 2 — BINDING preamble to .coord/cc/backend.md (status open, directive this file, prefix db:).

## Implement — new file db/migrations/20260721_001_wfm_indexes.sql (idempotent, self-recording §38a)
```sql
-- WFM Phase 1 covering indexes (spec §6). Idempotent.
-- NOTE for DBA/operator apply on 140: RTSData_Interaction is a HOT table. Decide CREATE INDEX CONCURRENTLY
-- (outside a txn, non-blocking) vs plain (brief write lock). This migration uses plain IF NOT EXISTS; the
-- operator MAY run the CONCURRENTLY variant manually on 140 if write-lock is a concern (dba call).

-- λ (arrivals by InQueueDateTime) + covering the λ predicate/columns
CREATE INDEX IF NOT EXISTS ix_rtsint_wfm_inq
  ON public."RTSData_Interaction" ("TenantId","InQueueDateTime")
  INCLUDE ("Workgroup","Direction","InteractionType","CallType","IsCallbackRequest");

-- AHT (completed by AnsweredDateTime) — partial (only answered rows have AnsweredDateTime)
CREATE INDEX IF NOT EXISTS ix_rtsint_wfm_ans
  ON public."RTSData_Interaction" ("TenantId","AnsweredDateTime")
  INCLUDE ("Workgroup","Direction","InteractionType","CallType","IsAnswered","IsInQueue","TalkTime")
  WHERE "AnsweredDateTime" IS NOT NULL;

-- N (serving agents) — RTSData_UserStatus by StatusGroup
CREATE INDEX IF NOT EXISTS ix_rtsus_wfm
  ON public."RTSData_UserStatus" ("TenantId","StatusGroup")
  INCLUDE ("UserId");

-- §38a self-record
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260721_001_wfm_indexes') ON CONFLICT (migration_name) DO NOTHING;
```

## STEP 3 — verify file (§0.3): after Python write -> `sync; tail -3 <file>; wc -l <file>` (proper closing line).
## STEP 4 — pre-commit + commit (commit.lock, §0.4 plumbing if index.lock stuck) — ONE commit:
`db: WFM Phase1 covering indexes (ix_rtsint_wfm_inq/_ans + ix_rtsus_wfm) [wfm]`
§0.6 verify -> journal -> lock release -> §0.7 re-sync. NO push.

## STEP 5 — BINDING RESULT to .coord/cc/backend.md: commit hash, file, status done, verified object-store.

## Acceptance
- [ ] New file db/migrations/20260721_001_wfm_indexes.sql only; 3 CREATE INDEX IF NOT EXISTS + §38a self-record.
- [ ] No other file touched. Prefix `db:`. NO push. Working tree clean vs HEAD after.
- [ ] Note in RESULT: 140 apply is dba/operator (CONCURRENTLY decision on the hot table is theirs).

## Git push: do NOT run git push. Commit only.
