# CC task — v3 DATA-ARCH step-0: tier-3 aggregates slice + tier-2 RAW archive (impl)

> Owner: dba (slug dba-0620). §4-PASS: coordinator-0612 2026-06-21T20:42:22Z (v3 data-arch three-tier). Branch **v3**.
> Commits: web:/db:. NO push (§37). Security gate after commit. Design spec = docs/bi/Reports_v1_DataArch.md (authoritative).
> NO RTM-CONTOUR WRITE: archiver READS RTSData_* (contour read OK), WRITES reporting-owned EF-app only.
> PROMPT §4-PASS coordinator-0612 (2026-06-21T21:09:06Z) + FULLY UNBLOCKED (2026-06-21T21:13:49Z): backend co-sign RECEIVED (21:05) + OPERATOR VERDICT (A) — add the contour UpdateTime index. EXECUTE authorized: branch v3, web:/db:, commit.lock, security gate after, NO push. Run the FULL step-0 (T1 + T2.1/2.2 + ArchiverService T2.3 + contour index T2.4 — no hold). FREEZE #3 LIFTED.
> RE-SCOPE §4-PASS: coordinator-0622 2026-06-21T22:31:17Z — 3-table re-scope (ChatMessage CARVED per security 21:59 SF-ARC-001/002/003) REVIEWED & APPROVED: ChatMessage cleanup (remove ArchRtsDataChatMessage entity + migration 20260622090000 + archiver ref) correct; per-table conflict policy (interaction/userstatus DO UPDATE, userstatuslog DO NOTHING) + STABLE PartTime + §38a-self-record-ONLY-in-T2.4 + T2.4 CONCURRENTLY+invalid-index-recovery + backend 2 ops flags (autovacuum 0.05 / indisvalid) all present. EXECUTE authorized: native CC, branch v3, commit.lock, security gate after, NO push.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md ; .claude/skills/role-dba/role-dba.md (§A/§C)
Read: **docs/bi/Reports_v1_DataArch.md** (the ratified design — table shapes, PartTime, idempotency, invariants)
Read: docs/bi/Reports_v1_Scope.md (bi v1 scope) ; src/CcDashboard.Infrastructure/Migrations/App/20260621080000_AddHistoricalReportsTables.cs (Track A pattern: partitioned table via migrationBuilder.Sql, fn_hist_ensure_partitions/drop_aged; NOTE post-11622f0 the EF migration does NOT self-record §38a — EF=__ef_migrations_history)
Read source table shapes from db/schema.sql HEAD (RTSData_Interaction/UserStatusLog/UserStatus — mirror EXACTLY; ChatMessage carved out).

## INIT / discipline
- §0.2 integrity; **branch v3** (git checkout v3; base origin/v3 0996a91); §0.5 object-store verify, NOT mount status.
- §0.3 Python+fsync for any .coord write; after every source write: sync + tail -3 + wc -l + STEP-0.5 NUL-check (0 NUL).
- §42.6 sync block: slug dba-0620; claims = ["src/CcDashboard.Domain/Domain/Historical/**","src/CcDashboard.Domain/Domain/Archive/**","src/CcDashboard.Application/**Archive*","src/CcDashboard.Infrastructure/**","src/CcDashboard.Infrastructure/Migrations/App/**","db/migrations/*arch*","db/migrations/*sl_threshold*","tests/CcDashboard.Tests.Unit/**"]. commit.lock around commit. §0.6b binding -> .coord/cc/dba.md. NO push.
- ⚠ INDEX-LOCK (coordinator-0622 2026-06-22): `.git/index.lock` is a stuck phantom -> normal `git add` fails (`Unable to create '.git/index.lock': File exists`). If operator has NOT Windows-deleted it, commit via §0.4 temp-index: `cp .git/index /tmp/dba_idx; GIT_INDEX_FILE=/tmp/dba_idx git add <files>; GIT_INDEX_FILE=/tmp/dba_idx git commit -m ...; cp /tmp/dba_idx .git/index`. HEAD.lock is free.

## ✅ STEP 0 — SATISFIED (backend co-sign RECEIVED + operator verdict): run the FULL step-0, no hold
- backend-0620 CO-SIGN (inbox/dba.md 2026-06-21T21:05): lock-contention with the RTM write path = NONE (MVCC; an AsNoTracking
  read-committed SELECT takes no row locks vs the INSERT...ON CONFLICT DO UPDATE writers). Cadence hourly + batch 5-10k = fine.
  Backend conditions are folded into T2.3 (per-table conflict policy, stable PartTime, batch<=10k+yield, watermark safety lag).
- OPERATOR VERDICT (A) (coordinator 2026-06-21T21:13:49): the `(TenantId,"UpdateTime")` index on RTSData_Interaction +
  RTSData_UserStatusLog is an APPROVED contour DDL (§23 VERIFY-06 / §25) — implement it in step-0 as a db: migration (T2.4).
- => ArchiverService (T2.3) is UNBLOCKED. Build T1 + T2.1 + T2.2 + T2.3 + T2.4 together in this step.

## THE WORK (branch v3)

### T1 — tier-3 aggregates slice (EF-app, App context)
a. EF migration: ADD index `hist_queue_intervals (TenantId, Workgroup, IntervalStart)` + `hist_agent_intervals (TenantId, AgentExternalId, IntervalStart)` (migrationBuilder.Sql CREATE INDEX, partition-local). EF-app App-context migration ONLY -> tracked by __ef_migrations_history; NO db_patch_history INSERT / NO companion db/migrations sql (a §38a INSERT inside an EF migration regresses CC-HIST-001 42P01, fixed 11622f0).
b. `TenantSettings.SlThresholdSeconds` int NULL DEFAULT 20 — Domain entity + EF config + App-context migration. `HistoricalAggregationService` reads it per-tenant at agg time (fallback 20 if null); replace the hardcoded const.
c. Pin the Hold StatusId literal in a code comment (deploy-smoke 234 confirms; graceful 0 already coded).

### T2 — tier-2 RAW archive (EF-app)
2.1 Three archive entities + tables `arch_rtsdata_interaction`/`_userstatuslog`/`_userstatus` (ChatMessage CARVED OUT — see note below) — EXACT column mirror of the
    source RTSData_* (per db/schema.sql) + `ArchivedAt timestamptz NOT NULL DEFAULT now()` + `PartTime timestamptz NOT NULL`.
    Partitioned `BY RANGE (PartTime)` monthly + DEFAULT (Track A pattern, migrationBuilder.Sql). PK = (source natural key…, PartTime):
    PartTime MUST derive from STABLE source cols only (mutable cols would shift the ON CONFLICT key on upsert -> duplicates):
    - interaction [UPSERTED src -> archive UPSERT]: (InteractionId,Segment,OnDate,ServerId,Workgroup,PartTime);
      PartTime = COALESCE("InQueueDateTime", to_timestamp("OnDate",'DD/MM/YYYY'))  -- NOT AnsweredDateTime/UpdateTime (they mutate)
    - userstatus [UPSERTED daily snapshot -> archive UPSERT]: (UserId,StatusId,ServerId,OnDate,PartTime);
      PartTime = to_timestamp("OnDate",'DD/MM/YYYY')  -- OnDate is the stable snapshot key, NOT UpdateTime
    - userstatuslog [APPEND-ONLY -> archive DO NOTHING]: (Id,PartTime); PartTime = COALESCE("StartTime", to_timestamp("OnDate",'DD/MM/YYYY'))
    🚫 CHATMESSAGE = CARVED OUT (SECURITY ruling 2026-06-22): RTSData_ChatMessage has NO TenantId column (v3:db/schema.sql:305-324) ->
      tenant-scoping needs a JOIN-inference whose cross-tenant-leak + orphan + PII/content-retention risk must be spec'd separately.
      DO NOT create arch_rtsdata_chatmessage / ArchRtsDataChatMessage in step-0. If the prior CC run already added that entity + its table
      (in migration 20260622090000) + any archiver/DI reference -> REMOVE them. ChatMessage archiving = future task, HOLD SF-ARC-001/002/003.
    Indexes per design §2.5: (TenantId,PartTime) each; +interaction (TenantId,Workgroup,PartTime); +userstatuslog (TenantId,StatusGroup,StartTime).
    TenantId on every entity + GQF. EF-app App-context migrations ONLY (tracked by __ef_migrations_history; NO db_patch_history INSERT / NO companion db/migrations sql — §38a-in-EF regresses CC-HIST-001 42P01). Initial partitions current+next2+prior (DEFAULT catches rest).
2.2 `arch_watermark` table (TableName text, TenantId uuid, ArchivedThrough timestamptz, PK(TableName,TenantId)). Reuse generalized
    fn_hist_ensure_partitions/fn_hist_drop_aged for the arch tables (keep_months=84). Daily ensure + monthly drop wired in the service.
2.3 `ArchiverService` (IHostedService, Infrastructure/BackgroundServices) — backend-0620 CO-SIGNED conditional (21:05; lock-contention NONE via MVCC):
    per-tenant DI scope (ARCH-07); read RTSData_* AsNoTracking, batch <=10k ORDER BY UpdateTime, inter-batch yield 200-500ms.
    IMPLEMENTATION (dba-blessed, CC design 2026-06-22): the archiver may use raw `INSERT INTO arch_* (...) SELECT ... FROM "RTSData_*" ...
    ON CONFLICT ... ` (ExecuteSqlInterpolated, CODE-01 parameterized — NOT string-concat) instead of EF entity materialization. RATIONALE:
    the RtsData* EF entities do NOT mirror the full source (no CustomCallData1-20); raw INSERT...SELECT is a faithful column-map AND avoids
    routing ~255M rows through the EF change-tracker. Keep AsNoTracking only where a row is read into C#; prefer set-based INSERT...SELECT.
    WATERMARK SCAN w/ safety lag: `WHERE "TenantId"=@t AND "UpdateTime" > ArchivedThrough AND "UpdateTime" <= now() - interval '2 min'`
    (TenantId equality MANDATORY — drives the T2.4 (TenantId,UpdateTime) index range scan, per backend review; per-tenant DI scope ARCH-07; avoid racing in-flight UPSERTs).
    PER-TABLE CONFLICT POLICY (backend pt.4 — sources differ): interaction + userstatus are UPSERTED in source (UpdateTime moves) ->
      `ON CONFLICT (natkey…,PartTime) DO UPDATE SET <all non-key cols>, "ArchivedAt"=now()` (refresh to LATEST; PartTime STABLE per 2.1 so key never shifts).
      userstatuslog = append-only -> `DO NOTHING`. (ChatMessage carved out — see T2.1.)
    Advance ArchivedThrough only AFTER batch commit (archive-FIRST -> purge-SECOND). NO DELETE on arch_* except drop-aged (upsert-to-latest = faithful latest fact, not history rewrite).
    WATERMARK INDEX = OPERATOR-APPROVED (verdict A, 2026-06-22) -> implemented in T2.4 (db: contour migration). With it the watermark
    scan `WHERE "UpdateTime" > wm` is an index range scan, NOT a seq-scan of an unbounded table (RTSData_MidnightClear dead, Engine.cs:957).

2.4 ⚠ CONTOUR index migration (OPERATOR-APPROVED verdict A 2026-06-22; db: migration, touches RTSData_* contour tables — the ONLY contour write in step-0):
    `CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_rtsdata_interaction_tenant_updatetime ON "RTSData_Interaction" ("TenantId","UpdateTime");`
    `CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_rtsdata_userstatuslog_tenant_updatetime ON "RTSData_UserStatusLog" ("TenantId","UpdateTime");`
    Migration HEADER comment MUST read: 'operator-approved contour index 2026-06-22 - read-perf for reporting archiver watermark scan;
    NO column/behaviour change'. Use CREATE INDEX CONCURRENTLY (avoid locking the live RTM write path); CONCURRENTLY cannot run inside a
    tx -> deliver as a standalone db/migrations sql (not an EF migration body that wraps in a tx), or document the brief lock window if
    the runner forces a tx. §38a self-record. Index-only: NO column/constraint/data change to RTSData_*.
    BACKEND-0620 REVIEW (21:35, APPROVE): positional-safe (index-only, no ordinal/layout change — RTM reads positionally); shape
    (TenantId,UpdateTime) optimal IFF the archiver carries `WHERE "TenantId"=@t` (it does — per-tenant scope, ARCH-07, T2.3). Fold its 2 ops flags:
    (F1 autovacuum) RTSData_Interaction is UPSERTED + UpdateTime MUTATES -> new index entry moves each update (non-HOT) -> tuple churn/bloat over
      time (MidnightClear dead -> unbounded). Add in the SAME db/migrations sql: `ALTER TABLE "RTSData_Interaction" SET (autovacuum_vacuum_scale_factor=0.05);`
      (RTSData_UserStatusLog append-only -> no concern). Operational, not a behaviour/contour change.
    (F2 invalid-index recovery) a CONCURRENTLY build interrupted leaves an INVALID index; `IF NOT EXISTS` then SKIPS it -> watermark silently
      reverts to seq-scan. Post-apply VERIFY (in the sql + REBUILD_RUNBOOK): for both index names, if `pg_index.indisvalid=false` -> DROP + rebuild
      CONCURRENTLY; do NOT rely on IF NOT EXISTS alone.

### T3 — unit tests (tests/CcDashboard.Tests.Unit/, >=6)
(1) archiver idempotency: re-run same window -> no double rows (ON CONFLICT). (2) watermark advance + resume. (3) PartTime COALESCE
correctness incl null primary time -> DEFAULT partition. (4) multi-tenant isolation (tenant A archive never reads B). (5) dedup on natural
key. (6) SlThresholdSeconds read (per-tenant value used; null->20). (7) archive-first invariant: watermark only advances post-commit.

## ACCEPTANCE
- `dotnet build CcDashboard.sln` green; `dotnet test tests/CcDashboard.Tests.Unit` >=6 new green.
- arch migration applies fresh+existing; partitions created; idempotent re-run safe. ArchiverService/app code does ZERO writes to RTSData_*/NGC_*/identity (contour read-only) — verify diff. The ONLY contour change in step-0 = the T2.4 operator-approved index migration (index-only, no column/data change).
- T2.4 contour index migration present (both indexes, CREATE INDEX CONCURRENTLY, operator-approved header, §38a self-record).
- TenantSettings.SlThresholdSeconds present + agg reads it. +2 hist indexes present. §38a self-record ONLY in the T2.4 db/migrations sql (EF-app migrations T1/T2.1/T2.2 = __ef_migrations_history, NO db_patch_history INSERT — avoids CC-HIST-001 42P01).
- Object-store-verified commits (web:/db:), branch v3, commit.lock, NO push. Backend co-sign recorded for ArchiverService.

## STEP final — §0.6b binding RESULT -> .coord/cc/dba.md ; CAPTURE lesson if any -> role-dba §B ; commit-lock release + §0.7 re-sync. NO push.
