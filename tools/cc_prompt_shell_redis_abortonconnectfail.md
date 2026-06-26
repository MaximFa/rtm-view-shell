# CC task — INC-001 (a): Redis backplane AbortOnConnectFail=false (role-shell)
> §4-PASS by coordinator-0612 (2026-06-21) — EXECUTE authorized. Owner: role-shell. Executor: native CC. Claim: src/CcDashboard.Web/Program.cs. Commit `fix:`. **NO push** (§37).
> INC-001 root: Memurai/Redis down at Shell start -> `RedisHubLifetimeManager.OnConnectedAsync` throws on circuit connect -> WebSocket 1011 -> BOTH Viewer AND Editor (InteractiveServer, shared circuit) blank. `AbortOnConnectFail` defaults TRUE in StackExchange.Redis -> the backplane throws at startup/connect instead of degrading. Fix = set it false so Shell starts and the circuit connects even with Redis down (SignalR backplane degrades; single-instance unaffected).
> ONE-RELEASE with devops INC-001 (b) (Memurai service Automatic + recovery). Coordinate at deploy.

## INIT (role-shell §A + §C-green) + §40 (widget-planner / widget-creator / session-coord). §0.6a integrity + POST-VERIFY (ls+cat+git show HEAD, NOT -f/-s stat — mount phantoms). §42.6 sync slug shell-0609 (S1-S5). §0.3 Python+fsync (Edit BANNED). Binding PREAMBLE -> .coord/cc/shell.md.

## §42.6 sync — slug shell-0609
- S1 push-barrier: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report. (coordinator 05:33: freeze LIFTED, request.md is a mount false-positive — re-verify by `cat`; if it shows FREEZE ACTIVE content, STOP and escalate.)
- S2 claims: `python3 tools/coord_check_claims.py shell-0609 src/CcDashboard.Web/Program.cs` -> exit 1 = STOP. Touch ONLY this file (+ /tmp scratch).
- S3 commit.lock around git add/commit (owner shell-0609; 15-min stale=report+wait). Covers §0.4 plumbing path.
- S4 post-commit: `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- S5: NO git push.

## ROOT / GROUNDING (object-store, Program.cs:42-45)
```csharp
    var redisConn = config.GetConnectionString("Redis") ?? "localhost:6379";
    var signalR = services.AddSignalR();
    if (!isDev)
        signalR.AddStackExchangeRedis(redisConn, opts =>
            opts.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("CcDashboard"));
```
The lambda is a single expression (sets ChannelPrefix only). `opts.Configuration` is a StackExchange.Redis `ConfigurationOptions`; `AbortOnConnectFail` defaults true.

## THE WORK — single edit, Program.cs
Convert the expression-bodied lambda to a block and add `AbortOnConnectFail = false;`, KEEPING ChannelPrefix:
```csharp
    if (!isDev)
        signalR.AddStackExchangeRedis(redisConn, opts =>
        {
            opts.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("CcDashboard");
            opts.Configuration.AbortOnConnectFail = false;
        });
```
- Do NOT touch the `isDev` gate (dev still in-memory transport), the `/health/ready` Redis check (L124), or anything else.
- No new using needed (StackExchange.Redis already referenced for RedisChannel). No new C# member -> no @inject/@using guard issue.

## VERIFY (build-cite or honest 'not run')
- Object-store: Program.cs lambda is now a block with BOTH `ChannelPrefix = ...Literal("CcDashboard")` AND `AbortOnConnectFail = false;`; `if (!isDev)` gate unchanged; balanced braces (the new `{ ... });` closes correctly).
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE the 0-Error line; else honest "BUILD: not run (no dotnet)".** (Brace-balance is the only compile risk — confirm by cat.)

## ACCEPTANCE (product floor — operator/devops; anti false-confirmation)
Redis is UP today so a naive test passes for the WRONG reason. PROOF = **stop Memurai -> start Shell with env != Development (so the backplane is actually wired; Development uses in-memory and would false-pass) -> BOTH the Viewer page AND an Editor page open and become interactive (no WebSocket 1011 blank).** A green that the running Redis produces is NOT acceptance.
Deploy as ONE release with devops INC-001 (b) (Memurai Automatic + recovery).

## §0.6b CAPTURE -> role-shell §B (git add -f) if a real lesson, e.g.:
"StackExchange.Redis AbortOnConnectFail defaults true -> SignalR Redis backplane throws at circuit connect when Redis is down, blanking ALL InteractiveServer pages (shared circuit). RULE: set AbortOnConnectFail=false on the backplane so the app degrades instead of failing closed; test with the dependency DOWN + non-Development env (Development uses in-memory transport -> false-pass)."

## Commit (fix:, NO push) under commit.lock
`bash tools/pre-commit-check.sh` -> acquire commit.lock -> `git add src/CcDashboard.Web/Program.cs` (+ role-shell.md if CAPTURE, `-f`) -> `git commit -m "fix: INC-001(a) Redis backplane AbortOnConnectFail=false so Shell circuit survives Redis-down (was WebSocket 1011 blanking Viewer+Editor) [shell-0609]"` -> §0.6 post-commit (verify git show HEAD) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync from HEAD -> sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; Program.cs lambda block + AbortOnConnectFail=false (ChannelPrefix kept, isDev gate intact); build cite OR 'not run'; CAPTURE if any. NO push. ONE-release w/ devops (b). verified: object-store.

## Report (chat): commit hash; the one edit via git show HEAD; build line OR honest not-run; restate acceptance = Redis DOWN + non-Development, Viewer+Editor interactive (operator/devops floor); ONE-release w/ devops (b). NO push.
