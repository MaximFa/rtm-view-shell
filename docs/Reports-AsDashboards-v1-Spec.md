# Reports-as-Dashboards — v1 Specification (Ф0)

> **Status:** DRAFT for operator review → §4 + security (PG/BU scope) + dba (schema) review → phased build.
> **Owner:** coordinator (spec) · shell/ux-ui (UI, bulk) · backend/bi (scope resolver, queries, export, distribution) · dba (schema, membership views) · security (PG/BU enforcement, SMTP creds) · test (functional gate) · techwriter (doc).
> **Branch:** v3 (continue; v3→v2-backend trunk merge stays backlogged). **Free/MIT components only.**
> **Supersedes:** the v3 standalone `/reports` 4-tab page (migrated, §9).

---

## 1. Concept

Historical Reports become a **dashboard-style, widget-based experience**:
- A **reports list** page (View / Edit / Settings per row, category, PG-scoped).
- **View** opens a report screen read-only with a date selector on top.
- **Edit** opens a dashboard-style editor: report-widgets in a palette, placed/resized on a canvas, each configured (columns, thresholds, fonts, Business Unit by PG) like dashboard widgets.
- A **single date filter** on the screen applies to **all report-widgets**.
- Dark / Light mode.
- Per report: **export to Excel / PDF** and **scheduled email distribution** (stub until SMTP configured).

What we today call "a report" (Queue Interval, Queue Wait Time, Agent Monthly, Agent Shift Detail, distribution charts) becomes a **report-widget** placeable on a report screen.

---

## 2. Architecture decisions (ratified)

| # | Decision | Rationale |
|---|---|---|
| F1 | **Separate entity** for report screens/widgets (NOT a `Kind` discriminator on `dashboards`) | Isolation: report-only / realtime-only specs can diverge; no regression risk to live dashboards (`ScreenEditorPage` untouched); simpler QA per side. |
| F2 | **Per-type report-widget components** (table / chart / distribution) | Different structure, config, and params per type; not forced into one generic shell. |
| F3 | **Migrate** the current `/reports` 4-tab page into the new model | One coherent model; the data layer (queries/repo/scope) is reused as-is; presentation moves. Phased; seed default report-screens. |
| F4 | **Branch v3** | Builds on the report data layer already on v3; merge to trunk later (backlog). |

### Design discipline — reconciling "separate entity" with the "UX в ноль" mandate
The reports UX/UI MUST be **identical** to the existing dashboard look & behaviour. With a separate entity this is achieved by a **shared visual/component layer**, NOT by duplicating-with-divergence:
- Factor the common UI building blocks — **canvas, widget palette, widget config modal, list-card, date-bar, theming/tokens, drag-resize JS** — into reusable components/CSS consumed by BOTH the dashboard editor and the report editor.
- Where extraction is too invasive in v1, the report editor uses the **same design-system primitives** (tokens.css, the same markup/classes) so it is pixel-identical.
- **Separate** = entity / data / routes / queries. **Shared** = look, components, tokens, interactions. QA verifies visual parity against the live dashboard editor.

---

## 3. Domain model (net-new + reused)

### Net-new entities (separate from `dashboards`)
- **`report_screens`** — mirror of the dashboard screen: `Id, TenantId, Name, Description, CategoryId?, Status (Draft|Published), IsPublic, IsDarkMode, LayoutJson, CreatedBy/At, UpdatedBy/At, IsDeleted/DeletedAt/By, RowVersion (xmin)`.
- **`report_widgets`** — `Id, ReportScreenId, TenantId, ReportWidgetType (enum: QueueInterval | QueueWaitTime | AgentMonthly | AgentShiftDetail | Distribution | …), PositionJson, ConfigJson, IsDeleted`.
- **`report_permissions`** — `(PermissionGroupId, ReportScreenId, TenantId, AccessLevel bitmask View=1/Edit=2/Delete=4/Full=7)` — same shape/semantics as `dashboard_permissions`.
- **`report_categories`** — mirror of `DashboardCategory` (or reuse a shared `category` table with a `scope` column — dba decides).
- **`report_schedules`** — `Id, ReportScreenId, TenantId, Cadence (cron-ish), Recipients (jsonb), Format (xlsx|pdf|both), DateWindow (rolling-N | prev-month | fixed), IsActive, LastRunAt, NextRunAt, CreatedBy`.

### Reused as-is (no change)
- **Data layer:** `hist_queue_intervals`, `hist_agent_intervals`, the 4 MediatR queries (`GetQueueIntervalReportQuery` etc.), `HistoricalReportRepository`, `ReportScopeResolver` — REUSED. Report-widgets call the same queries.
- **`TenantSettings.EmailProviderConfig`** (encrypted, Data Protection) — reused for SMTP.
- **`IEmailSender`** abstraction (2FA-07) — reused for distribution.
- **NGC membership tables** (§4).

### Migrations
- New tables above (EF migration, App context, branch v3). All multi-tenant: `TenantId` + GQF; `report_screens` combined GQF `TenantId && !IsDeleted` (like dashboards).
- Seed: report widget "catalog" (the report-widget types) + optional 4 default report-screens replicating the current `/reports` tabs (F3 migration).

---

## 4. BU-scope resolution (canonical membership model)

A report-widget scoped to a Business Unit resolves the BU to concrete data filters. Two axes:

### 4.1 Queue-scoped widgets (queue/workgroup reports)
A BU has ≥1 queue. Resolve BU → its queues via `NGC_BusinessUnitQueueClassification` (ClassificationId='ALL', §36) → SQL filter:
```
... AND "Workgroup" IN (Queue1, Queue2, …)
```
Flat IN-set.

### 4.2 Agent-scoped widgets (agent reports)
BU → N Supergroups (`NGC_BusinessUnitSupergroup`); each SG → N AgentGroups (`NGC_SupergroupAgentgroup`); agent↔AG via `NGC_UserAgentgroup`.

- **Detail (agent-list) reports:** **UNION** — ALL agents of ALL SGs/AGs in the BU.
- **Cumulative (aggregate) reports:** included-agent set =
  ```
  ∪_{SG ∈ BU} ( ∩_{AG ∈ SG} members(AG) )
  ```
  Per SG an agent qualifies only if a member of **every** AG in that SG (intersection); then union across SGs.

### 4.3 Why the intersection — two client conventions (BOTH supported by ONE formula)
The AND-within-SG models how a client maps agent membership to workgroup eligibility:
- **Conv-1:** to take Workgroup "US-Support", agent ∈ AgentGroup "US-Support" — SG has **one** AG.
- **Conv-2:** to take Workgroup "US-Support", agent ∈ AgentGroup "US" **AND** "Support" — SG has **multiple** AGs; eligibility = intersection.

The single formula `∪_SG(∩_AG)` covers both natively: Conv-1 = ∩ of one AG; Conv-2 = ∩ of all. **The convention is DATA** (cardinality of `NGC_SupergroupAgentgroup` per SG), **not a code branch / per-tenant flag**.

### 4.4 Resolver implication
`ReportScopeResolver` (or a new `BuMembershipResolver`) computes the structured set at resolve-time → a **flat agent/workgroup set** → the repo keeps `… IN (set)`. The report-widget passes `{BU, report-type (detail|cumulative)}`; the resolver returns the right set. **PG-scope is intersected on top** (BU-set ∩ PG-allowed) — SF-BI-001 enforcement preserved.

---

## 5. UX (design "в ноль")

- **Reports list** (`/reports`): table/cards — Name, Category, Access (PG), Status, Updated, Actions (View/Edit/Settings). Search + category filter + PG filter + "New report". Mirrors `ScreenListPage`.
- **View** (`/reports/{id}`): top bar with shared **date range** (From→To) + Apply, Export (Excel/PDF), Schedule; read-only report-widget grid. Date applies to all widgets.
- **Edit** (`/reports/{id}/edit`): report-widget palette + canvas (drag/resize) + per-widget config modal — tabs **General / Columns / Thresholds / Appearance (table+header fonts, light+dark colors) / Business Unit (PG-scoped)** (+ chart-specific tabs for chart/distribution widgets). Save.
- **Dark / Light:** reuse `tokens.css` (both modes) + per-screen `IsDarkMode` toggle.
- All components visually identical to the dashboard equivalents (shared layer, §2).

---

## 6. Export (Excel + PDF)

- Per-report export of the current screen data (all report-widgets, current date window, PG/BU-scoped). Also per-widget export (optional v1).
- **Server-side, FREE/MIT libs only** — Ф0 decision: xlsx → **ClosedXML** (MIT); pdf → **QuestPDF** (MIT community) or equivalent. NO PolyForm/commercial-restricted libs (EPPlus v5+ is not free for commercial — excluded).
- Honors the date filter + `ReportScopeResolver` (PG/BU). Precedent: AUD-08 CSV export.

---

## 7. Distribution + SMTP

- **Distribution:** per-report schedule (`report_schedules`) — cadence + recipients + format (xlsx/pdf) + date window (rolling/fixed). A background job (`IHostedService`) renders + emails via `IEmailSender`.
- **STUB until SMTP configured:** schedules persist; the job is wired but **queues/no-ops** with a clear log + UI banner ("SMTP not configured — Tenant Settings → Email"). No real send until SMTP set.
- **SMTP config in the Tenant Admin menu** (Tenant Settings → Email/SMTP tab): host, port, encryption (STARTTLS/SSL/None), username, password, From address/name, "Send test" (stub). Stored in `TenantSettings.EmailProviderConfig`, **encrypted (Data Protection)**. Security reviews creds handling.

---

## 8. Permissions / categories / theming

- **PG:** `report_permissions` (View/Edit/Delete bitmask per PG) — same model as dashboards. List filtered by PG; Edit/View/Settings gated by AccessLevel. `[Authorize]` + Application-layer check (CODE-03).
- **BU scope:** §4, PG-intersected (SF-BI-001).
- **Categories:** assignable per report (`report_categories`), shown/filtered on the list.
- **Dark/Light:** §5.

---

## 9. Migration of current /reports

Phased, no disruption during build:
1. Build the new model alongside (new routes under a flag or staged).
2. Reuse the existing queries/repo/scope unchanged.
3. When ready: repoint `/reports` from the 4-tab page to the new reports-list; **seed 4 default report-screens** replicating the current reports so no value is lost.
4. Retire the standalone `Components/Reports/*.razor` tab pages (keep the Application/Infrastructure data layer).

---

## 10. Phases · owners · gates

| Phase | Work | Owner |
|---|---|---|
| Ф1 | Entities + migration (`report_screens/_widgets/_permissions/_categories/_schedules`) + report-widget type seed | backend + dba |
| Ф2 | `BuMembershipResolver` (queues IN; detail-union; cumulative ∪_SG(∩_AG)); PG-intersect; report-type aware | backend/bi (security review) |
| Ф3 | Shared UI layer extraction (canvas/palette/config-modal/list/date-bar/tokens) | shell |
| Ф4 | Report-widget components per type (table types + chart/distribution) + config modal | shell |
| Ф5 | Reports list + View (shared date filter cascade) + Edit | shell |
| Ф6 | Export (xlsx/pdf, free libs) | backend + shell |
| Ф7 | Distribution job (stub) + `report_schedules` + Tenant Settings SMTP UI | backend + shell + dba |
| Ф8 | Migrate current /reports + seed defaults; retire tabs | shell + bi |
| Gates | per-change QA + standing pre-push regression (incl. **live-dashboard regression** even though entity is separate, to catch shared-layer extraction breakage); security (PG/BU + SMTP creds); techwriter doc | test / security / techwriter |

---

## 11. Open / pending decisions
- Export lib final pick (ClosedXML confirmed-free; PDF lib QuestPDF vs alternative — confirm MIT/free at build).
- `report_categories` shared-with-dashboards vs separate (dba).
- Per-widget export in v1 or screen-only (defer per-widget to v1.1 if scope-heavy).
- Shared-layer extraction depth in v1 (full extraction vs design-primitive mirroring) — shell proposes at Ф3.

*v1 spec — 2026-06-24 — coordinator-0623. Ratified forks F1-F4. Free/MIT only. Branch v3.*
