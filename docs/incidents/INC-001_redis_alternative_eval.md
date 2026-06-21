# INC-2026.06.20-001 — Redis Alternative Evaluation Report

**Date:** 2026-06-21  
**Author:** devops-0619  
**Status:** RECOMMENDATION READY  
**Incident:** INC-2026.06.20-001 (Memurai Developer Edition 10-day auto-shutdown)

---

## Executive Summary

**Root cause:** Memurai Developer Edition has a hard 10-day max-uptime limit (vendor-imposed), after which it auto-shuts down. This caused the SignalR backplane outage on 2026-06-20 (Redis down → `RedisHubLifetimeManager.OnConnectedAsync` throws → WS 1011 → blank Viewer/Editor).

**Requirement:** FREE production-appropriate Redis replacement with NO uptime/connection/RAM tier caps.

**Recommendation:** **Microsoft Garnet** — native Windows, MIT license, FREE for production, full RESP compatibility with StackExchange.Redis, supports pub/sub (SignalR backplane requirement).

---

## Constraint Matrix

| Constraint | Garnet | Valkey (WSL2) | Redis OSS (WSL2) |
|------------|--------|---------------|------------------|
| **Native Windows Server (§2)** | PASS — .NET 8, native exe | GAP — requires WSL2 distro | GAP — requires WSL2 distro |
| **No Docker/Linux-systemd (§2)** | PASS — Windows Service via NSSM or sc.exe | PARTIAL — WSL2 distro auto-start needs wsl.conf + task | PARTIAL — same WSL2 complexity |
| **SignalR Redis backplane** | PASS — RESP wire protocol, StackExchange.Redis compatible, pub/sub supported | PASS — full Redis compatibility | PASS — full Redis compatibility |
| **RESP coverage (JTI, rate-limit, PG-cache)** | PASS — GET/SET/EXPIRE/TTL/pub-sub all supported | PASS | PASS |
| **Redis 7+ feature parity** | PARTIAL — covers our needs (strings, lists, pub/sub, TTL); some Redis 7 commands not yet implemented | PASS — Redis 7.2 compatible fork | PASS — is Redis 7.x |
| **Persistence (RDB equivalent)** | PASS — checkpoint/AOF supported | PASS | PASS |
| **AUTH (requirepass)** | PASS — `--auth <password>` CLI arg or config | PASS | PASS |
| **Bind 127.0.0.1:6379 (DEPLOY-08/09)** | PASS — `--bind 127.0.0.1 --port 6379` | PASS | PASS |
| **Windows Service, auto-start** | PASS — via NSSM or community wrapper | GAP — WSL2 distro boot requires workaround | GAP — same |
| **FREE for PRODUCTION** | PASS — MIT license, no tier caps | PASS — BSD 3-Clause | PARTIAL — Redis 7.4+ is SSPL/RSAL (not OSI-approved) |
| **NO uptime/connection/RAM caps** | PASS — no artificial limits | PASS | PASS (but license concern) |

### Scoring Summary

| Candidate | PASS | GAP/PARTIAL | Total Score |
|-----------|------|-------------|-------------|
| **Microsoft Garnet** | 10 | 1 (Redis 7 feature parity partial) | **10/11** |
| Valkey (WSL2) | 8 | 3 (native Windows, service, Docker-free) | 8/11 |
| Redis OSS (WSL2) | 7 | 4 (native Windows, service, Docker-free, license) | 7/11 |

---

## Detailed Analysis

### 1. Microsoft Garnet (RECOMMENDED)

**Pros:**
- Native Windows executable (.NET 8) — no WSL2/Docker dependency
- MIT license — FREE for production, no restrictions
- RESP wire protocol — works with existing StackExchange.Redis client (Shell connection string unchanged)
- Pub/sub support — SignalR Redis backplane compatible
- High performance — Microsoft Research benchmarks show sub-300µs p99.9 latency
- Already used internally at Microsoft by several platform teams
- Checkpoint persistence (RDB-equivalent) and AOF support

**Cons:**
- Still marked preview/beta on GitHub (v1.0 not yet GA as of 2026-06)
- Some advanced Redis 7 commands not yet implemented (not needed for our use case)
- Requires NSSM or community wrapper for Windows Service (not built-in)

**Windows Service Installation:**
```powershell
# Option 1: Using NSSM (recommended)
nssm install Garnet "C:\Program Files\Garnet\GarnetServer.exe"
nssm set Garnet AppParameters "--bind 127.0.0.1 --port 6379 --auth <password> --checkpointdir C:\Garnet\checkpoint"
nssm set Garnet Start SERVICE_AUTO_START
nssm start Garnet

# Option 2: Using sc.exe with community wrapper
sc.exe create Garnet binPath= "C:\Program Files\Garnet\Garnet.worker.exe --config-import-path garnet.conf" start= auto
```

**Configuration (garnet.conf):**
```
bind 127.0.0.1
port 6379
auth <requirepass-value>
checkpointdir C:\Garnet\checkpoint
```

### 2. Valkey (WSL2)

**Pros:**
- Full Redis 7.2 compatibility — drop-in replacement
- BSD 3-Clause license — truly open source, no tier caps
- Active Linux Foundation governance
- AWS ElastiCache default since late 2024

**Cons:**
- Requires WSL2 distro installation and management
- Auto-start at boot requires `wsl.conf` + Windows Task Scheduler workaround
- Additional operational complexity vs native Windows
- Not "all-in-one Windows Server" per §2 constraint

### 3. Redis OSS 7.x (WSL2)

**Pros:**
- The original — maximum compatibility
- Mature, well-documented

**Cons:**
- License changed to SSPL/RSAL (not OSI-approved) in Redis 7.4+
- Requires WSL2 (same operational complexity as Valkey)
- License violation risk if used commercially without compliance

---

## Migration Outline (Garnet)

### Pre-migration
1. Download Garnet release from [microsoft/garnet](https://github.com/microsoft/garnet/releases)
2. Extract to `C:\Program Files\Garnet`
3. Download NSSM from [nssm.cc](https://nssm.cc)

### Installation
```powershell
# 1. Install Garnet as Windows Service
nssm install Garnet "C:\Program Files\Garnet\GarnetServer.exe"
nssm set Garnet AppParameters "--bind 127.0.0.1 --port 6379 --auth <same-password-as-memurai> --checkpointdir C:\Garnet\data"
nssm set Garnet Start SERVICE_AUTO_START
nssm set Garnet AppDirectory "C:\Program Files\Garnet"

# 2. Stop Memurai
Stop-Service Memurai
Set-Service Memurai -StartupType Disabled

# 3. Start Garnet
nssm start Garnet

# 4. Verify
redis-cli -h 127.0.0.1 -p 6379 -a <password> PING
# Expected: PONG
```

### Shell Configuration
**No change required** — existing connection string `localhost:6379` with password works unchanged (RESP protocol compatible).

### Rollback
```powershell
# If Garnet fails, revert to Memurai (interim)
nssm stop Garnet
Set-Service Memurai -StartupType Automatic
Start-Service Memurai
```

---

## Verification Checklist (Post-Migration)

- [ ] `redis-cli PING` returns `PONG`
- [ ] Shell `/health/ready` returns 200 (Redis check passes)
- [ ] SignalR backplane works: open 2 browser tabs, verify live data sync
- [ ] Pub/sub test: `redis-cli SUBSCRIBE test` in one terminal, `redis-cli PUBLISH test hello` in another
- [ ] JTI revocation test: logout user, verify token rejected
- [ ] Service survives reboot: `Restart-Computer`, verify Garnet auto-starts

---

## Decision Record

| Option | Recommendation | Rationale |
|--------|----------------|-----------|
| **Microsoft Garnet** | **PROCEED** | Native Windows, MIT license, RESP compatible, meets all critical constraints. Preview status acceptable given Microsoft internal production use. |
| Valkey (WSL2) | DEFER | Viable fallback if Garnet fails SignalR pub/sub verification, but adds operational complexity (WSL2 management). |
| Redis OSS (WSL2) | AVOID | License concern (SSPL/RSAL) + WSL2 complexity. |
| Memurai Developer | REMOVE | 10-day uptime cap makes it unsuitable for production. Root cause of INC-001. |
| Memurai Pro | AVOID | Paid license required — operator constraint is FREE. |

---

## Next Steps

1. **Operator approval** of Garnet recommendation
2. **PoC on test environment** (not 234/45 prod) — verify SignalR pub/sub fan-out
3. **Update Install-RTMView.ps1** to include Garnet + NSSM instead of Memurai MSI
4. **Deploy to prod servers** (234, 45) during maintenance window
5. **Remove Memurai** from server after successful Garnet verification

---

## References

- [Microsoft Garnet GitHub](https://github.com/microsoft/garnet)
- [Garnet Documentation](https://microsoft.github.io/garnet/docs)
- [Garnet Windows Service Discussion](https://github.com/microsoft/garnet/discussions/301)
- [Garnet Production Deployment Discussion](https://github.com/microsoft/garnet/discussions/658)
- [Valkey Official Site](https://valkey.io/)
- [Redis vs Valkey 2026](https://dev.to/synsun/redis-vs-valkey-in-2026-what-the-license-fork-actually-changed-1kni)
