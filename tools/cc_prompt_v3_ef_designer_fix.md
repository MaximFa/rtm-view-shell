# CC task — v3 EF migration integrity: regenerate missing Designer.cs (impl)

> Owner: backend (executing backend session). Pair: bi (hist tables) + dba (DB state / deployed-server reconcile).
> STATUS: **DRAFT** — authored by backend-0620 2026-06-22. Route: coordinator **§4** → then EXEC.
> §4-PASS: coordinator-0622 2026-06-22T20:14:01Z — proper root fix (re-scaffold via EF tooling, preserve Up/Down SQL verbatim+diff, regen Designer.cs+snapshot, SAME migration IDs); acceptance PROVEN on FRESH scratch Postgres (Web.exe migrate App+Audit auto-applies all + history + idempotent + NO 42883/42P07); audit fix = clean fresh-DB flow (not code); deployed-reconcile = dba one-time history INSERT (NOT band-aid in migrations). APPROVED. ⚠ ensure re-scaffold keeps the EXACT original IDs (rename + [Migration] attr) so origin/v3 history aligns. Branch v3, commit.lock, NO push; security gate after.
> Branch **v3** (the defect ships on origin/v3 243e4a4). Commits: web:. NO push (§37). Security gate after commit.
> §4-CONFIRM (extended): coordinator-0622 2026-06-22T20:34:56Z — Audit Fix-A folded (claim +InfrastructureServiceExtensions.cs registration line ONLY; 1-line MigrationsHistoryTable("__ef_migrations_history","audit") -> runtime==design-time; Audit migration code untouched; Fix-B band-aid SKIPPED). App 3×Designer.cs regen + Audit Fix-A = ONE v3 commit. Acceptance: fresh-DB migrate App+Audit clean, idempotent, NO 42883/NO 42P07. EXECUTE authorized.
> Root analysis: inbox/coordinator.md (backend-0620 2026-06-22) — DO NOT re-investigate; implement the fix.

## ⚠ STATUS: 187e8ca = TASK A DONE — this re-run COMPLETES THE REMAINDER (do NOT redo TASK A)
Commit 187e8ca (v3) already delivered TASK A correctly (3 App Designer.cs + updated AppDbContextModelSnapshot.cs, ORIGINAL [Migration] IDs). KEEP it — do NOT regenerate the Designer.cs.
The PRIOR run skipped: (B) Audit Fix-A, (proof) fresh-DB migrate, (binding) the §0.6b RESULT. This run does ONLY:
  1. WRITE the explicit §0.6b binding PREAMBLE (below) to .coord/cc/backend.md BEFORE work.
  2. TASK B — add the 1-line Audit Fix-A (InfrastructureServiceExtensions.cs, AuditDbContext registration). Follow-up `web:` commit on top of 187e8ca (or amend).
  3. PROOF — run + PASTE the fresh-DB scratch-Postgres migrate output (App+Audit, history, 2nd-run no-op, NO 42883/42P07) into the binding RESULT.
  4. WRITE the §0.6b binding POSTAMBLE (RESULT) to .coord/cc/backend.md.


## ROOT (confirmed, object-store origin/v3 243e4a4 — context only, do NOT re-derive)
- 3 App migrations were hand-authored (migrationBuilder.Sql etc.) WITHOUT `dotnet ef migrations add` → each has ONLY a `.cs`, NO paired `.Designer.cs`. The `[Migration("<id>")]` + `[DbContext(typeof(AppDbContext))]` attributes live in the Designer.cs → without it EF cannot detect/order the migration → `database update` reports "up to date" → objects never auto-created → applied manually → `__EFMigrationsHistory` not recorded.
- `AppDbContextModelSnapshot.cs` is STALE: last touched e43731c 2026-06-05 (UserWidgetSettings), 16 days BEFORE these migrations → it does NOT reflect their model changes.
- Audit context is NOT defective: `20260507135314_InitialCreate` HAS its Designer.cs + snapshot; audit_logs has a SINGLE creator (this EF migration), NOT in db/schema.sql. The startup `AuditDbContext.Migrate()` **42P07** is a NON-PRISTINE-DB artifact (audit_logs present but Audit `__EFMigrationsHistory` missing the InitialCreate row), NOT a missing Designer.cs. ⚠ UPDATED 2026-06-22 (DEEPER ROOT, coordinator-approved Fix A): the RUNTIME AuditDbContext registration (InfrastructureServiceExtensions.cs:53-59) sets NO MigrationsHistoryTable -> EF defaults to audit."__EFMigrationsHistory" (capitalised, schema=audit via HasDefaultSchema), while the DESIGN-TIME factory (DesignTimeDbContextFactory.cs:52) writes audit.__ef_migrations_history (lowercase). RUNTIME != DESIGN-TIME -> if audit_logs was provisioned via `dotnet ef` / manual SQL, runtime never finds the InitialCreate row -> re-runs CreateTable -> PERSISTENT 42P07. DURABLE FIX = Fix A (TASK B below): align runtime to design-time + project lowercase convention. The Audit MIGRATION code stays unchanged; the one-line registration IS the fix. (Fix B dev-DB reconcile = SKIPPED per operator: fresh DB + Fix A = clean.)

## The 3 App migrations + their nature (drives how each Designer.cs regenerates)
- `20260621080000_AddHistoricalReportsTables.cs` — 3× `migrationBuilder.Sql` ONLY (raw partitioned-table DDL; NO EF-modeled entity delta). Designer target model == prior snapshot (no model change).
- `20260622090000_AddArchiveTables.cs` — `AddColumn`×1 + `DropColumn`×1 + `Sql`×7 (REAL EF-modeled column delta + raw SQL). Designer target model MUST include the modeled column delta.
- `20260622100000_UserReportSoftDelete.cs` — `AddColumn`×3 + `CreateIndex`×2 + `DropColumn`×3 (REAL EF-modeled delta). Designer target model MUST include these.
⇒ Designer.cs CANNOT be empty stubs for the latter two — the per-migration `BuildTargetModel` must reflect the cumulative model at each step, and the final `AppDbContextModelSnapshot.cs` must equal the head model. This is exactly what `dotnet ef migrations add` produces — so regenerate via tooling, do NOT hand-write snapshots.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md ; .claude/skills/role-backend/role-backend.md (§A/§C)
Read: .claude/skills/widget-planner/widget-planner.md ; .claude/skills/widget-creator/widget-creator.md
Read: the 3 migration .cs bodies (preserve their Up/Down SQL+ops VERBATIM) + AppDbContextModelSnapshot.cs + the AppDbContext entity model.

## INIT / discipline
- §0.6a integrity FIRST; **branch v3** (`git checkout v3`; §0.5 object-store verify, NOT mount status; HEAD has shown NUL/mount drift — verify via git rev-parse + hash-object).
- §0.3 Python+fsync for any `.coord/` write; after every source write: `sync` + `tail -3` + `wc -l` + NUL-check (0).
- §42.6 sync block: slug = your backend slug; **claims** = `["src/CcDashboard.Infrastructure/Migrations/App/**","src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs"]` (App migrations + snapshot for the Designer.cs regen; InfrastructureServiceExtensions.cs ONLY for the 1-line Audit Fix-A at line 57 — do NOT touch the Audit/BackendEmulation MIGRATION files, only the registration line). commit.lock around commit. §0.6b binding → `.coord/cc/backend.md`. pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## TASK — regenerate the 3 App Designer.cs + bring the ModelSnapshot current (EF-correct, idempotent)

Goal: the 3 App migrations become EF-detectable + ordered, with a current cumulative snapshot, so a FRESH-DB `Web.exe migrate` (App + Audit) auto-applies ALL of them, records `__EFMigrationsHistory`, and a re-run is a no-op — NO 42883, NO 42P07, NO manual SQL, NO band-aid (no manual history insert, no `IF NOT EXISTS` hacks in the migrations).

Approach (EF tooling regenerates snapshots — do NOT hand-write `BuildTargetModel`):
1. Confirm the AppDbContext C# entity model + Fluent config already reflect the HEAD intended state (archive columns + user_report soft-delete props/indexes). If a modeled property is missing in code, the AddColumn/CreateIndex can't be re-derived — STOP and flag (the model code must match before regen). hist_*/arch_* partitioned tables are raw-SQL (not EF entities) — expected.
2. Preserve the 3 migrations' Up/Down bodies (copy aside). Reset the snapshot to the pre-2026062 baseline (the 2026-06-05 snapshot already is that).
3. Re-scaffold each migration IN TIMESTAMP ORDER via `dotnet ef migrations add <Name> --context AppDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web` so the tooling emits `<id>_<Name>.cs` + `<id>_<Name>.Designer.cs` + updates `AppDbContextModelSnapshot.cs`. ⚠ EXACT-ID RENAME (coordinator §4 note): `dotnet ef migrations add` stamps a NEW current timestamp — after scaffolding each, RENAME the generated `<newts>_<Name>.cs`/`.Designer.cs` back to the ORIGINAL IDs (20260621080000_AddHistoricalReportsTables, 20260622090000_AddArchiveTables, 20260622100000_UserReportSoftDelete) AND edit the `[Migration("<original-id>")]` attribute in each Designer.cs + any migrationId string to the original — so the files match the IDs already pushed to origin/v3 (a new ID would diverge from the pushed v3 history). Verify `dotnet ef migrations list` shows the THREE ORIGINAL IDs, no stray new-timestamp migration left behind.
   - For the raw-SQL-only migration the scaffolded Up is empty → paste the 3 `migrationBuilder.Sql(...)` bodies back in (verbatim).
   - For the AddColumn/CreateIndex/DropColumn ones the tooling regenerates the modeled ops from the model delta → re-insert the 7 / raw `Sql(...)` portions back in their original order alongside the regenerated ops. Diff against the preserved originals to ensure Up/Down are byte-equivalent in EFFECT (same DDL).
4. Verify the migration .cs now have `[DbContext]`+`[Migration]` (in the Designer.cs) and `AppDbContextModelSnapshot.cs` reflects all three.

## TASK B — Audit history-table alignment (Fix A — durable, 1 line, same v3 commit)
Root: runtime AuditDbContext uses default audit."__EFMigrationsHistory" while design-time uses audit.__ef_migrations_history -> persistent 42P07 (see ROOT). Fix:
- In `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs`, the AuditDbContext registration (currently ~lines 53-59, the `UseNpgsql` for AuditDbContext that sets ONLY `MigrationsAssembly`) -> ADD `npg.MigrationsHistoryTable("__ef_migrations_history", "audit");` so RUNTIME == DESIGN-TIME (DesignTimeDbContextFactory.cs:52) == project lowercase convention.
- Touch ONLY the AuditDbContext registration block; do NOT change the App/BackendEmulation registrations or any migration file. One-line addition.
- This is ONE v3 commit with TASK A (App Designer.cs regen). NO band-aid reconcile (Fix B skipped).

## VERIFY (fresh-DB clean — the acceptance, must be PROVEN)
- `dotnet ef migrations list --context AppDbContext ...` shows all 3 as detected (not "up to date" anomalies).
- Spin a FRESH scratch Postgres (Testcontainers or a throwaway DB). Run `CcDashboard.Web.exe migrate` (App + Audit). ASSERT:
  - all 3 App migrations + Audit InitialCreate applied; `__EFMigrationsHistory` (App) has all 3 rows, Audit history has InitialCreate;
  - hist_*/arch_*/user_report objects + audit.audit_logs all present;
  - a SECOND `migrate` run = no-op (idempotent); NO 42883 (function/arity), NO 42P07 (relation exists).
- `dotnet build CcDashboard.sln` green; existing migration/integration tests green.

## DEPLOYED-SERVER RECONCILE (pair dba — separate, NOT a code band-aid)
234/45 where the hist_*/arch_* SQL was applied MANUALLY have the objects but no App `__EFMigrationsHistory` rows. Fix on those servers = INSERT the `__EFMigrationsHistory` rows for the 3 already-applied migrations (mark applied; objects already exist) so the next `migrate` is a no-op — dba authors that as a one-time server reconcile script, NOT inside the migrations. Flag to dba; do NOT put `IF NOT EXISTS`/history-insert hacks in the migration bodies (operator: zero band-aids).

## ACCEPTANCE
- 3 App `.Designer.cs` present + `AppDbContextModelSnapshot.cs` current (reflects all 3); migration IDs unchanged.
- Fresh-DB `Web.exe migrate` (App+Audit) auto-applies ALL, records history, idempotent re-run, NO 42883/42P07 — PROVEN (paste the run output in the binding RESULT).
- Up/Down DDL effect identical to the preserved originals (diff shown). Audit MIGRATION code untouched (only the 1-line registration Fix-A changed). ZERO RTM-contour touch.
- Fix A: fresh-DB `Web.exe migrate` records Audit InitialCreate into **audit.__ef_migrations_history** (lowercase, runtime==design-time); 2nd run no-op; NO 42P07 even when re-run.
- Object-store-verified commit (web:), branch v3, commit.lock, **NO push**. Deployed-server reconcile flagged to dba (not in migrations).

## §0.6b binding blocks (EXPLICIT — L-SC-27; the shorthand is why the prior run skipped it)
PREAMBLE — CC appends to `.coord/cc/backend.md` at START (Python+fsync), before any work:
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_v3_ef_designer_fix.md | status: open
### DIRECTIVE: regen 3 App Designer.cs (EF tooling, same IDs, SQL verbatim) [DONE 187e8ca, keep] + Audit Fix-A 1-line. Claims: Migrations/App/** + InfrastructureServiceExtensions.cs. gate: fresh-DB migrate clean no-42883/42P07. commit-prefix web:.
```
POSTAMBLE — CC appends at END (after commit + proof), Python+fsync:
```
### RESULT: commits <hash> . build/test <counts> . files <list> . status done|failed . blockers . verified: object-store
```
Include the fresh-DB migrate output (App+Audit, no 42883/42P07, 2nd-run no-op) in/under the RESULT. Leave `> consumed <UTC>` for the coordinator. Relay a short digest to inbox/coordinator.md.
