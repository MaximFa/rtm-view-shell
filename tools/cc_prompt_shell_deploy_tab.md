# CC Task (Shell specialist, slug shell-0609) — "Deploy new metrics" tab (hot-reload, Shell side)

> DRAFT for coordinator §4. Builds the Shell side of the 4-session hot-reload feature.
> Canon: `.coord/meeting_hotreload_0609.md`. Contracts (READ BOTH, they are FINAL):
>   - `docs/metrics-hot-reload-contract.md`  (metrics-side, v1.0 FINAL — delta/manifest/RT-vs-history/R1/R2)
>   - `docs/metrics-apply-endpoint-contract.md` (devops apply-endpoint — request/response, ledger, security)
> Scope = UI tab + Deploy TRIGGER + ledger-delta READ + compileMetrics invoke + Recompile. NO web-DML, NO apply, NO compile.

## Git push — DO NOT (§37). Commit only; push requested separately via tools/cc_prompt_push.md.

---

## Step 0 — §0.6a MANDATORY INTEGRITY CHECK (first, no exceptions)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== integrity check complete ==="
```
NOTE: mount `.git` reads can be unreliable (git rev-parse HEAD may fail / show `A ./`). If `git status` looks
corrupted, verify each claimed file by EXPLICIT hash: `git hash-object <f>` vs `git rev-parse <HEADHASH>:<f>`.
Do not escalate corruption from mount git status alone (feedback_git_mount_distrust).

## Step 0b — §40 mandatory skill reads (before any work)
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
```
Then the Shell specialist skills for THIS task:
```
Read: .claude/skills/ux-ui-expert/...             (WHAT: tab UX, deploy/confirm/result states, dark+RTL)
Read: .claude/skills/frontend-design/...           (HOW: design tokens, existing MetricsPage patterns)
Read: .claude/skills/blazor-frontend-design/...    (HOW: Blazor/Bootstrap, RTL, localized strings)
Read: .claude/skills/blazor-server-expert/...      (render-mode/circuit; InteractiveServer page)
Read: .claude/skills/app-cyber-security-expert/... (Superadmin gate CODE-03, NO web-DML, no token in client/localStorage §41, no secret in source CODE-05)
```
Also READ the two contract docs in full before coding:
```
Read: docs/metrics-hot-reload-contract.md
Read: docs/metrics-apply-endpoint-contract.md
```

## Multi-session sync (§42.6) — slug shell-0609
> Apply the machinery from `tools/cc_prompt_sync_block.md` (READ it first): phantom-aware `/tmp/acquire_lock.py`
> + S1/S3/S4. This section fills slug + claims.

CLAIMS (EXPANDED for this task — coordinator ratifies in §4; all in `web` file-mode, none held by active sessions
[backend-0609=Engine/Union/ngc; daytrend-2=DayTrend handler/widget; devops=none-in-src; metrics-2=on-hold]):
  EXISTING (mine, standing):
  - src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor
  - src/CcDashboard.Web/wwwroot/app.css
  NEW (this task):
  - src/CcDashboard.Application/Interfaces/IRtmRelayService.cs          (add InvokeCompileMetricsAsync)
  - src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs          (impl the invoke)
  - src/CcDashboard.Application/Interfaces/IMetricDeployLedgerReader.cs  (NEW)
  - src/CcDashboard.Application/Interfaces/IMetricApplyClient.cs         (NEW)
  - src/CcDashboard.Contracts/DTOs/Metrics/ApplyMetricsDtos.cs          (NEW — both records in one file; Contracts/DTOs is THE cross-layer DTO home, e.g. ConfigurationDtos.cs / LoginRequest.cs. Do NOT create Application/DTOs.)
  - src/CcDashboard.Infrastructure/Metrics/MetricDeployLedgerReader.cs   (NEW)
  - src/CcDashboard.Infrastructure/Metrics/MetricApplyHttpClient.cs      (NEW)
  - src/CcDashboard.Web/Program.cs                                       (DI registration + HttpClient + options)
- **S1 push-barrier:** `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report.
- **S2 claims:** `python3 tools/coord_check_claims.py shell-0609 <each path above>` -> exit 1 = STOP. Touch ONLY claimed paths (+ /tmp scratch).
- **S3 commit.lock** around every git add/commit; create+use `/tmp/acquire_lock.py` per sync_block (owner shell-0609; 15-min stale=report+wait, never auto-delete). Covers §0.4 plumbing path too.
- **S4 post-commit:** `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- **S5:** no git push.

## §0.3 — Edit tool BANNED. ALL writes via Python read->modify->write + os.fsync, then `sync && tail -3 && wc -l`. Applies to .cs, .razor, Program.cs — everything.

---

## THE WORK — Shell side of hot-reload "Deploy new metrics"

### A. Add interfaces + DTOs (Application layer)
1. `IMetricDeployLedgerReader` — read-only, returns the set of MetricIds already recorded as applied on THIS
   client DB (the per-metric ledger, contract §9 / §38a). Signature e.g.
   `Task<IReadOnlySet<string>> GetAppliedMetricIdsAsync(CancellationToken ct)`.
   (Ledger has NO TenantId — RTSGrid_Metric is platform-wide, contract §9.)
2. `IMetricApplyClient` — triggers the devops apply-endpoint (contract §5/§6). Signature e.g.
   `Task<ApplyMetricsResponse> ApplyAsync(ApplyMetricsRequest req, CancellationToken ct)`.
3. DTOs mirror the contract EXACTLY (place BOTH records in src/CcDashboard.Contracts/DTOs/Metrics/ApplyMetricsDtos.cs — Contracts is the project's cross-layer DTO home; there is no Application/DTOs):
   - `ApplyMetricsRequest`  { string PackageRef; string MigrationRef; IReadOnlyList<string> MetricIds; string TriggeredBy; }
   - `ApplyMetricsResponse` { bool Success; IReadOnlyList<string> AppliedRtMetricIds; IReadOnlyList<LedgerRow> LedgerRows; IReadOnlyList<string> Warnings; string? AuditId; string? Error; }
     LedgerRow { string MetricId; DateTimeOffset DeployedAt; string SourceCommit; }

### B. Relay invoke (Application interface + Infrastructure impl)
4. Add to `IRtmRelayService`:
   `Task InvokeCompileMetricsAsync(Guid tenantId, IReadOnlyList<string> metricIds, CancellationToken ct = default);`
5. Implement in `RtmRelayService`: resolve the tenant RTM hub URL (same source as existing connections —
   `TenantSettings.SignalRConnectionUrl`, reuse the existing hub-url resolution/Redis cache used by
   SubscribeUnion/Grid). Open or reuse a control HubConnection to that URL and
   `await conn.SendAsync("compileMetrics", metricIds, ct)` — **fire-and-forget** (SendAsync, not InvokeAsync),
   matching contract §6 + RTM-PROTO. Empty `metricIds` -> no-op (log + return). Reuse the class's existing
   connection/locking patterns; do NOT block the circuit. Log via the existing logger (no PII).
   R1: callers pass EXACTLY `appliedRtMetricIds` (RT-only). RTM also history-skips as defense-in-depth (Backend).

### C. Infrastructure impls
6. `MetricDeployLedgerReader` — read the per-metric ledger table (read-only, AsNoTracking). The ledger table is a
   **devops follow-up** (contract §12 open: name `metric_deploy_log` candidate or folds into `db_patch_history`).
   ⚠ PENDING: confirm final table/columns with devops before wiring the concrete query. Until confirmed, implement
   against the contract's minimal columns (`MetricId, DeployedAt, SourceCommit`) behind one clearly-marked
   `// PENDING devops ledger DDL` query; if the table is absent at runtime, catch + return empty set (delta then
   shows full manifest as undeployed — acceptable v1, log a warning). Use `FromSqlInterpolated` only (CODE-01), no concat.
7. `MetricApplyHttpClient` — typed HttpClient POST to the apply-endpoint (contract §3/§5: `http://127.0.0.1:<port>/apply-metrics`,
   `Authorization: Bearer <service-token>`). BaseUrl + token from configuration/options (NOT source, CODE-05) —
   ⚠ PENDING devops: exact port + token provisioning. Bind options to a config section (e.g. `MetricsApply:{BaseUrl,Token}`),
   document the section, leave value placeholders. Serialize request / deserialize response to the §B DTOs.
   On non-200 / transport error -> return `ApplyMetricsResponse{ Success=false, Error=... }` (never throw to the UI raw).

### D. Program.cs DI
8. Register: `IMetricDeployLedgerReader`, `IMetricApplyClient` (AddHttpClient typed), bind `MetricsApply` options.
   `IRtmRelayService` already Singleton — no change to its registration.

### E. MetricsPage.razor — the "Deploy new metrics" tab
9. Page is `@rendermode InteractiveServer`, `@attribute [Authorize(Roles="Superadmin")]` — already Superadmin-only;
   the tab inherits that. Still assert Superadmin in the Deploy handler (defense-in-depth, CODE-03) before calling apply.
10. Add a tab/section "Deploy new metrics" alongside the existing metrics list (follow the page's existing tab/section
    pattern; localized strings via the same `IStringLocalizer`/catalogue path as the rest of the page + MetricWizard).
11. DELTA list: load the install-package MANIFEST (MetricIds + localized DisplayName/ShortDescription/type/mirror-pair)
    from the catalogue source the page/MetricWizard already use (`docs/metrics-catalog.json` per contract §4 — reuse the
    existing catalogue load path; do NOT invent a new loader). Compute `undeployed = manifest MetricIds MINUS
    IMetricDeployLedgerReader.GetAppliedMetricIdsAsync()` (contract §3). Mirror entry (RT+history pair, contract §2)
    = ONE row, show both halves; "new" if EITHER half unrecorded. Show: DisplayName, MetricId, type (RT/history),
    mirror link, shortDescription. Empty delta -> "All metrics deployed" state.
12. DEPLOY button (per undeployed entry, or multi-select -> one apply): confirm dialog (Superadmin action), then call
    `IMetricApplyClient.ApplyAsync(new ApplyMetricsRequest{ PackageRef=<manifest/package id>, MigrationRef=<from manifest>,
    MetricIds=<the undeployed ids for this entry>, TriggeredBy=<current Superadmin UserId> })`.
    - on `Success`: fire `IRtmRelayService.InvokeCompileMetricsAsync(tenantId, response.AppliedRtMetricIds, ct)` —
      EXACTLY the response set (R1), NEVER the raw manifest. Refresh the delta (ledger now has the rows). Show
      success + any `warnings`.
    - on failure: show `Error`, do NOT fire compile, leave delta unchanged.
13. RECOMPILE affordance (contract §6.1 R2 / apply §10): a "Recompile" action on an already-deployed entry that
    re-fires `InvokeCompileMetricsAsync(tenantId, <that entry's applied RT ids>, ct)` WITHOUT calling the apply-endpoint
    (no re-apply). Idempotent on RTM side. Superadmin only.
14. Shell TRIGGER logging (contract §4: "Shell logs the trigger separately"): log the Deploy/Recompile trigger via
    Serilog structured log (who=UserId, what=metricIds, result), no PII beyond UserId, no token. NOTE: a formal
    audit EVENT type for the Shell trigger is NOT in CLAUDE.md §16 — do NOT invent an audit event / touch §16 here;
    Serilog structured log for v1, flag in the report if a dedicated audit event is wanted (coordinator/§16 owner decides).
15. tenantId for the invoke = current tenant (`ICurrentUserAccessor`/`ITenantContext`); compileMetrics targets that
    tenant's RTM hub.

### F. Styling (app.css)
16. Any new tab/list/badge styling: reuse existing MetricsPage/configurator tokens; ensure dark-mode + RTL parity
    (logical CSS props). If you add a CSS version-sensitive asset, bump `app.css?v=` in App.razor — **but App.razor is
    NOT in this task's claims**; if a bump is needed, FLAG it to coordinator to add App.razor to claims rather than
    editing it unclaimed. (Most likely no bump needed — prefer existing classes.)

### PENDING / integration seams (call out in report — these are devops/Backend follow-ups, NOT blockers to build green)
- Ledger table final name/columns (devops, contract §12) — query behind a marked TODO.
- Apply-endpoint port + service-token provisioning (devops, contract §12 / §4).
- RTM `compileMetrics(string[])` hub handler (Backend) — Shell only sends; handler is Backend's.
- The feature is NOT end-to-end runnable until devops apply-service + ledger + Backend handler land. This task delivers
  the Shell side compiling green against the FINAL contracts with config-driven seams.

### Verify (mandatory, before commit)
- `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors (Infrastructure + Application build via the Web build).
- Architecture: no Application->Infrastructure ref (ARCH-11); interfaces in Application, impls in Infrastructure,
  Web wires via Program.cs only. Confirm DTOs match the contract field-for-field.
- Confirm: NO DML / INSERT into RTSGrid_Metric anywhere in web/Shell code; apply is only via IMetricApplyClient POST.
- Confirm: no service token / secret hardcoded; bound from config (CODE-05). compileMetrics sends only response RT ids.
- Re-read MetricsPage tab: Superadmin gate present; localized strings (no hardcoded UI text, I18N-03).

## Commit (web:)
```bash
bash tools/pre-commit-check.sh   # exit 1 -> restore truncated, retry Python write, re-check
# acquire commit.lock (S3), then add ONLY the claimed paths:
GIT_INDEX_FILE=/tmp/cc-idx git add <the claimed files actually changed/created>
# commit-tree path (HEAD.lock-safe, §0.4) OR normal commit -m "web: hot-reload Deploy-new-metrics tab — Shell trigger + ledger delta + compileMetrics invoke [shell-0609]"
```
Then §0.6 post-commit verify (git status clean, diff HEAD empty, line counts match) -> S4 `bash tools/cc_post_commit.sh shell-0609 <hash>`
-> §0.6/PD-007 re-sync each committed file from HEAD (`git show HEAD:<f> > <f>`) -> `sync`.

## Report back
List files created/changed ; build result (0 errors) ; confirm no web-DML + no hardcoded secret + DTOs match contract ;
commit hash ; the PENDING seams left for devops/Backend ; whether an app.css?v bump was needed (and if so that it was flagged, not done). NO push.
