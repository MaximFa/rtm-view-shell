# CC task — DEVOPS: Garnet PoC (INC-001 (d) durable fix — PHASE 1 of 3, GATE)
> §4-PASS coordinator-0612 (2026-06-21T21:29:58Z) — EXECUTE authorized (eval/research, NO prod change, free/MIT). Owner devops-0619. Branch v2-backend. NO push (§37).
> NO prod change — dev/local PoC only. FREE/MIT binary only (operator standing constraint). This PoC GATES Phase 2 (migration).

## Context
INC-2026.06.20-001 root = Memurai Developer Edition 10-day max-uptime auto-shutdown. Operator accepted Microsoft Garnet
(MIT, native Windows, RESP, no uptime cap) as the durable replacement (eval 5e9e22d). Phased adoption:
  Phase 1 = PoC (THIS prompt, gate) -> Phase 2 = migration (Install/Update/packaging) -> Phase 3 = fleet rollout 234+45.
Interim resilience already in: (a) shell AbortOnConnectFail=false [9732eab], (b) Memurai sc-failure auto-restart [da4cd7e].

## INIT + discipline
- §0.2/§0.5 object-store (mount lies). §0.3 Python+fsync. Binding PREAMBLE -> .coord/cc/devops.md. commit.lock around the docs commit. NO push (§37).
- READ: .claude/skills/session-coord/session-coord.md + CLAUDE.md §2 (stack: native Windows, ALL-IN-ONE, NO Docker/systemd), §34 (RTM Relay / SignalR backplane), §23 SCALE-02, DEPLOY-08/09/11 (Redis 127.0.0.1:6379, requirepass, RDB). SKIP widget-planner/widget-creator (coordinator: irrelevant to this devops task).
- App Redis surface (object-store grounded — what the PoC must exercise):
  - `src/CcDashboard.Web/Program.cs:41` redisConn = GetConnectionString("Redis") ?? "localhost:6379"
  - `src/CcDashboard.Web/Program.cs:42-47` AddSignalR().AddStackExchangeRedis(redisConn, opts => opts.Configuration.AbortOnConnectFail=false)  <-- THE INC-001 backplane dependency
  - `src/CcDashboard.Web/Program.cs:127` health `.AddRedis(...)`
  - `src/CcDashboard.Infrastructure/Caching/RedisCacheService.cs` (PG-permission cache, distributed state, TTL)
  - `src/CcDashboard.Web/appsettings.json:8` "Redis": "localhost:6379" (conn-string stays UNCHANGED — Garnet listens on the same host:port)

## THE POC (dev/local, NO prod change)
1. Stand up Garnet locally from a FREE/MIT release (microsoft/garnet GarnetServer.exe): bind 127.0.0.1, port 6379,
   `--auth <password>` (requirepass-equiv), checkpoint dir (RDB-equivalent persistence). Record exact version + flags.
2. Point a DEV Shell at it (appsettings "Redis":"localhost:6379" already matches — no code change). Run the app dev profile.
3. VERIFY against ACTUAL uses (PASS/GAP with evidence — command output or app log per row), NOT just GET/SET:
   - [CRITICAL] SignalR backplane: `AddStackExchangeRedis` -> RedisHubLifetimeManager CONNECTS **and pub/sub fan-out works**.
     Two-circuit test if feasible (two Shell instances / two browser circuits sharing the backplane; verify a hub broadcast
     fans out across both). This is the exact failure path of INC-001 — connect alone is NOT sufficient, prove pub/sub.
   - [RESP] revoked-JTI list (AUTH-API-05): list add + TTL expiry.
   - [RESP] rate-limit counters (BFP-02): INCR + EXPIRE semantics.
   - [RESP] PG-permission cache (PG-07, RedisCacheService): StringSet/StringGet + KeyExpire TTL semantics.
   - [RESP] distributed state (SCALE-02): keys with tenant prefix `{tenantId}:...`.
   - [AUTH] `--auth` password accepted by StackExchange.Redis client; bind 127.0.0.1:6379 only (DEPLOY-08/09).
   - [PERSIST] checkpoint/RDB-equivalent survives a service restart (DEPLOY-11).
4. If ANY GAP blocks the backplane (esp. pub/sub) -> STOP, document the gap, recommend FALLBACK to WSL2-Valkey (eval #2). Do not force-fit.

## DELIVERABLE
- Report `docs/incidents/INC-001_garnet_poc_results.md`: filled parity matrix PASS/GAP + evidence per row + verdict
  (GREEN gates Phase 2 / RED -> Valkey fallback) + exact Garnet version/flags used + any caveats (e.g. Redis-7 command parity).
- Throwaway PoC config (garnet.conf / run script), if produced, under `infra/**` or `deploy/**` (devops territory).
- Commits: docs: for the report; deploy:/infra for any PoC config. commit.lock, narrow git add, §0.6/§0.7 verify. NO push.

## ACCEPTANCE (Phase-1 gate)
PoC report exists with the full matrix; the CRITICAL pub/sub backplane row is evidenced PASS (two-circuit fan-out) OR a
documented RED verdict routing to Valkey. Verdict explicit. NO prod change, NO push.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: verdict (GREEN/RED), backplane evidence, any GAPs, commit hashes. Hold Phase 2 for operator confirm on GREEN.
