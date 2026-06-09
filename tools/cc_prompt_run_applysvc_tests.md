# CC Task — RUN ApplyService integration tests (verification, NO commit/push)

> Session devops-2-0607. Operator raised Docker → execute the 72bd997 ApplyService integration suite
> (Testcontainers+Postgres now available) to close the test-execution gate Security flagged.
> This is a VERIFICATION RUN ONLY: no code change, no commit, no push, no claims.

## 0. §0.6a integrity check (light: git status --short; do NOT modify anything).
## NO push (§37). NO commit. Do not edit any file.

## Run
```
dotnet test tests/CcDashboard.Tests.Integration --filter ApplyService --logger "console;verbosity=detailed"
```
(If the filter misses, fall back to the test class names: ApplyServiceIntegrationTests / ApplyServiceSecurityTests / the unit Theory classes. Ensure Docker is running first: `docker ps`.)

## Report back — per scenario PASS/FAIL (+ failure detail if any)
FUNCTIONAL: (1) apply-twice idempotent ; (2) RT-only appliedRtMetricIds ; (3) bad-migration→500 rollback.
SECURITY: (4) F-2 wrong-token 401 + missing-header 401 + empty/placeholder-token startup-throw ; (5) F-5 audit-fail→500 + success-path server-principal audit ; (6) F-4 tampered→409 + missing-hash→409 ; (7) F-6 unknown-metricId→400.
UNIT: ConstantTimeEquals (5 cases) ; PathTraversal (5 cases).
Give the totals (passed/failed/skipped) + the dotnet-test summary line. If any FAIL: full message + stack (may reveal a real regression). NO commit, NO push.
