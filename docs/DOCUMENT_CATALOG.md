# RTM View Shell — Document Catalog

> **Purpose:** Structured index of all project documents with description, type, status, and location.
> Updated: 2026-05-30.

---

## How to use this catalog

| Column | Meaning |
|---|---|
| **ID** | Unique document identifier for cross-referencing |
| **Title** | Document name |
| **Type** | `spec` · `arch` · `guide` · `ref` · `analysis` · `test` · `process` · `template` |
| **Status** | `current` · `draft` · `archived` · `template` |
| **Location** | Path relative to project root |

---

## 1. Governing Documents

Core documents that define the project scope, rules, and current state.

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| GOV-01 | **CLAUDE.md** — Comprehensive instructions for all executors (Claude Code, Cowork). Single source of truth: stack, architecture rules, security checklist, coding conventions, deployment, all §§ | spec | current | `CLAUDE.md` |
| GOV-02 | **PROJECT_STATUS.md** — Session-resume snapshot: sprint inventory with commit hashes, test counts, pending actions, backlog, and security/process findings register | process | current | `PROJECT_STATUS.md` |
| GOV-03 | **CHANGELOG.md** — All notable changes by version (Keep a Changelog format), correlated with TZ revisions | process | current | `CHANGELOG.md` |

---

## 2. Technical Specification (TZ)

Official Technical Specification documents in chronological order.

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| TZ-01 | **CC Dashboard Shell TZ v1.0** — Initial Russian-language specification | spec | archived | `CC_Dashboard_Shell_TZ_v1.0.docx` |
| TZ-02 | **CC Dashboard Shell TZ v1.1** — First revision (Russian) | spec | archived | `CC_Dashboard_Shell_TZ_v1.1.docx` |
| TZ-03 | **CC Dashboard Shell TZ v1.2** — Baseline for v1.3 gap analysis (Russian) | spec | archived | `CC_Dashboard_Shell_TZ_v1.2.docx` |
| TZ-04 | **CC Dashboard Shell TZ v1.2 EN** — English translation of v1.2 | spec | archived | `CC_Dashboard_Shell_TZ_v1.2_EN.docx` |
| TZ-05 | **CC Dashboard Shell TZ v1.3 EN** — Adds widget framework, agent states, data-ownership model, deployment details | spec | current | `docs/CC_Dashboard_Shell_TZ_v1.3_EN.docx` |
| TZ-06 | **CC Dashboard Shell TZ v1.4 EN** — Adds §32 proactive doc maintenance, i18n refinements, audit log partition details | spec | current | `docs/CC_Dashboard_Shell_TZ_v1.4_EN.docx` |
| TZ-07 | **TZ v1.2 Baseline (text extract)** — Plain-text extraction used as baseline for gap analysis | ref | archived | `analysis/tz_v1.2_baseline.md` |

---

## 3. Architecture Documents

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| ARCH-01 | **Stakeholder Summary v1.3** — Non-technical overview of RTM View Shell: purpose, components, deployment, security highlights; intended for product owners and managers | guide | current | `docs/RTM-View-Shell-Stakeholder-Summary-v1.3.md` |
| ARCH-02 | **Architecture Diagrams** — C4 Context, C4 Container, ER diagram, Login+2FA sequence, Refresh Token rotation sequence, Tenant resolution sequence (Mermaid) | arch | current | `docs/diagrams/architecture.md` |
| ARCH-03 | **RTS Infrastructure** — Technical reference for the CC platform RTS layer: RTSGrid_Metric catalogue, metric format (narrow/wide), SignalR connection, SUM_OVERLAP_MS semantics | arch | current | `docs/architecture/rts-infrastructure.md` |
| ARCH-04 | **Widget Framework Architecture v1.3** — Architecture of the widget subsystem: IWidget contract, DataSlot RTS persistence, AgentGrid/QueueGrid patterns, dark mode, RTL | arch | current | `docs/architecture/widget-framework.md` |

---

## 4. Installation & Operations

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| OPS-01 | **Installation Guide (MD)** — Step-by-step deployment: Windows Server, IIS, PostgreSQL, Memurai Redis, HTTPS/TLS, firewall, pg_hba, seed data | guide | current | `INSTALL.md` |
| OPS-02 | **Installation Guide (DOCX)** — Formatted Word version of OPS-01 for delivery | guide | current | `RTM_View_Shell_Installation_Guide.docx` |
| OPS-03 | **Simulator Installation Guide** — Deployment of the simulator package (pre-baked PostgreSQL dump) on Windows 10/11 or Server for demo/testing | guide | current | `INSTALL-SIMULATOR.md` |
| OPS-04 | **Quick Start with Claude Code** — Developer quick-start: prerequisites, dotnet/EF commands, build, test, publish | guide | current | `SETUP.md` |
| OPS-05 | **Backup & Restore Guide (MD)** — Full project backup to Box.com; restore procedure to resume on any PC | guide | current | `docs/BACKUP_RESTORE.md` |
| OPS-06 | **Backup & Restore Guide (DOCX v1)** — Word version of backup/restore documentation | guide | archived | `docs/RTM_View_Shell_Backup_Restore.docx` |
| OPS-07 | **Backup & Restore Guide (DOCX v2)** — Updated Word version with additional procedures | guide | current | `docs/RTM_View_Shell_Backup_Restore_v2.docx` |
| OPS-08 | **appsettings Template** — Template for `appsettings.json` with all configurable parameters (secrets omitted) | ref | current | `appsettings.template.json` |
| OPS-09 | **RebuildAndRestart script** — PowerShell helper to stop IIS pools, rebuild solution, restart (dev workflow) | ref | current | `RebuildAndRestart.ps1` |

---

## 5. User Documentation

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| USR-01 | **User Guide (MD)** — End-user guide: login/2FA, dashboard management, permission groups, widget catalogue | guide | current | `USER_GUIDE.md` |
| USR-02 | **User Guide (DOCX)** — Word version for delivery to end users | guide | current | `RTM_View_Shell_User_Guide.docx` |
| USR-03 | **Dashboard User Guide v1.0 (DOCX)** — Detailed guide for dashboard creation and screen management | guide | archived | `docs/user-documentation/user/B-02_DashboardUserGuide_v1.0_EN.docx` |
| USR-04 | **Dashboard User Guide v1.1 (DOCX)** — Revised dashboard user guide (current release) | guide | current | `docs/user-documentation/user/B-02_DashboardUserGuide_v1.1_EN.docx` |
| USR-05 | **Documentation Registry** — Master registry of all user/admin documentation packages maintained by user-doc-expert skill | process | current | `docs/user-documentation/DOC-REGISTRY.md` |

---

## 6. Reference Documents

Technical references for developers and integrators.

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| REF-01 | **Traceability Matrix** — Maps every numbered TZ requirement (ARCH-xx, AUTH-xx, PWD-xx, AUD-xx, USR-xx, etc.) to implementation files and test cases | ref | current | `docs/traceability-matrix.md` |
| REF-02 | **RTSGrid_Metric Reference Guide** — Complete reference for 190 CC platform metrics: metric IDs, parameter formats, aggregation types, join keys for agent/queue data | ref | current | `docs/rtsgrid-metric-reference.md` |
| REF-03 | **Widget Catalogue v1.3** — Catalogue of all implemented widget types: AgentGrid, QueueGrid, DataSlot, DayTrend; version history, RTS persistence notes | ref | current | `docs/widget-catalogue.md` |
| REF-04 | **Widget Specification** — Technical spec per widget: data source, metrics used, configuration options, rendering requirements, CC task implementation notes | ref | current | `docs/widget-specification.md` |
| REF-05 | **Metrics CSV** — Raw export of 190 metrics from CC platform (source of truth for REF-02) | ref | current | `Metrics.csv` |
| REF-06 | **Backend Tasks** — Task backlog for Claude Code: infrastructure tasks, implementation items, backlog items with DoD checklists | process | current | `docs/backend-tasks.md` |
| REF-07 | **Skills Roadmap** — Just-in-time activation plan for project skills; maps triggers to skill creation/activation | process | current | `docs/skills-roadmap.md` |
| REF-08 | **Widget Creator Skill** — Developer guide for creating RTS grid widgets: patterns from AgentGrid implementation, dark mode, RTL, SignalR connection | ref | current | `docs/skills/widget-creator.md` |

---

## 7. Test Coverage Documents

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| TEST-01 | **Test Coverage Report v1 (DOCX)** — First edition: executive summary, sprint inventory table, test file catalogue, sprint-by-sprint results, SF/PD summary, requirements coverage | test | archived | `docs/RTM_View_Shell_Test_Coverage_Report_v1.docx` |
| TEST-02 | **Test Coverage Report v2 (DOCX)** — Detailed edition: all 63 test files with individual test method names and descriptions, grouped by subsystem and sprint; 382 tests total | test | current | `docs/RTM_View_Shell_Test_Coverage_Report_v2.docx` |

---

## 8. Sprint Documents

Task specifications for each test-coverage sprint executed by Claude Code.

### 8.1 Sprint Specifications

| ID | Sprint | Title | Status | Location |
|---|---|---|---|---|
| SPR-T1A | T1 Phase A | Security & tenant isolation tests — Phase A: GQF, web auth foundation (30 tests) | closed | `docs/sprints/T1-security-and-tenant-isolation.md` |
| SPR-T1C | T1 Phase C | Golden-path auth tests via WebApplicationFactory (19 tests) | closed | `docs/sprints/T1-phase-c.md` |
| SPR-T2 | T2 | Licensing enforcement + force-logout + JWT key configuration (20 tests) | closed | `docs/sprints/T2-licensing-enforcement.md` |
| SPR-T3 | T3 | Multi-tenancy integration tests: cross-tenant isolation, tenant resolution (36 tests) | closed | `docs/sprints/T3-multitenancy-integration.md` |
| SPR-T4 | T4 | Permission Group authorization semantics: bitmask, CC-resource filtering (46 tests) | closed | `docs/sprints/T4-pg-authorization-semantics.md` |
| SPR-T5 | T5 | Widget framework tests: IWidget contract, DataSlot, AgentGrid, QueueGrid (28 tests) | closed | `docs/sprints/T5-widget-framework.md` |
| SPR-T6 | T6 | User Management + Audit Trail (79 tests across Phase A + B) | closed | `docs/sprints/T6-user-audit.md` |

### 8.2 Gap Analysis Reports

| ID | Sprint | Title | Location |
|---|---|---|---|
| GAP-T1A | T1-A | Gap Analysis Phase A: GQF bypass, SecurityStamp handling | `docs/sprints/T1-gap-analysis-phase-a.md` |
| GAP-T1B | T1-B | Gap Analysis Phase B: JWT signing key, lockout, token rotation | `docs/sprints/T1-gap-analysis-phase-b.md` |
| GAP-T1C | T1-C | Gap Analysis Phase C: SSO stub, cookie auth, password change flow | `docs/sprints/T1-gap-analysis-phase-c.md` |
| GAP-T2 | T2 | Gap Analysis: licence slot enforcement, force-logout, Redis revocation | `docs/sprints/T2-gap-analysis.md` |
| GAP-T3 | T3 | Gap Analysis: tenant mismatch handling, cross-tenant mutation | `docs/sprints/T3-gap-analysis.md` |
| GAP-T5 | T5 | Gap Analysis: widget interface contracts, DataSlot null handling | `docs/sprints/T5-gap-analysis.md` |
| GAP-T6A | T6-A | Gap Analysis Phase A: missing audit events, cross-tenant mutation, self-role change | `docs/sprints/T6-gap-analysis-phase-a.md` |
| GAP-T6B | T6-B | Gap Analysis Phase B: audit log insert-only, partition GQF, CSV export limits | `docs/sprints/T6-gap-analysis-phase-b.md` |

### 8.3 Backlog Items

| ID | Title | Location |
|---|---|---|
| BLG-14 | WebFixture rate-limit isolation fix (resolves PD-003) | `docs/sprints/backlog-14-gap-note.md` |
| BLG-B111 | BackendEmulationDbContext introduction (infrastructure refactor) | `docs/sprints/backlog-b1-11-backend-emulation.md` |

### 8.4 Sprint Templates

| ID | Title | Location |
|---|---|---|
| TPL-SPR | Sprint document template | `docs/sprints/_template.md` |
| TPL-GAP | Gap analysis document template | `docs/sprints/_gap-analysis-template.md` |

---

## 9. Analysis & Audit

| ID | Title | Type | Status | Location |
|---|---|---|---|---|
| ANA-01 | **Security Findings Register** — SF-001..SF-007: severity, root cause, resolution commit, impact window estimate; all findings closed | analysis | current | `analysis/security-findings.md` |
| ANA-02 | **Process Deviations Register** — PD-001..PD-005: deviations from sprint working agreements detected during test-coverage programme | analysis | current | `analysis/process-deviations.md` |
| ANA-03 | **TZ v1.2 vs Implementation Gap Analysis** — Full divergence list: what TZ v1.2 required vs. what was actually implemented; feeds TZ v1.3 update | analysis | archived | `analysis/v1.2-vs-impl-gaps.md` |

---

## 10. Wireframes

Interactive HTML prototypes for all screens. Open in browser to navigate.

| ID | Screen | Route | File |
|---|---|---|---|
| WF-IDX | Index — navigation hub for all wireframes | — | `wireframes/en/index.html` |
| WF-01 | Login / SSO / 2FA / Change Password / Reset Password | `/login` | `wireframes/en/01_login_2fa.html` |
| WF-02 | User Management | `/admin/users` | `wireframes/en/02_user_management.html` |
| WF-03 | Permission Groups | `/admin/permission-groups` | `wireframes/en/03_permission_groups.html` |
| WF-04 | Screen Management (Dashboards) | `/screens` | `wireframes/en/04_screen_management.html` |
| WF-05 | Dashboard Viewer | `/screens/{id}` | `wireframes/en/05_dashboard_viewer.html` |

---

## Document Type Legend

| Type | Description |
|---|---|
| `spec` | Technical specification or governing requirement document |
| `arch` | Architecture document — system structure, patterns, design decisions |
| `guide` | User-facing or operator-facing procedural guide |
| `ref` | Technical reference — lookup tables, metric catalogues, API references |
| `analysis` | Gap analysis, security review, or post-mortem report |
| `test` | Test coverage report or test specification |
| `process` | Process document — status tracking, registries, task backlogs |
| `template` | Reusable blank template for a document type |

---

## Status Legend

| Status | Meaning |
|---|---|
| `current` | Active, authoritative version |
| `draft` | Work in progress, not yet reviewed |
| `archived` | Superseded by a newer version; kept for historical reference |
| `template` | Blank template — not a deliverable |

---

*This catalog is maintained manually. Update when documents are added, revised, or archived.*
