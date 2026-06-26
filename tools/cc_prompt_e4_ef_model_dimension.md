# CC task — E4: EF-model ⊇ schema invariant (Regen pre-check + optional Compare Dimension E)
> §4-DRAFTED by coordinator-0612 2026-06-14T11:59Z. Owner: dba-0610. Executor: native CC, Windows, .NET 8 SDK + dotnet ef present.
> Claims: db/tools/Regen-Schema.ps1 + db/tools/Compare-ToBaseline.ps1. Commit `db:`. **NO push** (rides next barrier).
> Builds on E2 (af8d89a). This is the "E4" of the A+E4 decision — the durable guarantee that closes the 45 drift-class.

## Why
The root cause (PD-008): the EF model could silently diverge from its migrations, so a regen/build would bake in a wrong schema.
`dotnet ef migrations has-pending-model-changes` (EF 8) reports whether a context's model has changes NOT yet in a migration.
Enforcing it = "EF-model ⊇ schema.sql": schema.sql is only ever regenerated from a model that is fully captured by migrations.

## Mandatory read (§40) + integrity + binding PREAMBLE
- Read: widget-planner / widget-creator / session-coord skills.
- §0.2: git status; branch v2-backend; hash-verify both claimed files vs HEAD.
- Binding PREAMBLE -> .coord/cc/dba.md:
```
## 2026-06-14T11:59Z | binding: dba <-> CC | directive: tools/cc_prompt_e4_ef_model_dimension.md | status: open
### DIRECTIVE: E4 — has-pending-model-changes pre-check in Regen-Schema.ps1 (mandatory abort) + optional Dimension E in Compare (-CheckEfModel). Claims: Regen-Schema.ps1 + Compare-ToBaseline.ps1. db:. NO push.
```
## S1 barrier + S2 claim
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo BARRIER; exit 1; fi
python3 tools/coord_check_claims.py dba-0610 db/tools/Regen-Schema.ps1 db/tools/Compare-ToBaseline.ps1
```

## Pre-step — CONFIRM exit-code semantics (do this first, adapt code if needed)
Run once and OBSERVE the exit code on a clean model (HEAD has R1; should be clean):
```
dotnet ef migrations has-pending-model-changes --context AppDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web ; echo "EXIT=$LASTEXITCODE"
```
Per EF 8: exit 0 = NO pending changes (model captured by migrations); non-zero = pending changes exist. CONFIRM this, and wire the
checks to the OBSERVED semantics (if your EF build differs, branch on the printed message instead of exit code).

## PART 1 — Regen-Schema.ps1: MANDATORY E4 pre-check (abort regen on pending changes)
At the START of the regen (after param validation, BEFORE creating the scratch DB), add:
```powershell
# ── E4: EF-model ⊇ migrations invariant — abort if any context has uncaptured model changes ──
Write-Host "[E4] Verifying EF model is fully captured by migrations..." -ForegroundColor Cyan
$ctxs = @("AppDbContext","AuditDbContext","BackendEmulationDbContext")
foreach ($ctx in $ctxs) {
    dotnet ef migrations has-pending-model-changes --context $ctx `
        --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web 2>&1 | Write-Host
    if ($LASTEXITCODE -ne 0) {
        throw "[E4] $ctx has PENDING model changes — model diverges from its last migration. Add a migration (dotnet ef migrations add ...) BEFORE regenerating schema.sql. (EF-model ⊇ schema.sql invariant — PD-008.)"
    }
    Write-Host "  [E4] $ctx: model captured (no pending changes)." -ForegroundColor Green
}
```
(Adjust the `-ne 0` per the Pre-step observed semantics.)

## PART 2 — Compare-ToBaseline.ps1: optional Dimension E (gated by -CheckEfModel switch; default OFF)
- Add `[switch]$CheckEfModel` to the param block (default off so server-side Compare without the SDK is unaffected).
- After Dimension D, add Dimension E ONLY if $CheckEfModel:
```powershell
if ($CheckEfModel) {
    Write-Host "`n[E] EF MODEL SYNC (has-pending-model-changes)" -ForegroundColor Yellow
    [void]$DeltaLines.Add("-" * 40); [void]$DeltaLines.Add("DIMENSION E: EF MODEL (has-pending-model-changes)"); [void]$DeltaLines.Add("-" * 40)
    $efPending = 0
    foreach ($ctx in @("AppDbContext","AuditDbContext","BackendEmulationDbContext")) {
        dotnet ef migrations has-pending-model-changes --context $ctx --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $efPending++; [void]$DeltaLines.Add("  - $ctx: PENDING model changes (model NOT fully captured by migrations)") }
        else { [void]$DeltaLines.Add("  - $ctx: OK (model captured)") }
    }
    [void]$DeltaLines.Add("")
}
```
- Add an "E. EF model pending: <n>" line to the SUMMARY block (only when $CheckEfModel; else omit or "skipped").
- Do NOT change Dimensions A/B/C/D behaviour. Default run (no switch) must be byte-identical in behaviour to E2.

## Verification GATES (report)
1. Pre-step exit-code observation pasted.
2. PowerShell parses clean (ParseFile both files, no errors).
3. Regen-Schema.ps1 dry sanity: run the E4 block path — at HEAD (R1 applied) all 3 contexts must report NO pending changes (the invariant holds now). If any reports PENDING -> STOP and report which context (that would be a real model/migration gap to fix first).
4. `Compare-ToBaseline.ps1 -CheckEfModel -Database rtmviewdb_regen -Password <pw>` -> Dimension E prints 3x OK; A/B/C/D unchanged vs E2.
5. `Compare-ToBaseline.ps1 -Database rtmviewdb_regen -Password <pw>` (NO switch) -> NO Dimension E, behaviour identical to E2 (server-safe).

## Commit (db:, NO push) under commit.lock
Acquire .coord/locks/commit.lock (dba-0610). While holding:
```
bash tools/pre-commit-check.sh
git add db/tools/Regen-Schema.ps1 db/tools/Compare-ToBaseline.ps1
git commit -m "db: E4 EF-model invariant — has-pending-model-changes pre-check in Regen-Schema (mandatory abort) + optional Compare Dimension E (-CheckEfModel)"
git rev-parse HEAD
```
§0.6 post-commit -> `bash tools/cc_post_commit.sh dba-0610 $(git log -1 --format=%h)` -> sync -> §0.7 re-sync both files from HEAD.

## Binding RESULT -> .coord/cc/dba.md (status: done)
```
### RESULT (by CC): commit <hash>; has-pending exit-semantics=<observed>; Regen E4 pre-check added (aborts on pending); Compare Dimension E behind -CheckEfModel; at HEAD all 3 contexts NO pending (invariant holds); default Compare unchanged. NO push. verified: object-store + reruns.
```

## Report (chat) — NO push
exit-code semantics observed; all 3 contexts clean at HEAD (invariant holds); Dimension E prints under -CheckEfModel; default Compare unchanged; commit hash. NO push.
