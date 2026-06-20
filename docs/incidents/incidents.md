# RTM View Shell — Incident Ledger
> Owner: role-incident. Durable, versioned. Each incident pinned to the FLOOR (specific error + stack), not a narrative.
> Processing: KNOWN-DETECTION by floor-signature FIRST; match -> confirm signature -> apply known fix; no match -> full §A diagnosis.

| ID | Date/time | Server | Symptoms (observed) | Root (FLOOR-pinned) | Resolution (+durable status) | Status |
|---|---|---|---|---|---|---|
| INC-2026.06.20-001 | 2026-06-20 ~14:07 +03 | 234 | dashboard VIEW does not open; EDIT opens but empty (no grid, no widgets); server log shows dashboards/widgets rendering server-side, so NOT data/code | Redis/Memurai DOWN -> SignalR Redis backplane `RedisHubLifetimeManager.OnConnectedAsync` throws on circuit connect -> WebSocket 1011 -> every interactive Blazor page blank (view AND edit). PIN: log-20260620 ~14:07 Redis errors (x7) + RedisHubLifetimeManager.OnConnectedAsync stack; aoc:1 | Immediate: restart Memurai (Redis) service -> prod restored. Durable (PENDING): AbortOnConnectFail=false in StackExchange.Redis config + Memurai service resilience/auto-restart + document the edit-vs-view backplane dependency. | resolved / durable-fix PENDING |

## Notes
- Same symptom ("editor empty") has had DIFFERENT roots historically (Redis-down vs stale-asset-cache vs ConfigJson-format) — ALWAYS match by floor-signature (error+stack), never by symptom.
