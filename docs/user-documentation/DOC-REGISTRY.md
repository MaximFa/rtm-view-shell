# RTM View Shell — Documentation Registry

> Maintained by `user-doc-expert` skill. Legend: 🟢 Current | 🟡 Draft / Needs review | 🔴 Not started | ⚪ Deferred

**Last updated:** 2026-05-29  
**Spec baseline:** TZ v1.4 (CLAUDE.md 2026-05-28)  
**Widget spec:** `docs/widget-specification.md` v1.8  

---

## Family A — Administrator Documentation

| ID | Document | File | Status | Notes |
|---|---|---|---|---|
| A-01 | Installation & Deployment Guide | `A-01_InstallDeployGuide_v1.0.docx` | 🔴 | Covers §24 DEPLOY-01–15; IIS, PostgreSQL, Redis, Memurai |
| A-02 | Administrator's Guide | `A-02_AdminGuide_v1.0.docx` | 🔴 | Users, PGs, Tenant settings, Audit log |
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
| B-02 | Dashboard Management User Guide | `B-02_DashboardUserGuide_v1.0.docx` | 🔴 | Create / edit / delete screens; widget picker |
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

*Registry v1.0 — initialised 2026-05-29*
