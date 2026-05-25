# ADR-001: Widget Catalogue scope — entity yes, admin CRUD screen no

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner), Architecture team
**Tags:** scope, ui, permissions

## Context

The RTM View Shell manages which widget types are available for placement on dashboards.
The initial requirement described a "Widget Catalogue" module covering:

1. A `WidgetCatalogItem` entity (category, name, description, icon, `IsActive` flag).
2. An administrative CRUD screen where Superadmin can manage catalogue items.
3. A browse/pick UI for Editors building dashboards.

The problem: building a full admin CRUD screen for widget types means defining update/delete
flows, activation controls, and their audit trail before widget *rendering* is even designed.
This creates spec scope that cannot be verified end-to-end in v1.

Relevant requirements:
- [WGT-01] `WidgetCatalogItem` is a cross-tenant entity (shared platform-wide).
- [WGT-02] Browse by category and name; accessible to Editor / Administrator / Superadmin.
- [WGT-03] Only Superadmin can add / edit / deactivate catalogue items.
- [WGT-04] Widget rendering is **out of scope**.

## Options considered

### Option A — Full admin CRUD screen (add / edit / deactivate) in v1
- **Pros:** Superadmin has full self-service catalogue management from day one.
- **Cons:** Requires designing item-edit modal, image/icon upload, deactivation logic, and
  cascading soft-delete of `DashboardWidget` references — all before rendering is proven.
- **Cost estimate:** +3 sprint days.

### Option B — Entity + seed data only; no admin CRUD screen in v1 (chosen)
- **Pros:** Catalogue is populated via seed migration; browse/pick UI is implemented;
  Superadmin manages items via DB or future admin screen.
  Reduces v1 scope by one unverifiable screen.
- **Cons:** Superadmin cannot manage catalogue without DB access in v1.
- **Cost estimate:** baseline.

### Option C — No catalogue entity; hard-code widget types in Blazor component
- **Pros:** Zero schema cost.
- **Cons:** Defeats the purpose of a data-driven catalogue; cannot be extended without code changes.
- **Cost estimate:** cheaper short-term, expensive long-term.

## Decision

We chose **Option B**.

## Rationale

1. Widget rendering is explicitly out of scope for v1 ([WGT-04]). An admin screen to manage
   types that cannot yet be rendered has no verifiable acceptance criteria.
2. Seed data covers the minimal browse/pick use-case for Editors. The entity is designed
   correctly for future admin CRUD.
3. Superadmin deactivation of `IsActive = false` hides items from non-Superadmin — this
   is enforced at the query level and does not require an admin screen to function.
4. Keeps v1 deliverable surface area small and test-verifiable (WidgetCatalogTests in T5).

## Requirement traceability

- Implements: [WGT-01], [WGT-02], [WGT-03], [WGT-04]
- Partially implements: [MAINT-04] (schema exists; admin UI deferred)

## Open questions

- OQ-1: Should `WidgetCatalogItem` carry a `SchemaVersion` field for future config
  migration? — Status: Open (deferred to widget-library sprint)

## Consequences

**Positive**

- v1 scope is bounded and testable.
- `WidgetCatalogItem` entity is correctly modelled for future admin CRUD with no schema change.

**Negative / trade-offs**

- Superadmin cannot add or deactivate catalogue items via UI in v1.
- Adding an item requires a new EF migration or direct DB insert by a developer.

**Migration / rollout impact**

- Seed migration populates at least one item per category (Queues, Agents, General metrics) on first run [DATA-07].

## Notes

- See also: ADR-004 (SignalR widget feed seam), ADR-008 (dual-write pattern).
- Code: `src/CcDashboard.Domain/Domain/WidgetCatalogItem.cs`,
  `src/CcDashboard.Web/Components/Widgets/WidgetCategoryBrowser.razor`.
