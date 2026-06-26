# CC task — R7 Export-button wiring (shell): enable Report Export → .xlsx download — AWAITING §4-BLESS
> bi's Export backend LANDED (152bed7). Contract: `ExportReportCommand(Guid ReportId, DateTime From, DateTime To, Guid? TenantId = null) → ReportExportResult(byte[] Content, string FileName, string ContentType)` (one sheet per widget, server-built FileName, ContentType=xlsx). Coordinator CONFIRMED the button place = the existing (currently disabled) Export button in the ReportViewPage header (~:57). Wire it to a browser download. Schedule stays a stub.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37). claim=frontend (web). Report-scoped, parity-guard.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`. Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_export_wiring.md | status: open
### DIRECTIVE (spec->CC): enable ReportViewPage Export → ExportReportCommand → JS download. Claim: ReportViewPage.razor, app.js (download helper if absent). feat:, NO push, §4 + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Reports/ReportViewPage.razor — MODIFY (enable Export button + handler)
- src/CcDashboard.Web/wwwroot/app.js — MODIFY ONLY IF no download helper exists (add `window.ccApp.downloadFile`)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (export error/label if new)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)
- DO NOT touch the Schedule button (stays stub), dashboard/shared.

## GROUNDING (object-store v3)
- `ExportReportCommand(Guid ReportId, DateTime From, DateTime To, Guid? TenantId = null) → ReportExportResult(byte[] Content, string FileName, string ContentType)` (CONFIRM the exact record in the tree before coding; from bi 152bed7).
- ReportViewPage: Export button (~:57) currently `disabled title="@L["Reports_ExportStub"]"`. Date range applied to widgets = `_rangeFrom`/`_rangeTo` (set from `_from`/`_to` on apply). The report = `_report` (ReportScreenDetailDto, has `Id`/`TenantId`). `@inject IMediator Mediator`, `@inject IJSRuntime JS`, `@inject ILogger` present (verify).
- A JS download helper may or may not exist (check app.js for `ccApp.downloadFile`/blob download). If absent, add one.

## THE WORK
### A. JS download helper (app.js) — only if not present
Add `window.ccApp = window.ccApp || {}; window.ccApp.downloadFile = function(base64, fileName, contentType){ const bin=atob(base64); const len=bin.length; const bytes=new Uint8Array(len); for(let i=0;i<len;i++) bytes[i]=bin.charCodeAt(i); const blob=new Blob([bytes],{type:contentType}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=fileName; document.body.appendChild(a); a.click(); document.body.removeChild(a); URL.revokeObjectURL(url); };` (or reuse an existing equivalent).
### B. ReportViewPage Export button
1. Replace `disabled` with `disabled="@_exporting"` and add `@onclick="ExportReport"` (drop the `Reports_ExportStub` title; use `@L["Reports_Export"]`). Show a small spinner / "Exporting…" while `_exporting`.
2. Add `private bool _exporting; private string? _exportError;` and:
```csharp
private async Task ExportReport()
{
    if (_report is null || _exporting) return;
    _exporting = true; _exportError = null; StateHasChanged();
    try
    {
        var res = await Mediator.Send(new ExportReportCommand(_report.Id, _rangeFrom, _rangeTo, _report.TenantId), _cts.Token);
        var base64 = Convert.ToBase64String(res.Content);
        await JS.InvokeVoidAsync("ccApp.downloadFile", base64, res.FileName, res.ContentType);
    }
    catch (Exception ex)
    {
        Logger.LogError(ex, "Report export failed for {Id}", _report.Id);
        _exportError = L["Reports_ExportFailed"]; // add resx
    }
    finally { _exporting = false; StateHasChanged(); }
}
```
   - TenantId = `_report.TenantId` (the report's tenant — Superadmin cross-tenant resolves correctly on Prod Mirror; server ignores it for non-SA). From/To = `_rangeFrom`/`_rangeTo` (same range the widgets show).
   - Surface `_exportError` near the button (small text-danger) if set.
3. Schedule button: leave as-is (stub). Do NOT touch.

## VERIFY / DoD (role-shell §A — ⛔ LIVE, NOT object-store)
- **Object-store:** Export button enabled + `@onclick=ExportReport` (no longer `disabled` hardcoded) → `ExportReportCommand(_report.Id, _rangeFrom, _rangeTo, _report.TenantId)` → `ccApp.downloadFile(base64, FileName, ContentType)`; `_exporting` spinner + `_exportError` handling; Schedule untouched; download helper present.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator on Prod Mirror):** open a Prod-Mirror report (019e03e9) → click Export → a `.xlsx` downloads (name = report+range+timestamp), opens with one sheet per widget containing the real data for the view's range/scope; button shows a spinner during; error shows friendly text on failure. Do NOT report without live download confirmation.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `feat(web): reports — wire Export button to ExportReportCommand + .xlsx browser download [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Report Export wired in ReportViewPage: ExportReportCommand(Id, _rangeFrom, _rangeTo, _report.TenantId) → ReportExportResult(byte[]) → ccApp.downloadFile(base64→blob). TenantId=Report.TenantId for cross-tenant export; _exporting spinner; Schedule stays stub (needs backend schedules infra)." SOURCE:<commit> + bi 152bed7. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportViewPage.razor (+app.js/resx) . status done|failed . blockers . verified: object-store (LIVE .xlsx download = operator gate, pending)
```
