# CC task — E2: Compare-ToBaseline semantic Dimension A + multi-overload Dimension B
> §4-DRAFTED by coordinator-0612 2026-06-14T11:34Z. Owner: dba-0610. Executor: native CC, Windows, PG18.
> Claim: db/tools/Compare-ToBaseline.ps1 (single file). Commit prefix `db:`. **NO push** (rides next barrier).
> Builds on B-5 (01d4db6). Two enhancements; ALSO closes the B-5 [A] caveat by enumerating the 337 dev-DB drift objects.

## Why
Dim A today reports only LINE COUNTS ("50 missing / 287 extra") — can't tell WHICH objects drift (PD-008 E2 gap). Dim B uses a
name->single-kind map (last-CREATE-wins) so multi-overload routines false-flag: NGC_CreateSupergroup legitimately has 2 FUNCTION +
1 PROCEDURE overloads (all caller-backed) but Dim B reports "expected PROCEDURE, server has FUNCTION" -> the chronic false [B]=1.

## Mandatory read (§40) + integrity + binding PREAMBLE
- Read: widget-planner / widget-creator / session-coord skills.
- §0.2: git status; branch v2-backend; hash-verify db/tools/Compare-ToBaseline.ps1 vs HEAD.
- Binding PREAMBLE -> .coord/cc/dba.md:
```
## 2026-06-14T11:34Z | binding: dba <-> CC | directive: tools/cc_prompt_e2_compare_semantic.md | status: open
### DIRECTIVE: Compare Dim A semantic object-enumeration + Dim B multi-overload (name->set-of-kinds). Claim: db/tools/Compare-ToBaseline.ps1. db:. NO push.
```
## S1 barrier + S2 claim (bash)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo BARRIER; exit 1; fi
python3 tools/coord_check_claims.py dba-0610 db/tools/Compare-ToBaseline.ps1
```

## PART 1 — Dimension A: enumerate objects, not just line counts
KEEP the existing line-set diff ($MissingOnServer / $ExtraOnServer line lists + counts — do not remove). ADD a classification pass
that buckets each diff line by the object it declares, and report grouped OBJECT NAMES in the delta report (this is what tells us
WHAT drifts). Classification regex per diff line (case-insensitive), applied to BOTH $MissingOnServer and $ExtraOnServer:
- TABLE:       `^CREATE TABLE\s+(\S+)`            -> capture schema.qualified table name
- INDEX:       `^CREATE (?:UNIQUE )?INDEX\s+(\S+)` -> index name
- CONSTRAINT:  `ADD CONSTRAINT\s+"?(\w+)"?`        -> constraint name (also matches inline lines)
- ROUTINE:     `^CREATE (?:OR REPLACE )?(?:FUNCTION|PROCEDURE)\s+(\S+?)\s*\(` -> routine name
- SEQUENCE:    `^CREATE SEQUENCE\s+(\S+)`          -> sequence name
- COLUMN/OTHER: any remaining line -> bucket "detail lines (column/clause — review)" with a COUNT only.
Emit in the delta report, for BOTH directions (missing-on-server = baseline has, server lacks; extra-on-server = server has, baseline lacks):
```
DIMENSION A: SCHEMA
  Lines: missing 50 / extra 287            (keep the existing counts line)
  --- ENUMERATED (E2) ---
  Tables   missing-on-server: <names or (none)>
  Tables   extra-on-server:   <names or (none)>
  Indexes  missing/extra:     <names>
  Constraints missing/extra:  <names>
  Routines missing/extra:     <names>
  Sequences missing/extra:    <names>
  Detail (column/clause) lines: missing <n> / extra <n>  (review schema.sql vs server for these)
```
This converts raw line counts into an actionable object list. (Full per-column attribution is out of scope; bucketing top-level
objects + a detail-line count is the E2 deliverable.)

## PART 2 — Dimension B: multi-overload aware (name -> SET of prokinds)
Replace the single-kind maps with kind-SETS on BOTH sides, keyed by routine name:
- EXPECTED: while scanning db/functions/*.sql, collect ALL declared kinds per name into a set:
  `$ExpectedKinds[$name]` = HashSet of 'p'/'f' (do NOT overwrite — ADD each CREATE's kind). Keep one Source per name for messages.
- SERVER: from the pg_proc query (already selects prokind, pronargs), collect ALL rows per name:
  `$ServerKinds[$name]` = HashSet of prokinds from every server row for that name (do NOT overwrite — ADD each row).
- MISMATCH rule (overload-aware): for each expected name, flag ONLY if a kind the baseline declares is ABSENT on the server:
  `missing = $ExpectedKinds[$name] - $ServerKinds[$name]` (set difference). If non-empty -> mismatch (the real RTM-SEC-002 case:
  baseline expects a PROCEDURE that the server only has as FUNCTION). If the server merely has EXTRA kinds (more overloads) -> NOT a flag.
  MISSING routine (name absent on server entirely) -> keep as today.
- Result: NGC_CreateSupergroup expected {f,p}, server {f,p} -> set-diff empty -> NO flag. RTSData_SetChatMessage expected {p},
  server {f} -> {p}-{f}={p} non-empty -> correctly still flagged.
Update the delta + align messages to print the expected-set vs server-set for any real mismatch.

## Verification GATES (run all; report)
1. Re-run vs the fresh HEAD-build scratch: `Compare-ToBaseline.ps1 -Database rtmviewdb_regen -Password <pw>` (rebuild it via Regen-Schema.ps1 -KeepScratch if dropped).
   - Dim A enumerated section present; Dim A counts still ~0 (0/2) — E2 must NOT change the line-diff result, only ADD enumeration.
   - Dim B: NGC_CreateSupergroup NO LONGER flagged (the false [B] cleared).
2. Re-run vs local dev: `Compare-ToBaseline.ps1 -Database rtmviewdb -Password <pw>`.
   - Dim A now ENUMERATES the ~337 drift -> PASTE the enumerated object lists in your report. This confirms the B-5 caveat:
     the drift should be old/stale objects (extra-on-server tables/columns the new clean schema dropped) + missing recent migrations — NOT a schema.sql gap.
3. PowerShell parses clean: `[System.Management.Automation.Language.Parser]::ParseFile(...)` no errors.

## Commit (db:, NO push) under commit.lock
Acquire .coord/locks/commit.lock (owner dba-0610). While holding:
```
bash tools/pre-commit-check.sh
git add db/tools/Compare-ToBaseline.ps1
git commit -m "db: Compare E2 — semantic Dimension A object enumeration + Dimension B multi-overload (name->set-of-kinds; clears NGC_CreateSupergroup false [B])"
git rev-parse HEAD
```
§0.6 post-commit -> `bash tools/cc_post_commit.sh dba-0610 $(git log -1 --format=%h)` -> sync -> §0.7 re-sync the file from HEAD.

## Binding RESULT -> .coord/cc/dba.md (status: done)
```
### RESULT (by CC): commit <hash>; Dim A enumerated (tables/indexes/constraints/routines/seq + detail count); Dim B set-of-kinds, NGC_CreateSupergroup cleared; verify: regen Dim A still 0/2 + B clean; dev-rtmviewdb 337 enumerated = <stale objects summary>. NO push. verified: object-store + Compare reruns.
```

## Report (chat) — NO push
commit hash; confirm: (1) NGC_CreateSupergroup no longer in Dim B; (2) regen Dim A still ~0; (3) PASTE the enumerated dev-rtmviewdb Dim A object lists (so we confirm the 337 = stale-DB, closing B-5). NO push.
