# Today's deploy lessons — STAGING for role-skill §B capture (Phase 2, after 45)
> Captured 2026-06-19T09:01:19Z by coordinator-0612. Source = 234 deploy (2026-06-19) + 45-green saga. Write each into the named role-skill §B (dated, source-pinned, status: active) per §45/NORM-CUR-11, and the cross-cutting ones into CLAUDE.md.

## HEADLINE DISCIPLINE (coordinator + devops) — operator directive 2026-06-19
- **MANDATORY Compare-ToBaseline before ANY deploy. Never rely on memory.**
  Never apply migrations/binaries to a server without FIRST running Compare-ToBaseline against THAT server (fresh, read-only). Never reuse another server's -MigrationList or trust recollection of what's applied — each server's applied-set differs (234 needed FULL-10; 45 already has the 0613 work -> its own shorter list). The Compare IS the gate: it yields the server-specific -MigrationList AND catches runtime-critical drift BEFORE pg_dump/apply. E1 gate elevated to inviolable discipline.
  SOURCE: 234 deploy STEP-4a (baseline_delta 111313 -> FULL-10) + 45 separate-Compare requirement; journal 2026-06-19.

## role-devops §B
- StrictMode scalar.Count: `Get-ChildItem`/`Sort-Object`/`.Split()` return a SCALAR on single item -> `.Count` (or index) THROWS under `Set-StrictMode -Version Latest` ("property Count cannot be found"). ALWAYS wrap collection results in `@(...)`. SOURCE: 234 Update-RTMView crash post-pg_dump; fix de5e835 (@() on $allBackups L137 + $migrations L204).
- §35 BOM re-encode via Python: a Python TEXT write drops the UTF-8 BOM -> PS 5.1 fails "Unexpected token" on box-draw/Cyrillic. Re-encode in BINARY: `b"\xef\xbb\xbf" + text_CRLF.encode("utf-8")` + fsync; verify `head -c3 == ef bb bf`. SOURCE: d62e704 dropped BOM -> 024feef fix.
- Deploy must PRESERVE operator-customised config: Update-RTMView Shell-preserve missed appsettings.json -> overwrote 234's live conn-string -> 28P01 password auth failed on Shell start. Preserve every operator config file (appsettings.json incl.), not just *.Production.json. SOURCE: 234 Shell crash; recovered from deploy backup; fix in cc_prompt_devops_preserve_appsettings.md.
- pg_dump completeness: the pre-apply pg_dump must run as the OBJECT OWNER (postgres) for postgres-owned objects, else the backup is INCOMPLETE (no full rollback). Don't split gate-user from dump-user if it makes the dump partial — run the whole apply path as postgres. SOURCE: 234 STEP-4 pg_dump-completeness flag (Update-RTMView L128 used $DBUser).
- pkg-copy PD-007: the staged package file gets truncated by mount write-back AFTER a native commit; re-materialize from HEAD + byte/hash-verify the swap source before every swap. SOURCE: BOM + StrictMode fixes both needed pkg re-materialize (308/263 ln truncations).

## role-dba §B
- Apply-user for a DDL migration set = OWNER/superuser (postgres), NOT the app user (ccdashboard_user gets "must be owner"). DML-only migs could use the app user, but run the WHOLE list as postgres for one consistent privilege. The read-only Compare gate stays app-user. SOURCE: dba-0610 STEP-4 apply-user confirm 2026-06-19.
- Idempotent-migration NOTICEs ("already exists, skipping" / "does not exist, skipping") on an already-populated server are EXPECTED, not errors — the guards (IF NOT EXISTS / to_regclass / ON CONFLICT) make re-apply safe. SOURCE: 234 STEP-4b log (all 10 migs [OK] amid NOTICEs).
- Pre-ledger migrations (created before _002_db_patch_history) CANNOT self-record (§38a) -> they show as permanent D-drift (MISSING/unknown) in Compare even when applied+effective. Optional 1-row-each ledger-backfill to reach D=0. SOURCE: 234 Compare-after 114916 (D=4: _604_001/_605_004/_606_005/_606_008 effective but unledgered).

## role-coordinator §B
- Anti-saga deploy discipline (worked on 234): stepwise via inbox; mandatory Compare gate BEFORE apply (headline above); pg_dump backup FIRST (FAIL-STOP); on ANY tool error mid-deploy -> STOP, do NOT improvise, rollback from the pg_dump backup; config clobber -> restore from the deploy's own binary backup; verify EVERY specialist binding RESULT natively by object-store before greenlight. SOURCE: 234 full deploy 2026-06-19 (StrictMode + BOM + appsettings clobber all caught at a gate, zero data loss).

## Cross-cutting -> CLAUDE.md
- Headline Compare-before-deploy discipline -> deploy section (§24/§43 area).
- Deploy preserve-config + pg_dump-owner + StrictMode-@() -> deploy/runbook notes.
