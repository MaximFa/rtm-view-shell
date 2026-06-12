# RTM View Shell — Documentation Registry

> User-facing A/B/C document families. Master index + governance: `docs/DOCS_INVENTORY.md`.
> Maintained by the RTM Tech Writer (techwriter-0610). Legend: 🟢 Current | 🟡 Draft / Needs review | 🔴 Not started | ⚪ Deferred
> **Standing rule:** approved docs use the “RTM View Shell Data Connector” template (branded docx-js); see DOCS_INVENTORY.

**Last updated:** 2026-06-11  
**B-02 status:** 🟢 Published v1.3 — 41 real screenshots embedded (all sections §4–§11, all 6 widget config tabs)  
**Spec baseline:** TZ v2.7 (CLAUDE.md 2026-06-08)  
**Widget spec:** `docs/widget-specification.md` v1.8  

---

## Family A — Administrator Documentation

| ID | Document | File | Status | Notes |
|---|---|---|---|---|
| A-01 | Installation & Deployment Guide | `A-01_InstallDeployGuide_v1.0.docx` | 🔴 | Covers §24 DEPLOY-01–15; IIS, PostgreSQL, Redis, Memurai |
| A-02 | Administrator's Guide | `admin/A-02_AdminGuide_v1.0_EN.docx` | 🟢 | v1.0 released 2026-05-30. 14 real screenshots: User Management, Permission Groups (4 tabs), Tenant Management (3 tabs), Dashboards, Audit Log. 1.3 MB. |
| A-03 | Permission Groups Configuration | `A-03_PermGroupsConfig_v1.0.docx` | 🔴 | Menu/Screens/Queues/Skills/BU/SG tabs detail |
| A-04 | Security Configuration Guide | `A-04_SecurityConfig_v1.0.docx` | 🔴 | JWT, SSO, 2FA, brute-force, headers |
| A-05 | SSO Integration Guide | `A-05_SSOIntegration_v1.0.docx` | 🔴 | SAML2 / OIDC / AD-LDAP; claim mappings |
| A-06 | Backup & Restore Runbook | `A-06_BackupRestoreRunbook_v1.0.docx` | 🟡 | Draft exists (`RTM_View_Shell_Backup_Restore_v2.docx`) |
| A-07 | Multi-Tenant Management Guide | `A-07_MultiTenantGuide_v1.0.docx` | 🔴 | Tenant create/suspend/delete; Superadmin flows |
| A-08 | Info Slot Administration Guide | `A-08_InfoSlotAdminGuide_v1.0.docx` | 🔴 | Based on §6 widget-spec; CC-010/011/012 |
| A-09 | Upgrade & Patch Guide | `A-09_UpgradePatchGuide_v1.0.docx` | 🔴 | Update-CcDashboard.ps1 procedure |

---

## Family B — User Documentation

| ID | Document | File | Status | Notes |
|---|---|---|---|---|
| B-01 | Quick Start Guide | `B-01_QuickStart_v1.0.docx` | 🔴 | First login, 2FA, change password, basic nav |
| B-02 | Dashboard Management User Guide | `user/B-02_DashboardUserGuide_v1.3_EN.docx` | 🟢 | v1.3 released 2026-05-30. 41 real screenshots: all sections §4–§11 + all 6 widget configuration tab screenshots. 1.9 MB. |
| B-03 | Info Slot Message Management Guide | `B-03_InfoSlotMessages_v1.0.docx` | 🔴 | Viewer flow: list IS, write/edit messages, priority, expiry |
| B-04 | Profile & Settings Guide | `B-04_ProfileSettings_v1.0.docx` | 🔴 | Password change, 2FA toggle, locale, theme |
| B-05 | Dashboard Viewer Guide | `B-05_DashboardViewer_v1.0.docx` | 🔴 | Screen 05; queue filter tabs; live updates |
| B-06 | Widget Catalogue Reference | `B-06_WidgetCatalogueRef_v1.0.docx` | 🔴 | All widget types; config options per §5–§6 widget-spec |

---

## Family C — Training Materials

| ID | Document | File | Status | Notes |
|---|---|---|---|---|
| C-01 | Administrator Onboarding (PPT) | `C-01_AdminOnboarding_v1.0.pptx` | 🔴 | 15–20 slides; system overview, first-run checklist |
| C-02 | Supervisor / Viewer Onboarding (PPT) | `C-02_ViewerOnboarding_v1.0.pptx` | 🔴 | 10–12 slides; login, screens, info slot messages |
| C-03 | Info Slot Feature Training (PPT) | `C-03_InfoSlotTraining_v1.0.pptx` | 🔴 | 8–10 slides; what it is, how to use, examples |
| C-04 | Permission Model Workshop | `C-04_PermModelWorkshop_v1.0.docx` | 🔴 | Interactive: role matrix, PG scenarios, lab exercises |
| C-05 | Security Awareness Briefing (PPT) | `C-05_SecurityBriefing_v1.0.pptx` | 🔴 | Password policy, 2FA, SSO, audit trail |

---

## Family D — Executive / Stakeholder Materials

| ID | Document | File | Status | Notes |
|---|---|---|---|---|
| D-01 | System Overview & Architecture (PPT) | `D-01_SystemOverview_v1.0.pptx` | 🔴 | C4 context; tech stack; non-functional summary |
| D-02 | Security & Compliance Summary | `D-02_SecurityCompliance_v1.0.docx` | 🔴 | JWT, 2FA, audit, password policy; compliance-ready |
| D-03 | Release Notes v1.0 | `D-03_ReleaseNotes_v1.0.docx` | 🔴 | Features delivered in v1; known limitations; roadmap |

---

## Recommended start order

1. **A-06** — draft already exists, quick win
2. **B-01** — Quick Start; unblocks end-user onboarding
3. **A-02** — Admin guide; highest demand from ops team
4. **A-08 + B-03** — Info Slot docs (CC-010/011/012 just shipped)
5. **C-01 / C-02** — Onboarding decks for go-live training
6. Remaining A / B / D in priority order

---

---

## Family E — Client & Methodology Deliverables (template-compliant)

| ID | Document | File | Status | Notes |
|---|---|---|---|---|
| E-01 | Unified Reporting Guide (BI, PostgreSQL) | `docs/bi/approved/doc/RTM_Unified_Reporting_Guide_EN_v1.0.docx` (+pdf) | 🟢 | v1.0, RTM-REL-2026.06. Data dictionary, 4 worked examples, Real Time Metrics Table. Branded template. |
| E-02 | Unified Reporting Guide (BI, SQL Server) | `docs/bi/approved/doc/RTM_Unified_Reporting_Guide_EN_SQLServer_v1.0.docx` (+pdf) | 🟢 | v1.0, RTM-REL-2026.06. Single-tenant, T-SQL. Branded template. |
| E-03 | Project Launch Runbook (methodology) | `docs/methodology/project-launch/approved/doc/Project-Launch-Runbook_EN_v1.0.docx` (+pdf+md) | 🟢 | v1.0, RTM-REL-2026.06. Cowork multi-session bootstrap P0–P5 + templates. Branded template. |

*Family E follows the approved/editing governance with in-doc revision tables; md sources retained in editing/.*

---

*Registry — refreshed 2026-06-11 by techwriter-0610 (baseline TZ v2.7). Legacy `DOCUMENT_CATALOG.*` retired (superseded by this registry + DOCS_INVENTORY).*

