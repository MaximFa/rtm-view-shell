# INC-2026.06.20-001 — Garnet PoC Results (Phase 1 Gate)

**Date:** 2026-06-22  
**Author:** devops-0619  
**Status:** PoC READY FOR EXECUTION  
**Garnet Version:** 2.0.0-beta.4 (latest MIT release)

---

## Executive Summary

This document records the PoC verification of Microsoft Garnet as a Memurai replacement for RTM View Shell. The PoC tests all Redis operations used by the application against a local Garnet instance.

**CRITICAL GATE:** SignalR pub/sub backplane must demonstrate two-circuit fan-out to proceed to Phase 2.

---

## Garnet Instance Configuration

```
Executable:      C:\Garnet\GarnetServer.exe
Version:         2.0.0-beta.4 (win-x64, MIT license)
Arguments:       --bind 127.0.0.1 --port 6379 --auth <password> --checkpointdir C:\Garnet\data
Persistence:     Checkpoint (RDB-equivalent)
```

---

## Parity Matrix

| Test | Requirement | Status | Evidence |
|------|-------------|--------|----------|
| **PING** | Basic connectivity | PENDING | `redis-cli PING` |
| **StringSet/Get** | RedisCacheService (PG-07) | PENDING | SET/GET round-trip |
| **TTL/EXPIRE** | Cache expiry, JTI TTL (AUTH-API-05) | PENDING | `SET key val EX 60` + `TTL key` |
| **INCR** | Rate-limit counters (BFP-02) | PENDING | `INCR key` returns 1, 2, ... |
| **LIST ops** | Revoked-JTI list (AUTH-API-05) | PENDING | RPUSH/LLEN/LRANGE |
| **AUTH** | requirepass equivalent (DEPLOY-11) | PENDING | Connection with --auth |
| **PUB/SUB (command)** | PUBLISH accepted | PENDING | `PUBLISH channel msg` |
| **PUB/SUB (fan-out)** | CRITICAL — SignalR backplane | PENDING | Two-circuit live sync |
| **Tenant keys** | Prefixed keys (SCALE-02, ARCH-08) | PENDING | `{tenantId}:namespace:key` |
| **Persistence** | Checkpoint survives restart (DEPLOY-11) | PENDING | Restart Garnet, keys persist |

### Verification Script Output

```
[Run infra\garnet-poc\Verify-GarnetPoC.ps1 and paste output here]
```

### Manual SignalR Backplane Verification

**Test procedure:**
1. Start Garnet: `C:\Garnet\GarnetServer.exe --bind 127.0.0.1 --port 6379 --auth TestPwd123 --checkpointdir C:\Garnet\data`
2. Start Shell (Production mode for Redis backplane): `dotnet run --project src\CcDashboard.Web --no-launch-profile`
3. Open http://localhost:5000 in **two separate browser windows** (not tabs in same window)
4. Login as admin in both
5. Open a dashboard with live widgets (e.g., QueueGrid or AgentGrid)
6. Observe: updates should appear **simultaneously** in both windows (SignalR pub/sub fan-out)

**Result:** PENDING

**Evidence:** [Screenshot or observation notes]

---

## Verdict

| Outcome | Action |
|---------|--------|
| **GREEN** | All tests PASS including SignalR fan-out → Proceed to Phase 2 (migration) |
| **YELLOW** | Minor GAPs (non-backplane) → Document workarounds, proceed with caution |
| **RED** | SignalR backplane GAP → STOP, fallback to Valkey (WSL2) per eval recommendation |

**Current Verdict:** PENDING (awaiting PoC execution)

---

## GAPs and Mitigations

| GAP | Impact | Mitigation |
|-----|--------|------------|
| (none yet) | | |

---

## Caveats

1. **Beta status:** Garnet 2.0.0-beta.4 is pre-GA. Microsoft uses it internally but caveat emptor.
2. **Redis 7 commands:** Some advanced Redis 7 commands may not be implemented. Our app uses basic commands only (STRING, LIST, TTL, PUB/SUB).
3. **Cluster mode:** Not tested — single-node deployment per §2 all-in-one constraint.

---

## Next Steps (Post-GREEN)

1. **Phase 2 — Migration:**
   - Update `Install-RTMView.ps1` to install Garnet + NSSM instead of Memurai MSI
   - Update `Update-RTMView.ps1` to handle Memurai → Garnet migration
   - Package Garnet binaries + NSSM in release zip

2. **Phase 3 — Fleet Rollout:**
   - Deploy to 234 during maintenance window
   - Verify SignalR backplane in production
   - Remove Memurai from server
   - Repeat for 45

---

## References

- [Microsoft Garnet GitHub](https://github.com/microsoft/garnet)
- [Garnet Releases](https://github.com/microsoft/garnet/releases)
- [INC-001 Redis Alternative Eval](INC-001_redis_alternative_eval.md)
- [PoC Configuration](../../infra/garnet-poc/)
