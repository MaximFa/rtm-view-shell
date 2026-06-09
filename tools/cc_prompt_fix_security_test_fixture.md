# CC Task — Fix ApplyService SECURITY-test fixture (token injection) + re-run

> Session devops-2-0607. The 06:00 test run: unit 17/17 + functional 4/4 GREEN, but ALL 10 security tests
> FAILED at host startup with "ApplyService:Token is missing or placeholder" (Program.cs:25). This is the F-2
> guard working correctly — the SECURITY-test fixture just never injects a valid token before startup
> (the functional fixture does). TEST-CODE fix only, no production change. Then re-run.

## 0. §0.6a integrity (light). 
## Sync slug devops-2-0607. Claims: `tests/CcDashboard.Tests.Integration/ApplyService/` (test code only).
## §37 NO push.

## Fix (test code only — do NOT touch src/CcDashboard.ApplyService)
1. BEHAVIOURAL security tests (need a STARTED host with a VALID token): in the ApplyServiceSecurityTests
   WebApplicationFactory/fixture, set the token BEFORE startup:
   `builder.UseSetting("ApplyService:Token", "test-token-1234567890")` (in ConfigureWebHost / WithWebHostBuilder),
   matching whatever the FUNCTIONAL fixture already does (align them — copy the working pattern).
   - F-2 WrongToken_ShouldReturn401: send a DIFFERENT bearer → 401.
   - F-2 MissingAuthHeader_ShouldReturn401: no header → 401.
   - F-5 SuccessfulApply audit / AuditFailure→500, F-4 tampered/missing-hash→409, F-6 unknown-metricId→400:
     send the CORRECT "test-token-..." so the host starts and the per-request logic is exercised.
2. STARTUP-THROW tests (F-2 Empty/Placeholder token SHOULD throw) — these must NOT use the valid-token factory.
   Build a host with ApplyService:Token = "" (empty) and = "REPLACE_AT_DEPLOY" (placeholder) and assert the
   build/start THROWS InvalidOperationException (Assert.Throws / await Assert.ThrowsAsync around factory.CreateClient()
   or the host build). They verify the guard fires; do not let the shared fixture mask it.
3. F-5 AuditFailure test still injects the failing AuditDbContext (override DI) AFTER setting the valid token.

## Run + report
```
dotnet test tests/CcDashboard.Tests.Integration --filter ApplyService --logger "console;verbosity=detailed"
```
Report per-scenario PASS/FAIL again. EXPECT: all security tests now exercise their assertions (401/500/409/400 + startup-throw) and pass. If any FAIL now → that is a REAL behavioural finding (report full detail — may be a production issue).

## Commit — web: (test code)
pre-commit-check.sh→0 ; commit.lock ; `git add tests/CcDashboard.Tests.Integration` → `git commit -m "web: fix ApplyService security-test fixture (inject token before startup) — all 31 green"` ; §0.6 verify ; cc_post_commit.sh ; HEAD re-sync. NO push.
(Only commit if the re-run is GREEN. If failures are real production bugs, do NOT commit — report them.)

## Report back
re-run totals (passed/failed) ; per security-scenario result ; whether all 31 green ; commit hash (if green). NO push.
