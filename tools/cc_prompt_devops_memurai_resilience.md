# CC task — DEVOPS: Memurai (Redis) service resilience — INC-001 task (b)
> §4-PASS coordinator-0612 2026-06-21T06:05:07Z. Owner devops-0619. Commit `deploy:`. NO push (§37).
> NO active push-freeze (corrected: request.md absent; push #2 done 5206633). EXECUTE NOW (native CC). ONE-RELEASE with shell task (a) (`AddStackExchangeRedis` AbortOnConnectFail=false); 234 deploy is operator-gated.

## INCIDENT
INC-2026.06.20-001: Redis/Memurai down -> SignalR backplane `RedisHubLifetimeManager.OnConnectedAsync` throws -> WS 1011 -> Viewer+Editor render blank.
- Part (a) SHELL (separate prompt): `AddStackExchangeRedis(..., opts => opts.ConnectionMultiplexerFactory / Configuration.AbortOnConnectFail=false)` so the circuit tolerates a transient Redis-down at start.
- Part (b) THIS PROMPT (devops): make the Memurai Windows service auto-start at boot AND auto-restart on failure, so Redis self-heals.

## INIT + discipline
- §0.2/§0.5 object-store (mount lies — verify by `git show HEAD:`, not mount `git status`). §0.3 Python+fsync for any .coord write. Binding PREAMBLE -> `.coord/cc/devops.md`. `commit.lock` around the commit (§42.6 S3). NO push (§37).
- CONFIRM FIRST (object-store) HEAD `deploy/Install-RTMView.ps1` still has the Memurai block intact (the `[ 2/6 ] Memurai` section).

## ENCODING — IMPORTANT (do NOT regress §35, but Install convention differs from Update)
- `deploy/Install-RTMView.ps1` repo source is **NO-BOM** (HEAD blob first3 = `23 52 65`). `tools/Build-ProdRelease.ps1` (L311-323) adds UTF-8 BOM + CRLF to every PS1/TXT at PACKAGE time. So the SHIPPED Install script gets BOM from the build; the repo source stays no-BOM.
- => PRESERVE the existing repo encoding: do **NOT** introduce a BOM into `Install-RTMView.ps1` (that would diverge from convention). Edit via Python read->modify->write; keep endings per `.gitattributes` (`*.ps1 text eol=crlf` -> blob LF, CRLF on checkout). Verify HEAD-blob first3 stays `23 52 65` after the edit (no new BOM).
- (Unlike `Update-RTMView.ps1`, which DOES carry BOM in-repo because its staged copy is overwritten directly outside the build — different file, different rule.)

## THE FIX — deploy/Install-RTMView.ps1, [ 2/6 ] Memurai block (~L150-178)
Add a service-resilience step that runs in BOTH branches (the `if ($redisSvc) { Already installed }` branch AND the fresh-MSI-install branch) so existing AND new Memurai installs are hardened. Insert AFTER the service exists/started. Suggested helper applied once after the Memurai block resolves the service:

```powershell
# Harden Memurai service: auto-start at boot + auto-restart on failure (INC-2026.06.20-001 resilience)
$memSvc = Get-Service -Name "Memurai" -ErrorAction SilentlyContinue
if ($memSvc) {
    try {
        Set-Service -Name "Memurai" -StartupType Automatic -ErrorAction Stop
        # Recovery: restart after 5s, 10s, then 60s; reset failure count daily
        & sc.exe failure "Memurai" reset= 86400 actions= restart/5000/restart/10000/restart/60000 | Out-Null
        & sc.exe failureflag "Memurai" 1 | Out-Null
        Write-Host "  Memurai resilience: StartupType=Automatic, recovery=auto-restart" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Could not set Memurai resilience: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
```

Place it so it executes whenever Memurai is present (not gated behind the fresh-install-only path). Logic otherwise UNCHANGED. Do not touch the `requirepass` / MSI logic.

## /health/ready — NO new endpoint (verify only)
The Redis readiness check already exists: `Program.cs:124` `.AddRedis(...)` + `Program.cs:165-166` `MapHealthChecks("/health")` + `MapHealthChecks("/health/ready")`. `/health/ready` returns Unhealthy when Redis is down. Do NOT add code. Add a runbook note to `deploy/README.txt` (Monitoring section) instructing ops to poll `GET /health/ready` and alert on non-200 (covers Redis-down). This is a deploy/ doc step within devops claim.

## VERIFY (object-store)
- `git show HEAD:deploy/Install-RTMView.ps1` (after commit): `Set-Service -Name "Memurai" -StartupType Automatic` present; `sc.exe failure "Memurai"` + `failureflag` present; Memurai `requirepass`/MSI logic unchanged.
- Encoding: HEAD blob first3 still `23 52 65` (NO BOM added). Line count increased only by the inserted block.
- README runbook note present.
- PowerShell parse: native-Windows only ([Parser]::ParseFile) — if on Linux mount, state "parse owed to operator".

## COMMIT (deploy:, NO push) under commit.lock
`deploy: Memurai service resilience — StartupType=Automatic + sc.exe failure auto-restart (INC-2026.06.20-001; Redis self-heal so SignalR backplane recovers) [devops]`
then §0.6 post-commit verify + §0.7 re-sync + sync.

## ACCEPTANCE (shared with shell task (a))
Redis DOWN at Shell start, env != Development, BOTH Viewer + Editor open interactive (no WS 1011 blank). Part (b) ensures Memurai auto-starts at boot and auto-restarts on crash; part (a) ensures the Shell tolerates a transient Redis-down at startup.

## REPORT -> binding `cc/devops.md` RESULT + `inbox/coordinator.md`
commit hash; resilience lines confirmed (object-store); encoding unchanged (no BOM); README runbook note added; Memurai MSI/requirepass logic untouched. NO push.
