# RTM View Shell — Documentation Inventory (master governance index)

last_synced: 2026-06-11
last_synced_branch: v2-backend
spec_baseline: CLAUDE.md TZ v2.7 (2026-06-08)
maintained_by: techwriter-0610 (RTM Tech Writer)

> Project-wide index of all documentation, its governance state, and the standing rules.
> For the user-facing A/B/C document families see the detailed catalogue: `user-documentation/DOC-REGISTRY.md`.
> (The legacy `DOCUMENT_CATALOG.*` is RETIRED — superseded by this inventory + DOC-REGISTRY.)

---

## Standing rules (binding)

- **Template:** every document uses the **“RTM View Shell Data Connector”** template — the branded docx-js
  generator (INSIGHTENSE cover + logo, mandatory revision-history table, TOC populated via the UNO render,
  navy/blue headings, firm-styled tables, callout boxes, dark code blocks, keep-together pagination, logo
  header/footer). Markdown may be the editing source; the approved `.docx`/`.pdf` MUST use this template.
  Plain pandoc/soffice output is not acceptable as an approved copy.
- **Layout per doc area:** `approved/doc/` (versioned .docx) + `approved/pdf/` (versioned .pdf) + `editing/`
  (working) + `editing/build/` (generators). Every approved doc carries the revision table
  (Version | Date | Summary | Product release ID | Shipped-with).
- **Product release ID** is assigned by the coordinator (`RTM-REL-YYYY.MM[.patch]`); requested, never invented.
- **Flow:** edit in `editing/` → coordinator review → operator approval → file versioned in `approved/`.
- **Push quorum:** the Tech Writer runs a doc-sync impact triage at every barrier and ACKs READY only when
  affected docs are updated and in `approved/`.

## Doc areas — status

| Area | Path | Format / template | Governance | Status |
|---|---|---|---|---|
| BI / Reporting (client) | `docs/bi/` | branded docx+pdf (template) ✅ | approved/editing ✅ | 🟢 Unified Reporting Guide v1.0 (EN PG + EN SQL Server), RTM-REL-2026.06 |
| Methodology | `docs/methodology/project-launch/` | branded docx+pdf (template) ✅ | approved/editing ✅ | 🟢 Project Launch Runbook v1.0, RTM-REL-2026.06 |
| User docs (A/B/C families) | `docs/user-documentation/` | per-doc (pre-template) ⚠ | partial (versioned filenames) | see DOC-REGISTRY: 4 🟢, 2 🟡, 21 🔴 |
| Architecture | `docs/architecture/`, `docs/diagrams/` | markdown | in-repo working | 🟡 rts-infrastructure, widget-framework |
| Deploy / Ops | `deploy/`, `docs/External-Server-Ops-Layout.md` | scripts + md | working | 🔴 A-01 Install/Deploy Guide not started (doc-debt from barrier #4) |
| Backup / Restore | `docs/RTM_View_Shell_Backup_Restore_v2.docx`, `BACKUP_RESTORE.md` | pre-template ⚠ | none (loose) | 🟡 draft (= A-06) |
| Spec / SAD / TZ | `docs/CC_Dashboard_Shell_TZ_v1.6_EN.docx`, `SAD_*`, Stakeholder Summary | pre-template ⚠ | none (loose, version-sprawl) | 🟢 current = TZ v1.6 (older v1.3/v1.4 = history) |
| Security overview | `docs/RTMViewShell_SecurityOverview.docx` | pre-template ⚠ | none | 🟢 current |
| Metrics | `docs/RTM_Shell_Metrics_Overview.md`, `metrics-catalog*.json` | md/json | working | 🟢 current |
| Multi-session / operator guides | `docs/Multi-Session_Operator_Guide*` | pre-template ⚠ | none (6-version sprawl) | 🟢 current = RU_v5 (+EN) |

## Open hygiene actions (from the 2026-06-11 audit)

1. **Commit uncommitted approved work** (native CC): `docs/bi/`, `docs/methodology/`, `docs/assets/brand/`,
   this inventory + DOC-REGISTRY — currently untracked (`??`), so not version-controlled.
2. **Cleanup:** 8 zero-byte preview PNGs in `docs/bi/`; the `~$…DashboardUserGuide_v1.3` Word lock; add
   `docs/**/node_modules/` to `.gitignore` and remove the 2 node_modules dirs from the docs tree.
3. **Version sprawl:** keep only the current of each (TZ v1.6, Multi-Session RU_v5+EN, B-02 v1.3, one
   Backup/Restore); archive or delete the rest (operator call); track history in the in-doc revision table.
4. **Screenshots:** de-duplicate the `(1)/(2)/(3)` variants under `user-documentation/*/screenshots/`.

## Content gaps — priority (per DOC-REGISTRY)

1. **A-01 Installation & Deployment Guide** 🔴 — live on server 234; absorbs the barrier-#4 doc-debt.
2. **A-07 Multi-Tenant Management Guide** 🔴 — “create a new tenant/project”.
3. **B-01 Quick Start Guide** 🔴.
4. **A-06 Backup & Restore Runbook** 🟡 — promote the existing draft into the template.
5. A-03 Permission Groups, A-04 Security Config, A-05 SSO, A-09 Upgrade/Patch; B-03..B-06; C-01..C-05.

## Pending docs in flight

- BI Unified Reporting Guide v1.0 + Project Launch Runbook v1.0 — approved, awaiting their first push barrier to
  fill `Shipped-with`.
