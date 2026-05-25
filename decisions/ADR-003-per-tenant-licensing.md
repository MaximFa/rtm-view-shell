# ADR-003: Per-tenant licensing model — Purchased licences + User connections

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner)
**Tags:** commercial, security, audit

## Context

The RTM View Shell is sold as a licensed product. Each tenant organisation purchases a
number of named-user licences (seats). The system must enforce that:

1. The number of *active* users in a tenant cannot exceed the purchased licence count.
2. Concurrent *connected* sessions (Blazor circuits + API tokens) are optionally bounded.
3. Superadmin can view and adjust licence counts per tenant.
4. Licence expiry results in graceful degradation (read-only or login denied) rather
   than abrupt service loss.

This decision was deferred from the original TZ v1.0 because the commercial model was
not finalised. At v1.3 the commercial model is defined: per-tenant seat count with
optional concurrent-connection cap.

## Options considered

### Option A — No licence enforcement in application; managed externally
- **Pros:** Zero implementation cost in v1.
- **Cons:** No safeguard against overage; no audit trail for licence events.
- **Cost estimate:** 0 now, high later (retrofitting enforcement).

### Option B — Soft licence ceiling: warn but allow overage
- **Pros:** Prevents accidental lock-out; easy to implement (counter + threshold check).
- **Cons:** Does not guarantee compliance; commercially weaker.
- **Cost estimate:** 1 sprint day.

### Option C — Hard licence ceiling: block user creation beyond seat count; log events (chosen)
- **Pros:** Guarantees compliance. Audit trail for licence events. Superadmin override possible.
  Seat count stored in `tenant_settings` or dedicated `tenant_licences` table.
- **Cons:** Requires careful UX — error message when admin tries to create user beyond limit.
- **Cost estimate:** 2 sprint days (deferred to v1.4 sprint).

## Decision

We chose **Option C**, deferred to a dedicated licensing sprint (v1.4).

In v1.3 the schema includes placeholder columns in `tenant_settings`
(`PurchasedSeats INTEGER DEFAULT 0`, `LicenceExpiresAt TIMESTAMPTZ NULL`) with enforcement
**not yet active** (`PurchasedSeats = 0` means unlimited).

## Rationale

1. Hard enforcement is commercially required — soft ceiling cannot be offered as a
   contractual guarantee.
2. The schema placeholder ensures no migration is needed when enforcement is activated.
3. Deferring implementation to v1.4 keeps v1.3 scope focused on security and widget framework.
4. `PurchasedSeats = 0` sentinel for unlimited is a well-understood convention and avoids
   nullable ambiguity.

## Requirement traceability

- NEW-LIC-01: Hard seat count enforcement (deferred to v1.4)
- NEW-LIC-02: Licence expiry grace period (deferred)
- Implements partially: `TenantSettings` schema (columns added in v1.3)

## Open questions

- OQ-1: Should concurrent connection cap be per-tenant or global? — Status: Open
- OQ-2: Grace period on licence expiry: 7 days or 30 days? — Status: Open
- OQ-3: Superadmin override for licence breach: audit-only or hard block? — Status: Open

## Consequences

**Positive**

- Schema is forward-compatible with licence enforcement.
- No breaking migration needed in v1.4.

**Negative / trade-offs**

- No enforcement in v1.3; commercial compliance relies on process until v1.4.

**Migration / rollout impact**

- `tenant_settings` migration adds `PurchasedSeats` and `LicenceExpiresAt` columns (v1.3 migration).

## Notes

- See also: [USR-01], [USR-05] for user creation rules already enforced.
