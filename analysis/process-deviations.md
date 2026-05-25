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

## Summary table

| ID | Severity | Sprint | Disposition | Backlog item |
|---|---|---|---|---|
| PD-001 | 🟡 Low | T1 Phase C | Accept; refine clause | — |
| PD-002 | 🟡 Low | T1 Phase C | Accept; backlog refactor | #13 (DatabaseInitializer → interface) |

## Pattern note

PD entries are not failures of the sprint — they are failures of the
contract between architect and executor. The fix for a PD is
usually a hand-off-prompt edit, not a code edit. Track and apply at
the start of every subsequent sprint.
