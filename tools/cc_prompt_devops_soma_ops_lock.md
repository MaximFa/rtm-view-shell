# CC task — DEVOPS: Soma /ops build-output orphan lock + suite Docker-gate (F-QA-7 ext + coverage)
> §4-PASS coordinator-0623 2026-06-24T11:00:53Z — GREENLIT (v3 window, single tree, serialize w/ Ф2). Owner devops-0619.
> Branch **v3** (follow-up to 7410f34 / Soma 2.4.0). FREE/MIT, loopback-only, auth/audit intact, no new external surface. NO push. fix: prefix.
> ⚠ SEQUENCING: single shared v3 WT (backend Ф2) — run ONE at a time; coordinator/operator pick the window. AUTHOR + §4 now (non-committing).

## STEP 0 — PRE-FLIGHT
- MANDATORY READ (§40/§0.8): role-devops §A+§C + session-coord.
- §0.2/§0.5 object-store; build on top of 7410f34 (FreeShellPort already exists, Soma 2.4.0). Re-verify line anchors of `/ops/build`, `/ops/test`, and `FreeShellPort` before editing (file shifted +85 after 7410f34).
- ⚠ NARROW-ADD (L-SC-09): stage ONLY `tools/Soma/Program.cs` + `tools/Soma/USAGE.md`. git status --short = only those; re-sync shared from HEAD if stale; post-commit zero file-deletion stat.

## ROOT CAUSE (QA, this session)
`/ops/build` and `/ops/test` run `dotnet build/test` into the SAME `bin/` an orphan `CcDashboard.Web` holds open -> MSB3026/3027 "Exceeded retry count" -> FALSE build/test failure (NOT a code break — sln builds clean once the orphan is freed). Orphans seen: pid 18380, 20624. (Same F-QA-7 class; 7410f34 fixed /shell/* but NOT /ops/*.)

## THE FIX (tools/Soma/Program.cs)
1. **Reuse/extend the F-QA-4-safe orphan-free** at the START of BOTH `/ops/build` and `/ops/test` (before spawning dotnet):
   - Call `FreeShellPort(5239)` (frees the Shell holding its port). 
   - PLUS, because a crashed Shell may hold the DLL without listening, add a path-based sweep `FreeShellByPath()`: enumerate processes whose `MainModule` path is the Shell (`CcDashboard.Web` exe / the published/dev Shell path) and Kill(tree) them. **F-QA-4 SAFETY (mandatory):** EXCLUDE `Environment.ProcessId` (Soma) and match ONLY the Shell path — NEVER `GetProcessesByName("dotnet")` blanket-kill. AuditLog each freed pid.
   - (Helper may be a single `FreeShellOrphans()` that does port + path; keep it loopback/local only.)
2. Keep all existing /ops behaviour (whitelist suites, timeouts, ArgumentList no-shell-concat) unchanged.

## USAGE.md (coverage gate — QA finding)
- Document that via Soma `/ops/test`, only `unit` + `architecture` run locally without Docker; `security` + `integration` need Testcontainers/Docker (else fixture-init mass-fail). Either (a) note it clearly in USAGE.md, AND/OR (b) gate: if a suite needs Docker and Docker is absent, return a clear `{skipped:"requires Docker"}` instead of a noisy failure. Prefer the doc note + a soft-gate message.

## VERIFY (build + object-store)
- `dotnet build tools/Soma` OK. Object-store: only tools/Soma/Program.cs + USAGE.md changed; no file deletions; orphan-free called at start of /ops/build AND /ops/test; F-QA-4 safe (excludes Environment.ProcessId, no blanket dotnet-kill, path/port match only); USAGE.md Docker note present.
- Functional (QA via Soma after deploy): with an orphan CcDashboard.Web holding bin, /ops/build and /ops/test succeed (orphan auto-freed first); Soma never killed.

## COMMIT (fix:, NO push) under commit.lock — NARROW ADD
`fix(soma): free CcDashboard.Web build-output orphan before /ops/build+/ops/test (path+port, F-QA-4 safe) + USAGE.md Docker-gate note for security/integration suites (F-QA-7 ext) [devops]`
then §0.6 post-commit (status clean of non-claimed; zero deletions) + §0.6b binding -> .coord/cc/devops.md + §0.7 re-sync.

## ACCEPTANCE
orphan-free (port+path, F-QA-4 safe) at start of /ops/build + /ops/test; USAGE.md Docker note / soft-gate; build OK; narrow-add (Program.cs + USAGE.md only); NO push. Submit coordinator §4 BEFORE run; EXECUTE in a v3 window (serialized w/ backend Ф2).

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash, files, build OK, zero-deletion stat, NO push.
