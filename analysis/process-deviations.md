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

## PD-005 — Cowork session interruption left 8 working-tree files truncated mid-write

**Detected:** 2026-05-25, during T2 startup verification (incident #1); same session post-commit (incident #2); same session mid-PD-update (incident #3)
**Severity:** 🔴 **High (recurring — 3 incidents in one session 2026-05-25)** (broke build state; required manual recovery each time; in incident #3 the Edit-tool success return decoupled from filesystem reality)
**Sprint:** T2 (pre-execution interrupted, post-commit close-out, mid-PD-update — all same day 2026-05-25)
**Agreement clause violated:** None directly — this is an environment failure mode, not a contract breach. Logged here because the recovery procedure and detection pattern are reusable.

### What happened

A prior Cowork session began Sprint T2 execution (LICENSE-USER tests
+ SF-006 audit emission in `UserManagementService`) and was
interrupted before completion. On resumption, `git status` showed 13
dirty files. Eight of them were **truncated** (file content ended
mid-statement, unclosed braces, partial comments):

- 5 production / test infra files: `AuthorizationBehavior.cs`,
  `InfrastructureServiceExtensions.cs`, `UserManagementService.cs`,
  `Fixtures/PostgresFixture.cs`, `Fixtures/WebFixture.cs`
- 3 documentation files: `CLAUDE.md`, `analysis/security-findings.md`,
  `docs/traceability-matrix.md`

Failure signature: every truncated file ended with an unclosed
statement (e.g., `"// API hook (no-op until CC-platform API is available"`
with no closing paren / next line), and `wc -c` showed file sizes
suspiciously close to round-number boundaries (~3-5 KB shorter than
HEAD). The .NET project would not compile in this state.

Five files survived intact — all were either single-write outputs
(four untracked files: T2 brief + three new test files) or had been
saved before the interruption (`PROJECT_STATUS.md`).

### Disposition

**Recovered.** Procedure:

1. `git status` to enumerate dirty files.
2. For each modified file, `tail -3 <file>` to check for truncation
   signature (unclosed statements, mid-comment endings).
3. For each truncated file, restored from HEAD via shell redirect:
   ```bash
   git show HEAD:<path> > <path>
   ```
   (Note: `git checkout HEAD -- <path>` failed with `unable to
   unlink: Operation not permitted` — the Cowork mount blocks
   unlink/rename. Shell redirect truncates in-place without unlink
   and works.)
4. After restore, verified each file ends with proper closing
   brace / paragraph.
5. Intact files (PROJECT_STATUS sanity-check edits, T2 brief, three
   LicenseUser test files) preserved as-is.

No data loss: all important close-out updates from T1 + T4 + #14
were already in commits `ca0ccd9` / `b846f1b` / `77e1537` /
`cb7af32` / `b66184b`. The truncated working-tree changes were
either (a) post-commit doc tweaks that HEAD already captured, or
(b) the in-progress T2 work that needs to re-run anyway.

### Lesson

**After any Cowork session recovery, before doing any new work:**

1. `git status` first.
2. For every `M` file: `tail -3 <path>` and look for the truncation
   signature (unclosed statement, mid-comment ending, dangling
   bracket). Production files are the highest priority.
3. For every `??` file: same check via `tail`.
4. If any file is truncated, **restore via** `git show HEAD:<file> > <file>`,
   **not** via `git checkout` (mount-permission limitation).
5. Only after the working tree is verified buildable should new
   work begin.

This is **independent** of (and complementary to) the PROJECT_STATUS
sanity-check lesson (filesystem-vs-claimed-tracks). PD-005 is about
working-tree corruption from session interruption; the sanity-check
is about long-term documentation drift. Both belong in every
session-resume checklist.

## PD-005 incident #2 (same day, 2026-05-25)

After Sprint T2 was successfully committed (`d562845`), the working tree
was checked again per PD-005 procedure — **7 of the same family of files
were truncated again**, including `UserManagementService.cs` in the
critical position (`if (user` — unclosed statement in production code).
The commit itself was valid (HEAD contains full correct files); the
corruption was post-commit, while the session was performing close-out
doc updates (PROJECT_STATUS, traceability matrix, security-findings).

**Truncated files (working tree size → HEAD size):**
- `PROJECT_STATUS.md` (10931 → 12336)
- `analysis/process-deviations.md` (11067 → 14741)
- `analysis/security-findings.md` (13658 → 18703)
- `docs/traceability-matrix.md` (8159 → 9496)
- `src/CcDashboard.Infrastructure/Identity/UserManagementService.cs` (11314 → 12635) — **production code, mid-statement**
- `tests/CcDashboard.Tests.Security/Fixtures/WebFixture.cs` (24581 → 25841)
- `tests/CcDashboard.Tests.Security/Licensing/LicenseUserAuditTests.cs` (10604 → 10611)

**Recovery:** same `git show HEAD:<file> > <file>` procedure as incident #1.
All 7 files restored to HEAD state. Working tree clean after.

---

## PD-005 incident #3 (same day, 2026-05-25)

After recovery from incident #2, an attempt was made to add this very
"incident #2" note to `analysis/process-deviations.md` via the Edit tool.
The tool returned success, but `tail -5` showed the file was re-truncated
with the added text ending mid-sentence at `"After Sprint T2 was
successfully committed (\`d562845\`), the"`. `wc -c` confirmed the file
remained at 14741 bytes — the same size as immediately after recovery,
meaning the edit **did not actually persist**. Shortly after, `git status`
began failing with `unable to unlink '.git/index.lock': Operation not
permitted`, indicating git lock files were also affected.

**This is the most serious symptom:** the Edit tool's success return does
not guarantee filesystem reality. Tool acknowledgement and persistence
have decoupled.

**Disposition:** session terminated. PD-005 update deferred to a fresh
session (this one) where environment is presumed stable.

---

## Conclusion from three incidents in one session

This is no longer a single-incident pattern — it is a **recurring
environmental failure mode** with measurable impact:

- Three independent partial-write incidents in one calendar day
- Each requiring manual recovery via `git show HEAD:<file> > <file>` workaround
- One incident (#3) blocked further documentation work in the same session
- Production code (`UserManagementService.cs`) was the target in 2 of 3 incidents

**Severity upgraded from Medium → High.**

**Mandatory practice going forward** (encode in every hand-off prompt):

1. After every `git status` showing `M` files: `tail -3` each file to
   detect truncation signature (unclosed statements, mid-comment endings).
2. After every successful Edit / Write on a critical file: verify
   immediately via `tail -3` (do not trust tool success return alone).
3. If truncated: restore via `git show HEAD:<path> > <path>` (never
   `git checkout` — fails on Cowork mount with permission error).
4. If `.git/index.lock` Operation-not-permitted errors appear, terminate
   the session — environment is no longer trustworthy. Continue in a
   fresh process.

**Backlog item (new):** raise the issue with Anthropic — recurring
post-write truncation in Cowork mounted folder, with Edit-tool success
returns that do not correspond to filesystem state.

---

## Summary table

| ID | Severity | Sprint | Disposition | Backlog item |
|---|---|---|---|---|
| PD-001 | 🟡 Low | T1 Phase C | Accept; refine clause | — |
| PD-002 | 🟡 Low | T1 Phase C | Accept; backlog refactor | #13 (DatabaseInitializer → interface) |
| PD-003 | 🟠 Medium | T4 | ✅ **Resolved** | #14 (closed — WebFixture rate-limit clearing) |
| PD-004 | 🟡 Low | T4 | Accept; tighten next hand-off | — |
| PD-005 | 🔴 High (recurring — 3 incidents 2026-05-25) | T2 (pre-execution + post-commit + mid-PD-update) | ✅ Recovered ×2; incident #3 required session restart | Backlog: raise Cowork file-write reliability with Anthropic team |

## Pattern note

PD entries are not failures of the sprint — they are failures of the
contract between architect and executor. The fix for a PD is
usually a hand-off-prompt edit, not a code edit. Track and apply at
the start of every subsequent sprint.
