# ADR-004: External widget data feed seam — per-tenant SignalR Connection URL

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner), Architecture team
**Tags:** integration, multi-tenancy

## Context

Widget rendering is out of scope for the RTM View Shell v1 ([WGT-04]). However the shell
*must* be designed so that a future widget library can connect to live CC-platform data
feeds without requiring changes to the shell's authentication or tenant isolation model.

The external data feed is a SignalR hub on the backend CC platform. Each tenant has a
distinct hub URL. The question is: how does the shell provide the widget library with the
correct, authenticated connection endpoint?

Constraints:
- Multi-tenant: each tenant points to a different backend SignalR URL.
- Security: the URL must not be exposed to non-authenticated users.
- Decoupled: the shell must not depend on the widget library at compile time.
- [ARCH-09]: SignalR group names within the shell are prefixed `"t:{tenantId}:{groupName}"`.

## Options considered

### Option A — Hard-code backend hub URL in `appsettings.json` per tenant
- **Pros:** Simple, no DB changes.
- **Cons:** URL changes require config redeployment; no multi-tenant support without
  per-tenant config files; not auditable.
- **Cost estimate:** Low initially, high maintenance.

### Option B — Store SignalR Connection URL per tenant in `tenant_settings`; expose via API (chosen)
- **Pros:** Superadmin can configure per-tenant URL in UI. Widget library calls
  `GET /api/v1/tenants/current/signalr-endpoint` (authenticated, returns URL + token hint).
  Auditable. Supports multiple tenants from a single deployment.
- **Cons:** One more column in `tenant_settings`; API endpoint needed.
- **Cost estimate:** 1 sprint day (endpoint stub in v1.3; widget library integration deferred).

### Option C — Publish hub URL via SSO claim or custom JWT claim
- **Pros:** Zero API call needed; widget library reads claim from JWT.
- **Cons:** URL in JWT is stale for the token's lifetime (15 min); cache invalidation
  on URL change is impossible without forced re-auth.
- **Cost estimate:** Low, but fragile.

## Decision

We chose **Option B**.

## Rationale

1. Per-tenant URL in `tenant_settings` is consistent with the existing per-tenant
   configuration pattern (SSO, email provider, password policy).
2. An API endpoint (`GET /v1/tenants/current/signalr-endpoint`) is clean, cacheable,
   and auditable. It also allows the shell to inject a short-lived connection token
   in future without JWT claim changes.
3. Option C's JWT-staleness problem is a known design anti-pattern; rejected.
4. Stub implementation (returns `null` URL with 200 OK) satisfies v1.3 without requiring
   a live backend.

## Requirement traceability

- Implements: [ARCH-09] (tenant-prefixed SignalR groups within shell)
- NEW-INT-01: External widget feed seam
- See also: ADR-008 (dual-write pattern for backend notification)

## Open questions

- OQ-1: Should the API endpoint also return a pre-negotiated access token for the
  backend hub? — Status: Open (deferred to widget-library sprint)
- OQ-2: Should URL be validated (format, reachability) on save? — Status: Open

## Consequences

**Positive**

- Widget library can be built independently; it only needs the API contract.
- URL is hot-configurable by Superadmin without redeployment.

**Negative / trade-offs**

- Widget library must make an authenticated API call before connecting to the feed hub.
- `tenant_settings` table grows by one column per integration seam added.

**Migration / rollout impact**

- `tenant_settings` migration adds `BackendSignalRUrl VARCHAR(1000) NULL`.
- API stub endpoint added in `CcDashboard.Api` v1.3.

## Notes

- Code: `src/CcDashboard.Api/Controllers/TenantController.cs` (stub).
- See widget architecture doc: `docs/architecture/widget-framework.md`.
