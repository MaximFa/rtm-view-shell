# CC TASK — restore CcDashboard.Tests.Unit (62 compile errors, Reports/HistoricalReports drift)

> Owner: role-bi (bi-0626). Branch: v3 (ONLY branch). status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. HIGH: CcDashboard.Tests.Unit does NOT compile — 62 errors, ALL in Reports/HistoricalReports
> tests. My Reports backend changes shipped WITHOUT updating their tests → the suite has been RED → unit gate unsatisfiable.
> FIX = update the TESTS to the CURRENT prod API (do NOT change prod to fit stale tests unless prod is genuinely wrong). NO push.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + BRANCH NORM + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD   # MUST == v3 (v2-backend consolidated into v3; v3 is the ONLY branch — checkout v3 if not)
git rev-parse HEAD                 # verify v3 tip
git status --short                 # M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
CLAIM (file-mode): tests/CcDashboard.Tests.Unit/** (the 6 drifted test files below) + .claude/skills/role-bi/role-bi.md (§B).
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## CURRENT PROD API (the TRUTH the tests must match — object-store, v3 HEAD)
1. `RunReportWidgetQuery(ReportWidgetType WidgetType, string ConfigJson, DateTime From, DateTime To, int Page = 1, Guid? TenantId = null, bool AllRows = false) : IRequest<ReportWidgetResult>`
2. `IReportScreenRepository.GetByIdAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default)` — SAME shape for `GetByIdWithWidgetsAsync` and `GetByIdWithWidgetsAndSchedulesAsync` (the `bool bypassTenantFilter` is BEFORE `ct`).
3. `ReportWidgetScopeService(IReportScopeResolver scopeResolver, IBuMembershipResolver buResolver, ICurrentUserAccessor currentUser, ILogger<ReportWidgetScopeService> logger)` — **4-arg ctor** (the old 5th dep, the BackendEmulation/beDb, was removed in the BU-only refactor).
4. `ReportWidgetConfigValidator` — PageSize rule = `InclusiveBetween(1, 1000)` ("PageSize must be between 1 and 1000"); the `ValidPageSizes` const {25,50,100} was REMOVED (R9).

## FIX BY ERROR CLASS (update tests to the above)
- **CS1503 ×23 (CancellationToken where bool expected)** — SaveReportWidgetsTests:47/71/98/143, CloneReportScreenCommandTests:163, ReportScreenCrudTests:120: the repo `GetById*` calls/mock setups now have `bool bypassTenantFilter` before `ct`. Update every mock Setup/Verify + call to include the bool: e.g. `Setup(r => r.GetByIdWithWidgetsAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()))` and calls to `GetByIdWithWidgetsAsync(id, /*bypassTenantFilter*/ false, ct)` (or named `ct: ct`). Same for GetByIdAsync / GetByIdWithWidgetsAndSchedulesAsync. If any test invokes RunReportWidgetQuery positionally past `To`, align to the new (Page, TenantId, AllRows) tail (use named args).
- **CS1729 ×6 (no 5-arg ctor)** — ReportWidgetScopeServiceTests:226 (+others): construct ReportWidgetScopeService with the 4 deps (scopeResolver, buResolver, currentUser, logger) — DROP the removed beDb/BackendEmulation mock arg.
- **CS0117 ×32 (missing member/const)** — ReportWidgetConfigValidatorTests (×26): remove references to the deleted `ValidPageSizes`; rewrite the PageSize cases to the new bound — VALID: 1, 25, 500, 1000; INVALID: 0, 1001 (assert message "PageSize must be between 1 and 1000"). Fix the remaining CS0117 per the compiler (member renamed/removed → use the current member).
- **CS1061 ×1** — a member rename/removal; fix per the compiler against the current prod type.
Files to touch: ReportWidgetConfigValidatorTests, ReportWidgetScopeServiceTests, ReportScreenCrudTests, SaveReportWidgetsTests, CloneReportScreenCommandTests, BuMembershipResolverTests. (Only touch tests; do NOT edit prod unless a test reveals a genuine prod defect — if so, STOP and flag, do not silently change prod.)

## METHOD (build-driven — iterate to zero)
1. `dotnet build tests/CcDashboard.Tests.Unit` → read the errors.
2. Update each failing test to the CURRENT prod API (above). Re-build until 0 errors.
3. `dotnet test tests/CcDashboard.Tests.Unit` → make failed=0 (fix any now-compiling-but-asserting-stale test to the correct current behaviour; if a test asserts something prod no longer does because prod is CORRECT, update the assertion; if it reveals a real prod bug, STOP + flag).

## ACCEPTANCE (DoD)
1. `CcDashboard.Tests.Unit` COMPILES (0 errors). 2. `dotnet test tests/CcDashboard.Tests.Unit` → **failed=0**, REPORT the COUNTS (passed/failed/skipped/total). 3. `dotnet build CcDashboard.sln` clean (sln compiles). 4. NO prod code changed (tests-only) — or, if a genuine prod defect was found, it is FLAGGED not silently patched. 5. v3 branch. NO migration. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify post-commit. commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed test files) → commit `test: restore CcDashboard.Tests.Unit to current Reports API (bypassTenantFilter/AllRows arg order, ReportWidgetScopeService 4-arg ctor, PageSize 1..1000) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (files, test COUNTS passed/failed/total, build status, object-store verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-07-02 · Reports backend changes (bypassTenantFilter single-load, R2 ReportWidgetScopeService 4-arg ctor, RunReportWidgetQuery +AllRows, R9 ValidPageSizes→InclusiveBetween) shipped WITHOUT updating their unit tests → CcDashboard.Tests.Unit RED (62 compile errors), unit gate unsatisfiable, Reports work shipped untested. RULE: any prod signature/ctor/const change updates its tests IN THE SAME task. · SOURCE: coordinator 2026-07-02 + CS1503/CS1729/CS0117 · status: active`

## DO NOT
- Do NOT change prod code to fit stale tests (update the tests to prod). If a test reveals a real prod defect → STOP + flag.
- Do NOT commit to any branch except v3. NO migration / NO push.
