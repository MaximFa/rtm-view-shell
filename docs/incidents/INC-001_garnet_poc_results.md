# INC-2026.06.20-001 — Garnet PoC Results (Phase 1 Gate)

**Date:** 2026-06-22
**Author:** devops-0619 (executed live with operator on dev workstation LAPTOP-M4B1MKEC)
**Garnet version tested:** 1.1.10 (win-x64 net8.0 readytorun build) — NOT 2.0.0-beta.4 as the harness template assumed
**Status:** ✅ **VERDICT: GREEN** — Garnet validated as the Memurai replacement. Phase-1 gate PASSED.

---

## Executive Summary

Microsoft Garnet (MIT, native Windows, no uptime cap) was stood up locally and validated against ALL Redis
operations RTM View Shell actually uses — including the CRITICAL one that failed in INC-001: the SignalR Redis
**backplane pub/sub fan-out** (`RedisHubLifetimeManager`).

**The CRITICAL gate PASSED:** bidirectional cross-instance SignalR fan-out through Garnet was observed live.
A message broadcast on instance B (:5001) was delivered to a client connected to instance A (:5000) and vice-versa —
only possible if Garnet's pub/sub carried it between processes. This is exactly the path that threw WS 1011 in INC-001.

GREEN gates **Phase 2 (migration)** — pending operator confirm.

---

## Environment

| Item | Value |
|---|---|
| Machine | LAPTOP-M4B1MKEC (dev workstation, NOT prod) |
| .NET SDK | 8.0.422 |
| Garnet | 1.1.10, `C:\Garnet\net8.0\GarnetServer.exe` (win-x64 MIT) |
| Start args | `--bind 127.0.0.1 --port 6379 --auth Password --password TestPwd123 --checkpointdir C:\Garnet\data` |
| CLI used | `memurai-cli.exe` copied to `C:\Garnet\redis-cli.exe` (RESP-compatible) |
| Memurai | stopped during PoC (freed port 6379) — **restart after** |

---

## Parity Matrix (verified live)

| # | Test | Requirement | Result | Evidence |
|---|------|-------------|--------|----------|
| 1 | PING | connectivity + AUTH | ✅ PASS | `PONG` with `-a TestPwd123` |
| 2 | StringSet/Get | RedisCacheService (PG-07) | ✅ PASS | SET/GET round-trip |
| 3 | TTL/EXPIRE | cache expiry, JTI TTL (AUTH-API-05) | ✅ PASS | `SET … EX 60`→`TTL`=60, `PTTL`=59915 (verified manually — see Finding 3) |
| 4 | INCR | rate-limit counters (BFP-02) | ✅ PASS | INCR→1,2 |
| 5 | LIST ops | revoked-JTI list (AUTH-API-05) | ✅ PASS | RPUSH/LLEN=2 |
| 6 | AUTH | requirepass equivalent | ✅ PASS | authenticated with `--auth Password --password` |
| 7 | PUB/SUB command | PUBLISH accepted | ✅ PASS | PUBLISH returns subscriber count |
| 8 | Tenant-prefixed keys | SCALE-02 / ARCH-08 | ✅ PASS | `{tenantId}:pg_permissions:…` |
| 9 | **SignalR backplane fan-out** | **CRITICAL — INC-001 dependency** | ✅ **PASS** | two-instance cross-process delivery (below) |
| 10 | Persistence (checkpoint) | RDB-equivalent (DEPLOY-11) | ✅ PASS | key survived stop + restart **with `--recover`** |

**Command-level: 8/8 PASS. CRITICAL backplane: PASS. Persistence: PASS.**

---

## CRITICAL gate — SignalR backplane fan-out (evidence)

Tested with a minimal 2-instance SignalR app (`infra/garnet-poc/BackplaneTest/`) that mirrors the Shell's exact wiring
— same `AddSignalR().AddStackExchangeRedis(...)` + same `ChannelPrefix = "CcDashboard"` (Program.cs:44-47). DB-free, so
it isolates the backplane. (Note: the Shell wires the backplane only in non-Development — Program.cs `if (!isDev)`.)

- Both instances logged `RedisHubLifetimeManager[2] Connected to Redis.` against Garnet (distinct Server Names).
- `PUBSUB CHANNELS *` on Garnet showed the shared backplane topology:
  `CcDashboardTestHub:all`, `:internal:groups`, and `:internal:ack/return:<server>` for BOTH instances + `CcDashboard__Booksleeve_MasterChanged`.
- **Fan-out, both directions:**
  - Broadcast triggered on instance B (:5001) → received by the client on instance A (:5000) — `[06:48:57] broadcast BY instance localhost:5001`.
  - Broadcast triggered on instance A (:5000) → received by the client on instance B (:5001) — `[06:48:54] broadcast BY instance localhost:5000`.
- Each client is connected to ONE instance only; receiving the OTHER instance's broadcast proves Garnet carried it cross-process. ✅

---

## Findings (fold into Phase 2 / fix the harness)

1. **Auth syntax (harness bug).** `garnet-args.txt` + the template said `--auth <password>`. Garnet's `--auth` is the MODE
   (`NoAuth`/`Password`/`Aad`/`ACL`); the password goes in `--password`. Correct: `--auth Password --password <pwd>`.
2. **§35 BOM (harness bug).** `Verify-GarnetPoC.ps1` had box-draw chars but no UTF-8 BOM → Windows PowerShell 5.1 failed
   to parse ("string is missing the terminator"). Re-encoded to UTF-8 BOM + CRLF.
3. **redis-cli `-a` warning pollutes output (harness bug).** The `-a` password warning merges into stdout (`2>&1`),
   making `$ttl` an array → the TTL test crashed on `[int]$ttl` and was SILENTLY dropped (summary read "7/7", not "8/8").
   Use `REDISCLI_AUTH` env var instead of `-a`. TTL was re-verified manually (PASS).
4. **Doc procedure was invalid.** The template's "dev run + two browser tabs on one instance" proves nothing: the Shell
   backplane only wires in non-Development, and one instance can't show fan-out. The real gate needs TWO instances
   (Production Shell ×2, or the minimal app used here).
5. **Migration prerequisite.** Shell conn-string must include the password for Garnet's `--auth`:
   `appsettings ConnectionStrings:Redis = "localhost:6379"` → must become `"localhost:6379,password=<pwd>"`. App code
   unchanged (host:port the same; `AbortOnConnectFail=false` already in).
6. **Persistence needs `--recover`.** Garnet recovers the checkpoint on startup ONLY with `--recover`. Phase 2 service
   registration must pass it (and a checkpoint frequency).

---

## Caveats

1. **Version pinning.** Tested on Garnet **1.1.10** (net8.0 build inside `win-x64-based-readytorun.zip`). Phase 2 must pin
   a specific tested version; re-validate if bumping.
2. **Redis 7 parity is partial** — Garnet covers our uses (STRING/LIST/TTL/PUB-SUB/INCR/AUTH); advanced Redis 7 commands
   not exercised (we don't use them).
3. **Dev DB drift** blocked the full-Shell path (baseline↔EF history mismatch: `tenant_settings.SlThresholdSeconds`
   missing though EF reported "up to date"). Sidestepped via the minimal backplane app. Not a Garnet issue; flagged for
   the dev-DB owner separately.

---

## Verdict

**GREEN.** Garnet is a viable, free (MIT), native-Windows, no-uptime-cap replacement for Memurai Developer for both the
SignalR backplane (the INC-001 failure path) and all RESP uses, with working AUTH, internal bind, and checkpoint
persistence. **Proceed to Phase 2 (migration)** on operator confirm. No fallback to Valkey needed.

## Next (Phase 2 — migration, on operator GO)

- Garnet as a Windows Service (NSSM or `Garnet.worker.exe`): `--bind 127.0.0.1 --port 6379 --auth Password --password <prod> --checkpointdir <dir> --recover`, StartupType=Automatic + `sc failure` recovery (parity with da4cd7e).
- `Install-RTMView.ps1` / `Update-RTMView.ps1`: Memurai block → Garnet; `Build-ProdRelease.ps1` packaging.
- Shell conn-string: add `,password=<prod>` (no code change).
- Phase 3: fleet rollout 234 + 45 (+ enumerate Memurai-Developer boxes — SF-INC-001) during maintenance windows.
