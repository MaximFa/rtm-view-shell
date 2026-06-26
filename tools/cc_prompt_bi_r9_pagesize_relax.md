# CC TASK — R9: relax report PageSize validator to 1..1000 (arbitrary rows-per-page)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. Operator: rows-per-page is now ARBITRARY (free input), cap MAX 1000. Server currently
> rejects anything except {25,50,100} → free input fails. Relax the server bound to 1..1000. Lands with shell free-input. NO push.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short
```
CLAIM (file-mode): src/CcDashboard.Application/HistoricalReports/Validators/ReportWidgetConfigValidator.cs + tests/CcDashboard.Tests.Unit/** + .claude/skills/role-bi/role-bi.md (§B if applicable).
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## THE CHANGE — ReportWidgetConfigValidator.cs ONLY (the sole remaining restrictor)
Object-store fact: the OTHER PageSize validators (ReportQueryValidators.cs L21/37/53/69) are ALREADY `InclusiveBetween(1, 1000)` — consistent, NO change. Only ReportWidgetConfigValidator still restricts to {25,50,100}.
- REMOVE the `ValidPageSizes` set (L14: `private static readonly HashSet<int> ValidPageSizes = new() { 25, 50, 100 };`).
- REPLACE the PageSize rule (L37-39):
```csharp
RuleFor(x => x.PageSize)
    .Must(ValidPageSizes.Contains)
    .WithMessage("PageSize must be 25, 50, or 100");
```
with:
```csharp
RuleFor(x => x.PageSize)
    .InclusiveBetween(1, 1000)
    .WithMessage("PageSize must be between 1 and 1000");
```
(PageSize is a non-nullable int, default 25 — the rule applies always; bound 1..1000 matches ReportQueryValidators.)

## ACCEPTANCE (DoD)
1. Build 0. 2. Unit: PageSize=75 / 200 / 1000 = VALID; PageSize=0 / 1001 = INVALID ("between 1 and 1000"); PageSize=25/50/100 still VALID. 3. No other {25,50,100}/ValidPageSizes restrictor remains (ReportQueryValidators already 1..1000). 4. RunReportWidgetQuery signature UNCHANGED (PageSize comes from ConfigJson; shell overrides via `Config with`). 5. NO migration. 6. NO push.

## PUBLISH (in RESULT, for shell)
Final server bound = **PageSize 1..1000 inclusive**. Shell clamps free input to the same 1..1000.

## STEP 5 — COMMIT + binding RESULT + re-sync
- §0.3 native CC; object-store-verify post-commit. commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `fix: relax report PageSize validator to 1..1000 (arbitrary rows-per-page) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (the rule change + published bound 1..1000, build/tests, object-store verify, status done).

## DO NOT
- Do NOT touch ReportQueryValidators (already 1..1000) / RunReportWidgetQuery signature / other validators. NO migration / NO push.
