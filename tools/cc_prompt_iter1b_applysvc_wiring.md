# CC Task — iter-1b: orchestrator Phase 5a ApplyService config-wiring fix (match ApplyService contract) + repackage

> Issued by devops-2-0607 -> coordinator §4. PART2 on server-45 crashed in Phase 5a (StrictMode on the Kestrel patch),
> and the ApplyService config-wiring didn't fully match the ApplyService's ACTUAL contract. Verified against
> src/CcDashboard.ApplyService/Program.cs (HEAD). DB on 45 is already clean-rebuilt; this only fixes Phase 5a wiring.
> Two TARGETED changes (NOT a Phase 5a rewrite). deploy: commit + repackage. NO push.

## ApplyService ACTUAL contract (Program.cs, authoritative):
 - `ApplyService:Token`  (startup guard L21 + per-request L59) -> env `ApplyService__Token` ✓ (orchestrator already sets — correct).
 - `ApplyService:Port` (L32, default 5099) -> app SELF-binds `UseUrls("http://127.0.0.1:{port}")` (L33). NO Kestrel:Endpoints needed.
 - CatalogueOwner conn: `GetConnectionString("CatalogueOwner")` (L37) -> env `ConnectionStrings__CatalogueOwner` ✓ (orchestrator already sets — correct; conn built with Username=ccdashboard_catowner = the SQL role ✓).
 - Audit conn: `GetConnectionString("Audit")` (L41) -> env `ConnectionStrings__Audit` — ⚠ orchestrator does NOT set it -> AuditDbContext conn null -> F-5 audit write fails -> 500 on every apply.
 (appsettings placeholder Username=catalogue_owner is irrelevant — the env var overrides it; role-name mismatch RETRACTED.)

## §0.6a integrity FIRST: git status; restore deploy/Apply-Server45Upgrade.ps1 from HEAD if PD-007-truncated. 
## Sync slug devops-2-0607. Claims: `deploy/Apply-Server45Upgrade.ps1`. S1 marker barrier; S2 coord_check_claims; S3 lock; S4 cc_post_commit. §35 BOM+CRLF. §0.3 Python+fsync. NO push (§37).

## FIX A — Phase 5a: DELETE the Kestrel:Endpoints:Http:Url patch block (it StrictMode-crashes AND is unnecessary)
Remove the entire block that starts at `Log "Patching ApplyService appsettings.json (non-secrets only)..."` through the
`$applyJson | ConvertTo-Json -Depth 10 | Set-Content $applyAppSettings -Encoding UTF8` + its `Log "  Set Kestrel..."`.
(The 4 lines: ConvertFrom-Json, the 3 `if (...PSObject.Properties.Name -notcontains ...)` Kestrel/Endpoints/Http guards, the Add-Member Url, the write-back.) The ApplyService binds 127.0.0.1:{ApplyService:Port} itself (Program.cs L32-33); ApplyService:Port=5099 is already in the shipped appsettings.json. Replace the block with a single:
`Log "ApplyService binds 127.0.0.1:$ApplyServicePort from ApplyService:Port (app-side UseUrls) — no Kestrel patch needed."`
(Keep `$applyAppSettings`/`$applyDir` var definitions if used later by Phase 5b — verify Phase 5b still resolves PackageMigrationsDir/ManifestPath; it re-reads appsettings, fine.)

## FIX B — Phase 5a: add the Audit connection env var
In the ApplyService service ENV block, where `$envVars = @("ConnectionStrings__CatalogueOwner=$catownerConn", "ApplyService__Token=$applyToken")`, ADD a third entry:
`"ConnectionStrings__Audit=$catownerConn"`
(catowner has INSERT on audit.audit_logs per 02_catowner_role.sql -> audit writes succeed; F-5 fail-closed satisfied with a real conn.)
Result: $envVars = CatalogueOwner conn + Audit conn + Token (3 entries).

## Self-tests (no server)
- AST parse 0 err. greps: NO `Kestrel.Endpoints.Http.Url` patch remains in Phase 5a; `ConnectionStrings__Audit` present in the ApplyService $envVars; `ConnectionStrings__CatalogueOwner` + `ApplyService__Token` still present; `MetricsApply__Token` (Shell) + MetricsApply:BaseUrl patch intact; Phase 5c F-3 intact. BOM ok; tail proper.

## Commit (deploy:, NO push) + REPACKAGE
git add deploy/Apply-Server45Upgrade.ps1 -> commit "deploy: iter-1b ApplyService Phase 5a wiring — drop crashing Kestrel patch (app self-binds ApplyService:Port) + add ConnectionStrings__Audit env (F-5 audit)". §0.6 verify + cc_post_commit + re-sync. NO push.
Then REPACKAGE 45 from the new HEAD (build_45 process), verify every .ps1 BOM + no Kestrel patch in the packaged orchestrator. Report new package path.

## Re-run on 45 (operator, AFTER §4 + repackage): DB is already clean-rebuilt — just re-run the orchestrator
`.\Apply-Server45Upgrade.ps1 -PgVersion 15 -AutoRollback -ReleaseCommit '<newHEAD>' -AppPassword .. -SuperPassword .. -InstallRoot C:\RTMView -MigrationList '<the 4>' -ShellPublish .\bin\Shell -RtmPublish .\bin\RTM -ApplyServicePublish .\bin\ApplyService`
(Phase 0 probe passes; Phase 2 backs up clean DB; Phase 4/5 idempotent; Phase 5a provisions catowner + 3 env vars + registers RTMApplyService; Phase 5c F-3 RTM loopback; Phase 6 start.) Then DG-1 (8088=127.0.0.1) + DG-2 (RTMApplyService Running; POST /apply-metrics 401 no-token).

## Report: commit hash; the greps (no Kestrel patch, ConnectionStrings__Audit present); package path; NO push.
