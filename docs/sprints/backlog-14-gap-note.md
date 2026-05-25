# Backlog #14 — WebFixture Rate-Limit Isolation Fix

**Date:** 2026-05-25
**Resolves:** PD-003 (2 failing E2E tests due to shared rate-limiter state)

---

## Problem

After T4, 2 of 146 `Tests.Security` tests failed when the full suite ran together:
- `AuthorizationE2ETests.Editor_AccessAdminUsersPage_IsDenied`
- `AuthorizationE2ETests.Viewer_AccessAdminUsersPage_IsDenied`

**Root cause:** `LoginRateLimitMiddleware` uses a static `ConcurrentDictionary<string, RateLimitEntry>`
to track login attempts per IP. The BFP-02 limit is 10 logins per minute per IP. Because all
`WebApplicationFactory` tests share loopback IP (`127.0.0.1` / `::1`), cumulative logins across
the test suite exhaust the budget. Tests that run after ~10 logins receive `429 TooManyRequests`
instead of the expected responses.

**Production code correctness:** The middleware itself is correct — it correctly rate-limits per
IP as specified by BFP-02. The issue was purely test infrastructure isolation.

---

## Solution Approach

**Approach chosen:** Reflection-based clearing of the static dictionary in `WebFixture`.

**Why this approach:**
- User pre-approved only test-side changes (`WebFixture.cs` modification, test-only stub classes)
- Production code (`LoginRateLimitMiddleware.cs`, `Program.cs`) remains byte-identical
- No new options classes or feature flags needed in production
- Minimal invasiveness — one static method added to test fixture

**Alternative approaches considered but rejected:**
- **Add `LoginRateLimitOptions.Enabled`:** Would require production code change (not pre-approved)
- **Remove middleware in `ConfigureWebHost`:** Difficult because middleware is registered via
  `UseMiddleware<T>()` in the app pipeline, not in DI services
- **Replace backing service:** Middleware uses static dictionary, not an injected service

---

## Implementation

Added to `tests/CcDashboard.Tests.Security/Fixtures/WebFixture.cs`:

```csharp
/// <summary>
/// Clears the static rate-limit state in LoginRateLimitMiddleware [Backlog #14].
/// </summary>
public static void ClearLoginRateLimitState()
{
    var middlewareType = typeof(LoginRateLimitMiddleware);
    var entriesField = middlewareType.GetField("_entries", BindingFlags.NonPublic | BindingFlags.Static);
    if (entriesField?.GetValue(null) is System.Collections.IDictionary dict)
    {
        dict.Clear();
    }
}
```

Called in two places:
1. `InitializeAsync()` — clears state when fixture initializes (collection-level isolation)
2. `LoginAsync()` (both overloads) — clears state before each login (test-level isolation)

---

## Verification

| Run | Total | Passed | Failed | Notes |
|-----|-------|--------|--------|-------|
| Before fix (T4) | 146 | 144 | 2 | E2E tests fail with 429 |
| After fix (run 1) | 146 | 146 | 0 | All pass |
| After fix (run 2) | 146 | 146 | 0 | Confirms no state leakage |

---

## Files Changed

- `tests/CcDashboard.Tests.Security/Fixtures/WebFixture.cs` — added `ClearLoginRateLimitState()` method
  and calls in `InitializeAsync()` and both `LoginAsync()` overloads
- `analysis/process-deviations.md` — PD-003 marked as resolved
- `docs/traceability-matrix.md` — coverage summary updated (146 passing, 0 failing)
- `PROJECT_STATUS.md` — backlog #14 marked closed

---

## Production Code Verification

`src/CcDashboard.Web/Program.cs` is byte-identical to commit `cb7af32` (T4 close):
```
git diff cb7af32 HEAD -- src/CcDashboard.Web/Program.cs
(no output = no changes)
```
