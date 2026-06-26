# CC task — MaintenanceService v1: SF-MS-003 anti-RCE contract layer (impl)

> Owner: backend (slug = the executing backend session, e.g. backend-0620). Pairs with devops (service lead).
> STATUS: **§4-PASS coordinator (2026-06-21T21:51:33Z)** — contract design approved; EXEC still gated by the EXEC GATE (devops scaffold + security re-review). security re-reviews landed code+tests post-commit.
> Branch **v2-backend**. Commits: web:. NO push (§37). Security gate after commit (mandatory ack, like §42.7).
> Design spec = **docs/MaintenanceService-v1-ReadPlane-Spec.md** (authoritative) §5 (API surface) + §7 (SF-MS-003).
> SCOPE: v1 READ-plane contract layer ONLY. NO write-plane, NO arbitrary-exec endpoint, NO RTM-contour touch.

## ⛔ EXEC GATE — do NOT run until ALL true (authoring is freeze-safe; execution is gated)
1. devops's `src/Maintenance/RTMMaintenance.ReadPlane/` scaffold (.csproj + Program.cs Windows-Service host) is COMMITTED on v2-backend (this layer plugs into it).
2. coordinator §4-PASS on THIS prompt + security re-review of the spec-delta is GREEN.
3. devops priority reached (per journal 2026-06-21T21:02:48: Garnet PoC first, then Maint v1) — confirm with coordinator.
Until then this file is a §4 review artifact, not an execution order.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md ; .claude/skills/widget-planner/widget-planner.md ; .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/role-backend/role-backend.md (§A core + §C verify)
Read: **docs/MaintenanceService-v1-ReadPlane-Spec.md** (§5 API surface, §7 SF-MS-003 — the ratified contract)
Read: docs/MaintenanceService-Design-Review.md §F/§G (operator D1–D5 + security CONDITIONAL ACK) for context
Read: devops's committed `src/Maintenance/RTMMaintenance.ReadPlane/**` scaffold (mirror its namespaces/DI exactly)
Only after reading all: proceed.

## INIT / discipline
- §0.6a integrity block FIRST (git status; for every M file hash-verify vs HEAD via `git hash-object` vs `git rev-parse HEAD:<f>` — mount shows false-M, §0.5; restore PD-007-truncated files from HEAD before any work).
- Branch **v2-backend** (git checkout v2-backend; §0.5 object-store verify, NOT mount git status).
- §0.3 Python+fsync for any `.coord/` write; after every SOURCE write: `sync` + `tail -3` + `wc -l` + STEP-0.5 NUL-check (0 NUL bytes — schema.sql/.git have shown mount NUL padding, guard your own writes too).
- §42.6 sync block: slug = your backend slug; **claims** (file-mode, non-overlapping with devops):
  `["src/Maintenance/RTMMaintenance.ReadPlane/Contracts/**","src/Maintenance/RTMMaintenance.ReadPlane/Validation/**","src/Maintenance/RTMMaintenance.ReadPlane/Jobs/Contracts/**","src/Maintenance/RTMMaintenance.ReadPlane.Tests/**"]`
  devops owns: Program.cs, endpoints, auth (mTLS/token/IP), the read SCRIPTS, the job RUNNER/wiring, Install scripts, scrub/ACL/retention.
  If a file is needed by both (e.g. the catalog→script binding) → coordinate at §4; backend owns the catalog/validation DATA + contracts, devops owns the runner that consumes them.
- commit.lock around every commit (§42.4). §0.6b binding → `.coord/cc/backend.md` (preamble open + RESULT). pre-commit-check.sh. §0.7 re-sync from HEAD as last step. **NO push.**

## TASK — SF-MS-003 contract layer (spec §7; the surface that stops the named-op catalog becoming RCE)

### 1. Named-op catalog = fixed enum (NO user string ever selects a script)
- `Contracts/MaintenanceSignal.cs`: `public enum MaintenanceSignal { EventLog, ServiceRecovery, RedisInfo, DiskMem, SerilogTail, Health }` — the EXACT fixed set from spec §5 (`eventlog`, `service-recovery`, `redis-info`, `disk-mem`, `serilog-tail`, `health`). No `Other`, no free-string fallback.
- `Contracts/SignalScriptMap.cs`: a COMPILE-TIME immutable `IReadOnlyDictionary<MaintenanceSignal, string>` (enum → exactly ONE script identifier/key). Static, readonly, no runtime mutation, no reflection-built keys. Each enum value MUST map to exactly one entry (add a static-ctor assertion: `Enum.GetValues<MaintenanceSignal>()` all present; throw on startup if any unmapped). devops's runner resolves the script-id → the physical pre-authored script; backend NEVER concatenates a path from input.

### 2. Param allow-list validation BEFORE any script (FluentValidation or explicit guards)
- `Contracts/CollectIncidentRequest.cs`: record `{ DateTimeOffset Since; DateTimeOffset Until; IReadOnlyList<MaintenanceSignal> Signals; }`. Bind `signals[]` as the ENUM TYPE directly (System.Text.Json enum binding with `JsonStringEnumConverter` set to **reject unknown** — NOT integer-tolerant, NOT case-permissive in a way that accepts garbage); an unknown signal string → 400 at deserialization, never reaches logic.
- `Validation/CollectIncidentValidator.cs`:
  - `Signals`: non-empty; every element ∈ `Enum.IsDefined`; reject duplicates; cap count ≤ enum size.
  - `Since`/`Until`: both present; `Since < Until`; span capped (`Until - Since <= TimeSpan.FromDays(7)` per spec §5); reject `Until > now()+skew` (no future windows beyond small clock skew); reject unparseable (handled by typed binding + explicit ModelState check).
  - On ANY violation → 400 with a generic message (no echo of raw input into the error to avoid reflected-injection in logs/responses); audit the rejection.
- NO param is interpolated into SQL, a path, or a command line at this layer.

### 3. Arg-array, no-shell-concat contract (the anti-RCE core)
- `Jobs/Contracts/IScriptInvocation.cs`: the contract devops's runner MUST satisfy — params passed ONLY as a typed `IReadOnlyList<string>` argument array (maps to `ProcessStartInfo.ArgumentList`, NEVER `ProcessStartInfo.Arguments` string). Document in XML-doc: "no value reaches a shell unquoted; no `cmd /c`/`-Command "<concat>"`; PowerShell scripts invoked as `pwsh -File <fixed-script> -Since <arg> -Until <arg>` via ArgumentList only."
- Provide `Validation/ArgumentArrayGuard.cs`: a helper that converts a validated `CollectIncidentRequest` → the typed arg array for a given signal (timestamps as ISO-8601 round-trip `o` format, never free text). This is the ONLY sanctioned path from request → script args.

### 4. Async-job contract
- `Jobs/Contracts/ICollectJob.cs` + `JobId`, `JobStatus { Queued, Running, Succeeded, Failed }`, `JobResult { BundleLocation, CompletedAt }`. POST `/collect/incident` → `JobId`; GET `/jobs/{id}` → status+result (devops wires the endpoints; backend defines the contract types + the job-lock interface `ISingleCollectLock` — one collect job at a time per server, mirrors commit.lock discipline, spec §5).

### 5. Injection security tests (MANDATORY — §4-critical / security re-review gate; build is NOT done without these)
Project `src/Maintenance/RTMMaintenance.ReadPlane.Tests/` (xUnit + FluentAssertions). ≥12 tests:
- INJECTION CORPUS on every param — for each of `signals`, `since`, `until` feed: `"; rm -rf"`, `"& calc"`, `"| whoami"`, `"$(id)"`, backtick-cmd, `"../../etc/passwd"`, `"..\\..\\windows"`, null byte `"\0"`, oversized (10k chars), unicode-escape, and a fake signal `"eventlog; del"` → ASSERT 400 / validation failure, NEVER reaches `IScriptInvocation`.
- ASSERT each `MaintenanceSignal` resolves to EXACTLY ONE script-id (SignalScriptMap completeness + uniqueness); a value not in the enum cannot select a script.
- ASSERT `ArgumentArrayGuard` produces a pure arg array (no element contains shell metacharacters un-isolated; timestamps are ISO-8601 `o`); ASSERT the codebase never uses `ProcessStartInfo.Arguments` (string) for these invocations — a unit/architecture test grepping for `.Arguments =` in the ReadPlane invocation path, or a NetArchTest-style rule.
- ASSERT span cap (>7 days → reject), `Since>=Until` → reject, empty signals → reject, duplicate signals → reject, future `Until` → reject.
- ASSERT validation rejection does NOT echo raw input into the response/audit (no reflected payload).

## PAIR (SF-MS-002 scrub policy) — separate, do NOT block this prompt
Backend also pairs with devops on the SF-MS-002 scrub/redact policy logic (connection strings, `Password=`/`PGPASSWORD`/`pwd=`, token/bearer/secret/api-key/JWT-shaped, caller ANI/phone; default-deny secret-shaped → `[REDACTED]`). Track that under devops's scrub prompt; this prompt is the SF-MS-003 contract layer only.

## ACCEPTANCE
- `dotnet build` of the ReadPlane solution/projects green; `dotnet test src/Maintenance/RTMMaintenance.ReadPlane.Tests` ≥12 green (incl. the full injection corpus).
- `MaintenanceSignal` enum = the exact 6 signals; `SignalScriptMap` complete + one-to-one (startup assertion present).
- `CollectIncidentRequest` binds `signals[]` as enum (unknown → 400 at deserialization); validator enforces span cap ≤7d, `Since<Until`, non-empty/dedup/no-future.
- `IScriptInvocation` contract mandates `ArgumentList` (arg-array) — XML-doc + the no-`.Arguments` test present.
- Async-job + job-lock contracts present (`ICollectJob`, `ISingleCollectLock`).
- ZERO RTM-contour touch; ZERO write-plane; ZERO arbitrary-exec endpoint. Object-store-verified commit (web:), branch v2-backend, commit.lock, **NO push**.
- Security re-review of the spec-delta + injection tests = the final gate (like §42.7) before SF-MS-003 is "done".

## §0.6b binding RESULT (fill at end)
commits <hash> · build/test <counts> · files <list+lines> · status done|failed · blockers · verified: object-store. Relay digest to inbox/coordinator.md.
