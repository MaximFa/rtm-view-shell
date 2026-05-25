# ADR-008: Dual-write pattern — DB + Backend API notification for categories 3 and 4; replaces NoOpConfigurationApiHook

**Status:** Accepted
**Date:** 2026-05-15
**Decider(s):** Max (Product Owner), Architecture team
**Tags:** integration, reliability

## Context

Some shell operations (creating/updating permission groups, user assignments, dashboard
metadata) must propagate to the CC backend platform so it can update its own runtime state
(e.g., refresh which agents are allowed to see which queues on a live dashboard).

The CC backend exposes a REST configuration API. The shell must call it after writing to
the DB. This is a dual-write scenario with two failure modes:

1. DB write succeeds, API call fails -> CC platform is stale.
2. API call succeeds, DB write then fails (transaction rollback) -> CC platform has ghost data.

The current implementation uses `NoOpConfigurationApiHook` — a stub that logs the event
but makes no actual HTTP call.

## Options considered

### Option A — Synchronous HTTP call inside the MediatR handler (same transaction)
- **Pros:** Simple; API result visible before returning to UI.
- **Cons:** DB transaction is held open during HTTP call. Network latency (50-500ms)
  degrades UI response time. API failure causes transaction rollback — even if DB write
  was valid ([REL-02] risk).
- **Cost estimate:** Low to implement, high operational risk.

### Option B — Outbox pattern: write notification intent to DB table; background service delivers (production target)
- **Pros:** DB write and notification are in the same transaction. Background service
  retries on API failure. No transaction held open during HTTP call.
- **Cons:** Notification is eventually consistent (seconds delay). Outbox table adds schema.
  Background service adds operational complexity.
- **Cost estimate:** +2 sprint days (deferred to v1.4).

### Option C — Fire-and-forget with retry: call API asynchronously after DB commit (v1.3 implementation)
- **Pros:** Simple to implement now (replace `NoOpConfigurationApiHook` with real HTTP client).
  DB transaction not blocked. Minimal schema change.
- **Cons:** If the process crashes between DB commit and API call, notification is lost.
  No guaranteed delivery. Acceptable risk for v1.3.
- **Cost estimate:** 1 sprint day.

## Decision

**v1.3:** Implement **Option C** (fire-and-forget with structured retry) to replace
`NoOpConfigurationApiHook`. The interface `IConfigurationApiHook` is retained.

**v1.4:** Migrate to **Option B** (outbox pattern) for production-grade guaranteed delivery.

## Rationale

1. The `IConfigurationApiHook` abstraction already exists; replacing the NoOp with a real
   HTTP client is a low-risk one-day change that eliminates the most egregious gap (no
   notification at all).
2. Fire-and-forget with retry (Polly) gives 3 attempts within the same async context;
   this satisfies the v1.3 reliability requirement without outbox complexity.
3. Outbox pattern in v1.4 replaces Option C cleanly via the same interface — zero changes
   to command code.
4. Failure mode analysis: DB commit + API failure -> CC platform is stale until next manual
   refresh or next change event. Acceptable for v1.3 where live deployments have admin
   oversight; not acceptable for production scale.

## Requirement traceability

- Implements: [REL-02] (all mutations in PostgreSQL transactions)
- NEW-INT-02: Backend API notification on permission change
- See also: ADR-004 (SignalR feed seam), ADR-007 (database boundary)

## Open questions

- OQ-1: What is the Backend API authentication scheme — service account JWT or mTLS?
  — Status: Open (pending backend API documentation)
- OQ-2: What events trigger dual-write notification?
  — Status: Resolved 2026-05-15. All writes to `permission_groups`, `pg_queues`,
  `pg_agent_supergroups`, `pg_business_units`, `dashboard_permissions`.
- OQ-3: Outbox table partition strategy (partition by month, or single table)?
  — Status: Open (deferred to v1.4 design)

## Consequences

**Positive**

- v1.3: CC platform receives live notifications; no more silent NoOp stub.
- Interface is stable; zero command-code changes when outbox replaces fire-and-forget.

**Negative / trade-offs**

- v1.3: Notification is not guaranteed; crash between DB commit and API call loses event.
- Fire-and-forget retries extend async context; unhandled exceptions must be caught and logged.

**Migration / rollout impact**

- v1.3: Replace `NoOpConfigurationApiHook` with `HttpConfigurationApiHook` (Polly retry).
  Register in DI: `services.AddScoped<IConfigurationApiHook, HttpConfigurationApiHook>()`.
- v1.4: Add `outbox_messages` table; background delivery service.

## Notes

- Code: `src/CcDashboard.Infrastructure/ApiHooks/HttpConfigurationApiHook.cs` (v1.3 stub path).
- NoOp registration: `src/CcDashboard.Web/Program.cs`.
- Polly: `dotnet add src/CcDashboard.Infrastructure package Microsoft.Extensions.Http.Polly`
