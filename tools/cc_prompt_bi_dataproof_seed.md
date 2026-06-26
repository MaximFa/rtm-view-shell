# CC TASK — DATA-PROOF seed: one report-screen, 1 widget/type, REAL data (G-DATA / VC22-28,30-31)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП ACTIVE — no-run-without-bless. Do NOT run until coordinator §4-bless + operator run-timing.
> REV (2026-06-26): scope = BU-ONLY (operator). ALL 5 widgets use {"scope":{"businessUnitIds":[<int>],"agentAxis":"detail"}} — NO queueIds. Depends on the BU-only refactor (cc_prompt_bi_scope_buonly.md) + backfill landing first.
> GOAL: seed ONE report-screen "DATA PROOF" with one report-widget of EACH of the 5 types, each bound to a REAL
> scope that HAS hist_* rows in the TARGET DB, so the operator opens it in **View** (no editor) and sees REAL
> historical data render in all 5 widget types. Plus an SQL row-count PROOF per widget. Idempotent. NO migration. NO push.
> DATA-AGNOSTIC: the seed SELF-DISCOVERS the data-bearing tenant + scopes, so it works for BOTH run-timings:
>   A = current dev rtmviewdb (proves the widget path renders data at all) · B = the migrated DB loaded with the 234
>   prod-mirror backup (real-data proof). Same script; it picks whatever tenant/scope actually has rows.

## Mandatory — read before starting (NORM-CUR-11 / §40)
Read file: .claude/skills/role-bi/role-bi.md   (§A CORE incl ⛔ЧП block at top + §C VERIFY against current code)
Read file: .claude/skills/session-coord/session-coord.md   (§1 runbook, §10 commands)
Only after reading: proceed. Reality wins — if §A disagrees with code/schema, the code/schema is right.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim (§0.6a/§0.6b)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD          # MUST be v3 (else: git checkout v3)
git rev-parse HEAD                        # record base SHA (object-store truth, §0.5)
git status --short
# for each M: hash-verify WT vs HEAD (git hash-object <f> vs git rev-parse HEAD:<f>);
# if truncated/NUL -> restore: git show HEAD:<f> > <f>. Do NOT trust mount line counts.
```
- CLAIM (file-mode, db): `db/dev-seed/seed_dataproof_screen.sql` (NEW) + `.claude/skills/role-bi/role-bi.md` (§B lesson only).
  No overlap with shell [web] / dba / backend (verified by coordinator: db/dev-seed unclaimed).
- BINDING PREAMBLE — append to `.coord/cc/bi.md` (Python+fsync):
  `## BINDING <UTC> | spec: bi | directive: tools/cc_prompt_bi_dataproof_seed.md | status: open`
  `### DIRECTIVE: DATA-PROOF seed (1 screen, 5 widgets/type, real scope-with-rows, row-count proof). claim db/dev-seed/seed_dataproof_screen.sql. gate: coordinator §4-bless + operator run-timing. seed:/feat: commit, commit.lock, NO push.`

## TARGET-DB GUARD (DEV / MIRROR only — NEVER a real prod DB)
- Params: `-DbName` (default `rtmviewdb`), `-AppPassword` (ccdashboard_user), `-Confirm` (must equal `DATA-PROOF`).
- ABORT unless `-Confirm DATA-PROOF` AND DbName ∈ {rtmviewdb, the named 234-mirror DB the operator passes}. 234 is a
  prod-MIRROR (NOT prod) — allowed when the operator names it. Print the resolved DbName before any write.
- Run as `ccdashboard_user` (owner). NO superuser needed (data-only INSERT, no DDL).

## STEP 1 — PRECONDITION: schema present (DATA-ONLY; ABORT if not migrated — do NOT create anything)
Verify (psql, ABORT with a clear message pointing to migrate-first if any is missing — this seed creates NOTHING):
- tables `report_screens`, `report_widgets`, `report_permissions` exist (EF migration 20260624093015_AddReportEntities).
- tables `hist_queue_intervals`, `hist_agent_intervals` exist + `to_regprocedure('fn_hist_ensure_partitions(text,int,int)')` NOT NULL (20260621080000_AddHistoricalReportsTables).
This seed is **DATA-ONLY**: NO CREATE TABLE / NO CREATE FUNCTION / NO EF migration (role-bi §B 2026-06-22 lesson — seed-created schema desyncs __ef_migrations_history + 42883).

## STEP 2 — SELF-DISCOVER the data-bearing tenant + scopes (ABORT if none — never seed an empty proof)
Use psql `\gset` (or a DO block with SELECT INTO + RAISE). All discovery is per the column/join facts below.

2a. **Tenant** = the TenantId with the MOST hist rows (works on dev AND 234):
```sql
SELECT t."Id" AS tenant_id
FROM tenants t
JOIN (
  SELECT "TenantId", COUNT(*) n FROM hist_queue_intervals GROUP BY "TenantId"
  UNION ALL
  SELECT "TenantId", COUNT(*) n FROM hist_agent_intervals GROUP BY "TenantId"
) h ON h."TenantId" = t."Id"
GROUP BY t."Id" ORDER BY SUM(h.n) DESC LIMIT 1;
```
ABORT if NULL (no hist data anywhere → nothing to prove; tell operator to seed/load data first).

2b. **Owner user** (CreatedByUserId/UpdatedByUserId — must be a real user in that tenant; prefer a Superadmin/Admin):
```sql
SELECT u."Id" FROM identity.users u
WHERE u."TenantId" = :tenant_id
ORDER BY (u."NormalizedUserName" LIKE '%SUPER%') DESC, u."Id" LIMIT 1;
```
If NULL (e.g. Superadmin has TenantId = platform, not the data tenant): fall back to ANY user; if still none, use the platform-tenant Superadmin Id (record which, in RESULT).

2c. **BU scope (ALL 5 widgets — scope is BU-only)** — pick ONE NGC_BusinessUnit that resolves to BOTH (i) queues with
    hist_queue_intervals rows (BU→NGC_BusinessUnitQueueClassification ClassificationId='ALL'→QueueId=workgroup) AND
    (ii) agents with hist_agent_intervals rows (BU→SG→AG→User). So one BU drives all 5 widgets:
```sql
WITH bu_q AS (   -- BU -> queues-with-rows (queue widgets)
  SELECT bqc."BusinessUnitId" AS bu_id, COUNT(DISTINCT h."Workgroup") AS queues_with_data,
         SUM(h."Answered") + SUM(h."Abandoned") AS qact
  FROM "NGC_BusinessUnitQueueClassification" bqc
  JOIN hist_queue_intervals h ON h."Workgroup" = bqc."QueueId" AND h."TenantId" = bqc."TenantId"
  WHERE bqc."TenantId" = :tenant_id AND bqc."ClassificationId" = 'ALL'
  GROUP BY bqc."BusinessUnitId"
), bu_a AS (      -- BU -> agents-with-rows (agent widgets)
  SELECT bus."BusinessUnitId" AS bu_id, COUNT(DISTINCT h."AgentExternalId") AS agents_with_data
  FROM "NGC_BusinessUnitSupergroup" bus
  JOIN "NGC_SupergroupAgentgroup" sag ON sag."SupergroupId" = bus."SupergroupId" AND sag."TenantId" = bus."TenantId" AND sag."AgentgroupId" IS NOT NULL
  JOIN "NGC_UserAgentgroup" uag ON uag."AgentgroupId" = sag."AgentgroupId" AND uag."TenantId" = bus."TenantId" AND uag."UserId" IS NOT NULL
  JOIN hist_agent_intervals h ON h."AgentExternalId" = uag."UserId" AND h."TenantId" = bus."TenantId"
  WHERE bus."TenantId" = :tenant_id
  GROUP BY bus."BusinessUnitId"
)
SELECT q.bu_id, q.queues_with_data, a.agents_with_data
FROM bu_q q JOIN bu_a a ON a.bu_id = q.bu_id
ORDER BY q.qact DESC, a.agents_with_data DESC
LIMIT 1;
```
ABORT if NULL (no single BU has BOTH queue-data AND agent-data → report clearly: the operator may need to pick a BU per
widget-family, or the BU mappings need seeding). Prefer a BU with queue Answered+Abandoned>0 so Distribution is non-empty.

Print the discovered tenant_id / owner_user / bu_id (+queues_with_data, agents_with_data) BEFORE inserting (PASS/FAIL gate).

## STEP 3 — SEED the screen + 5 widgets (idempotent, fixed UUIDs; ON CONFLICT upsert)
Fixed UUID literals (so re-run upserts the SAME rows):
- screen   = `11111111-1111-4111-8111-111111111111`
- w.QueueInterval    = `21111111-1111-4111-8111-111111111111`
- w.QueueWaitTime    = `22222222-2222-4222-8222-222222222222`
- w.AgentMonthly     = `23333333-3333-4333-8333-333333333333`
- w.AgentShiftDetail = `24444444-4444-4444-8444-444444444444`
- w.Distribution     = `25555555-5555-4555-8555-555555555555`

**report_screens** (cols verbatim; Status string 'Published'; IsPublic=true so View works for any tenant user AND
superadmin bypass; xmin auto):
```sql
INSERT INTO public.report_screens
  ("Id","TenantId","Name","Description","CategoryId","Status","IsPublic","IsDarkMode","LayoutJson",
   "CreatedByUserId","CreatedAt","UpdatedByUserId","UpdatedAt","IsDeleted","DeletedAt","DeletedByUserId")
VALUES
  ('11111111-1111-4111-8111-111111111111', :tenant_id, 'DATA PROOF',
   'Auto-seeded data-proof screen — 1 widget per type bound to a real scope with rows.', NULL,
   'Published', true, false, NULL, :owner_user, now(), :owner_user, now(), false, NULL, NULL)
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId"=EXCLUDED."TenantId","Status"='Published',"IsPublic"=true,"IsDeleted"=false,
  "DeletedAt"=NULL,"DeletedByUserId"=NULL,"UpdatedByUserId"=EXCLUDED."UpdatedByUserId","UpdatedAt"=now();
```

**report_widgets** (WidgetType stored as the ENUM-NAME STRING; ConfigJson jsonb; PositionJson non-overlapping
{x,y,width,height}). Build each ConfigJson with the DISCOVERED ids. ConfigJson is **camelCase** (JsonNamingPolicy.CamelCase),
Columns OMITTED → server DefaultColumns(type) applies (a7e213b). Validator-valid (Scope present; QueueIds for queues,
BusinessUnitIds+agentAxis for bu):

| Widget | WidgetType | PositionJson | ConfigJson (substitute discovered ids) |
|---|---|---|---|
| QI  | `QueueInterval`    | `{"x":0,"y":0,"width":600,"height":320}`     | `{"scope":{"businessUnitIds":[<BU_INT>],"agentAxis":"detail"},"interval":30}` |
| QW  | `QueueWaitTime`    | `{"x":620,"y":0,"width":600,"height":320}`   | `{"scope":{"businessUnitIds":[<BU_INT>],"agentAxis":"detail"}}` |
| AM  | `AgentMonthly`     | `{"x":0,"y":340,"width":600,"height":320}`   | `{"scope":{"businessUnitIds":[<BU_INT>],"agentAxis":"detail"}}` |
| ASD | `AgentShiftDetail` | `{"x":620,"y":340,"width":600,"height":320}` | `{"scope":{"businessUnitIds":[<BU_INT>],"agentAxis":"detail"}}` |
| DST | `Distribution`     | `{"x":0,"y":680,"width":600,"height":320}`   | `{"scope":{"businessUnitIds":[<BU_INT>],"agentAxis":"detail"}}` |

```sql
INSERT INTO public.report_widgets
  ("Id","ReportScreenId","TenantId","WidgetType","PositionJson","ConfigJson","IsDeleted")
VALUES (<wid>, '11111111-1111-4111-8111-111111111111', :tenant_id, '<WidgetType>',
        '<PositionJson>'::jsonb, '<ConfigJson>'::jsonb, false)
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId"=EXCLUDED."TenantId","WidgetType"=EXCLUDED."WidgetType",
  "PositionJson"=EXCLUDED."PositionJson","ConfigJson"=EXCLUDED."ConfigJson","IsDeleted"=false;
```
(One INSERT per widget. ALL 5 use the SAME BU scope {businessUnitIds:[<BU_INT>],agentAxis:"detail"} — queue widgets resolve their queues server-side from the BU; agentAxis ignored by queue widgets. agentAxis "detail" serializes from AgentReportAxis.Detail via CamelCase. NO mode/queueIds.)

**report_permissions** — OPTIONAL: IsPublic=true already makes the screen visible to all tenant users, and Superadmin
bypasses PG. Do NOT add a permission row unless a non-public path is wanted (keep it simple; note this in RESULT).

## STEP 4 — ROW-COUNT PROOF per widget (the data path produces output BEFORE the visual)
RunReportWidgetQuery uses window [from, To.Date.AddDays(1)) and reads hist_* filtered by the resolved scope. Mirror that
read with a WIDE window (e.g. from='2000-01-01', to_excl='2100-01-01') and COUNT — cite counts in RESULT:

- QueueInterval / QueueWaitTime / Distribution (scope = chosen BU → its resolved workgroup SET; widgets are BU-AGGREGATED → one row/interval):
```sql
WITH wg AS (   -- BU -> workgroups (same path the handler uses: ClassificationId='ALL')
  SELECT DISTINCT bqc."QueueId" AS workgroup
  FROM "NGC_BusinessUnitQueueClassification" bqc
  WHERE bqc."BusinessUnitId" = :bu_id AND bqc."TenantId" = :tenant_id AND bqc."ClassificationId" = 'ALL'
)
SELECT COUNT(DISTINCT h."IntervalStart") AS aggregated_rows,   -- = BU-aggregated row count (one per interval)
       COUNT(*)                          AS raw_workgroup_rows,
       SUM(h."Answered") + SUM(h."Abandoned") AS qact            -- Distribution needs > 0 for non-empty buckets
FROM hist_queue_intervals h JOIN wg ON wg.workgroup = h."Workgroup"
WHERE h."TenantId" = :tenant_id
  AND h."IntervalStart" >= '2000-01-01' AND h."IntervalStart" < '2100-01-01';
-- aggregated_rows > 0 = the BU-aggregated queue widgets render; qact > 0 = Distribution non-empty.
```
- AgentMonthly / AgentShiftDetail (scope = chosen BU → resolved AgentExternalId set):
```sql
WITH agents AS (
  SELECT DISTINCT uag."UserId" AS ext
  FROM "NGC_BusinessUnitSupergroup" bus
  JOIN "NGC_SupergroupAgentgroup" sag ON sag."SupergroupId"=bus."SupergroupId" AND sag."TenantId"=bus."TenantId" AND sag."AgentgroupId" IS NOT NULL
  JOIN "NGC_UserAgentgroup" uag ON uag."AgentgroupId"=sag."AgentgroupId" AND uag."TenantId"=bus."TenantId" AND uag."UserId" IS NOT NULL
  WHERE bus."BusinessUnitId" = :bu_id AND bus."TenantId" = :tenant_id
)
SELECT COUNT(*) AS interval_rows,
       COUNT(DISTINCT to_char(h."IntervalStart",'YYYY-MM')) AS distinct_months,
       COUNT(DISTINCT h."AgentExternalId") AS distinct_agents
FROM hist_agent_intervals h JOIN agents a ON a.ext = h."AgentExternalId"
WHERE h."TenantId" = :tenant_id
  AND h."IntervalStart" >= '2000-01-01' AND h."IntervalStart" < '2100-01-01';
```
ACCEPTANCE (functional, QA floor): every widget's count > 0 (AgentMonthly groups by month → distinct_months>0;
AgentShiftDetail → interval_rows>0; Distribution → Answered+Abandoned sum > 0 ideally, else note empty-but-valid).
If any is 0, the proof is INCOMPLETE — report exactly which widget + scope so coordinator/operator can adjust the scope.
OPTIONAL cross-check: the chosen scope's counts should equal what the legacy Q1/Q5/A4/A5 path returns for the same
scope+range (same hist_* source) — note if you can corroborate via Soma /db or the old /reports.

## STEP 5 — COMMIT (db/dev-seed/seed_dataproof_screen.sql) + binding RESULT + re-sync
- Write the assembled, idempotent script to `db/dev-seed/seed_dataproof_screen.sql` (the discovery + inserts + proof,
  parameterized; header comment = purpose + DATA-PROOF guard + "DATA-ONLY, NO migration"). §0.3 write discipline.
- commit.lock (atomic open "x", retry 5×60s; content-based phantom check L-SC-10/14) → `bash tools/pre-commit-check.sh`
  → `git add db/dev-seed/seed_dataproof_screen.sql` → commit `seed: DATA-PROOF report-screen (1 widget/type, real scope) [bi]`
  → §0.6 post-commit verify → `tools/cc_post_commit.sh bi-0626 <hash>` (journal+flush+lock-release) → §0.7 re-sync from HEAD.
- BINDING POSTAMBLE — append RESULT to `.coord/cc/bi.md`:
  `### RESULT: commit <hash> . file db/dev-seed/seed_dataproof_screen.sql (<lines>) . screen 11111111-… . tenant <id> . queue <id>/<workgroup> . bu <id> (<agents> agents) . per-widget proof counts: QI=<n> QW=<n> AM(months)=<n> ASD(rows)=<n> DST(ans+aband)=<n> . status done|failed . verified: object-store . NO push`
  status: done.
- §0.6b CAPTURE (only if a real lesson emerges, e.g. a scope/column gotcha) → append dated SOURCE-pinned line to role-bi §B (git add -f).

## DO NOT
- Do NOT run any EF migration / CREATE TABLE / CREATE FUNCTION (DATA-ONLY).
- Do NOT `git push` (§37 — bundled barrier HELD).
- Do NOT seed an empty proof — ABORT at STEP 2 if no data-bearing tenant/queue/BU.
- Do NOT touch files outside the claim (db/dev-seed/seed_dataproof_screen.sql + role-bi §B).

## ACCEPTANCE (definition of done)
1. db/dev-seed/seed_dataproof_screen.sql committed (seed:), idempotent, DATA-ONLY, NO migration.
2. On run against the target DB: screen "DATA PROOF" (Published, IsPublic) + 5 widgets present; each widget's ConfigJson
   bound to a discovered REAL scope WITH hist_* rows.
3. Per-widget row-count proof printed (all > 0; Distribution buckets non-empty or explicitly flagged).
4. RESULT published to .coord/cc/bi.md with screen id + tenant + scopes + per-widget counts.
5. Coordinator personally visual-verifies (ЧП): operator opens the screen in VIEW (no editor) on the target DB and sees
   REAL data in all 5 widget types (VC22-28/30-31).
