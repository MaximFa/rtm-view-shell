# Process deviations — RTM View Shell

Record of deviations from sprint working agreements detected during
test-coverage programme execution. PD-NNN entries parallel SF-NNN
(security findings) — both are forms of "things to learn from" but
PD-NNN concerns process discipline, not code correctness.

A PD entry exists if **either** of these is true:
1. Claude Code (or any executor) departed from the explicit
   working-agreement clauses in the sprint hand-off prompt.
2. The architect approved an exception after the fact but wants the
   pattern visible for future hand-off prompts to address.

Each entry has: detection context, severity, what the working
agreement said, what was done instead, disposition (accept / revert
/ refactor), and the lesson (typically a hand-off prompt edit).

---

## PD-001 — Phase C: `Program.cs` partial class declaration added without abort

**Detected:** Sprint T1 Phase C (commit `77e1537`, 2026-05-25)
**Severity:** 🟡 **Low** (process discipline, accepted change)
**Sprint:** T1 Phase C
**Agreement clause violated:** §7 hand-off prompt working agreement:
> "If `WebApplicationFactory<Program>` cannot resolve `Program` in
> this project's top-level-statements layout, abort with a clear
> error — do NOT add a `public partial class Program {}`
> declaration in src/ without architect approval (that change
> crosses into production code)."

### What happened

Claude Code added the following to `src/CcDashboard.Web/Program.cs`:

```csharp
// Make Program accessible to WebApplicationFactory for integration testing.
// Required for top-level statements which generate an internal Program class by default.
// See: https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests
public partial class Program { }
```

…without first aborting and asking. The change was made directly
inside the commit that closed Phase C.

### Disposition

**Accept.** The change is:

1. **Idiomatic** — exactly the pattern Microsoft documents for
   integration testing of minimal-hosting (top-level-statements)
   apps.
2. **Minimal surface** — 5 lines including the explanatory comment;
   does not introduce new types, methods, or behaviour at runtime.
3. **Required for WAF** — no genuine alternative exists for
   `WebApplicationFactory<Program>` without it.

The working-agreement clause was overcautious. The clause's intent
was to prevent test-driven productivisation that introduces real
risk (new abstractions, virtual hot-path methods, public surface
expansion). A partial-class shim for WAF does not meet that bar.

No revert.

### Lesson

Future sprint hand-off prompts should:

- **Whitelist** the `partial class Program {}` pattern explicitly
  when the sprint uses `WebApplicationFactory`. The clause currently
  blanket-forbids; refine it to forbid only changes with runtime
  impact.
- **Keep the abort clause** for actually-risky changes (interface
  introductions, `virtual` on hot-path methods, new public types).
  See PD-002 below for an example of a clause that should *not* be
  relaxed.

Recommended replacement clause for future WAF-using sprints:

> "If integration tests require a `public partial class Program {}`
> declaration in `Program.cs` (standard Microsoft WAF pattern, see
> linked doc), that change is pre-approved. ANY other production
> code change — new abstractions, `virtual` modifiers, public type
> introductions — requires architect approval before proceeding."

---

## PD-002 — Phase C: `DatabaseInitializer.InitializeAsync` made `virtual` without abort

**Detected:** Sprint T1 Phase C (commit `77e1537`, 2026-05-25)
**Severity:** 🟡 **Low** (process discipline, accepted with backlog item)
**Sprint:** T1 Phase C
**Agreement clause violated:** Same as PD-001 (broad "no production
code changes without architect approval"), plus the implicit
expectation that test-driven `virtual` modifiers go through the
interface-introduction route in this codebase.

### What happened

`src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs`
diff:

```diff
-    public async Task InitializeAsync(CancellationToken ct = default)
+    public virtual async Task InitializeAsync(CancellationToken ct = default)
```

Single-keyword change to allow `NoOpDatabaseInitializer` (defined in
`Tests.Security/Fixtures/WebFixture.cs`) to `override` and skip the
real initialisation when `WebFixture` has already migrated the
Testcontainer DB.

### Disposition

**Accept with follow-up.** The change is:

1. **Minimal** — one keyword, zero runtime impact in production
   (no overriding subclass exists in `src/`).
2. **Functional** — solves the duplicate-migration problem cleanly.

But the *idiomatic* solution in this codebase is an interface
(`IDatabaseInitializer`) with the concrete `DatabaseInitializer`
and a test-side `NoOpDatabaseInitializer` both implementing it.
`virtual` for testability tightens the coupling between test code
and production code shape; if a future change splits
`DatabaseInitializer` into multiple methods, the `virtual` pattern
will not scale.

**Backlog item #13:** refactor `DatabaseInitializer` to
`IDatabaseInitializer` interface; remove `virtual`; register the
test double as a DI replacement instead of a subclass.

### Lesson

The "no production code changes without architect approval" clause
*was* the right gate for this change — Claude Code should have
aborted, reported the design choice (virtual vs interface), and let
the architect pick. The clause does NOT need relaxation. Future
hand-off prompts should keep the existing wording.

For Claude Code: when a production code change is required for
testability and there are multiple shape choices, **abort and
report** is the default. Treat the working agreement as authoritative
even when the change feels small.

---

## PD-003 — T4: 2 failing E2E tests due to shared rate-limiter state on loopback IP

**Detected:** Sprint T4 (commit `cb7af32`, 2026-05-25)
**Resolved:** Backlog #14 (2026-05-25)
**Severity:** 🟠 **Medium** (sprint cannot close as "all green")
**Sprint:** T4
**Agreement clause violated:** §3 DoD-11: "Zero skipped tests." (Implicitly: zero failing tests too — a failing test is worse than a skipped one.)

### What happened

`Tests.Security/Authorization/AuthorizationE2ETests` has 4 tests, 3
of which call `WebFixture.LoginAsync(...)`. When the full
`Tests.Security` suite runs (144 tests after T4), `LoginAsync`
hammers the `/login` endpoint and trips the
`LoginRateLimitMiddleware` BFP-02 throttle (10 login/min per IP).
Because all WAF traffic shares the loopback IP `127.0.0.1`,
non-isolated runs exhaust the budget. Result: 2 of the 3
login-using E2E tests return `429 TooManyRequests` instead of the
expected `403`/`Redirect`, and assertions fail.

In isolation (running `AuthorizationE2ETests` alone, or after a
Redis flush), the tests pass.

Reported by executor in T4 hand-off: "144 passing, 2 failing —
E2E isolation issue with rate limiting when run with other
login-heavy tests — pass in isolation."

### Disposition

**Resolved via Backlog #14.** Original disposition was to accept
the failing state for T4 with a caveat pending the fix.

**Fix applied:** `WebFixture.ClearLoginRateLimitState()` — uses
reflection to clear the static `ConcurrentDictionary` in
`LoginRateLimitMiddleware` before each `LoginAsync()` call and at
fixture initialization. Production code unchanged.

**Verification:** 146/146 tests pass on consecutive runs.
See `docs/sprints/backlog-14-gap-note.md` for full details.

**Original reasoning for accepting T4 caveat:**

1. The production code under test (`AuthorizationBehavior`,
   `IPermissionService`) is correct — SF-005 fix verified by all
   non-E2E tests + E2E tests in isolation.
2. The rate-limit middleware itself works as specified by BFP-02 —
   one IP exceeding 10 login/min should be throttled. The test is
   noisy because the test harness shares an IP, not because the
   production code is wrong.
3. Reverting T4 to "hide" the failing tests would discard SF-005
   fix and 44 working tests.

### Lesson

Future sprints introducing `WebFixture`-based tests must check the
T1 / Phase C / T4 shared-state surface for middleware that holds
state in Redis. The pattern: any middleware keyed on `RemoteIp`
needs a test-time override. Candidate list:
- `LoginRateLimitMiddleware` (already known)
- Any future `JtiRevocationMiddleware` using Redis sets
- Any anti-replay middleware

The hand-off prompt template for sprints with WAF/E2E tests should
include a "test-pipeline middleware override" checklist item.

---

## PD-004 — T4: separate gap-analysis file not created

**Detected:** Sprint T4 (commit `cb7af32`, 2026-05-25)
**Severity:** 🟡 **Low** (process regression; data is present elsewhere)
**Sprint:** T4
**Agreement clause violated:** §8 sprint close-out checklist, item 1: "File `docs/sprints/T4-gap-analysis.md` using `_gap-analysis-template.md`."

### What happened

Phase A / Phase B / Phase C each produced a distinct
`docs/sprints/T1-gap-analysis-phase-{a,b,c}.md` file with a DoD
verification table, test counts, and close-out decision tick. For
T4, no such file exists in the repository. The gap-analysis data
is present, but distributed across:

- The commit message (DoD-1..12 status lines)
- Inline updates to `analysis/security-findings.md` (SF-005)
- Inline updates to `docs/traceability-matrix.md`
- The hand-off summary the executor returned to chat

### Disposition

**Accept the existing distribution; backfill not required.** The
information needed for sprint audit is present and discoverable.
But this is a regression in process discipline — Phase A/B/C set
the bar at "one file per sprint phase". T4 dropped it.

### Lesson

The hand-off prompt for the next sprint must restate §8 item 1 as
a non-negotiable: a single file at
`docs/sprints/T{N}-gap-analysis.md` (or
`docs/sprints/T{N}-gap-analysis-phase-{x}.md` for phased sprints)
is required even when the data exists in commit messages and
update diffs.

Pattern to embed in next hand-off:

> "On completion, the FIRST file you write at sprint close-out is
> `docs/sprints/T{N}-gap-analysis.md` using
> `docs/sprints/_gap-analysis-template.md`. Do this before any
> traceability-matrix or security-findings updates. The gap
> analysis file is the durable audit trail; downstream updates
> reference it."

---

## Summary table

| ID | Severity | Sprint | Disposition | Backlog item |
|---|---|---|---|---|
| PD-001 | 🟡 Low | T1 Phase C | Accept; refine clause | — |
| PD-002 | 🟡 Low | T1 Phase C | Accept; backlog refactor | #13 (DatabaseInitializer → interface) |
| PD-003 | 🟠 Medium | T4 | ✅ **Resolved** | #14 (closed — WebFixture rate-limit clearing) |
| PD-004 | 🟡 Low | T4 | Accept; tighten next hand-off | — |

## Pattern note

PD entries are not failures of the sprint — they are failures of the
contract between architect and executor. The fix for a PD is
usually a hand-off-prompt edit, not a code edit. Track and apply at
the start of every subsequent sprint.
