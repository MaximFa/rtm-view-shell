# ADR-005: Per-tenant theme palette — background/font colours + font-size presets

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner)
**Tags:** ui, theming, i18n

## Context

Customers (tenants) want to brand their RTM dashboards with corporate colours. The minimum
viable theming requirement is:

- Background colour (hex) and font colour (hex) configurable per tenant.
- Three font-size presets: Compact / Normal / Comfortable.
- Applied globally across all Blazor pages for that tenant's session.
- RTL-compatible (no hard-coded directional CSS).

The shell uses Bootstrap 5 with custom CSS variables (`--bs-*` overrides).

## Options considered

### Option A — Static theme file per tenant in `wwwroot/themes/{slug}.css`
- **Pros:** Zero runtime DB cost; pure CSS.
- **Cons:** Requires redeployment to change theme; not Superadmin-configurable.
- **Cost estimate:** Low per change, high operationally.

### Option B — Theme values in `tenant_settings`; injected as CSS variables via Blazor component (chosen)
- **Pros:** Superadmin changes theme in UI; applied on next page load.
  Implemented as `<style>:root { --tenant-bg: #hex; --tenant-fg: #hex; }</style>`
  injected in `App.razor`.
- **Cons:** One HTTP round-trip (DB read) per session start to fetch theme.
  Values cached in Redis (`"{tenantId}:theme"`).
- **Cost estimate:** 1 sprint day.

### Option C — Full CSS-in-DB: store arbitrary CSS per tenant
- **Pros:** Maximum flexibility.
- **Cons:** XSS vector if CSS is not sanitised; operational complexity; testing burden.
- **Cost estimate:** +2 days; security review required.

## Decision

We chose **Option B**.

## Rationale

1. CSS variable injection is safe (no arbitrary CSS; only two validated hex values and
   an enum preset) and does not create an XSS vector.
2. Redis caching ensures no DB overhead on every Blazor circuit reconnect.
3. Three font-size presets (Compact / Normal / Comfortable) translate to a CSS class on
   `<body>` — simple, testable, localisation-neutral.
4. Option C rejected: arbitrary CSS injection is a security anti-pattern per [CODE-02].

## Requirement traceability

- NEW-THEME-01: Per-tenant colour palette
- NEW-THEME-02: Font-size presets
- Implements: [I18N-02] (RTL via CSS logical properties; theme values do not override direction)
- Implements: [ARCH-08] (Redis key `"{tenantId}:theme"`)

## Open questions

- OQ-1: Should dark-mode be a separate tenant setting or a user preference? — Status: Open
- OQ-2: What is the validation rule for hex colours (3-digit shorthand allowed)? — Status: Open

## Consequences

**Positive**

- Tenants can self-brand via Superadmin UI; no redeployment needed.
- Theme values are cached; negligible runtime overhead.

**Negative / trade-offs**

- Theme is global (all users in a tenant see the same theme). User-level override not supported in v1.
- Poorly-chosen colours (e.g., white-on-white) are a UX risk; no contrast validation in v1.

**Migration / rollout impact**

- `tenant_settings` migration adds `ThemeBgColour VARCHAR(7) NULL`, `ThemeFgColour VARCHAR(7) NULL`,
  `ThemeFontSize VARCHAR(20) DEFAULT 'Normal'`.
- Redis TTL for theme cache: 1 hour.

## Notes

- Code: `src/CcDashboard.Web/Components/Layout/ThemeInjector.razor`.
- CSS preset classes: `.theme-compact`, `.theme-normal`, `.theme-comfortable` in `app.css`.
