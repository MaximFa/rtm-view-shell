# CC task — CONVERGE 234 WITH DATA TRANSFER — our-stack 06-24-schema -> @d1982de  (Rev 12)
> ⛔ЧП. Branch v3. Commits only, **NO push**, ветку НЕ двигать. §4-review by coordinator BEFORE run.
> Operator gets the run-box from **devops-0829** (owner) AFTER bless — one box at a time.
> ⛔ **EVERY run-box opens with WHERE IT RUNS** — machine (DEV / 234), database, read-or-write — as its first line,
> before the code. Phase R boxes and Phase P boxes look alike; the destination is never left to the operator's
> memory. Operator directive 2026-08-29.
> Target product = **d1982de**. Package **Installations\29082026.1119.zip** (131.88 MB, BUILD=0, unit 283/0) — REUSE, do NOT rebuild.
> ⛔ REHEARSAL ON DEV (restore of the 234 dump) IS MANDATORY AND GREEN BEFORE 234. §A: end-to-end on the REAL app, not harness/object-store.
>
> **Rev 3 changelog (answers coordinator §4 REVISE of 2026-08-29T~08:5xZ):** SEAM-1 single transfer source fixed;
> SEAM-2 post-load INTEGRITY check added, separate from row counts; SEAM-3 UserStatusLog FK question answered by
> schema + IDENTITY-resync seam raised (not asked for); SEAM-4 ownership and GRANT verified as two layers;
> SEAM-5 rehearsal weakening clause removed; the 25/26 number reconciled against the migration source.
> Owner handover: authored by devops-0625, taken over in full by **devops-0829** (operator, 2026-08-29).
>
> **Rev 12 (operator decision + coordinator recalibration, 2026-08-30):** the converge no longer touches the
> production database at all. It is executed on the ALREADY-RUNNING PostgreSQL **18.4 instance on port 5433**;
> the live 15.5 on 5432 is left untouched and becomes the rollback. Finish = switch both `appsettings` to 5433 and
> restart OUR two services. Two consequences worth stating plainly: the version mismatch that invalidated the
> rehearsal now resolves in our favour (rehearsal ran on 18, target becomes 18), and the drop of 26 tables happens
> on a fresh copy rather than on live data.
> **Also recalibrated:** 234 is a TEST server attached to the production environment, read-only towards it. The
> thirteen gates collapse into THREE RUNS with three reports; gates remain as in-run checks but no longer stop for
> the coordinator, except the three conditions in §STOP-CONDITIONS. What does NOT relax: legacy RTM, `RTM.Twilio`
> and Garnet are never touched — from this server that would reach production.
>
> **Rev 11 (coordinator 2026-08-30T~03:1xZ — Phase R ACCEPTED, blocking fix before P):** tenant-slug handling
> becomes a STEP (measure on 234 -> write the key -> verify), not a post-check that only discovers the damage;
> the stale duplicate of the probe wording in POST-CHECKS is corrected (it still said "11 markers / open a screen");
> and the two DIFFERENT slug keys are separated, because they are not the same thing.
>
> **Rev 10 (coordinator 2026-08-30T~00:3xZ, BLOCKING before Phase P):** the integrity gate no longer compares to
> ZERO — it compares to the SOURCE BASELINE measured in staging before the reload. 234 already carries 21 dangling
> `RTSGrid_Cell` rows and 81 dangling `NGC_UserAgentgroup` rows; a zero-expecting gate would have fired on the live
> server AFTER the drop, on drift that predates us. PASS = equality with baseline; MORE = we created dangling rows;
> LESS = we silently repaired customer data, which is equally a STOP. **The norm is wider than this case: an
> integrity gate is measured against the state BEFORE the change, not against an ideal.**
>
> **Rev 9 (coordinator 2026-08-29T~22:5xZ):** §TYPE-WIDENING added — widening is allowed and RECORDED with the
> measured MAX() from the dump, narrowing is always a STOP; the drift gate compares against a NAMED APPROVED LIST
> instead of counting tables ("count answers whether something changed, not what"); and §STRUCT-DIFF must complete
> the FULL pass and report ALL drifts in ONE go, pre-classified, instead of one round-trip per finding.
>
> **Rev 8 (markup, coordinator condition 2026-08-29T~19:1xZ):** `rtmviewdb_src` now has a full lifecycle in BOTH
> phases — free-space check with a number BEFORE it is created, `DROP DATABASE` with proof of absence AFTER the
> two drifted tables are copied and the diff is emitted, and "cannot drop" is a STOP, never a leftover. Reason:
> today half a day went into identifying `rtmviewdb_prodstg`, an abandoned DB of unknown history. We do not
> create the next one.
>
> **Rev 7 changelog (rehearsal findings + coordinator §4 of 2026-08-29T~18:5xZ — generalise, do not patch):**
> the reload mechanism is fixed as a CLASS: a full structural diff of all 17 tables runs BEFORE any reload
> (§STRUCT-DIFF), the two drifted tables move by explicit column list, EVERY verify predicate is re-derived from
> `v3:db/schema.sql` with a line pin, the identity resync is done in-procedure over `deptype IN ('a','i')` because
> the standard tool's block is a no-op for identity, the metric check is redirected to the column that actually
> exists, and the columns that do NOT travel are named in the artifact instead of vanishing into the mechanism.
>
> **Rev 6 changelog (coordinator decisions 2026-08-29T~18:0xZ, DEV confirmed ISOLATED):** post-checks split into
> executable-in-R and feed-dependent-P-only; the "3 services" check is 2 services in R (RTM.Twilio is not registered
> on DEV) with the reason stated; DEV connection-string change is now a recorded, reverted config operation; the dump
> must be transported to DEV first, with SHA-256 matching in THREE points. `rtmviewdb_prodstg` is NOT touched.
>
> **Rev 5 changelog (coordinator §4 PASS 2026-08-29T~13:2xZ + mandatory condition):** POST-CHECKS may not be taken before the engine has repopulated the non-transferred RTSData tables — a readiness criterion with numbers is now mandatory in BOTH phases (§FEED-READY below), and a red comparison taken before it is not a conclusion.
>
> **Rev 4 changelog (answers coordinator §4 REVISE of 2026-08-29T~13:0xZ):** the missing DB layer is added as
> explicit steps in BOTH phases — and it turned out to be **three** layers, not two: `db/functions`, a SELECTIVE
> `db/data`, and `db/migrations` (which `Provision-FreshDb` does not run at all and which is the ONLY source of the
> WFM indexes). Two of the four `db/data` files are DESTRUCTIVE to the transfer set and are excluded by name, with
> the mechanism spelled out. The `align.sql` boundary is drawn in writing (§DB-LAYER-BOUNDARY). R3 renamed to a
> real step. Everything else from Rev 3 is unchanged.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-devops/role-devops.md

## Step 0 — INTEGRITY (object-store, §0.2/§0.5)
cd "D:\Claude\Projects\RTM View Shell"; git status --short; git rev-parse v3 origin/v3
git diff --name-only d1982de v3 -- src db deploy RTM devops wwwroot infra scripts CcDashboard.sln global.json appsettings.template.json | wc -l   # expect 0 (tip==d1982de)

## Git push — Do NOT run `git push`. Commit only.

## BINDING preamble (.coord/cc/devops.md)
`## BINDING <UTC> | spec: devops | directive: tools/cc_prompt_converge234_transfer.md | status: open`
`### DIRECTIVE: converge 234 (06-24 schema) -> d1982de WITH data transfer of NGC graph + RTSGrid user widgets + RTSData_UserStatusLog. Rehearsal-on-DEV-first mandatory. Claim: deploy/**, db/tools/**. NO push.`

## WHY (context)
234 sits on the 2026-06-24 schema (App ledger tip `20260624093015_AddReportEntities`). Pending App migrations:
`20260712223405_DropAppOwnedBackendTables`, `20260713041952_PerTenantUserNameIndex`, `20260721110721_WfmTenantSettings`.

**`DropAppOwnedBackendTables` CASCADE-drops 26 backend tables** — counted from the migration source, not from memory:
`git show v3:src/CcDashboard.Infrastructure/Migrations/App/20260712223405_DropAppOwnedBackendTables.cs | grep -ci "DROP TABLE"` = **26**,
26 distinct table names. ⚠ The migration's OWN comment (line ~21) says *"(25 tables total)"* — **the comment is wrong,
the statements are right**; earlier "25" in Rev 2 came from that comment. Do NOT "fix" the comment inside this task
(App-migration file = backend territory, not ours) — it is FLAGGED to the coordinator as a doc-defect.
The 26 include the FULL live NGC topology (BU59/Q61/SG41/AG43/UserAG566 + mappings), RTSGrid/RTSUserGrid and all RTSData.
`schema.sql` recreates the TABLES empty; `db/data` seeds only Site+metrics+grids — NOT the customer's NGC topology /
user widgets / status history. So converge MUST dump -> migrate -> schema.sql -> RELOAD.

## TRANSFER SET (what we preserve) — with rationale
Reload from the 234 backup, in FK dependency order (idempotent vs engine getOrCreate `ON CONFLICT`):
1. **Full NGC graph (9 tables)** — NOT just the 3 human tables. FK integrity: `NGC_BusinessUnitQueueClassification`/`NGC_BusinessUnitSupergroup` FK `NGC_BusinessUnit`; `NGC_BusinessUnitSupergroup`/`NGC_SupergroupAgentgroup` FK `NGC_Supergroup`; `NGC_BusinessUnit` FK `NGC_Site`. Engine getOrCreate (`NGC_GetOrCreateQueue` L96, Supergroup L486, mappings L577/657/716 — all `ON CONFLICT DO NOTHING/UPDATE`) upserts safely over reloaded rows on reconnect. Order:
   NGC_Site -> NGC_BusinessUnit -> NGC_Supergroup -> NGC_Queues -> NGC_AgentGroups ->
   NGC_BusinessUnitQueueClassification -> NGC_BusinessUnitSupergroup -> NGC_SupergroupAgentgroup -> NGC_UserAgentgroup
   (human-only that discovery will NEVER rebuild: NGC_BusinessUnitSupergroup [ConfigurationCommands.cs:142]; human curation not reproduced by discovery: NGC_BusinessUnit names + NGC_BusinessUnitQueueClassification composition [ConfigurationCommands.cs:108/129].)
2. **RTSGrid user widgets (4):** RTSGrid_Grid, RTSGrid_Row, RTSGrid_Column, RTSGrid_Cell — SaveQueueGridRtsCommand.cs:56/86/99/126 (+ SaveAgentGrid/SaveDataSlot). User-built dashboard widgets.
3. **RTSUserGrid (3):** RTSUserGrid_Grid, RTSUserGrid_ColumnsSet, RTSUserGrid_Column.
4. **RTSData_UserStatusLog** — 202917 rows. MidnightClear (02_rtsdata_functions.sql:262-263) clears ONLY Interaction+UserStatus; UserStatusLog accumulates (feeds fn_daytrend + BU-resolver:448). Transfer whole, else DayTrend/history on 234 zeroes out = a "bug" that isn't.
   **[SEAM-3 — FK question answered, from the schema, not from silence]** `RTSData_UserStatusLog` has **NO foreign key at all** —
   its only constraint is `PK_RTSData_UserStatusLog PRIMARY KEY ("Id")` (`db/schema.sql:400-413` DDL, `:876-880` constraint;
   the whole-file FK scan lists no FK on or to this table). `TenantId`/`UserId` are plain columns, not references.
   **=> load order for this table is INDIFFERENT.** It is loaded LAST purely because it is the largest (202917 rows),
   so a failure in the small config set aborts before we spend the time.

NOT transferred (engine repopulates live / seeded fresh): RTSData_Interaction, RTSData_UserStatus, RTSData_ChatMessage (MidnightClear-transient); RTSGrid_Metric/MetricTranslation/Statistic/UserStatus, RTSUserGrid baseline defs, db_patch_history, metric_deploy_log (db/data + migrations).
**⚠ REHEARSAL WATCH — metric references:** db/data seeds baseline metrics; 234 had metric drift (1 missing `QueueNumberOfCompletedIncomingCalls` + 6 extra incl. typo `QueueNumAbandonefCalls`). After db/data seed, VERIFY every reloaded RTSGrid_Cell.MetricId resolves against RTSGrid_Metric. Any dangling ref -> STOP, report which metric rows must be transferred too (do NOT perpetuate the typo blindly).

## TRANSFER MECHANISM
**[SEAM-1 — ONE source, no fork]** The reload source is **`C:\RTMView-Ops\backup\rtmviewdb_20260829_1129.dump`**
(custom format) — the SAME physical file in the rehearsal (R6) and on 234 (P5). **No intermediate dump is produced
at any point.** Re-dumping out of `rtmviewdb_reh` is explicitly FORBIDDEN: a re-dump is taken after a restore and
carries its own encoding, ordering and possible losses, so the rehearsal would exercise a DIFFERENT artifact than
the one that goes to production. If for any reason the original dump cannot serve as the reload source, that is a
STOP to the coordinator, not a substitution.

Selective, order-safe, identity-safe, run as postgres/owner. **Two mechanisms, chosen by §STRUCT-DIFF:**
· **Structure identical (15 tables):** `pg_restore --data-only --disable-triggers --table="<T>" <dump>`
· **Structure drifted (`NGC_Queues`, `NGC_AgentGroups`):** explicit column-list copy out of the staging DB —
  `psql -d rtmviewdb_src -c "\copy (SELECT \"Id\",\"TenantId\",\"ExternalId\",\"Name\",\"IsActive\" FROM public.\"<T>\") TO STDOUT"`
  piped into `psql -d <target> -c "\copy public.\"<T>\" (\"Id\",\"TenantId\",\"ExternalId\",\"Name\",\"IsActive\") FROM STDIN"`.
  Ids are preserved, no intermediate file is written. ⛔ Do NOT instead "let the engine rebuild queues": both tables
  are bucket-1, but `NGC_BusinessUnitQueueClassification."QueueId"` (varchar, `schema.sql:176-181`) references
  `NGC_Queues."ExternalId"` (`schema.sql:214-220`), so engine-recreated rows with different `Id`s would leave all
  61 classification rows pointing at nothing.
(`--disable-triggers` bypasses FK validation DURING load — hence the mandatory post-load integrity check below;
`--data-only` preserves IDENTITY values in the rows).

**[SEAM-3b — IDENTITY resync — CONFIRMED BY EXPERIMENT, and the standard tool does NOT do it]**
⛔ `Provision-FreshDb.ps1` step 7 (block copied from `Restore-All.ps1`) selects sequences by
`pg_depend.deptype='a'`. Measured on the rehearsal DB 2026-08-29: **all 15 sequences in `public` are `deptype='i'`,
none are `'a'`** — because `GENERATED ALWAYS AS IDENTITY` sequences are INTERNAL dependencies. The standard block
therefore resyncs NOTHING, silently, and `pg_sequence_last_value` stays NULL. Do NOT rely on it: this procedure runs
its OWN resync selecting `deptype IN ('a','i')`, after the reload and before services start, then verifies every
sequence is ahead of its column max. (The tool defect is filed separately as a `db/tools` change; suspected root
cause of the server-45 `23505` incident.)
12 of the transferred tables have
`GENERATED ALWAYS AS IDENTITY` keys (`db/schema.sql`, ALTER ... ADD GENERATED ALWAYS AS IDENTITY):
NGC_BusinessUnit, NGC_Supergroup, NGC_SupergroupAgentgroup, NGC_UserAgentgroup, RTSData_UserStatusLog,
RTSGrid_Grid, RTSGrid_Row, RTSGrid_Column, RTSGrid_Cell, RTSUserGrid_Grid, RTSUserGrid_ColumnsSet, RTSUserGrid_Column.
A `--data-only` COPY inserts the existing key values but **does NOT advance the owning sequence**, so the first
engine/UI insert after start collides -> `23505 duplicate key`. This is not hypothetical: it is exactly the class
that bit server 45 (role-devops §B, 2026-06-07: "42P10 / 23505 IDENTITY seq"; PD-008 P6 IDENTITY-resync step).
**Therefore, after the reload and BEFORE services start**, for each of the 12 tables run, as owner:
`SELECT setval(pg_get_serial_sequence('public."<T>"','<IdCol>'), COALESCE((SELECT MAX("<IdCol>") FROM public."<T>"), 0) + 1, false);`
then VERIFY: `SELECT last_value FROM <seq>` > `MAX(<IdCol>)` for all 12. Any sequence not ahead of its max = STOP.

## ═══ §DB-LAYER — FUNCTIONS + DATA + MIGRATIONS (Rev 4; every claim pinned) ═══
Canonical order, from the tool itself: `Provision-FreshDb.ps1:4` — *"drop -> init -> migrate(shell) -> schema.sql ->
functions -> data"* (steps enumerated at `:9-12`). Rev 3 had `migrate` and `schema.sql` and stopped there. Restored
below — **with three corrections found while pinning it.**

**Hard ordering rule:** `functions` and `data` run **BEFORE** the RELOAD, never after. Reason in (2): two of the four
`db/data` files TRUNCATE exactly the tables we are restoring.

### (1) FUNCTIONS — apply in full, idempotent, pinned
Files, in order: `db/functions/01_ngc_functions.sql`, `02_rtsdata_functions.sql`, `03_rtsgrid_read.sql`,
`04_misc_functions.sql` (as postgres/owner).
Idempotency measured, not assumed — `CREATE OR REPLACE` / kind-agnostic `DROP` guard counts per file:
01 = 26 / 44 · 02 = 14 / 14 · 03 = 8 / 10 · 04 = 3 / 3. The only two bare `CREATE` statements are
`01_ngc_functions.sql:753 CREATE PROCEDURE "NGC_SetUserAgentgroup"` and `:772 CREATE PROCEDURE "NGC_DeleteUserAgentgroup"`,
and BOTH are immediately preceded by `DROP ROUTINE IF EXISTS ...` (`:752`, `:771`) — so re-running is safe. They must
stay PROCEDUREs, not FUNCTIONs (`CALL` from RTM DBAdapter, CLAUDE.md §33.8 [RTM-SEC-002]); `CREATE OR REPLACE` cannot
change routine kind, which is why the DROP is there.
**This is the layer the coordinator's post-check depends on:** `01dbc2c` ("supersede per-row-TZ guard — interaction
load filter by UpdateTime SERVER-LOCAL date") changed `db/functions/02_rtsdata_functions.sql` and NOTHING else
(`git show --stat 01dbc2c` = 1 file, +2/-10). Without this layer 234 keeps the June function, the Queue-Grid-vs-legacy
post-check goes red on its own, and we would be tempted to write it off as "drift".

### (2) DATA — SELECTIVE, and this is a correction to the canonical order
`db/data/**` contains four files. Applying the directory wholesale (as `Provision-FreshDb` does, `:12` "name-sorted")
would **destroy the transfer set**:
- `db/data/03_rtsgrid.sql` — `TRUNCATE TABLE "RTSGrid_Grid"/"RTSGrid_Row"/"RTSGrid_Column"/"RTSGrid_Cell"` (+ the three
  RTSUserGrid tables) `RESTART IDENTITY CASCADE` — seven TRUNCATEs, hitting **exactly** transfer-set items 2 and 3
  (the customer's 32/62/77/338 widgets and 14/2/2 user grids), and reseeding a 1-grid/1-row/5-column baseline.
- `db/data/04_catalog.sql` — `TRUNCATE TABLE "NGC_Site" RESTART IDENTITY CASCADE`. `NGC_Site` is the PARENT of
  `NGC_BusinessUnit` (`FK_NGC_BusinessUnit_NGC_Site_SiteId`), and TRUNCATE ... CASCADE truncates every table with an FK
  to the named one — so this **empties `NGC_BusinessUnit`, and through it `NGC_BusinessUnitQueueClassification` and
  `NGC_BusinessUnitSupergroup`**: the entire human composition, in one statement. (`ON DELETE SET NULL` does not help —
  it governs DELETE, not TRUNCATE.)
**=> Applied: `02_metrics.sql` and `05_metric_translations.sql` only. NOT applied: `03_rtsgrid.sql`, `04_catalog.sql`** —
their whole content is superseded by the transfer set (the customer's own grids and sites), so skipping them loses
nothing and running them loses everything. If the rehearsal shows `NGC_Site` in the dump is NOT a superset of the three
baseline rows (`IL`, `SITE001`, `SITE002`), that is a STOP to the coordinator, not a reason to run `04`.
`02_metrics.sql` itself does `TRUNCATE "RTSGrid_Metric"/"RTSGrid_Statistic" RESTART IDENTITY CASCADE` — harmless here
because we do NOT transfer metrics, and no FK anywhere in `db/schema.sql` has an `RTSGrid_*` table as parent (checked:
zero `REFERENCES public."RTSGrid` in the whole schema), so nothing cascades out of it. `05` deletes only
`ru-RU`/`he-IL` translation rows and re-inserts them.
**Metric-reference consequence, stated precisely:** `RTSGrid_Metric."MetricId"` is `character varying(100)`
(`db/schema.sql:515`), i.e. a STRING key — so `RESTART IDENTITY` cannot silently renumber it and `RTSGrid_Cell.MetricId`
references survive by NAME. The residual risk is only the 6 extra 234-local metrics disappearing after the TRUNCATE,
which the existing rehearsal-watch check catches. Note the "1 missing" one, `QueueNumberOfCompletedIncomingCalls`, IS
present in the baseline (`02_metrics.sql`, 1 row) — the seed closes that gap by itself.

### (3) DB MIGRATIONS — a THIRD layer, absent from Provision entirely
`Provision-FreshDb.ps1` never mentions `db/migrations` (grep = 0 hits); `Update-RTMView.ps1`, `Create-FreshDb.ps1`,
`Compare-ToBaseline.ps1` do. `db/migrations/**` = 27 files. This matters concretely: **`83ce56b` (WFM Phase-1 covering
indexes) lives in `db/migrations/20260721_001_wfm_indexes.sql` and its indexes are NOT in `schema.sql`** (grep for
`ix_rtsint_wfm_inq|ix_rtsint_wfm_ans|ix_rtsus_wfm` in `v3:db/schema.sql` = 0). So after `schema.sql` alone the WFM
indexes simply do not exist, and the WFM post-check is measured without them.
Apply as postgres: **`20260721_001_wfm_indexes.sql`** (4 × `IF NOT EXISTS`) and **`20260622_001_arch_contour_indexes.sql`**
(`CREATE INDEX CONCURRENTLY IF NOT EXISTS`, must NOT run inside a transaction — the file says so itself).
`20260713_001_add_completed_incoming_calls.sql` is `ON CONFLICT DO NOTHING` and already covered by the `02_metrics`
seed — applying it is harmless, skipping it is equally correct; apply it for ledger completeness (§38a self-record).
The remaining `db/migrations` files are dated 2026-06-13 and earlier and target the 45-era reconcile; they are NOT
applied here — see the boundary below. Every applied file self-records into `db_patch_history` (§38a).

### §DB-LAYER-BOUNDARY — what we apply from `db/`, what we do not, and why `align.sql` stays out
The distinction is DIRECTION, and it is not a nuance:
- **`align.sql` is GENERATED by `Compare-ToBaseline` from a repo baseline** and moves the server toward that baseline.
  On 234 the baseline is BEHIND the server, so align would drag a live server BACKWARDS — that is §38.5 ("advisory,
  verify direction") and the RTM-SEC-002 precedent where the routine-kind section of an align could break a correct
  server. **Not applied. Unchanged from Rev 3.**
- **`db/functions/**` and `db/data/02+05` are PRODUCT SOURCE at the target revision.** Pinned:
  `git diff --name-only d1982de v3 -- db` = **0** — the `db/` tree on `v3` IS `d1982de`. Applying them is not "aligning
  to a stale baseline", it is bringing the database half of the product up to the same commit as the binaries we are
  swapping in. Refusing them would ship binaries from d1982de against June functions — a split-version server, which is
  precisely the RTM-DEPLOY-001 class ("signature change = Shell and DB in ONE release, else 42883").
- **`db/migrations/**`: only the two index files + the metric file above.** The 2026-06-13 reconcile set is excluded
  because it encodes the 45-era drift repair, not the d1982de product state — that IS baseline-shaped and belongs to
  the same family as align.
- **Nothing in `db/` is applied that we have not named here by filename.** If the rehearsal reveals a needed file
  outside this list, that is a STOP to the coordinator with the filename — not a judgement call at the console.

## ═══ §TARGET — WHERE THIS RUNS (Rev 12) ═══
| | |
|---|---|
| **Converge target** | PostgreSQL **18.4**, port **5433** (`postgresql-x64-18`), instance currently EMPTY |
| **Production DB** | PostgreSQL **15.5**, port **5432** — **NOT MODIFIED AT ANY STEP**; it is the rollback |
| **Cut-over** | both `appsettings.json` (Shell + RTM) `Port=5432` -> `Port=5433`, then restart OUR two services |
| **Never touched** | legacy RTM · `RTM.Twilio` · Garnet · anything on port 5432 |
Everything the rehearsal validated is unchanged below; only the target moves.

## ═══ §PHASING — THREE RUNS, THREE REPORTS (Rev 12) ═══
234 is a TEST server that reads from production. Per-step stops are dropped; the checks remain, inside the runs.
**RUN 1 — prepare on 5433 (one box):** pre-flight facts · create role + DB · restore the pinned dump ·
§STRUCT-DIFF full pass · BE §DB-INTAKE probe · `migrate` (3 App migrations) · `schema.sql` + ownership AND
privileges · functions + data(`02`,`05`) + the three named `db/migrations`. **One report, in numbers.**
**RUN 2 — transfer (one box):** RELOAD (15 standard + 2 by column list, row counts printed) · IDENTITY resync
(`deptype IN ('a','i')`, `quote_ident`) · integrity **against the source baseline** · metric gate · slug step.
**One report.**
**RUN 3 — cut-over (one box):** binary swap (cert `insightense.com` preserved) · both `appsettings` to 5433 ·
start OUR two services LAST · post-checks · `§FEED-READY` · comparison against legacy. **One report.**

## ═══ §STOP-CONDITIONS — the ONLY three (Rev 12) ═══
Everything else is decided at the console and recorded in the artifact.
1. **Anything would require touching legacy / `RTM.Twilio` / Garnet / port 5432.**
2. **Numbers disagree** with the expected set or with the source baseline — i.e. the transfer broke something,
   or silently repaired it.
3. **The provenance of instance 18 is not established** — before customer data is placed on it.
Rationale for keeping these three and dropping the rest: an error on a test server is cured by restoring the dump;
an error that corrupts the BUG REVIEW which follows immediately costs a week, because the operator would be showing
the coordinator OUR damage while we look for it in the product.

## ═══ §ROLLBACK-WINDOW — free until the first write on 18, lossy after (Rev 12) ═══
While we run on 5433 and the services still point at 5432, rollback is **free**: revert the port, restart, done —
the live database never changed. **From the moment the services are switched, the two databases DIVERGE**: every
interaction, status and saved layout lands on 18 and does not exist on 15.
- **Free-rollback boundary = the instant RUN 3 starts the services on 5433.** Record that timestamp in the artifact.
- After it, "revert the port" LOSES everything written on 18 since that moment. To see the cost at any time:
  `SELECT xact_commit, tup_inserted FROM pg_stat_database WHERE datname='rtmviewdb'` on 5433 — that is what a
  port-revert would discard.
- The dump pair (`rtmviewdb_20260829_1129.dump` + `C:\RTMView\Backup\20260829_1129`) remains as a second line,
  ON TOP of the port revert, not instead of it.

## ═══ §TWO-INSTANCES — what now lives on one machine (Rev 12) ═══
- **The old database on 5432 is NOT dropped and NOT stopped** after cut-over — it is the rollback. Its fate is the
  operator's separate decision, later.
- **Backups and maintenance configured against 5432 will silently back up the WRONG database after cut-over.**
  Measured 2026-08-30: no DB-related scheduled tasks exist on the machine (only Windows `RegIdleBackup`), so nothing
  breaks today — but the absence of any backup job on this server is itself recorded here as an operator item.
- Two live instances share memory and autovacuum on one host; `pg_trgm` is 1.6 on both, `pgcrypto` moves 1.3 -> 1.4
  (minor, arrives with the restore).

## ═══ §STRUCT-DIFF — STRUCTURAL DIFF OF ALL 17 TABLES, BEFORE ANY RELOAD (Rev 7, mandatory) ═══
The rehearsal proved the reload mechanism unsound where the dump's structure differs from the target's:
`pg_restore --data-only` is ALL-OR-NOTHING PER TABLE — one unknown column and the table loads ZERO rows
(`ERROR: column "CreatedDatetime" of relation "NGC_Queues" does not exist`). **The loud case is the lucky one.**
The mirror case — the dump having FEWER columns than the target — loads silently, leaving the new columns NULL
and a perfectly green row count. Counting proves arrival, not sameness; this is that same distinction at column level.

**Procedure, in BOTH phases, BEFORE the reload:**
0. **BEFORE creating it — free space check**, with the number into the artifact: the staging restore needs room for
   a full copy of the DB (dump is 19.03 MB compressed; the restored copy is larger). Insufficient space = STOP.
1. Restore the same physical dump into a staging DB (`rtmviewdb_src`). This is NOT an intermediate dump and does
   not violate SEAM-1: same file, same SHA-256; it is the only way to read the dump's structure.
   ⛔ **`rtmviewdb_src` IS TEMPORARY AND MUST NOT SURVIVE THE RUN.** As soon as (i) the diff is emitted and (ii) the
   two drifted tables have been copied out of it, run `DROP DATABASE rtmviewdb_src` and PROVE it is gone
   (`SELECT count(*) FROM pg_database WHERE datname='rtmviewdb_src'` = 0) — that proof is its own line in the RESULT.
   If it cannot be dropped, that is a STOP to the coordinator, not "we will clean it up later".
   (Reason, from today: `rtmviewdb_prodstg` — an abandoned DB of unknown history — cost half a day to identify.)
2. For all 17 transferred tables compare `information_schema.columns` (name + data type + ordinal) staging-side vs
   target-side, BOTH directions: `only in DUMP` and `only in TARGET`.
3. Emit the full table into the artifact — every table, matching ones included, not just the mismatches.
4. **Decide each mismatch explicitly and record the decision.** Known as of 2026-08-29:
   · `NGC_Queues` and `NGC_AgentGroups` — dump has `CreatedDatetime`, target does not (target =
     `Id, TenantId, ExternalId, Name, IsActive`, `schema.sql:214` / `:150`). Move by explicit column list; the
     column is dropped deliberately — see §COLUMNS-NOT-TRAVELLING.
   · The other 15 tables matched exactly (measured, rehearsal 2026-08-29).
5. **Complete the FULL pass first, then report ONCE with EVERY drift**, pre-classified by you as:
   `widening` / `narrowing` / `column only in dump` / `column only in target`, with your assessment of each.
   Stopping before the reload stays mandatory — but the coordinator gets one list, not one round-trip per finding.
   A drift on a column carrying MEANINGFUL data = STOP to the coordinator, never a console call.
6. **The gate compares against the NAMED APPROVED LIST below, not against a count.** A count says something
   changed; only a list says WHAT is new. Report new drift as `NEW DRIFT: <table>.<column>`.

### §TYPE-WIDENING — approved drifts where the column travels but the type differs
Widening (`int -> bigint`, `varchar(n) -> wider`, `-> text`) is SAFE: values cannot be lost, the cast is implicit,
and `pg_restore --data-only` handles it silently. **Narrowing is ALWAYS a STOP** — it loses data during the copy,
with no error and a green row count. Every widening is recorded here WITH the measured `MAX()` from the dump, so
"overflow is impossible" is a number and not an argument:
| Table | Column | Dump type | Target type | MAX() in dump | Verdict |
|---|---|---|---|---|---|
| `RTSData_UserStatusLog` | `Duration` | `integer` | `bigint` | measured each run, into the artifact | widening — approved (coordinator 2026-08-29); target `bigint` since BE migration `20260526203609:77` |

### APPROVED DRIFT LIST (the gate's reference — anything outside it is NEW and stops the run)
| Table | Column | Class | Decision |
|---|---|---|---|
| `NGC_Queues` | `CreatedDatetime` | only in dump | column-list copy; column dropped — see §COLUMNS-NOT-TRAVELLING |
| `NGC_AgentGroups` | `CreatedDatetime` | only in dump | column-list copy; column dropped — see §COLUMNS-NOT-TRAVELLING |
| `RTSData_UserStatusLog` | `Duration` | widening int->bigint | standard `pg_restore`; recorded in §TYPE-WIDENING with MAX() |

## ═══ §COLUMNS-NOT-TRAVELLING — named, not swallowed by the mechanism ═══
These columns exist in the 234 dump and do NOT exist in the target schema, so their content is LOST by design:
| Table | Column | Why it is acceptable |
|---|---|---|
| `NGC_Queues` | `CreatedDatetime` | removed from the product in d1982de; a creation stamp on a service row, not read by the app |
| `NGC_AgentGroups` | `CreatedDatetime` | same |
This table goes into the rehearsal artifact and into the BINDING RESULT as its own line. If §STRUCT-DIFF ever
adds a row here, it is reported BEFORE the run, never after.

## ═══ PHASE R — REHEARSAL ON DEV (MANDATORY, GREEN BEFORE 234) ═══
> **DEV IS ISOLATED — established by measurement 2026-08-29, not assumed:** `RTMViewShell` + `RTMService` are Running
> but configured to `Database=rtmviewdb`, and that DB has NO backend layer (`to_regclass public."RTSData_Interaction"`
> = null; `RTSData*` = 0 tables; `NGC_*` = 0). `RTM.Twilio` is not a registered service; pipes show legacy
> `\\.\pipe\rtmpipe` only, no `rtmpipe_v3`. Consequences are carried into R0/R7/POST-CHECKS below.
> `rtmviewdb_prodstg` exists on DEV with a backend layer — **it is NOT used, NOT measured and NOT modified**: the
> rehearsal must run the one physical dump file (SEAM-1), and a previously-restored DB of unknown history is a
> different artifact. Do not touch it.

R0. **TRANSPORT THE DUMP TO DEV** (the dump is on 234; it is NOT on DEV — three candidate paths verified empty).
    Copy `rtmviewdb_20260829_1129.dump` (19.03 MB) **without repacking** — byte-for-byte, no zip, no re-dump —
    to **`D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump`** on DEV — the fixed path for the whole rehearsal.
    (Deliberately OUTSIDE the git working tree: it carries live customer data and must never enter the repository.
    `D:` and not `C:` because on DEV the working disk is `D:`; the `C:\RTMView-Ops\` convention of CLAUDE.md §43 is
    a PROD-server layout and does not transfer to DEV by itself — operator decision 2026-08-29.)
    Source pin, point (i), measured on 234 2026-08-29: bytes **19949183**,
    SHA256 **EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468**.
    **SHA-256 must match in THREE points: (i) on 234 before sending, (ii) on DEV after arrival, (iii) at P0 before
    the 234 run.** Any mismatch = STOP to coordinator — never a silent re-copy.
    ⛔ The copy on 234 is NEVER deleted: it is one half of the rollback pair.
On DEV, against a fresh copy of the real 234 DB, run the WHOLE procedure end-to-end and present as artifact:
R1. `createdb rtmviewdb_reh` (as postgres); `pg_restore` the 234 dump into it. Confirm NGC/RTSGrid/UserStatusLog counts match the 234 numbers (BU59/Q61/SG41/AG43/UserAG566, BUQueueClass61/BUSG36/SGAG39, Grid32/Row62/Col77/Cell338, RTSUserGrid14/2/2, UserStatusLog202917).
R2. **BE §DB-INTAKE-01 gate** (schema.sql is IN PLAY again): as postgres probe `to_regclass('public."__BackendEmulationMigrationsHistory"')` + a signature BE object (`RTSGrid_Grid`) on rtmviewdb_reh BEFORE any migrate/schema.sql. Record objects-present/history state.
R3. **PIN THE RELOAD SOURCE.** Compute and record `Get-FileHash -Algorithm SHA256 rtmviewdb_20260829_1129.dump`.
    This one file is the reload source in R6 AND in P5; the hash is re-checked at P0 before 234. (Rev 2 offered
    "dump the transfer set out of rtmviewdb_reh **or** keep the source dump" — that fork is removed per SEAM-1;
    no intermediate dump is produced at any point.)
R4. **migrate** (App: Drop/PerTenantIdx/WfmTenantSettings + Audit) against rtmviewdb_reh via the packaged `CcDashboard.Web.exe migrate` (connection via `$env:ConnectionStrings__Default`, NOT REPLACE_ME). Confirm exactly the 3 App migrations apply; ledger now shows them. Anything beyond the 3 -> STOP.
R5. **schema.sql** creates BE-owned tables (as postgres). §DB-INTAKE gate outcome from R2 respected.
    **[SEAM-4 — ownership and GRANT are TWO layers; verify BOTH]** Schema GRANTs (`db/setup/01_init_db.sql:33-41`) are a
    layer distinct from object ownership, and neither implies the other (lesson 2026-07-03). After schema.sql:
    - **Ownership:** `SELECT tablename, tableowner FROM pg_tables WHERE schemaname='public' AND tablename IN (<the 26>);` — expected owner per the deploy convention, zero rows with the wrong owner.
    - **Privileges:** `SELECT has_schema_privilege('ccdashboard_user','public','USAGE');` = true, and per table
      `has_table_privilege('ccdashboard_user','public."<T>"','SELECT,INSERT,UPDATE,DELETE')` = true for all 26.
    - Default privileges for future objects checked too (`\ddp` / `pg_default_acl`).
    Either layer failing = STOP. Skipping this yields "the tables exist but the app cannot read them", discovered
    only after services start — i.e. at the worst possible moment.
R5a. **FUNCTIONS** (see §DB-LAYER below) — apply `db/functions/01,02,03,04` as postgres, in that order.
R5b. **DATA — SELECTIVE**: `db/data/02_metrics.sql` + `db/data/05_metric_translations.sql` ONLY.
     ⛔ `03_rtsgrid.sql` and `04_catalog.sql` are NOT applied — see §DB-LAYER (2). Applying them destroys the transfer set.
R5c. **DB MIGRATIONS** — apply the `db/migrations/**` files listed in §DB-LAYER (3) as postgres.
R6. **RELOAD** the transfer set from `rtmviewdb_20260829_1129.dump` (mechanism above) in FK order, then:
    (a) IDENTITY resync + verify (SEAM-3b), (b) INTEGRITY check (SEAM-2), (c) metric-reference check (rehearsal-watch).
R7. **Point the DEV services at `rtmviewdb_reh` and start them in the PROD-IDENTICAL service model.**
    **Config change, recorded and reverted:** capture the CURRENT connection strings
    (`C:\RTMView\Shell\appsettings.json`, `C:\RTMView\RTM\appsettings.json` — today `Database=rtmviewdb`) into the
    artifact BEFORE editing, point them at `rtmviewdb_reh`, and **restore the original values after the rehearsal**;
    both operations go into the artifact. The stand must end in the state it started.
    **Service count in R is TWO, not three:** `RTMViewShell` + `RTMService`. `RTM.Twilio` is not registered on DEV at
    all (measured), so "3 services Running" is not executable here. This is a recorded absence, not a rounded-up pass
    and not a failure — do NOT install a third service to make the line green. — every component a
    Windows service exactly as production runs it (§29.8 VALIDATION-ENV-01, operator norm 2026-07-02). **No `dotnet run`,
    no foreground PowerShell, no "at minimum the Shell".** If DEV physically cannot stand up the prod topology, that is
    reported to the coordinator **as a fact, and the rehearsal stops there** — the decision to relax is the coordinator's
    to make and the operator's to see. A silently degraded rehearsal is worse than none: it emits a green that is believed.
    End-to-end: /health Healthy, US All Queue Grid populates, WFM non-empty snapshot, Max Wait F5, probe (a) presence +
    (b) fires on a prod-ConfigJson screen (separately).
R8. **Number + integrity verify** (see §VERIFY). Off by one row, or one orphan, -> STOP to coordinator, fix procedure, re-rehearse. A GREEN rehearsal (counts + integrity + app end-to-end in the prod service model) is presented to the coordinator as the gate artifact BEFORE 234.

## ═══ PHASE P — 234 (only after GREEN rehearsal + coordinator OK) ═══
P0. Backup already exists (`rtmviewdb_20260829_1129.dump` 19.03MB + `C:\RTMView\Backup\20260829_1129`) — the ONLY rollback source, PAIR. Re-confirm present + SHA-256 matches the value recorded in R3.
P1. **Services DOWN and STAY down until reload done** — Stop RTMViewShell + RTMService (orphan-kill by PATH `\Shell\`/`\RTM\`, then VERIFY no live exe under `C:\RTMView\*`; service status is not evidence). ⛔ Engine reconnect would rediscover id=id BUs + ALL mapping -> conflict with restored rows; it must NOT wake before reload. Legacy/Twilio/Garnet: NOT touched at all.
P2. BE §DB-INTAKE-01 probe on 234 (as R2).
P3. **migrate** (as R4) — the 3 App migrations. If migrate wants anything beyond the known 3 -> STOP.
P4. **schema.sql** + ownership AND privileges verification (as R5, both layers).
P4a. **FUNCTIONS** — `db/functions/01,02,03,04` as postgres (as R5a).
P4b. **DATA — SELECTIVE** — `02_metrics.sql` + `05_metric_translations.sql` ONLY; `03`/`04` NOT applied (as R5b).
P4c. **DB MIGRATIONS** — as R5c.
P4d. **TENANT-SLUG CONFIG — A STEP, NOT A CHECK** (Rev 11; defect #7 of the rehearsal).
     A post-check would only discover, after services start, that nobody can log in while every DB number is green.
     ⚠ **Two DIFFERENT keys, do not conflate them** (measured 2026-08-30):
     · `DefaultTenantSlug` — read by `TenantResolutionMiddleware` to resolve the tenant per REQUEST. The middleware
       first derives the slug from the HOST: `ExtractSlug` returns `parts[0]` whenever the host contains a dot —
       so `rtm.insightense.com` yields `rtm`, bare `insightense.com` yields `insightense`, and an IP address like
       `10.0.0.234` yields `10`. If no tenant matches that string, the tenant stays unresolved and login fails with
       "Invalid username or password" without the password ever being checked. The config key is the FALLBACK, and
       it only applies when the host yields no slug at all (bare `localhost`). **So the answer depends on HOW 234 is
       addressed — that is a fact to measure, not to assume.**
     · `Seed:PlatformTenantSlug` — read by `DatabaseInitializer.cs:119` at SEED time (`a261840`, 2026-07-13),
       a different concern entirely. On 140 it had to be `nayax` or the slug was re-synced to the platform default.
     **Procedure:**
     1. **BEFORE the swap** — from the 234 database, record the ACTUAL tenant slugs (`SELECT "Slug" FROM tenants`)
        AND the host name(s) users actually use to reach the server. Both go into the artifact as values, not guesses.
     2. Derive from those two facts whether `ExtractSlug(host)` yields an existing slug. If it does, no key is
        needed. If it does not, **write `DefaultTenantSlug` = the real platform slug into the preserved
        `appsettings.json` AFTER the swap and BEFORE starting the services** — the June config predates the key,
        so "preserve the operator's config" preserves its ABSENCE.
     3. Set `Seed:PlatformTenantSlug` to the measured slug as well, so the seeder cannot re-point it.
     4. **AFTER start** — verify the tenant resolves and a login succeeds. This is now a confirmation, not the only
        defence.
     ⛔ If step 1 cannot produce the value, that is a STOP to the coordinator — never substitute by analogy with 140.
     **Same mechanism, wider scope:** any config key introduced after 2026-06-24 is absent from the preserved
     234 config. Enumerate them in the same pass and report as ONE list before the run.
P5. **RELOAD** the transfer set from `rtmviewdb_20260829_1129.dump` — the same file as R6, hash re-checked — in FK order,
    then IDENTITY resync + INTEGRITY check + metric-reference check (as R6a/b/c).
P6. **Binary swap** to d1982de (from package) — Shell + RTM; preserve appsettings.json (both) + data.sys/app.dat (RTM). Cert `insightense.com` preserve.
    **After the swap, before starting: verify the preserved Shell config still contains `DefaultTenantSlug`.**
    The tenant is resolved from the host subdomain and falls back to that key; if it is lost, tenant resolution
    fails and NOBODY CAN LOG IN — the login form reports "Invalid username or password" while the password is
    never even checked, so every DB number can be green and the server still unusable. (Found on DEV, where the
    key was simply absent, 2026-08-30.) Also verify by SHA-256 that the deployed binaries equal the package ones —
    file dates prove nothing. STEP 0 of any package use: `Set-ExecutionPolicy -Scope Process Bypass -Force` + `Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File` (mark-of-the-web).
P7. **Start RTMViewShell + RTMService LAST** (after reload + resync). Legacy/Twilio/Garnet untouched.
P8. §FEED-READY gate, then §VERIFY + post-checks (no live-data check before the gate passes).

## ═══ VERIFY — THREE SEPARATE PREDICATES (any failure = STOP to coordinator) ═══
### (1) COUNTS — did the rows arrive
- NGC_BusinessUnit = 59 **with HUMAN names** (spot-check names are NOT `id=id`); NGC_BusinessUnitQueueClassification = 61; NGC_BusinessUnitSupergroup = 36.
- NGC_Queues 61, NGC_Supergroup 41, NGC_AgentGroups 43, NGC_SupergroupAgentgroup 39, NGC_UserAgentgroup 566, NGC_Site 3.
- RTSGrid Grid/Row/Column/Cell = 32/62/77/338; RTSUserGrid Grid/ColumnsSet/Column = 2/2/14.
- RTSData_UserStatusLog = 202917.
Off by one row = STOP. No rounding, no "looks right".

### (2) INTEGRITY — are the rows MEANINGFUL  [SEAM-2 — separate predicate, counts cannot see this]
`--disable-triggers` switches FK checking OFF during the load, so a count can be perfect while references dangle.
**Every column name below is pinned to `v3:db/schema.sql`. A predicate without a pin is NOT ready** — the rehearsal
found three predicates invented from plausibility (`RTSGrid_Cell.MetricId`, `NGC_BusinessUnit."Name"`,
`NGC_Queues."QueueId"`), none of which exist.
**(2a) Declared FKs — 5 of them, revalidate:** BUQueueClassification.BusinessUnitId -> NGC_BusinessUnit;
BUSupergroup.BusinessUnitId -> NGC_BusinessUnit; BUSupergroup.SupergroupId -> NGC_Supergroup;
NGC_BusinessUnit.SiteId -> NGC_Site; SGAG.SupergroupId -> NGC_Supergroup. `VALIDATE CONSTRAINT` each; error = STOP.
**(2b) Logical references with NO declared FK — pinned, and note the join is on `ExternalId`, not on an id column:**
| child (schema.sql) | column | parent | parent column |
|---|---|---|---|
| `NGC_BusinessUnitQueueClassification` (`:176`) | `"QueueId"` varchar | `NGC_Queues` (`:214`) | `"ExternalId"` |
| `NGC_SupergroupAgentgroup` (`:253`) | `"AgentgroupId"` varchar | `NGC_AgentGroups` (`:150`) | `"ExternalId"` |
| `NGC_UserAgentgroup` (`:279`) | `"AgentgroupId"` varchar | `NGC_AgentGroups` (`:150`) | `"ExternalId"` |
| `RTSGrid_Row` (`:555`) | `"GridId"` | `RTSGrid_Grid` (`:489`) | `"GridId"` |
| `RTSGrid_Column` (`:465`) | `"GridId"` | `RTSGrid_Grid` (`:489`) | `"GridId"` |
| `RTSGrid_Cell` (`:432`) | `"RowId"` / `"ColumnId"` | `RTSGrid_Row` / `RTSGrid_Column` | `"RowId"` / `"ColumnId"` |
| `RTSUserGrid_Column` (`:641`) | `"ColumnsSetId"` | `RTSUserGrid_ColumnsSet` (`:667`) | `"ColumnsSetId"` |
**Measured against the SOURCE BASELINE, never against zero** (Rev 12):
1. BEFORE the reload, run every pair above against the staging DB (`rtmviewdb_src`) — that is the baseline, and it
   goes into the artifact as its own table.
2. AFTER the reload, run the same pairs against the target.
3. **PASS = target equals baseline, pair by pair.**
   · target > baseline -> the transfer CREATED dangling rows -> STOP.
   · target < baseline -> the transfer silently REPAIRED customer data -> **also STOP**: we promised an exact
     transfer, not an edit of the customer's data, and a converge that quietly fixes things makes every later
     number ambiguous (did it match because the transfer is exact, or because we changed things?).
   · zero remains the expectation only where the source measured zero.
Known baseline as of 2026-08-29 (re-measure every run, never assume): `RTSGrid_Cell->Row` **21**,
`RTSGrid_Cell->Column` **21**, `NGC_UserAgentgroup->AgentGroups.ExternalId` **81**, all other pairs **0**.
⛔ These 21 + 81 are PRE-EXISTING drift on 234 and travel AS IS — coordinator decision 2026-08-30: do NOT repair
them in this converge (out of the operator-approved scope; and a converge that also repairs cannot be verified).

**(2c) Metric references — REDIRECTED to the column that exists.**
`RTSGrid_Cell` has NO `MetricId` (`schema.sql:432-446`: CellId, RowId, ColumnId, ColNumber, UnionId, StyleId,
CellType, Value, Tooltip, OnClick, ThresholdSetId, NewRowId, OldRowId). The real metric reference is
`RTSUserGrid_Column."MetricId"` varchar(100) (`schema.sql:641-648`) -> `RTSGrid_Metric."MetricId"` (`:514-515`).
Check that one against its own source baseline by the same rule (it measured 0 in the source on 2026-08-29, so 0
is the expectation there), and report by name any that dangle (the 6 extra 234-local
metrics disappear when the baseline seed replaces them).
**In `RTSGrid_Cell` the metric appears as free text in `"Value"`** (a display string matching
`RTSGrid_Metric."Description"`, not a key). A reliable integrity predicate over it does NOT exist — `Value` also
holds plain labels. So it is NOT a gate: report the count of `Value` strings that match no metric description as
INFORMATION only. Saying so is honester than a tick that cannot fail.

### (3) IDENTITY — can the system still write  [SEAM-3b]
All 12 IDENTITY sequences ahead of their column max (see mechanism). Any sequence not ahead = STOP.

## ═══ §FEED-READY — GATE ON EVERY POST-CHECK THAT READS LIVE DATA (Rev 5, mandatory) ═══
`RTSData_Interaction` (119 052 rows) and `RTSData_UserStatus` are deliberately NOT transferred — the engine
repopulates them after reconnect. So for some minutes after services start these tables are legitimately near-empty,
and any comparison taken in that window measures an empty table, not a defect. **A red Queue-Grid-vs-legacy or an
empty WFM snapshot taken BEFORE this gate passes is NOT a conclusion** — same class as an empty probe grep without
part (a): the predicate was taken before its subject existed.

**Readiness criterion (numbers, not "looks alive"), run as postgres after P7/R7 service start:**
`SELECT count(*) FROM public."RTSData_Interaction" WHERE "TenantId" = '<tenant>';` — three samples, 60 s apart: N1, N2, N3.
**PASS requires: N1 > 0 AND N1 <= N2 <= N3 AND N3 > N1.** (`> 0` proves the feed arrived; monotonic non-decrease proves
it is a feed and not one stuck row; `N3 > N1` proves it is still growing.) Then the same three-sample rule on
`public."RTSData_UserStatus"` before any WFM check — `WfmInputQueryService.cs:65/88` reads `RTSData_Interaction`,
`:242/284` reads `RTSData_UserStatus`, so the WFM snapshot has exactly the same dependency.
**Why non-decrease is a valid predicate here:** the ONLY `DELETE` against `RTSData_Interaction`/`UserStatus` in the whole
function layer is `RTSData_MidnightClear` (`db/functions/02_rtsdata_functions.sql:262-263`), a once-a-day per-tenant
clear; `RTSData_SetInteraction` (`:31`) is an upsert, so completed calls stay as rows. ⛔ Therefore do NOT run this gate
across local midnight — the clear would make a correct feed fail the test. If the window is near midnight, STOP and say so.
**Ceiling: 15 minutes.** Not satisfied by then = **STOP to coordinator as "engine is not repopulating"** — a different
diagnosis with a different owner, NOT a failed comparison. Record N1/N2/N3 with timestamps in the artifact either way.

## POST-CHECKS — SPLIT BY EXECUTABILITY (coordinator decision 1, 2026-08-29)
### Executable in BOTH R and P — mandatory in the rehearsal
- Services Running + `curl.exe -sk https://localhost:8444/health` (or `Invoke-WebRequest -SkipCertificateCheck`) = Healthy.
  **In R: 2 services** (`RTMViewShell`, `RTMService`) — `RTM.Twilio` is not registered on DEV. **In P: 3 services.**
- Everything under §VERIFY (counts, integrity 2a/2b, IDENTITY) + ownership/GRANT + metric-reference check.
- PROBE — **(a) presence AND (b) firing**, reported separately in BOTH phases:
  · **(a) presence** — search the assembly for the UTF-16LE marker (`Encoding.Unicode` + `IndexOf`), NOT with a
    text grep: managed literals are UTF-16 and a byte-text grep returns a FALSE 0. And the predicate is PRESENCE,
    not the source count: the compiler interns identical literals, so 11 in source appears fewer times in the DLL.
  · **(b) firing — the probe fires on SAVE, not on open.** Corrected 2026-08-30 after it failed to fire in the
    rehearsal: the markers sit in `SaveWidgetConfig` (`ScreenEditorPage.razor:4665-4667`) and `SaveLayout`
    (`:5029-5037`), both logged BEFORE persisting, on page `/screens/{Id:guid}/edit`. Opening `/screens/{id}`
    (the fullscreen view) or merely rendering a screen produces NOTHING — the earlier wording "open a
    prod-ConfigJson screen THEN grep the live log" would have reported "probe never fires" on a perfectly
    working build. Correct step: open **`/screens/{id}/edit`**, change a widget's config, SAVE, then grep.
  · The service log is NOT in the app directory: the service runs with CWD `System32`, so it writes to
    `C:\Windows\System32\logs\log-<date>.txt` (lesson 2026-07-13, re-confirmed 2026-08-30). Grep there.

### `feed-dependent — NOT executable in R` — Phase P only
These require a live engine feed, which DEV does not have. In the rehearsal they are **not run and not reported as
red**; an empty result on DEV is a property of the stand, not a finding.
- **§FEED-READY** gate (N1/N2/N3 with timestamps) — P only.
- Queue Grid vs legacy — P only.
- WFM non-empty snapshot — P only.
- Max Wait survives F5 — P only.
- [P only] Queue Grid vs legacy — US All / US-Support baseline `01dbc2c`. ⚠ MEASURE AS A DELTA FROM T0 on both sides (coordinator ruling 2026-08-29): absolute same-day equality is not a well-posed predicate until we know whether the engine loads a full-day snapshot; fallback = compare the day after the midnight clear. ⚠ OPEN QUESTION raised to the coordinator (see BINDING): our table starts filling at reconnect while legacy holds the whole day, so a same-day count may legitimately differ even with a healthy feed. Report the numbers and the gate timestamps; do NOT self-rule on what the difference means.
- WFM non-empty snapshot (collision WARN for name==Workgroup&BU is a known open item, not a blocker).
- Max Wait survives F5 (`89feb34`+`16c6011`).
- PROBE — see the corrected definition above: **(a) PRESENCE = `> 0` occurrences found by a UTF-16LE search**
  (never "11", and never a text grep — both give false results on managed assemblies); **(b) FIRING = the marker
  appears in `C:\Windows\System32\logs` after SAVING on `/screens/{id}/edit`** (opening a screen fires nothing).
  An empty grep without (a) is NOT a conclusion. Report (a)/(b) separately.

## ⛔ ABORT / ROLLBACK (PAIR — as Rev 2)
Stop conditions: migrate wants >3 known migrations; any `db/` file needed beyond the §DB-LAYER named list; `NGC_Site` in the dump not a superset of the baseline rows; schema.sql/reload FK error; ownership OR privilege check fails;
any orphan in (2a)/(2b); dangling metric ref; any IDENTITY sequence not resynced; binaries fail on migrated schema;
VERIFY off-by-row; post-check broken.
Rollback = restore `rtmviewdb_20260829_1129.dump` (drop/rename + pg_restore as owner) AND binaries from
`C:\RTMView\Backup\20260829_1129` — as a PAIR; then re-check EF-history (App/Audit + BE) §DB-INTAKE; start services;
verify /health + 3 services; report rollback with numbers. "Revert binaries only" is NOT a rollback.

## CONSTRAINTS
- Nothing runs on 234 until GREEN rehearsal + coordinator OK. align.sql NOT applied (§38.5, pre-existing drift). No Garnet rotation. Branch not moved. NO push.
- §0.3 Python+fsync for `.coord/`; commit.lock §42.4 around any commit; journal + release + §0.7 re-sync. Passwords on-box, never in chat. Every "done" = object-store/live-log verified WITH NUMBERS + report Generated-time of any report artifact.

## BINDING postamble
Append RESULT to `.coord/cc/devops.md`: rehearsal artifact (counts + integrity + IDENTITY + app end-to-end in the prod
service model), BE-gate outcome, migrate result, ownership+privilege outcome, reload counts, orphan-check results,
metric-ref check, 234 phase numbers, service states, /health, Queue-Grid vs legacy, WFM snapshot, Max-Wait F5,
probe (a)+(b). status: done|failed. verified: object-store + live-log. Digest to inbox/coordinator.md.
