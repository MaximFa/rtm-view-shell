# CC TASK (DRAFT — pending coordinator §4 dispatch) — Evaluate FREE production Redis alternative (INC-2026.06.20-001 fix (d))

Status: §4-PASS by coordinator-0612 (2026-06-21T19:37:15Z) — EXECUTE authorized (devops cleared load: barrier #3 + tag done). EVAL/research only, NO prod change.
Owner role: devops (slug devops-0619). Claims: infra/**, deploy/** (+ the eval report doc under docs/). Branch: v2-backend. NO push (§37).

## Why
INC-001 root = Memurai **Developer Edition** free 10-day max-uptime auto-shutdown (vendor FAQ; floor: 06-10 03:54:12 -> 06-20 03:55:17 = 10d; INFO server edition=Memurai Developer). Operator requires a **FREE** production-appropriate replacement (no paid Memurai). (a) shell AbortOnConnectFail=false [9732eab] and (b) SC auto-restart [da4cd7e] are resilience/interim only — they do NOT remove the recurring 10-day outage or the prod-license violation. This task selects the durable replacement (d).

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Plus: CLAUDE.md §2 (stack constraints), §34 (RTM Relay/SignalR backplane), DEPLOY-08/09/11 (Redis on 127.0.0.1, requirepass, RDB, Windows Service).

## Task — evaluate candidates against the constraint matrix, produce a recommendation (research/PoC; NO prod change)
Candidates (rank Garnet first):
  1. **Microsoft Garnet** (microsoft/garnet) — native Windows + .NET, MIT, FREE, no tier/uptime cap, RESP wire-protocol.
  2. **Valkey** (BSD) under **WSL2** — §2-sanctioned 'Redis in WSL2' path (NOT Docker).
  3. **Redis OSS 7** under **WSL2** — fallback.

Constraint matrix — score EACH candidate PASS/GAP with evidence:
  - [§2] Native Windows Server, ALL-IN-ONE, **no Docker / no Linux-systemd**. (Garnet native; WSL2 path = distro auto-start at boot WITHOUT interactive login — verify feasibility/operability.)
  - [CRITICAL] **SignalR Redis backplane** works: `AddStackExchangeRedis` (StackExchange.Redis client) connects AND pub/sub fan-out functions (this is RedisHubLifetimeManager's actual dependency — test it, not just GET/SET).
  - [RESP coverage] All Redis uses in this app: revoked-JTI list, rate-limit counters, PG-permission cache, distributed state (SCALE-02) — verify required commands/TTL/pub-sub.
  - [Redis 7+] feature parity required by spec.
  - [Persistence] RDB-equivalent checkpoint (DEPLOY-11).
  - [AUTH] requirepass / password equivalent; bind 127.0.0.1:6379 only (DEPLOY-08/09).
  - [Service] runs as a Windows Service, auto-start at boot, idle-timeout safe.
  - [LICENSE] FREE for PRODUCTION (hard operator req) + **NO uptime/connection/RAM tier cap** (the exact failure class we are removing — Developer had 10-day + 10-IP + 50%-RAM caps).

## Deliverable (NO prod change in this task)
- A report at `docs/incidents/INC-001_redis_alternative_eval.md` (or docs/decisions/ADR-xxx): the filled matrix + a clear recommendation + migration outline (config: bind/port/requirepass/persistence + Windows-Service registration + Shell connection-string unchanged `localhost:6379`) + rollback. 
- If a throwaway PoC config is produced, it lands under infra/** or deploy/** (devops territory) via your own CC commit (commit.lock, NO push). The eval report is a docs commit.

## Discipline
§0.6a integrity first; sync block (slug devops-0619 + claims); binding pre/postamble to .coord/cc/devops.md; pre-commit-check; narrow git add; §0.6 verify; cc_post_commit; §0.7 re-sync; **NO push**. Report recommendation + any commit hashes to coordinator for the (d) decision.
