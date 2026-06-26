# CC task — DEVOPS: MaintenanceService v1 read-plane SCAFFOLD (operator GO, I am v1 LEAD)
> §4-PASS coordinator-0623 2026-06-24T08:39:46Z — GREENLIT. Owner devops-0619.
> Branch **v2-backend** (`git checkout v2-backend` FIRST — NOT v3). NO push (§37). FREE/MIT only (Kestrel built-in, self-signed certs). feat:/web: prefix.
> AUTHORITATIVE SPEC: docs/MaintenanceService-v1-ReadPlane-Spec.md (§2 architecture, §5 API, §4 SF-MS-001, §6 SF-MS-002, §7 SF-MS-003 seam). Security §G pin-at-build conditions folded below.

## STEP 0 — PRE-FLIGHT (do FIRST)
- MANDATORY READ (§40/§0.8): `.claude/skills/role-devops/role-devops.md` (§A core + §C verify) + `.claude/skills/session-coord/session-coord.md` before any work.
- SYNC-BLOCK S1: check `.coord/push/request.md` freeze; claim is `src/Maintenance/RTMMaintenance.ReadPlane/**` — NEW territory on v2-backend (no overlap with the v3 freeze / other claims). Proceed.
- Before `git checkout v2-backend`: ensure NO modified-TRACKED file blocks the switch (untracked v3-side prompts/docs do NOT block); if a tracked file shows M, re-sync from HEAD first (`git show HEAD:<f> > <f>`) — do not carry v3 WT edits across.
- `git checkout v2-backend`; §0.2/§0.5 integrity by OBJECT-STORE (mount-git flaky: HEAD-ref may read truncated, index may read corrupt — verify by-hash, native git is truth). Confirm on v2-backend.
- ⚠ NARROW-ADD DISCIPLINE (L-SC-09, the 9c6ac0e CLAUDE.md-sweep lesson): stage ONLY the NEW files you create under `src/Maintenance/RTMMaintenance.ReadPlane/**`. `git add` each explicit path — NEVER `git add -A`/`.`/sweep. Before commit: `git status --short` and confirm ONLY your new files are staged. If any SHARED file (CLAUDE.md, .sln, etc.) shows M from a stale WT, re-sync from HEAD first (`git show HEAD:<f> > <f>`) so you don't revert others' commits.

## SCOPE — v1 read-plane SCAFFOLD (skeleton + seams, NOT full impl)
Build the runnable skeleton + the security/structural seams. Full SF-MS-001/002/003 logic is wired as stubs/interfaces with `// TODO` referencing the spec; the SF-MS-003 contract is BACKEND's (define the seam only).

### A. Project
`src/Maintenance/RTMMaintenance.ReadPlane/RTMMaintenance.ReadPlane.csproj` + `Program.cs`:
- .NET 8, `Microsoft.NET.Sdk.Web`; self-contained `win-x64`; `UseWindowsService()` (PackageReference `Microsoft.Extensions.Hosting.WindowsServices`).
- Kestrel, SEPARATE process from CcDashboard.Web (must run when the Shell is down). Internal bind ONLY (127.0.0.1 / internal NIC) — NEVER external. HTTPS/TLS 1.2+.
- Do NOT add the project to CcDashboard.sln in this scaffold unless trivial+verified (separate lifecycle); if added, that's the only shared-file touch and must be a clean re-synced edit.
- RESERVE (comment only, do NOT create): `src/Maintenance/RTMMaintenance.WritePlane/` is v2 — not built.

### B. Endpoints — v1 ONLY
- `GET /status` — sync: service/Shell/RTM versions, uptime, Redis(Garnet)/PG up. Read-only composition (stub the data sources with `// TODO` per spec §5).
- `POST /collect/incident { since, until, signals[] }` -> returns `job-id` (async job stub).
- `GET /jobs/{id}` — poll async job status + result-bundle location. **(security pin-at-build (a): the /jobs result endpoint exists; bundle delivery is scrubbed — see D.)**
- NO write-plane endpoints (`/preflight`, `/deploy/*`, `/rollback`) — v2, do NOT create.

### C. Auth — defense-in-depth (ALL three), as middleware/handlers
- mTLS: client-cert required, thumbprint ALLOW-LIST (self-signed LocalMachine\My); reject non-allow-listed.
- Per-server bearer token: short-TTL. **(pin-at-build (b): define short-TTL CONCRETELY (e.g. 60 min, config) + a token-revoke path (revocation list / rotate-on-compromise hook).)** Read token from DPAPI/Credential Manager/config — NO literal token in source.
- IP allow-list (operator workstation only).
- A request must pass mTLS thumbprint AND token AND IP-allow-list; any failure -> 401/403 + audit. Wire as middleware with `// TODO` for the cert-store/Redis bits where infra is out of scaffold scope.

### D. SF-MS-001 / SF-MS-002 / SF-MS-003 seams
- **SF-MS-001** (read-only least-priv): document + stub the dedicated NON-admin account (enumerate the exact read set per spec §4: Event Log read / Serilog read / Redis-Garnet INFO read / `sc query`+`qfailure` / disk-mem / `/health`; explicit DENY restart/pg_dump/Program-Files-write). **(pin-at-build (c): the read-account credential isolation — the read-plane account/process MUST NOT be able to read the write-plane's / other planes' DPAPI/credential store or appsettings; document the isolation boundary.)** If a DB read is needed, reuse the least-priv `soma_ro` pattern (secrets revoked) — do NOT use an app/superuser role.
- **SF-MS-002** (confidentiality): the bundle writer is a seam with **STREAMING/in-memory scrub BEFORE write** (raw secrets never transiently on disk) — redact conn-strings/Password=/PGPASSWORD/token/bearer/secret/api-key/ANI-phone (locale-aware), default-deny; scrub the `/jobs/{id}` result payload too; output -> `C:\RTMView-Ops\output` with restrictive NTFS ACL + retention purge. Implement the scrub interface + a default redactor; full signal collectors are `// TODO`.
- **SF-MS-003** (anti-RCE, BACKEND-owned): define ONLY the SEAM — e.g. `ISignalValidator` / a request-DTO + a validation hook the handler calls before any collector runs. Do NOT implement the allow-list/enum (backend's §4-PASS contract plugs in here). Mark the seam clearly so backend's SF-MS-003 EXEC-gate opens on this commit.

### E. Audit + fallback
- Local structured audit (who/what/params/result/time) seam -> `C:\RTMView-Ops\output` + Serilog (off-box = v2, note boundary). Manual §43 fallback documented (agent down/cert expired -> operator carries scripts).

## VERIFY (object-store + build)
- `dotnet build src/Maintenance/RTMMaintenance.ReadPlane` succeeds (scaffold compiles; stubs/`// TODO` OK).
- Object-store: ONLY `src/Maintenance/RTMMaintenance.ReadPlane/**` (+ optionally .sln) committed; NO sweep of CLAUDE.md or other shared files (git status --short clean of non-claimed).
- v1 endpoints present; NO write-plane endpoints; auth middleware (mTLS+token+IP) wired; SF-MS-003 seam present + unimplemented; SF-MS-002 scrub interface present.

## COMMIT (feat:/web:, NO push) under commit.lock — NARROW ADD ONLY
`feat(maint): MaintenanceService v1 read-plane scaffold — Kestrel Windows Service, /status + /collect/incident + /jobs, mTLS+token+IP auth, SF-MS-001/002 seams + SF-MS-003 backend seam [devops]`
then §0.6 post-commit (git status --short = only your files) + §0.6b binding -> .coord/cc/devops.md + §0.7 re-sync.

## ACCEPTANCE
Scaffold compiles; v1-only endpoints (+/jobs); 3-factor auth seam; SF-MS-001 read-only-account doc + the 3 §G pin-at-build conditions reflected (streaming-scrub+/jobs; concrete short-TTL+revoke; read-account isolation); SF-MS-003 seam for backend; NO write-plane; narrow-add (no shared-file sweep); NO push. Submit to coordinator §4 BEFORE operator runs; on commit -> backend SF-MS-003 exec-gate opens -> security post-commit re-review.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash, files (only src/Maintenance/**), build OK, git status clean of non-claimed, NO push.
