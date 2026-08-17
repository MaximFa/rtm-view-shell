---
session: RTM — Backend (RTM Server / Engine / Shell backend)
slug: backend-0626
role: backend
started: 2026-06-26T00:00:00Z
heartbeat: 2026-07-22T14:02:13Z
status: active
modules: []
files:
  - src/CcDashboard.Application/Commands/**
  - src/CcDashboard.Application/Queries/**
  - RTM/**
  - db/functions/**
  - src/CcDashboard.Infrastructure/Seeding/SampleSeedGate.cs   # seeder-gate (pending §4-bless)
  - src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs
  - tests/CcDashboard.Tests.Unit/Seeding/SampleSeedGateTests.cs
cc_task: none (push barrier v3 WFM Phase1 — backend ACK=READY, awaiting quorum)
---
# backend-0626 — replaces backend-0620 (handoff) · ⛔ЧП ACTIVE

## 2026-06-26T00:00Z | boot (INIT runbook complete)
- §0.2/§0.5 integrity (object-store, NOT mount git status): branch v3, HEAD 14e6929 (matches expected v3 tip).
  ConfigurationQueries.cs INTACT — 284 lines, git hash-object == HEAD:<f> (PD-007 re-verify clean, no restore needed).
  M files in Application/Infra zone all FALSE-M (hash==HEAD, mount artifact). No truncation.
- Role-skill role-backend §A CORE loaded (⛔ЧП block active). §C VERIFY run: all 5 cardinal truths HOLD
  (RTM-SEC-002: 15 procedures = 2 CREATE PROCEDURE + 13 CREATE OR REPLACE PROCEDURE; p_tenant_id last;
  appsettings TenantId; relay Subscribe Union/Grid methods; JsonElement params). No supersession.
- session-coord skill loaded (§1 runbook, §10 verbs, ЧП shorthand .=входящие ..=check-result).
- Bus: no push/request.md (no barrier). cc/backend.md — ALL RESULTs consumed by coordinator (nothing to relay).
  inbox/backend.md — fully handled by predecessor (⛔ЧП HANDOFF-PREP processed). No unhandled directives.

## Inherited from backend-0620 HANDOFF (delivered + UNPUSHED on v3 · ЧП = NO push · awaiting QA live-seal)
- 051feea fix(di) F-QA-10 IAppDbContextFactory Singleton->Scoped — object-store VERIFIED, awaiting QA host-start smoke.
- cad6868 feat(dashboards) PurgeDashboardCommand (Trash hard-delete) — VERIFIED, awaiting QA build0+unit.
- 1e3efce fix(reports) R3 GetQueues/Sites/Supergroups/AgentGroups Superadmin tenant-fallback — VERIFIED + shell live-confirmed.
- origin/v3 = db9d18e; v3 tip = 14e6929. Whole branch unpushed (~30 ahead). NO in-flight CC, no open bindings.

## Resume point
Idle. Await coordinator dispatch under ЧП discipline (every visual detail RED; no decision around coordinator;
no chat run-prompt code-box until §4-bless; verify on 234 prod-mirror; never git push; code only via CC prompts).
