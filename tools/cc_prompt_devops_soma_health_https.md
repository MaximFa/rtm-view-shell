# CC TASK — Soma /ops/health: probe HTTPS Shell (5239) + accept self-signed loopback cert

> Owner: role-devops (Soma = my territory). Branch: **v3**. status: DRAFT -> coordinator §4 -> operator runs.
> WHY: after the prod-parity deploy the Shell is HTTPS-only (UseHttpsRedirection): http://localhost:5238/health = 307 -> https://localhost:5239/health = 200. Soma's shellHealthUrl (:5238 http) now reads 307, and even pointed at https it would fail cert-validation on the self-signed/AllowInvalid loopback cert -> /ops/health (+ /shell/* health polls) mis-read unhealthy. Non-blocking / not release-gating, but fix so QA smoke's /ops/health reads the prod-parity env correctly.

## Mandatory reads
.claude/skills/role-devops/role-devops.md (§A+§C) ; session-coord (§1/§10) ; tools/Soma/USAGE.md. Reality wins.

## STEP 0 — Integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD   # MUST be v3
```
BINDING PREAMBLE -> .coord/cc/devops.md (status open).

## FIX A — HealthUrl -> https (config, §0.3 Python+fsync)
- tools/Soma/appsettings.example.json L13: `"HealthUrl": "http://localhost:5238/health"` -> `"https://localhost:5239/health"`.
- tools/Soma/Program.cs L65 fallback default: `?? "http://localhost:7196/health"` -> `?? "https://localhost:5239/health"`.
(The RUNNING config tools/Soma/appsettings.json is gitignored — operator updates its HealthUrl to https://localhost:5239/health at redeploy; call that out in the hand-off.)

## FIX B — accept the self-signed LOOPBACK cert for health probes only (Program.cs, §0.3)
Add a small factory near the other helpers:
```csharp
static HttpClient CreateHealthClient(int seconds) =>
    new HttpClient(new HttpClientHandler {
        // Shell health probe is LOOPBACK-only (localhost) to our own Shell's self-signed/AllowInvalid cert.
        // Defense-in-depth (coordinator §4): accept the self-signed cert ONLY for loopback requests.
        ServerCertificateCustomValidationCallback = (req, _, _, _) => req?.RequestUri?.IsLoopback == true
    }) { Timeout = TimeSpan.FromSeconds(seconds) };
```
Replace EVERY `new HttpClient { Timeout = TimeSpan.FromSeconds(N) }` that probes `shellHealthUrl` with `CreateHealthClient(N)` — audit all occurrences (at least L700=3, L708=2, L723=5, L768=5, L845=5). Do NOT change any OTHER HttpClient (there should be none besides these health probes; if the docker-check or anything else exists, leave it).
SCOPE NOTE: the accept-any callback is limited to these loopback health-probe clients — it does NOT touch Soma auth, soma_ro, *_safe views, secret handling, or any non-loopback call (SF-SOMA-001 guards UNCHANGED).

## STEP 1 — Build Soma (native CC), NO push
```bash
dotnet build tools/Soma   # compile OK (copy-lock warnings if Soma running — not syntax errors)
```

## STEP 2 — Acceptance (after operator Soma-redeploy)
Operator restarts Soma to pick up the change (running instance won't hot-reload) + sets local appsettings.json HealthUrl=https://localhost:5239/health. Then via host-Chrome->Soma GET /ops/health: liveness.up=true + readiness.up=true (200), NOT the prior 307/unhealthy. Report the /ops/health JSON.

## STEP 3 — Commit (v3, NO push) — pre-commit + commit.lock
```bash
bash tools/pre-commit-check.sh tools/Soma/Program.cs tools/Soma/appsettings.example.json   # exit 0
# commit.lock -> narrow add ONLY those 2 files (NEVER D Installations/*, _DriftGateProbe.cs) ->
# git commit -m "fix(soma): /ops/health probe HTTPS Shell (5239) + accept self-signed loopback cert (prod-parity env) [devops]"
# -> journal -> release lock
```
BINDING POSTAMBLE -> .coord/cc/devops.md RESULT (commit hash, 2 files, CreateHealthClient count, HealthUrl https, SF-SOMA-001 intact, build OK, /ops/health acceptance). **NO push** (§37). §0.7 re-sync both from HEAD.

## DO NOT
- NO push. Touch ONLY tools/Soma/Program.cs + tools/Soma/appsettings.example.json. Do NOT weaken any non-loopback cert validation, Soma auth, soma_ro, or *_safe secret handling. Do NOT commit the gitignored appsettings.json (token). Do NOT stage D Installations/*, _DriftGateProbe.cs. Do NOT commit to v2-backend.
