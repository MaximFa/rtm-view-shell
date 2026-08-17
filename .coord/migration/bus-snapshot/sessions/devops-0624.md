---
session: RTM — Devops
slug: devops-0624
started: 2026-06-24T23:40:00Z
heartbeat: 2026-06-25T21:30:00Z
status: done
modules: [devops]
claims: [infra/**, deploy/**, tools/Build-*.ps1, tools/Soma/**, db/tools/**, .github CI, repo hygiene]
files: []
cc_task: F-QA-4 root fix authored (cc_prompt_devops_soma_fqa4_killguard.md) -> coordinator §4; /db/dashboards fix eeacd76 DONE
---

# devops-0624 — supersedes devops-0619

Continues devops-0619 (HANDOFF 2026-06-24T20:30Z). Branch v3 @ aa544d0.

## Active task
F-QA-8 residual: /db/dashboards 500 (Npgsql NO-MARS — outer reader not disposed before per-dashboard widget loop on same conn). Fix: nested {} scope so outer reader disposes before widget foreach. Narrow-add tools/Soma/Program.cs, v3, fix:.

## Queue
- tools/cc_prompt_devops_soma_healthurl.md — already MERGED as af41c68 (HealthUrl 7196->5238). [DONE — see journal 2026-06-24T19:30Z; queue item retired]
- SF-SEC-001 [HIGH] — live-tree purge of DB password (~27 files). OWN; GATED on operator rotation window.
- Garnet Phase-3 fleet rollout (234/45) — on operator GO.

## Discipline
object-store/by-SHA verify (mount HEAD-ref truncates = §0.5, not corruption); NARROW-ADD claimed files only (L-SC-09); NO push (§37); commits = native CC; CC prompts -> §4 (`коорд: ревью`) before run. Soma 127.0.0.1:5199 via host Chrome (sandbox bash cannot reach host loopback).
