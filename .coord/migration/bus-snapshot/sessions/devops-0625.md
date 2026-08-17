---
session: RTM DevOps
slug: devops-0625
started: 2026-06-25T19:57:00Z
heartbeat: 2026-07-22T10:12:00Z
status: active
modules: [devops]
files: []
cc_task: none
---
Role: devops (RTM View Shell), branch v3 @ 14e6929. ⛔ЧП ACTIVE (declared 2026-06-25 coordinator-0624) — role-skill §A top block: every detail (esp. visual)=RED; no decision around coordinator; NO chat CC run-code-box until §4 bless; coordinator personally visual-verifies each gap; verify on REAL prod-mirror data (234 backup). Shorthand: `.`=входящие, `..`=check-result.
Continues devops-0624. §0.2/§0.5 INTEGRITY: v3=14e6929 (object-store), origin/v3=db9d18e. §C VERIFY pass (Update-RTMView.ps1: @()-wrap, appsettings preserve, pg_dump, Compare-ToBaseline all present — no superseded). My 3 deliverables eeacd76/7ce8825/3fd7d0a — ANCESTORS of v3, all cc/devops.md RESULTs consumed (≤16:05). WT noise: `D Installations/03062026/*.dll` (NEVER commit) + reports/web M-files (other sessions' territory, not touched).

CLAIMS (devops territory): infra/**, deploy/**, tools/Build-*.ps1, tools/Soma/**, db/tools/**, .github CI, repo hygiene.

OPEN LOOSE-ENDS (post-init, coordinator §4 before ANY run):
1. [DEFERRED, non-blocking, coordinator @17:05 — UNHANDLED in inbox] doc-gap: add caveat to docs/Visual-Test-Preflight.md Profile A — standalone POST /ops/build COLLIDES w/ running dotnet-watch Shell -> CS2012 lock on Web.resources.dll (by-design F-QA-7 FreeShellOrphans; workaround = /shell/stop first OR rely on /shell/restart recompile).
2. [op-7, coordinator @21:25] Prod-Mirror-Seed (docs/Prod-Mirror-Seed-Plan.md) — devops/QA = VERIFY role; support when 234 backup lands in Installations/prod-mirror/.
3. [SF-SEC-001, HIGH, OWN] live-tree purge of DB password (~27 files incl tools/Soma/appsettings.json) — GATED on operator rotation window.
4. [Garnet Phase-3] fleet rollout 234/45 — on operator GO.

CURRENT IN-FLIGHT TASK: none. Inbox разобран (3 blocks handled), READY ack in barrier (freeze-notice, not a gate). Idle.
ENV: Soma 127.0.0.1:5199 (two-port 5199 Soma / 5238 Shell-probe; via host Chrome same-origin fetch + Bearer from tools/Soma/appsettings.json — never echo/commit token). Shell dev https:5239+http:5238. PG18.
