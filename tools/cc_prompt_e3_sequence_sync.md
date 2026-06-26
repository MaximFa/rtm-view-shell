# CC task — E3: Compare Dimension F (sequence-sync) + Restore-All setval resync (23505 class)
> §4-DRAFTED by coordinator-0612 2026-06-14T13:04Z. Owner: dba-0610. Executor: native CC, Windows, PG18.
> Claims: db/tools/Compare-ToBaseline.ps1 + db/tools/Restore-All.ps1. Commit `db:`. **NO push** (rides next barrier).
> Builds on E4 (33a842e). Closes the 23505 (duplicate-key) drift class seen in the 45 saga.

## Why
A freshly built / restored DB can have an identity/serial SEQUENCE whose last_value LAGS behind the MAX of its owned column
(e.g. data seeded without advancing the sequence). The next INSERT then collides -> PostgreSQL 23505. Compare today has no
dimension for this. E3 adds DETECTION (Compare Dimension F) + the FIX (a setval resync step in Restore-All, PD-008 P6).

## Mandatory read (§40) + integrity + binding PREAMBLE
- Read: widget-planner / widget-creator / session-coord skills.
- §0.2: git status; branch v2-backend; hash-verify both claimed files vs HEAD.
- Binding PREAMBLE -> .coord/cc/dba.md:
```
## 2026-06-14T13:04Z | binding: dba <-> CC | directive: tools/cc_prompt_e3_sequence_sync.md | status: open
### DIRECTIVE: E3 — Compare Dimension F sequence-sync (detect lagging owned sequences + emit setval to align.sql) + Restore-All setval resync step. Claims: Compare-ToBaseline.ps1 + Restore-All.ps1. db:. NO push.
```
## S1 barrier + S2 claim
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo BARRIER; exit 1; fi
python3 tools/coord_check_claims.py dba-0610 db/tools/Compare-ToBaseline.ps1 db/tools/Restore-All.ps1
```

## PART 1 — Compare-ToBaseline.ps1: add DIMENSION F (SEQUENCE SYNC)
Add after Dimension E (the EF-model dim from E4), using the existing Run-SQL helper. (Reads only — no DB writes.)
Enumerate owned sequences and their columns, then compare last_value vs MAX(owned column):
```sql
-- owned sequences + their table/column
SELECT s.relname AS seq, t.relname AS tbl, a.attname AS col, n.nspname AS sch
FROM pg_class s
JOIN pg_depend d  ON d.objid = s.oid AND d.deptype = 'a'
JOIN pg_class t   ON t.oid = d.refobjid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE s.relkind = 'S' AND n.nspname IN ('public','identity','audit')
ORDER BY 1;
```
For each returned (sch,tbl,col,seq):
- `$seqLast = Run-SQL 'SELECT last_value FROM "<sch>"."<seq>"'`  (quote identifiers)
- `$colMax  = Run-SQL 'SELECT COALESCE(MAX("<col>"),0) FROM "<sch>"."<tbl>"'`
- If `$colMax > $seqLast` -> LAGGING (23505 risk). Record it.
Report in the delta:
```
DIMENSION F: SEQUENCE SYNC (E3)
  <sch>.<seq> backing <tbl>.<col>: last_value=<x> < MAX=<y>  -> LAGGING (23505 risk)   [or]
  All owned sequences ahead of their column max (no 23505 risk).
```
For each LAGGING sequence, EMIT the fix into $AlignLines:
```
-- ===== DIMENSION F: SEQUENCE SYNC =====
SELECT setval('"<sch>"."<seq>"', (SELECT COALESCE(MAX("<col>"),1) FROM "<sch>"."<tbl>"), true);
```
Add "F. Sequences lagging: <n>" to the SUMMARY block. Note: on an EMPTY DB (e.g. rtmviewdb_regen) all maxes are 0 -> never lagging (expected).

## PART 2 — Restore-All.ps1: setval resync step (the durable FIX, PD-008 P6)
Add a FINAL step (after schema+functions+data are applied) that resyncs EVERY owned sequence to its column max, so a restored DB
never starts with a lagging sequence:
```sql
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a'
    JOIN pg_class t ON t.oid=d.refobjid
    JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
    JOIN pg_namespace n ON n.oid=t.relnamespace
    WHERE s.relkind='S' AND n.nspname IN ('public','identity','audit')
  LOOP
    EXECUTE format('SELECT setval(%L, (SELECT COALESCE(MAX(%I),1) FROM %I.%I), true)',
                   r.sch||'.'||r.seq, r.col, r.sch, r.tbl);
  END LOOP;
END $$;
```
Place it as the last action of Restore-All (idempotent; safe to re-run). Echo "[E3] sequences resynced." Match the script's existing psql-invocation idiom (write to a temp .sql + psql -f, NOT -c with embedded quotes — see A-3/B2 lesson 42703).

## Verification GATES (report)
1. PowerShell parses clean (ParseFile both files).
2. `Compare-ToBaseline.ps1 -Database rtmviewdb_regen -Password <pw>` -> Dimension F present, reports "no 23505 risk" (empty DB); A/B/C/D/(E off) unchanged.
3. (If a data-bearing DB is handy, e.g. local rtmviewdb or 45) run Compare -> Dimension F lists any real lagging sequences; paste them.
4. Restore-All.ps1: confirm the setval DO-block step is present and is the LAST schema step; (optional) dry-run against rtmviewdb_regen -> "sequences resynced" with no error.

## Commit (db:, NO push) under commit.lock
Acquire .coord/locks/commit.lock (dba-0610). While holding:
```
bash tools/pre-commit-check.sh
git add db/tools/Compare-ToBaseline.ps1 db/tools/Restore-All.ps1
git commit -m "db: E3 sequence-sync — Compare Dimension F (detect lagging owned sequences + setval to align) + Restore-All setval resync (23505 class, PD-008 P6)"
git rev-parse HEAD
```
§0.6 post-commit -> `bash tools/cc_post_commit.sh dba-0610 $(git log -1 --format=%h)` -> sync -> §0.7 re-sync both files from HEAD.

## Binding RESULT -> .coord/cc/dba.md (status: done)
```
### RESULT (by CC): commit <hash>; Compare Dimension F added (owned-seq last_value vs MAX, setval emitted to align); Restore-All setval resync DO-block added (last step); regen run = no 23505 risk (empty); parse clean. NO push. verified: object-store + rerun.
```

## Report (chat) — NO push
commit hash; Dimension F behaviour on regen (no risk); any lagging sequences found on a data DB (if run); Restore-All resync step confirmed; parse OK. NO push.
