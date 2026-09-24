# CC prompt — PR234-CMP-01 part 1: symmetric corpora for dimension A (routine OBJECTS out of the schema dump)

Author: devops-0916 · 2026-09-19 · REV 2 after coordinator §4 REVISE (pins, N4, statics).
Scope: ONE file of code (`db/tools/RtmSchemaDump.ps1`) + ONE new test file. No run on server 234.

## 0. Pins
GATE ON THE FILE, NOT ON THE BRANCH. Other roles commit to v3 while you work; the branch head moving is
not a reason to stop.
```
STOP-pin   git rev-parse v3:db/tools/RtmSchemaDump.ps1  == e1dd7da8b457414ea17293368e8392e4d0238395
           git hash-object db/tools/RtmSchemaDump.ps1  == the same (disk equals tree)
           If EITHER differs: STOP and report. Someone else changed the file under this prompt.
record     git rev-parse --short v3 · git rev-list --count origin/v3..v3
           (was 0ae2102/23 at REV 1, 25c12ec/26 at REV 2 - write down what YOU see; do not gate on it)
```

## 1. Why — measured, not inferred
The gate of `db/tools/Compare-ToBaseline.ps1` is `realDriftA` (`:942-943`); it sums `$ExtraEnum.Routines.Count`
among others. It is red on every healthy database because the two sides of dimension A differ in kind:
- baseline: committed `db/schema.sql` — blocks by first statement: 26 `CREATE TABLE`, 34 `ALTER TABLE ONLY`,
  13 `ALTER TABLE`, 7 index, 1 schema, 1 comment, **0 routines**.
- server: `Export-RtmSchema` (`RtmSchemaDump.ps1:48`) dumps ALL of `public`, splits on blank lines (`:96`) and
  keeps any block containing a quoted whitelist table name (`:99-117`). Routine blocks that mention a whitelisted
  table in their body are kept.
- live 18.09 on 234: 910 of 910 extra lines were routine header+body lines; table/index/sequence/alter/other 0.
The helper has two callers: `Compare-ToBaseline.ps1:197` (server) and `Export-All.ps1:84` (baseline).

## 2. TWO traps — both measured on real pg_dump output, both look right, both are wrong
Fixture: `tools/fixtures/pgdump16_rtm_fixture.sql`, 4151 B, sha256 `1b34438bcfc9d395725e617063dbe417ef59eb73721168892c48771134f30d6f`
— real pg_dump 16.13 output: 2 whitelisted tables, 2 FUNCTIONs and 1 PROCEDURE whose bodies reference the
business-unit table; ONE function has a blank line inside its body with the table reference AFTER it.
```
filter variant                                   kept   routine header+body blocks   non-routine
current                                            8               3                     5
TRAP 1  drop blocks matching 'Type: FUNCTION'      8               3                     5   changes NOTHING
TRAP 2  drop blocks whose first statement is
        CREATE [OR REPLACE] FUNCTION|PROCEDURE     6               1                     5   leaks the body tail
FIX     drop whole OBJECTS of Type FUNCTION/PROCEDURE
        (object = blocks from one pg_dump header
         '-- Name: ...; Type: X;' to the next)      5               0                     5   the 5 are byte-identical
```
Why the traps fail: pg_dump writes `-- Name: ...; Type: FUNCTION; ...` as a comment, then a BLANK LINE, then
`CREATE FUNCTION`. The blank-line split of `:96` puts header and CREATE in different blocks (trap 1). A blank line
INSIDE a body splits the body again; the tail block starts with neither the header nor CREATE (trap 2).
REV 1 of this prompt prescribed trap 2. The coordinator's §4 named the case; it was then measured and it fails.

## 3. The change
1. Extract the filter into a PURE function in the same file: `Select-RtmSchemaBlocks([string]$Raw) -> string[]`
   — no pg_dump, no file I/O. `Export-RtmSchema` calls it. Behaviour for non-routine objects must not change.
2. Walk the blocks in order. A block that is a pg_dump object header (`Type: <X>;`) sets the CURRENT OBJECT TYPE
   and is itself not emitted (the current filter never keeps these headers either: they carry the unquoted name).
   While the current object type is `FUNCTION` or `PROCEDURE`, skip every block. Otherwise apply the existing
   whitelist match unchanged. A comment at that spot says WHY: routines belong to `[A-R]`, not to dimension A,
   and neither a header match nor a first-statement match survives pg_dump's layout (§2).
3. Do NOT touch: `db/schema.sql`, `$script:RtmTableNames`, `Compare-ToBaseline.ps1` (its gate stays as is),
   `Export-All.ps1`. The committed baseline already has 0 routines; the fix makes the SERVER side match it.

## 4. Test — CONTROLS FIRST. A failed control means the counters below it are NOT read.
New file `db/tools/Test-RtmSchemaBlocks.ps1`, pwsh 7 and 5.1, no database. Dot-sources `RtmSchemaDump.ps1`,
loads the fixture, prints each line with PASS/FAIL, exit 1 on any FAIL.
```
C1 fixture is live     PRE-FIX logic (copied verbatim into the test) keeps routine header+body blocks = 3.
                       If 0: the fixture cannot show the defect - STOP.
C2 trap 1 is a trap    'Type:'-block exclusion keeps 3 (same as C1).
C3 trap 2 is a trap    first-statement exclusion keeps 1 - the body tail after the blank line.
C4 fixture integrity   sha256 = 1b34438bcfc9d395725e617063dbe417ef59eb73721168892c48771134f30d6f
---- counters, read only if C1..C4 PASS ----
N1  Select-RtmSchemaBlocks(fixture): routine header+body blocks = 0
N2  non-routine blocks = 5, byte-identical to the 5 of the pre-fix logic
N3  the blank-line function specifically: 0 of its blocks kept (this is the coordinator's N4 of REV 1,
    now a counter because the fixture carries it)
N4  a case of YOUR choosing, not in this prompt. If it FAILS, that is a result: report it, do not replace it.
```
Do NOT edit the fixture. Measured: a comment naming a quoted whitelist table made the filter keep the comment
itself as a table block. If you must, re-measure C1..C3 and N2 after.

## 5. Statics, before -> after, side by side. Count CODE lines only (lines not starting with '#').
```
RtmSchemaDump.ps1  code lines matching 'function Select-RtmSchemaBlocks'           0 -> 1
                   code lines matching "'FUNCTION','PROCEDURE'" or the type check   0 -> >=1
                   '$script:RtmTableNames = @('                                     1 -> 1   (whitelist untouched)
Compare-ToBaseline.ps1  'realDriftA = ('                                           1 -> 1   (gate untouched)
git diff --stat   exactly RtmSchemaDump.ps1 + Test-RtmSchemaBlocks.ps1 (+ the fixture if not yet committed)
```
Why 'code lines only': §3.2 asks for a comment that NAMES the traps; a grep over the whole file would count the
comment and turn a correct change red.
Parse both .ps1 with pwsh 7 (0 errors). UTF-8 BOM + CRLF for .ps1 (§35, .gitattributes).

## 6. Commit
One commit on v3, explicit pathspec. Message: what, why (§1 in two lines), how measured (§4).
No assistant signature, no co-author trailer, no session link. **No push — the §37 barrier is the coordinator's.**
RESULT into the binding even if the run breaks off.

## 7. NOT in this unit — live acceptance on 234, after shell-0912 finishes
```
realDriftA 0 · exit 0 · "A. Schema drift lines" 912 -> 2 (the 2 are schema CREATE/COMMENT, DetailCount only)
count BLOCKS, not names: routine objects 48 -> 0 (42 distinct names; 5 have overloads)
NEGATIVE HALF: scratch-shaped copy of the tool tree whose db/schema.sql lacks ONE CREATE TABLE block
               -> ExtraEnum.Tables = 1 -> exit 2. Non-destructive. (-BaselineDir is broken: CMP-BASEDIR-01.)
WATCH: triggers are Type TRIGGER and stay in dimension A. 18.09 measured 0 non-routine extras, so none today.
```
Until that passes, part 1 is DELIVERED, not CLOSED: the fixture is pg_dump 16, the server is 18.

## 8. cc-binding (NORM-CUR-07, zero item of the coordinator's §4) -> append RESULT to .coord/cc/devops.md

This block was MISSING from REV 2 and is added by devops-0919 on 2026-09-20 without touching a single
line of the unit above: the zero item is checked as `binding:` >= 1 AND `commit.lock|cc_prompt_sync_block`
>= 1, and both were 0. A prompt that commits and leaves no trace in the bus is how two RESULTs were lost
on 13.09.

Write the binding header BEFORE the work, the RESULT after it - and the RESULT goes in even if the run
breaks off midway:
```
## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_cmp01_part1_corpus_symmetry.md | status: open
### RESULT (by CC): commit <hash> ; C1..C4 and N1..N4 as measured ; parse 0 errors ; NO push.
```
Before committing, check that no lock is held: `commit.lock` / `cc_prompt_sync_block` absent in the repo
root. If either exists, STOP and report - another line is mid-commit.
