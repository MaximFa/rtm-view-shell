# CC Task (Shell specialist, slug shell-0609) — RV-1: fix orphaned Security test after F-1 (rewrite to absence regression)

> DRAFT for coordinator §4. Security re-review #2 (RV-1) follow-up to b7b20e4 (F-1 metrics read-only).
> b7b20e4 removed the metric-mutation commands, but `tests/CcDashboard.Tests.Security/Configuration/
> RtsGridMetricCatalogueTests.cs` still references SaveRtsGridMetricCommand(Handler)/SaveRtsGridMetricRequest →
> Tests.Security DOES NOT COMPILE → all Security tests masked. (Root cause: F-1 verify built only CcDashboard.Web,
> not the solution. Lesson: when removing public types, build the WHOLE sln.)
> Fix = rewrite the orphan file into a POSITIVE ABSENCE regression that locks the F-1 invariant.

## Git push — DO NOT (§37). Commit only; push requested separately. (234 HALT in effect.)

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
NOTE: mount `.git` unreliable — verify by EXPLICIT hash (`git hash-object <f>` vs `git rev-parse <HEADHASH>:<f>`),
incl. BYTE-LEVEL drift at identical line counts (lesson from b7b20e4). Don't escalate from mount git status alone.

## Step 0b — §40 mandatory skill reads
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/app-cyber-security-expert/...  (F-1 invariant: client cannot mutate vendor-constant metrics)
```

## Multi-session sync (§42.6) — slug shell-0609
> Apply the machinery from `tools/cc_prompt_sync_block.md` (READ it first): phantom-aware `/tmp/acquire_lock.py` + S1/S3/S4.

CLAIMS (1 file; coord_check_claims shell-0609 = exit 0, free — test-5 on-hold, devops holds a DIFFERENT dir
tests/CcDashboard.Tests.Integration/ApplyService/):
  - tests/CcDashboard.Tests.Security/Configuration/RtsGridMetricCatalogueTests.cs
- **S1 push-barrier:** `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report.
- **S2 claims:** `python3 tools/coord_check_claims.py shell-0609 tests/CcDashboard.Tests.Security/Configuration/RtsGridMetricCatalogueTests.cs` -> exit 1 = STOP. Touch ONLY this file (+ /tmp scratch).
- **S3 commit.lock** around git add/commit (acquire_lock per sync_block, owner shell-0609; 15-min stale=report+wait). Covers §0.4 plumbing path.
- **S4 post-commit:** `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- **S5:** no git push.
- **DO NOT edit CcDashboard.sln** (shared touch, devops flagged). Building the sln does NOT modify it — only build, never edit.

## §0.3 — Edit tool BANNED. Write the file via Python read->modify->write + os.fsync, then `sync && tail -3 && wc -l`.

---

## THE WORK — rewrite RtsGridMetricCatalogueTests.cs into an F-1 absence regression

The OLD file (317 lines, 6 [Fact]) exercised SaveRtsGridMetricCommandHandler + SaveRtsGridMetricRequest +
SaveRtsGridMetricCommand — ALL removed by b7b20e4. Those test cases are now meaningless (the mutation path is gone).
REPLACE the whole file with a regression that PROVES the F-1 invariant and compiles against current types.

### Required content
1. Namespace `CcDashboard.Tests.Security.Configuration`; keep xUnit + FluentAssertions. NO DB needed → drop the
   `[Collection("Postgres")]` + `PostgresFixture` ctor + EF/Npgsql/NSubstitute usings (remove now-unused usings so
   the file compiles clean; do not leave dangling `using CcDashboard.Application.Commands.Configuration;` etc.).
2. Reflection-based absence tests (NO references to the removed types — reference them only by STRING name):
   - Get the Application assembly via a STILL-EXISTING type, e.g.
     `typeof(CcDashboard.Application.Queries.Configuration.GetRtsGridMetricsQuery).Assembly`
     (verify this query exists; if the namespace differs, use any current Application type).
   - `[Fact]` assert the Application assembly contains NO type whose name is any of:
     `SaveRtsGridMetricCommand`, `SaveRtsGridMetricCommandHandler`, `DeleteRtsGridMetricCommand`,
     `DeleteRtsGridMetricCommandHandler`, `SaveMetricTranslationCommand`, `SaveMetricTranslationCommandHandler`,
     `DeleteMetricTranslationCommand`, `DeleteMetricTranslationCommandHandler`.
     (`asm.GetTypes().Select(t => t.Name)` must intersect the forbidden set as EMPTY.)
   - `[Fact]` assert the Contracts assembly (via a still-existing type, e.g.
     `typeof(CcDashboard.Contracts.DTOs.Auth.LoginRequest).Assembly` — verify) contains NO type named
     `SaveRtsGridMetricRequest` or `SaveMetricTranslationRequest`.
   - Add `[Trait("Req","F-1")]` and a class summary: "F-1 regression: metrics are vendor product-constants — the
     client has NO server-side command/request to create/edit/delete/translate a metric. If any reappears, F-1 has
     regressed (RCE surface via Roslyn-compiled MetricFunction/Parameter/Format)."
3. KEEP the read path legitimate: do NOT assert against `GetRtsGridMetricsQuery` or the Deploy/apply types
   (those are sanctioned). Only the MUTATION commands/requests must be absent.

### Verify (mandatory)
- `dotnet build CcDashboard.sln` -> 0 errors (WHOLE SOLUTION — this is the RV-1 lesson; one-project build is NOT enough).
- Confirm Tests.Security compiles. If a test runner is available, run this file's facts -> green; if Testcontainers/
  DB is unavailable in the sandbox, at minimum the project must COMPILE and the new facts must not require DB.
- `grep -rnE "SaveRtsGridMetric|DeleteRtsGridMetric|SaveMetricTranslation|DeleteMetricTranslation" tests --include=*.cs`
  -> only matches should be the STRING literals inside the absence assertions (no `new ...Command(...)`, no handler types).

## Commit (fix:)
```bash
bash tools/pre-commit-check.sh
# acquire commit.lock (S3), then:
GIT_INDEX_FILE=/tmp/cc-idx git add tests/CcDashboard.Tests.Security/Configuration/RtsGridMetricCatalogueTests.cs
# commit -m "fix: RV-1 rewrite orphaned RtsGridMetricCatalogue test as F-1 absence regression (Tests.Security compiles) [shell-0609]"
```
Then §0.6 post-commit verify -> S4 cc_post_commit.sh -> PD-007 re-sync (`git show HEAD:<f> > <f>`, hash-verify, NOT line-count) -> `sync`.

## Report back
file rewritten ; `dotnet build CcDashboard.sln` result (0 errors — whole solution) ; the grep result (only string
literals remain) ; whether facts ran/green or compile-only (DB availability) ; commit hash ; git status clean. NO push.
