# CC — F-QA-5 fix: ArchiverService 42703 (watermark read) + commit role-bi §B lessons

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3. §4-review (коорд: ревью) BEFORE operator runs. Push HELD on this.
> ROOT (object-store CONFIRMED, ArchiverService.cs GetWatermarkAsync L275-284): SqlQueryRaw<DateTime?>("""SELECT
> "ArchivedThrough" FROM public.arch_watermark WHERE "TableName"={0} AND "TenantId"={1}""").FirstOrDefaultAsync() — the
> FirstOrDefaultAsync COMPOSES, so EF wraps it `SELECT t."Value" FROM (<raw>) t LIMIT 1` and (scalar convention) needs the
> inner column named "Value"; the raw returns "ArchivedThrough" -> 42703 column does not exist, on EVERY archive run
> (per-tenant, caught+logged -> archiver never archives). Siblings using .ToListAsync() (no composition) are unaffected.

## STEP 0 — integrity + branch (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD
f=src/CcDashboard.Infrastructure/BackgroundServices/ArchiverService.cs; H=$(git show HEAD:"$f"|wc -l); W=$(wc -l <"$f"); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo RESTORED; } || echo OK; sync
```
## STEP 1 — sync block (file-mode) + binding PREAMBLE (.coord/cc/bi.md)
Claims (file-mode): src/CcDashboard.Infrastructure/BackgroundServices/ArchiverService.cs +
.claude/skills/role-bi/role-bi.md (§B append only). Touch ONLY these.

## FIX (1 line, ArchiverService.cs GetWatermarkAsync ~L279) — alias the column
Replace the raw SQL string:
    SELECT "ArchivedThrough" FROM public.arch_watermark WHERE "TableName" = {0} AND "TenantId" = {1}
with (add AS "Value" so the composed t."Value" resolves):
    SELECT "ArchivedThrough" AS "Value" FROM public.arch_watermark WHERE "TableName" = {0} AND "TenantId" = {1}
NO signature/behaviour change: SqlQueryRaw<DateTime?> + FirstOrDefaultAsync still returns DateTime? -> `?? DateTime.MinValue`
when no row. Do NOT change anything else (the 3 INSERT...ON CONFLICT watermark writes already use "ArchivedThrough" directly
and are fine — they don't compose).

## ACCEPTANCE (functional, QA floor)
- `dotnet build` = 0 errors.
- On an archive run, ArchiverService GetWatermarkAsync reads the watermark with NO 42703; the archive run proceeds
  (per-tenant, no caught-and-logged 42703). (Operator/QA verifies on run; the alias makes the composed query valid.)

## STEP 2 — CAPTURE role-bi §B (NORM-CUR-11) — append BOTH lessons, then a SEPARATE docs: commit
Append to .claude/skills/role-bi/role-bi.md §B (append-only; keep §A within cap):
1. NEW (this task): "<date> · ArchiverService 42703 on every archive run · EF SqlQueryRaw<scalar> + composition
   (FirstOrDefault/Where) -> EF wraps as `SELECT t."Value" FROM (<raw>) t` needing a column named "Value"; alias the
   projected column `AS "Value"` (or avoid composition via .ToListAsync()). · SOURCE: ArchiverService.cs:279 GetWatermarkAsync, F-QA-5, coordinator 2026-06-23 · status: active"
2. OPERATOR-APPROVED (carry-over, if not already present in §B): "<date> · dev seed 183b404 CREATE-TABLE'd hist_* + omitted
   fn_hist_* + skipped EF migration -> startup 42883 + host StopHost · RULE: a dev/data seed is DATA-ONLY (INSERT); schema +
   functions are EF-migration-owned (seed-created schema desyncs __ef_migrations_history + omits functions). migrate-first,
   seed data-only. · SOURCE: 183b404, coordinator 2026-06-22 · status: active" (skip if already in §B — do not duplicate).

## COMMITS (two, commit.lock each, object-store verify, NO push §37)
1. `fix: ArchiverService 42703 — alias arch_watermark.ArchivedThrough AS "Value" (EF composed-scalar; F-QA-5)` — ArchiverService.cs.
2. `docs: role-bi §B — EF SqlQueryRaw<scalar> composition 'Value' alias + data-only-seed lessons` — role-bi.md (git add -f; blocked by .gitignore).

## STEP 3 — binding POSTAMBLE RESULT (commits, build, acceptance) -> .coord/cc/bi.md. journal + §0.7 re-sync. NO push.
