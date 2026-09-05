# CC Task — DAYTREND-CULTURE-SEP: pin `dd/MM/yyyy` to InvariantCulture in the THREE culture-sensitive data paths

> Author: backend-0831 (per the 2026-08-29 norm: the run-box is written by the owner of the work).
> Blessed by: coordinator-0831 §4 — 2026-08-31T17:0xZ (both author corrections accepted:
>   unpushed = 4 not 24; seeder writes as well as reads -> report the re-seed, do NOT clean data).
> Operator GO: 2026-08-31.
> Branch `v3`. Ветка на момент написания: `v3 = 90d0202`, `origin/v3 = 79e3905`, **непушенных 4**.

## STEP 0 — §0.6a integrity (v3). §40 skill reads + role-backend §A/§C. §37 NO push. §0.3 Python+fsync (Edit tool BANNED). commit.lock per §42.4.

## STEP 1 — Sync block (tools/cc_prompt_sync_block.md), slug `backend-0831`. Claims — EXACTLY these two files:
##   - src/CcDashboard.Application/Handlers/DayTrendQueryHandler.cs        (MODIFY: 1 line + 1 using)
##   - src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs      (MODIFY: 2 lines + 1 using)
## Nothing else. If a third file needs touching — STOP and report.

## STEP 2 — BINDING preamble to .coord/cc/backend.md (§0.6b).

---

## THE DEFECT (one sentence, so the change is not applied blindly)

In a .NET format string `/` is NOT a literal — it renders `CurrentCulture.DateTimeFormat.DateSeparator`.
`Program.cs:109` registers `en-US`, `ru-RU`, `he-IL`; under the latter two the separator is `.`, so the
value becomes `31.08.2026` while `RTSData_Interaction."OnDate"` stores `31/08/2026` (varchar).
The comparison silently misses — no exception, zero rows, empty widget.

## THE FIX — exactly three call sites, verified in the object store before writing this box

| file | line on `v3 = 90d0202` | now | becomes |
|---|---|---|---|
| `src/CcDashboard.Application/Handlers/DayTrendQueryHandler.cs` | **41** | `.ToString("dd/MM/yyyy");` | `.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture);` |
| `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` | **736** | `... .ToString("dd/MM/yyyy");` | `... .ToString("dd/MM/yyyy", CultureInfo.InvariantCulture);` |
| `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs` | **788** | `... .ToString("dd/MM/yyyy");` | `... .ToString("dd/MM/yyyy", CultureInfo.InvariantCulture);` |

Add `using System.Globalization;` to BOTH files — **neither has it** (checked: DayTrendQueryHandler
has 8 usings, none Globalization; DatabaseInitializer has 12, none Globalization). Keep usings sorted.

**Do NOT touch anything else.** The other 20 culture-dependent `ToString` calls in the repo are pure
display (audit log, user admin, report headers, widget labels) — there culture dependence is correct
behaviour. The boundary: **culture is dangerous exactly where the result enters a DATA COMPARISON or a
SQL parameter.** A blanket sweep will be rejected.

## Why exactly three — independent sweep, run it again if you doubt it

```bash
git grep -n 'ToString("[^"]*[/:][^"]*")' v3 -- 'src/*' | grep -v InvariantCulture | grep -v '\.razor:'
# expect EXACTLY the three lines above, nothing else
git grep -nE '\{[A-Za-z_][A-Za-z0-9_.()]*:[a-zA-Z]{1,4}/[^}]*\}' v3 -- 'src/**/*.cs'
# expect EMPTY — no interpolated `{x:dd/MM/yyyy}` form hiding the same bug
git grep -n 'OnDate ==' v3 -- 'src/**/*.cs'
# expect ONLY DatabaseInitializer:737 and :789 — the two seeder guards fixed above
```

## ⚠ CONSEQUENCE OF THE SEEDER FIX — read before running, it is NOT cosmetic

At `:736`/`:788` the same `today` string is used BOTH as the idempotency key
(`AnyAsync(r => r.OnDate == today)`, `:737`/`:789`) AND as the value written into the rows
(`OnDate = today`). So on a non-invariant-culture host the dev seeder has been WRITING `31.08.2026`
into the data, not merely failing to find it. Therefore:

- the fix repairs both the read and the write, but **does NOT repair rows already seeded** with a dot;
- on a dev DB seeded earlier under `he-IL`, the guard will no longer match those rows and the seeder
  **will insert a second set for the same day**. Expected on dev only (`SeedDev*`), and it is a
  data-visible effect — report it, do not "clean up" anything.

## STEP 3 — build: 0 errors, 0 new warnings. Unit tests: run, report the counts as-is.

## STEP 4 — pre-commit (`bash tools/pre-commit-check.sh`) + ONE commit under commit.lock:

```
fix(app): pin dd/MM/yyyy to InvariantCulture in the 3 culture-sensitive date paths — DayTrend SQL param + 2 dev-seed guards [DAYTREND-CULTURE-SEP]

'/' in a .NET format string is DateSeparator, not a literal: under he-IL/ru-RU the
parameter became 31.08.2026 while RTSData_Interaction."OnDate" holds 31/08/2026 ->
silent zero rows, empty Day Trend. Display-only ToString calls deliberately untouched.
```

Then §0.6 post-commit verification and `bash tools/cc_post_commit.sh backend-0831 $(git log -1 --format=%h)`.

## STEP 5 — BINDING RESULT to .coord/cc/backend.md: commit hash, the three changed lines quoted from the
## COMMIT TREE (`git show <sha>:<file> | sed -n '<line>p'`), both `using` additions, build/test counts.

## Acceptance — object store only, no mount greps

1. `git show <sha>:src/CcDashboard.Application/Handlers/DayTrendQueryHandler.cs | grep -c 'InvariantCulture'` — expect **1**
2. `git show <sha>:src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs | grep -c 'InvariantCulture'` — expect **2**
3. Both files: `grep -c '^using System.Globalization;'` — expect **1** each
4. Negative control: `git show <sha>:src/.../DayTrendQueryHandler.cs | grep -c 'ThisMarkerMustNotExist'` — expect **0**
5. `git diff-tree --no-commit-id --name-only -r <sha>` — expect **exactly the two claimed files**

## Git push: do NOT run `git push` (§37). Commit only; the push command is the operator's.

## LIVE GATE (not part of this box — for the coordinator after redeploy)

The gate MUST be run in **עברית**, because in English it is green on the broken build too:
same screen `ca5c23ac-73ed-4bbf-9df4-c5b008f98fc7`, Day Trend Chart shows series, and the shell log
for that same cycle shows `DayTrend: ... Got N interaction rows` with **N > 0** and `Date=` printed
with a **slash**, not a dot. Both values quoted from the log as strings.
Negative control already on record: before the fix, same locale, N = 0 across 3210 matches.
