# CC — Dev report seed, CLEAN migrate-first (operator: ZERO Shell startup errors)

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3. dba PAIRS (DB reset + migration safety). -> coordinator §4 (REWORK).
> §4-PASS: coordinator-0622 2026-06-22T14:34:10Z — CLEAN migrate-first; CORE-RULE data-only seed (schema/fn from EF migration) fixes 183b404 root; STEP-1 creates fn_hist_ensure_partitions (VERIFY to_regprocedure); acceptance = ZERO startup errors (both BG services resolve, no 42883/StopHost). APPROVED. RUN gated on dba reset-pick (A/B) + migration-safety review. dba reviews, operator runs from bi session.
> §4-PASS (HARDENED): coordinator-0622 2026-06-22T19:19:00Z — root confirmed (RESET-B DROP silently failed, DB in use; NOT a migration bug — Up()@144 creates fn). Hardened gates APPROVED: STEP-0.5 terminate-conns-from-postgres-maint + DROP/CREATE OWNER ccdashboard_user; STEP-0.6 VERIFY-FRESH-or-ABORT; STEP-1 VERIFY-fn-or-ABORT+dump-history. Operator must STOP Shell first. EXECUTE authorized.
> GOAL: Shell on v3 starts with ZERO errors (HistoricalAggregationService AND ArchiverService both resolve
> fn_hist_ensure_partitions — no 42883 -> no BackgroundService StopHost), Superadmin /reports shows 7-day data.
> SUPERSEDES the deviated run 183b404 (which CREATE-TABLE'd hist_* + did NOT create fn_hist_* + did NOT apply the EF
> migration -> both BG services 42883 on startup -> .NET8 host stop). LOCAL DEV ONLY. Idempotent, parameterized (CODE-01).
> CORE RULE: SCHEMA + FUNCTIONS come ONLY from the EF migration; the seed is DATA-ONLY (INSERT). NEVER CREATE TABLE/FUNCTION in the seed.
> §4-PASS (END-TO-END): coordinator-0622 2026-06-22T19:39:01Z — privilege split CORRECT (postgres superuser ONLY for STEP-0.5 DROP/CREATE DATABASE OWNER ccdashboard_user; ccdashboard_user-owner for migrate+seed -> app-owned objects, runtime OK); both pwds=session params; VERIFY-or-ABORT gates 0.6/1/4; data-only seed. APPROVED, single run. Operator: STOP Shell first + supply -PgPassword (postgres) + -AppPassword.

## STEP 0 — integrity + branch + DEV guard + params + operator precondition
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD
```
PARAMS (session params, NOT hardcoded; DEV-ONLY): -PgPassword (postgres superuser) + -AppPassword (ccdashboard_user).
DEV-ONLY guard everywhere (DB-name == dev rtmviewdb AND --dev flag; refuse prod). RTSData_* writes = dev-only contour sim, marked.
OPERATOR PRECONDITION: STOP the Shell (close any rtmviewdb connection / pgAdmin) BEFORE running — else DROP DATABASE fails (in-use).
PRIVILEGE SPLIT (correct — do NOT run everything as postgres or objects become postgres-owned and break runtime):
  - postgres SUPERUSER (psql -U postgres -d postgres -W <PgPassword>): ONLY STEP 0.5 DB-admin (terminate + DROP + CREATE DATABASE OWNER ccdashboard_user).
  - ccdashboard_user (OWNER of the fresh DB; <AppPassword>): EVERYTHING else — STEP 1 migrate + STEP 2/3 seed. Owner = full rights on its own DB (NO grants needed); objects owned by app-user so the Shell (runs as ccdashboard_user) reads them at runtime.

## STEP 0.5 — RESET = FRESH DB (operator-locked: option B; HARDENED — prior run's DROP silently failed)
ROOT of the 3rd 42883: a previous RESET B DROP DATABASE rtmviewdb SILENTLY FAILED because a connection was open
(running Shell / pgAdmin) -> PG refuses to drop an in-use DB -> old broken state persisted (stale __ef_migrations_history
says applied, fn_hist_ensure_partitions never created) -> migrate "up to date" -> 42883. HARDEN:
- OPERATOR PRECONDITION: STOP the Shell (and close pgAdmin connections to rtmviewdb) BEFORE running.
- Run ALL of this as the postgres SUPERUSER on the maintenance DB (psql -U postgres -d postgres, password=-PgPassword; NOT rtmviewdb, NOT app-user — DROP/CREATE DATABASE is a superuser op):
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='rtmviewdb' AND pid <> pg_backend_pid();
    DROP DATABASE IF EXISTS rtmviewdb;
    CREATE DATABASE rtmviewdb OWNER ccdashboard_user;
  OWNER=app user: EF InitialCreate emits CREATE EXTENSION pg_trgm+pgcrypto (TRUSTED PG13+) so the owner (non-superuser)
  may create them. (pg_stat_statements NOT in EF model -> not needed by migrate.)

## STEP 0.6 — VERIFY-FRESH (ABORT if not empty -> the DROP did not take)
On the new rtmviewdb assert ALL: (a) to_regclass('public.hist_queue_intervals') IS NULL; (b) to_regprocedure(
'fn_hist_ensure_partitions(text,int,int)') IS NULL; (c) __ef_migrations_history absent/empty.
If ANY is non-empty -> ABORT (recreate failed / wrong DB) and report — do NOT migrate/seed. Print PASS/FAIL.

## STEP 1 — APPLY v3 EF migrations PROPERLY (as ccdashboard_user / owner; the schema+function source of truth)
Connection = ccdashboard_user (-AppPassword), owner of the fresh DB -> creates tables/functions + TRUSTED ext pg_trgm+pgcrypto itself, NO grants needed, objects app-owned for runtime.
`Web.exe migrate` (App+Audit) OR `dotnet ef database update --context AppDbContext` (+ Audit context) on v3.
This creates: fn_hist_ensure_partitions(text,int,int) + fn_hist_drop_aged + hist_queue_intervals/hist_agent_intervals
(partitioned: PRIOR+current+next2 + DEFAULT) + arch_* + TenantSettings.SlThresholdSeconds + UserReport soft-delete +
the 2 composite indexes, AND records 20260621080000 + step-0 in __ef_migrations_history.
VERIFY-OR-ABORT before seeding: to_regprocedure('fn_hist_ensure_partitions(text,int,int)') MUST be NOT NULL + hist_*/arch_*
exist + __ef_migrations_history contains the v3 migrations. If to_regprocedure is NULL AFTER a clean migrate on a
verified-empty DB -> ABORT and DUMP: SELECT * FROM __ef_migrations_history ORDER BY 1 (would prove
migration-records-without-creating = real bug -> hand to dba). On a truly fresh DB the migration Up()
(20260621080000 line 144, CONFIRMED inside Up) creates the function -> 42883 gone. Print PASS/FAIL.

## STEP 2 — SEED REFERENCE + RTSData_* (DATA-ONLY INSERT; tenant=Platform; as ccdashboard_user)
INSERT only (tables already exist from STEP-1). tenant=existing Platform (Superadmin login); tenant_settings SlThresholdSeconds=20.
- 3 NGC_Queues: SALES/SUPPORT/BILLING (IsActive). 5 agents agent101..105 + NGC graph (BU->Supergroup->Agentgroup->agents).
- LAST 7 DAYS, business hours 09:00-18:00, 30-min buckets.
- RTSData_Interaction per queue/interval: offered 5-30, answered ~85-95%, abandoned rest; TimeInQueue (mix </>20s for SL),
  TalkTime 120-400s; InteractionType='Call' CallType='External' Direction='Incoming'; InQueueDateTime/AnsweredDateTime in-bucket;
  Workgroup=queue ExternalId; UserId=handling agent. OnDate dd/MM/yyyy. N1-SEED RULE: each answered interaction's
  AnsweredDateTime sits INSIDE that agent's ONPHONE status interval in the SAME 30m bucket (floor coincides).
- RTSData_UserStatusLog per agent: AVAILABLE / ONPHONE (incl a StatusId='Hold' sub-row -> SumHoldMs>0) / PAPERWORK
  (StatusId='Wrap Up') / BREAK; Duration bigint = ms; StartTime/EndTime; StatusGroup; UserId=agent. N2: NO LOGGED_IN row.
ON CONFLICT (Interaction: InteractionId+Segment+ServerId) idempotent.

## STEP 3 — SEED hist_* DATA-ONLY (INSERT, PATH A 7-day; NO CREATE TABLE/FUNCTION)
Direct INSERT into the migration-created hist_queue_intervals/hist_agent_intervals for the full 7 days, formulas MATCHING
HistoricalAggregationService EXACTLY (queue exact per dba; agent N1/N2 per dba):
- PARTITIONS: the migration's initial partitions (PRIOR+current+next2 months) cover the last 7 days; to be safe FIRST call
  `SELECT fn_hist_ensure_partitions('hist_queue_intervals',1,2); SELECT fn_hist_ensure_partitions('hist_agent_intervals',1,2);`
  (the function now exists from STEP-1). Then INSERT.
- hist_queue_intervals: offered/answered/abandoned/answeredInSl(TimeInQueue<=Sl=20 & answered)/sumWaitAnswered/sumTalk;
  bucket=floor(InQueueDateTime,30m); QueueId via NGC_Queues.ExternalId=Workgroup; key (TenantId,IntervalStart,Workgroup).
- hist_agent_intervals: ROW ONLY where a status-log exists in the bucket; SumOnphoneMs=Sum(all ONPHONE);
  SumHoldMs=Sum(ONPHONE&&StatusId='Hold') subset; SumAvailable/Paperwork/Break/Training/UnavailableMs per group;
  SumLoggedInMs=Sum(ALL bucket status durations); Handled=Count(answered by agent) by floor(AnsweredDateTime), matched to
  (IntervalStart,AgentExternalId); key (TenantId,IntervalStart,AgentExternalId).
- ON CONFLICT (natural keys) DO UPDATE -> idempotent.

## STEP 4 — VERIFY (acceptance = ZERO startup errors) — print a clear PASS/FAIL line at EACH gate (0.6, 1, 4)
1. `SELECT COUNT(*)` hist_queue_intervals/hist_agent_intervals > 0 for the tenant/range.
2. `dotnet run` (or Web.exe) on v3 -> STARTUP LOG SHOWS ZERO ERRORS: BOTH HistoricalAggregationService AND ArchiverService
   resolve fn_hist_ensure_partitions (NO 42883, NO BackgroundService unhandled / host StopHost). Listener up.
3. Superadmin login -> /reports -> all 4 tabs render 7-day data (queue AHT=Talk; agent AHT full, Hold>0).

## ACCEPTANCE
- Reset done; v3 EF migration applied + recorded (__ef_migrations_history); fn_hist_ensure_partitions present.
- Seed is DATA-ONLY (zero CREATE TABLE/FUNCTION in the seed), idempotent, DEV-guarded, parameterized.
- Shell starts with ZERO errors (both BG services OK); /reports shows 7-day data.
- db/dev-seed/seed_historical_dev.sql REWORKED to DATA-ONLY (INSERT only, no CREATE TABLE/FUNCTION) — REPLACES the old 183b404 CREATE-TABLE version; committed on v3 (db:), commit.lock, NO push. (The reset+migrate steps are operational, run by the prompt; the committed .sql = the reusable data-only seed.)

## STEP 5 — CAPTURE (NORM-CUR-11) — append to role-bi §B (single-source skill edit, this CC run, docs: on v3)
Append a dated, source-pinned §B lesson to .claude/skills/role-bi/role-bi.md:
"<date> · dev seed 183b404 CREATE-TABLE'd hist_* + omitted fn_hist_* + skipped the EF migration -> both BG services
(HistoricalAggregationService + ArchiverService) 42883 fn_hist_ensure_partitions on startup -> .NET8 host StopHost (no
listener). · RULE: a dev/data seed MUST be DATA-ONLY (INSERT); schema + functions are EF-migration-owned — seed-created
schema desyncs __ef_migrations_history AND omits migration functions -> startup 42883. Always migrate-first, seed data-only.
· SOURCE: 183b404, HistoricalAggregationService EnsurePartitionsAsync, coordinator 2026-06-22 · status: active"
Keep §A within its cap (this is a §B append).

## STEP 6 — binding RESULT -> .coord/cc/bi.md + ping dba (reset+migration safety) + report. NO git push (§37).
