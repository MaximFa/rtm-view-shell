# CC Task — WFM Phase 1: ErlangCalculatorService (pure math) + unit tests

> web/backend change. Implements the pure Erlang C/B math core for WFM Phase 1 per spec
> `docs/wfm-phase1-erlang-core-spec.md` (formulas §2-3, worked anchor §7 — VERIFIED numerically). Owner of the
> FORMULAS = metrics-3-0609 (§4 the math against the spec). Owner of the CODE = backend. This prompt = the pure,
> deterministic, unit-testable core ONLY — NO hosted loop / SignalR / widgets yet (separate follow-up once transport
> + (tenant,queue) scope are decided). v3. NO push.

## 0. §0.6a integrity FIRST (branch MUST be v3). §40 reads. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock (§42.4).
## Sync slug backend-0626. Claims:
##   - src/CcDashboard.Application/Interfaces/IErlangCalculatorService.cs   (new)
##   - src/CcDashboard.Application/Wfm/*  (new DTOs: WfmErlangResult / sentinel enum)
##   - src/CcDashboard.Infrastructure/Wfm/ErlangCalculatorService.cs        (new)
##   - tests/CcDashboard.Tests.Unit/Wfm/ErlangCalculatorServiceTests.cs     (new)
##   - Program.cs DI registration (AddScoped<IErlangCalculatorService, ErlangCalculatorService>) — Infrastructure DI module only

## Implement (deterministic pure functions — NO DB, NO I/O)
Signatures (adjust namespaces to project convention):
- `double ErlangB(int n, double a)` — overflow-safe RECURSION (spec §2): B=1; for k in 1..n: B=(a*B)/(k+a*B); return B.
- `double? ErlangC(int n, double a)` — null (=SystemOverloaded) if n<=a; else B/(1 - rho + rho*B), rho=a/n.
- `double TrafficIntensity(double lambdaPerHour, double ahtSec)` = lambdaPerHour*ahtSec/3600.
- `double? PredictedSl(int n, double a, double ahtSec, int tSec)` — null if n<=a; else 1 - C*Exp(-(n-a)*tSec/ahtSec). (fraction 0..1)
- `double? PredictedAsaSec(int n, double a, double ahtSec)` — null if n<=a; else C*ahtSec/(n-a).
- `int RequiredAgents(double a, double ahtSec, int tSec, double targetFraction, int cap=200, out bool capped)` —
  min n in [ceil(a)+1 .. cap] with PredictedSl(n,a,aht,t) >= target; if none, return cap and capped=true.
- `double? OccupancyPct(double a, int nActual)` — null if nActual<=0; else a/nActual*100.
- `double? UnderstaffPct(int required, int nActual)` — null if required<=0; else Max(0, required-nActual)/required*100.
- `int StaffVariance(int nActual, int required)` = nActual - required.
Guard EVERYTHING per spec §6 (n<=a, aht<=0, n=0, cap). Return nullable/sentinel — NEVER NaN/Inf/throw.

## Unit tests (xUnit + FluentAssertions) — MUST reproduce spec §7 anchor
Inputs: lambda=160/hr, aht=180s, nActual=10, t=20, target=0.80, trunk=100. Assert (tolerance 0.005 abs / 0.5% rel):
- TrafficIntensity => 8.0
- ErlangB(10,8) ≈ 0.1217
- ErlangC(10,8) ≈ 0.4092
- PredictedSl(10,8,180,20) ≈ 0.6724
- PredictedAsaSec(10,8,180) ≈ 36.83
- RequiredAgents(8,180,20,0.80) == 11  (and PredictedSl(10)≈0.672, PredictedSl(11)≈0.824)
- StaffVariance(10,11) == -1 ; OccupancyPct(8,10)==80 ; UnderstaffPct(11,10) ≈ 9.09
- ErlangB(100,8) < 1e-60 (no overflow)
Edge tests: ErlangC(8,8)==null and ErlangC(7,8)==null (overload); PredictedSl(8,8,..)==null; OccupancyPct(8,0)==null;
UnderstaffPct(0,5)==null; RequiredAgents with impossible target => capped=true, returns 200.

## Build + test
`dotnet build src/CcDashboard.Infrastructure` ; `dotnet test tests/CcDashboard.Tests.Unit --filter Erlang` — all green.

## Commit (commit.lock, §0.4 plumbing if index.lock stuck) — one commit
`web: WFM Phase1 ErlangCalculatorService (pure Erlang B/C math + unit tests vs verified anchor) [wfm]`
§0.6 verify -> cc_post_commit.sh -> PD-007 re-sync. NO push.

## Report: test results (the 8 anchor assertions), files, commit hash. NO push.
## FOLLOW-UP (not this task): hosted 30s loop per (tenant,queue) reading lambda/AHT/N from RTSData (§1) + WfmSnapshot
## SignalR delivery + Shell WFM widgets + TenantSettings WFM config (§5). Route to backend/shell/dba at §4.
