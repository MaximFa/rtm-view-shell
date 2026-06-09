# CC Task (Shell specialist, slug shell-0609) — RV-1b: remove 3 Tests.Unit metric-mutation orphans (sln 0 errors)

> DRAFT for coordinator §4. Follow-up to 78bf89c (RV-1). That fix made Tests.Security compile, but
> `dotnet build CcDashboard.sln` STILL has 3 errors: three Tests.Unit files reference the metric-mutation
> commands/handlers removed by b7b20e4. This is the SAME root cause (removing public types orphans tests across
> MORE than one project). Closing this = the security gate's "sln 0 errors" condition (last 234 blocker).
> The F-1 invariant is ALREADY locked by the absence regression in 78bf89c (Tests.Security) — so here we only
> REMOVE the orphaned metric test coverage; no new absence tests needed.

## Git push — DO NOT (§37). Commit only. (234 HALT.)

---

## Step 0 — §0.6a MANDATORY INTEGRITY CHECK (first, no exceptions)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f ($WT_LINES)"; fi
done
sync; echo "=== integrity check complete ==="
```
NOTE: verify changed files by EXPLICIT hash (`git hash-object` vs `git rev-parse <HEADHASH>:<f>`) — incl. BYTE-LEVEL
drift at IDENTICAL line counts (observed twice now on this mount). Don't trust mount git status / line-count alone.

## Step 0b — §40 mandatory skill reads
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/app-cyber-security-expert/...  (F-1: no metric-mutation path)
```

## Multi-session sync (§42.6) — slug shell-0609
> Apply the machinery from `tools/cc_prompt_sync_block.md` (READ it first): phantom-aware `/tmp/acquire_lock.py` + S1/S3/S4.

CLAIMS (3 files; coord_check_claims shell-0609 = exit 0 at draft, all unclaimed — test-5/QA on-hold; these are
Tests.Unit, distinct from devops' Tests.Integration/ApplyService):
  - tests/CcDashboard.Tests.Unit/Commands/Configuration/SaveRtsGridMetricCommandHandlerTests.cs
  - tests/CcDashboard.Tests.Unit/Commands/Configuration/SaveMetricTranslationCommandHandlerTests.cs
  - tests/CcDashboard.Tests.Unit/Commands/Configuration/DeleteConfigurationCommandsTests.cs
- **S1 push-barrier:** `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report.
- **S2 claims:** `python3 tools/coord_check_claims.py shell-0609 <each of the 3 paths>` -> exit 1 = STOP. Touch ONLY these (+ /tmp scratch).
- **S3 commit.lock** around git add/commit (acquire_lock per sync_block, owner shell-0609; 15-min stale=report+wait). Covers §0.4 plumbing path.
- **S4 post-commit:** `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- **S5:** no git push. **DO NOT edit CcDashboard.sln** (only build it).

## §0.3 — Edit tool BANNED. Edits via Python read->modify->write + os.fsync; deletions via `git rm`. Verify with hash, not line-count.

---

## THE WORK — remove the 3 orphaned metric-mutation test coverages

Verified at draft (structure):
1. `SaveRtsGridMetricCommandHandlerTests.cs` (132 lines) — PURELY metric-save tests (class SaveRtsGridMetricCommandHandlerTests,
   no non-metric handlers). **DELETE the whole file** (`git rm`).
2. `SaveMetricTranslationCommandHandlerTests.cs` (140 lines) — PURELY metric-translation tests. **DELETE the whole file** (`git rm`).
3. `DeleteConfigurationCommandsTests.cs` (118 lines) — **MIXED**, do NOT delete:
   - KEEP `DeleteBusinessUnitCommandHandlerTests` (non-metric — valid coverage).
   - KEEP `DeleteSupergroupCommandHandlerTests` (non-metric — valid coverage).
   - REMOVE ONLY `DeleteRtsGridMetricCommandHandlerTests` (the class at ~line 86 referencing the removed
     `DeleteRtsGridMetricCommandHandler` / `DeleteRtsGridMetricCommand`). Remove that class + any now-unused usings it
     alone required. Leave the other two classes and their fixtures intact.
Before changing #1/#2, RE-CONFIRM each is purely metric (no `new Save/Delete<X>CommandHandler` for a non-metric X);
if a file is actually mixed, fall back to the class-removal approach (like #3) instead of deleting the file.

Do NOT add new tests — the F-1 absence invariant is already enforced by RtsGridMetricCatalogueTests.cs (78bf89c).

### Verify (mandatory)
- `dotnet build CcDashboard.sln` -> **0 errors** (whole solution — this is the gate condition; the prior fix proved
  one-project build is insufficient).
- `grep -rnE "SaveRtsGridMetricCommand|DeleteRtsGridMetricCommand|SaveMetricTranslationCommand|DeleteMetricTranslationCommand|SaveRtsGridMetricRequest|SaveMetricTranslationRequest" tests --include=*.cs`
  -> the ONLY remaining matches must be the STRING LITERALS in RtsGridMetricCatalogueTests.cs (the absence assertions).
  No `new ...Command(...)`, no handler-type references anywhere in tests.
- Confirm DeleteConfigurationCommandsTests still has the BusinessUnit + Supergroup test classes (coverage preserved).
- If a test runner/Docker is available, Tests.Unit + Tests.Security run green; else compile-only is acceptable for
  the build gate (the absence facts need no DB).

## Commit (fix:)
```bash
bash tools/pre-commit-check.sh
# acquire commit.lock (S3), then:
GIT_INDEX_FILE=/tmp/cc-idx git rm tests/CcDashboard.Tests.Unit/Commands/Configuration/SaveRtsGridMetricCommandHandlerTests.cs tests/CcDashboard.Tests.Unit/Commands/Configuration/SaveMetricTranslationCommandHandlerTests.cs
GIT_INDEX_FILE=/tmp/cc-idx git add tests/CcDashboard.Tests.Unit/Commands/Configuration/DeleteConfigurationCommandsTests.cs
# commit -m "fix: RV-1b remove metric-mutation Tests.Unit orphans -> CcDashboard.sln builds 0 errors [shell-0609]"
```
Then §0.6 post-commit verify -> S4 cc_post_commit.sh -> PD-007 re-sync the modified file from HEAD (hash-verify, NOT line-count) -> `sync`.

## Report back
files removed/edited ; `dotnet build CcDashboard.sln` result (MUST be 0 errors) ; grep result (only absence string
literals remain) ; confirm BU+Supergroup coverage preserved ; commit hash ; git status clean. NO push.
