---
role: devops
project: RTM View Shell
version: 0.1
last_verified: 2026-06-19T09:30:00Z
owner: devops
reviewer: curator
---
# role-devops — RTM DevOps role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (deploy/, tools/, Installations/, db/tools/, git log --oneline deploy/),
> NOT session narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: Deployment scripts, packaging, ops tooling. Owns: deploy/, tools/Build-*.ps1, Installations/, db/tools/.
Does NOT write business logic — code changes flow via CC prompts.

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **MANDATORY Compare-ToBaseline before ANY deploy. Never rely on memory.**
   Never apply migrations/binaries without FIRST running Compare-ToBaseline against THAT server.
   Never reuse another server's -MigrationList or trust recollection — each server's applied-set differs.
   The Compare IS the gate: yields the server-specific -MigrationList AND catches runtime-critical drift.
   · SOURCE: 234+45 deploys 2026-06-19; journal 2026-06-19; 234 baseline_delta 111313 -> FULL-10 vs 45's different list

2. **§35: PS1 files MUST be UTF-8 BOM + CRLF for Windows PowerShell 5.1.**
   Box-draw/Cyrillic without BOM -> "Unexpected token" parse failure.
   · SOURCE: CLAUDE.md §35, 024feef BOM fix

3. **Preserve operator config across binary updates (appsettings.json + *.Production.json).**
   · SOURCE: 234 28P01 incident; e46e849

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-19 · StrictMode scalar.Count: Get-ChildItem/Sort-Object/.Split() return SCALAR on single item -> .Count THROWS under Set-StrictMode -Version Latest. ALWAYS wrap collection results in @(...). · SOURCE: de5e835 (@() on $allBackups L137 + $migrations L204) · status: active
- 2026-06-19 · §35 BOM re-encode via Python: a TEXT write drops the UTF-8 BOM -> PS 5.1 fails. Re-encode in BINARY: b"\xef\xbb\xbf" + text_CRLF.encode("utf-8") + fsync; verify head -c3 == ef bb bf. · SOURCE: d62e704 dropped BOM -> 024feef fix · status: active
- 2026-06-19 · Deploy must PRESERVE operator config: Update-RTMView Shell-preserve missed appsettings.json -> overwrote 234's live conn-string -> 28P01 password auth failed. Preserve every operator config file, not just *.Production.json. · SOURCE: 234 Shell crash; e46e849 fix · status: active
- 2026-06-19 · pg_dump completeness: pre-apply pg_dump must run as OBJECT OWNER (postgres), else backup is INCOMPLETE. Run the whole apply path as postgres. · SOURCE: 234 STEP-4 pg_dump-completeness flag · status: active
- 2026-06-19 · pkg-copy PD-007: staged package file gets truncated by mount write-back AFTER native commit; re-materialize from HEAD + byte/hash-verify the swap source before every swap. · SOURCE: BOM + StrictMode fixes both needed pkg re-materialize · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "@\(Get-ChildItem"` — must exist (@() wrap)
2. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "appsettings\.json"` — must exist (preserve)
3. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "pg_dump"` — must exist (DB backup)
4. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "Compare-ToBaseline"` — must exist (E1 gate)

## §D REFERENCE
Scripts: deploy/Update-RTMView.ps1, deploy/Install-RTMView.ps1, tools/Build-ProdRelease.ps1.
Ops layout: CLAUDE.md §43 (external-server ops), §35 (prod release encoding).
