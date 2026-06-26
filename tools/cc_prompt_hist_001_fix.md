# CC-HIST-001-FIX — migration fix (dba CHANGES REQUESTED: 1 blocker + 2 minor)

> Owner design: role-bi (bi-0619). Execute: NATIVE CC. dba-0620 re-verifies after.
> STATUS: §4-review PASS (coordinator-0612 2026-06-21) — EXECUTE authorized (native CC, db: follow-up, commit.lock, NO push).
> Follow-up commit on top of b1bdd54 (NOT amend — avoid history rewrite). Same class: db:/web:.
> SCOPE: ONE file — src/CcDashboard.Infrastructure/Migrations/App/20260621080000_AddHistoricalReportsTables.cs. No other change.

## STEP 0 — integrity (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
```
## STEP 1 — skills + sync block
Read role-bi (§A/§C) + session-coord. Apply tools/cc_prompt_sync_block.md: slug=`bi-0619`,
claims=`src/CcDashboard.Infrastructure/Migrations/App/20260621080000_AddHistoricalReportsTables.cs`. Touch ONLY this file.
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md
`## BINDING <UTC> | spec: bi | directive: tools/cc_prompt_hist_001_fix.md | status: open`

---

## THE FIX (exact, in 20260621080000_AddHistoricalReportsTables.cs)

### 🔴 BLOCKER — REMOVE the db_patch_history INSERT (fresh-rebuild 42P01 after R0b carve)
Reason: this is an EF App-context migration (tracked by public.__ef_migrations_history). db_patch_history is RTM-canonical
(KEEP set, created by psql schema.sql which runs AFTER Web.exe migrate on fresh rebuild) -> INSERT raises 42P01 ->
migrate aborts. §38a self-record is for db/migrations/*.sql only, NOT EF migrations; a ledger row with no companion
db/migrations file = new Compare-ToBaseline D-drift. REMOVE (do NOT to_regclass-guard).

1. In Up(): DELETE this entire block (the comment + the migrationBuilder.Sql INSERT):
```csharp
        // Self-record in db_patch_history (§38a)
        migrationBuilder.Sql("""
            INSERT INTO public.db_patch_history (migration_name)
            VALUES ('20260621080000_AddHistoricalReportsTables')
            ON CONFLICT (migration_name) DO NOTHING;
            """);
```
2. In Down(): DELETE this single line from the Down SQL string:
```sql
            DELETE FROM public.db_patch_history WHERE migration_name = '20260621080000_AddHistoricalReportsTables';
```
(Leave the surrounding DROP TABLE statements intact.)

### MINOR 1 — fn_hist_drop_aged exception: RAISE WARNING instead of silent NULL (visibility of a bad DROP)
In the drop_aged EXCEPTION handler, replace:
```sql
                    EXCEPTION WHEN OTHERS THEN
                        -- Skip partitions with unexpected naming
                        NULL;
```
with:
```sql
                    EXCEPTION WHEN OTHERS THEN
                        RAISE WARNING 'fn_hist_drop_aged: skipped partition % (%)', part_rec.partition_name, SQLERRM;
```

### MINOR 2 — DEFAULT-partition collision caveat (one code comment, no behaviour change)
Near the DEFAULT partition creation, add a comment:
```sql
            -- OPS NOTE: if ensure_partitions lapses >window AND rows land in the DEFAULT partition for a month,
            -- a later CREATE ... PARTITION OF ... FOR VALUES for that month will ERROR (PG won't auto-move DEFAULT
            -- rows). Recovery: detach+drain the DEFAULT partition for that month before creating the monthly one.
```

### FLAG #1 (NO code change here) — Hold StatusId value = deploy-smoke item
Filter uses StatusId='Hold' (UserStatusLog has only StatusId, no StatusName — column is correct). The VALUE must be
confirmed on live 234: `SELECT DISTINCT "StatusId" FROM "RTSData_UserStatusLog" WHERE "StatusGroup"='ONPHONE'`.
If coded/numeric -> SumHoldMs silently 0 (graceful). Tracked for deploy-smoke/dba probe; NOT fixed in this prompt.

---

## ACCEPTANCE
- `dotnet build CcDashboard.sln` green; `dotnet test tests/CcDashboard.Tests.Unit` still green (no test change expected).
- `git show HEAD:<migration>` contains NO `db_patch_history` reference (grep returns nothing).
- Migration applies on a FRESH DB (Web.exe migrate) without 42P01.
- Contour still read-only (no RTSData_*/NGC_* writes).
- Follow-up commit `db: CC-HIST-001 fix — remove db_patch_history INSERT (fresh-rebuild 42P01) + drop_aged RAISE WARNING + DEFAULT caveat`.

## STEP 3 — binding POSTAMBLE RESULT -> .coord/cc/bi.md (commit hash, build/test, files, status, object-store verified)
## STEP 4 — commit.lock + journal + §0.7 re-sync. NO git push (§37). Ping dba-0620 to re-verify.
