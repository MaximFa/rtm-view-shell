# ADR-002: Navigation menu redesign — new groups + new menu keys + tenant-settings folding

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner)
**Tags:** ui, permissions

## Context

The original TZ described a flat navigation sidebar with items keyed by `MenuKey` strings.
During wireframe review (Screen 02, Screen 03) it became clear the sidebar needed grouping,
and that the "Tenant Settings" item should be accessible to Administrators (not Superadmin only).

Additionally, the original `menu_permissions` table had no concept of groups — each `MenuKey`
was independent, leading to permission configurations that were hard to reason about.

The sidebar must support:
- Section labels (Content / Administration / Platform) with no independent permission.
- Seven `MenuKey` values (see §6.2 of TZ).
- Role-based visibility constraints enforced at both UI and Application layer ([PG-04]).
- RTL layout without code changes ([I18N-02]).

## Options considered

### Option A — Keep flat list, add CSS groups only (UI cosmetic)
- **Pros:** No schema change; `menu_permissions` table unchanged.
- **Cons:** Grouping is cosmetic only; permission configuration remains confusing.
- **Cost estimate:** 0 (cosmetic).

### Option B — Add section-label concept at UI level; keep same MenuKeys (chosen)
- **Pros:** Section labels rendered as non-interactive dividers in NavMenu.razor.
  `MenuKey` set remains authoritative. Role constraints remain in code, not DB.
  Compatible with existing `menu_permissions` schema.
- **Cons:** Section labels are not permissioned — any authenticated user sees the label
  even if they have no permissions for items under it (acceptable UX; label disappears
  if all child items are hidden).
- **Cost estimate:** Minor Blazor component change.

### Option C — Model sections as permission groups with parent/child keys
- **Pros:** Full hierarchical permission model.
- **Cons:** Over-engineered for the seven menu items in v1. Schema complexity high.
- **Cost estimate:** +2 sprint days.

## Decision

We chose **Option B**.

## Rationale

1. Seven menu keys fit a flat enumeration with cosmetic grouping — hierarchical modelling
   adds schema complexity with no corresponding permission-expressiveness gain.
2. Section labels that hide when all children are hidden are standard UX; no additional
   permission logic needed.
3. Folding "Tenant Settings" under Administration (accessible to Administrator + Superadmin)
   is a content decision, not a schema change — the `menu.tenantSettings` key already
   carries the correct role constraint.
4. All permission checks are enforced at Application layer regardless of UI visibility.

## Requirement traceability

- Implements: §6.2 menu_permissions table, [PG-04]
- Implements: [I18N-02] (CSS logical properties for RTL)
- Satisfies: wireframe Screen 02 and Screen 03 sidebar spec

## Open questions

- OQ-1: Should section labels (Content / Administration / Platform) be translated via
  `.resx`? — Status: Resolved 2026-05-15. Yes; all UI strings in `.resx` per [I18N-03].

## Consequences

**Positive**

- NavMenu is clean and matches wireframes without schema changes.
- Role-constraint table (§6.2) is enforced in code and is easy to audit.

**Negative / trade-offs**

- Section label visibility is not permission-driven; minor UX inconsistency if a user has
  permissions for no items in a section but still sees the label.

**Migration / rollout impact**

- No migration required. NavMenu.razor updated with section dividers.

## Notes

- Code: `src/CcDashboard.Web/Components/Layout/NavMenu.razor`.
- Menu key enumeration: `src/CcDashboard.Domain/Enums/MenuKey.cs`.
