# CC TASK — R7: whole-report Export → .xlsx (ClosedXML, one sheet per widget, sync)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless (mechanism review §26.8).
> ⛔ ЧП — no-run-without-bless. Operator FIXED the design: whole report → ONE .xlsx; ONE sheet per tabular widget
> (sheet name = widget title); SYNC download (no IBlobStorage/email). Library = ClosedXML (MIT, free — NOT EPPlus).
> Export = ALL rows for the range/scope (NOT paginated), cap 50 000 rows/sheet (AUD-08). Distribution = its tabular buckets as a sheet.
> Design forks are CLOSED by the operator — this prompt PROPOSES the MECHANISM for §4. Schedule stays a stub. NO push.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short
```
CLAIM (file-mode): src/CcDashboard.Application/HistoricalReports/Queries/RunReportWidgetQuery.cs +
src/CcDashboard.Application/Handlers/RunReportWidgetQueryHandler.cs +
src/CcDashboard.Application/Reports/Export/** (new: IReportExporter + ExportReportCommand + DTOs) +
src/CcDashboard.Infrastructure/Reports/Export/ClosedXmlReportExporter.cs (new) +
src/CcDashboard.Infrastructure/CcDashboard.Infrastructure.csproj (ClosedXML NuGet) +
src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs (DI: IReportExporter) +
tests/CcDashboard.Tests.Unit/** + .claude/skills/role-bi/role-bi.md (§B).
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## MECHANISM (PROPOSAL for §4 — coordinator reviews before run)

### 1. Library + project (clean arch, matches Ф6 plan)
- ClosedXML NuGet → **Infrastructure** (the lib stays out of Application). `IReportExporter` abstraction in **Application**; `ClosedXmlReportExporter` impl in **Infrastructure**. Justification: Application has zero ClosedXML dependency (ARCH dependency rules); swappable later. DI: `services.AddScoped<IReportExporter, ClosedXmlReportExporter>()`.

### 2. Reuse the read path via an ALL-ROWS mode on RunReportWidgetQuery (no logic duplication)
- Add `bool AllRows = false` to `RunReportWidgetQuery` (LAST param, after `Guid? TenantId = null`).
- In each Run*Async (QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail; Distribution already returns all buckets): the full `rows` list is already built BEFORE pagination (handler L~111-113). When `AllRows` → `var resultRows = rows.Take(ExportRowCap).ToList();` (ExportRowCap=50000) instead of the Skip/Take page slice; keep `TotalCount = rows.Count` (so a caller can detect truncation when TotalCount > 50000). Pagination params ignored when AllRows. This reuses ALL existing scope/BU-aggregate/factory-read/cross-tenant logic verbatim — no duplicate query.

### 3. ExportReportCommand (Application/Reports/Export)
```csharp
public record ExportReportCommand(Guid ReportId, DateTime From, DateTime To, Guid? TenantId = null)
    : IRequest<ReportExportResult>, IAuditable;   // IAuditable event = "ReportScreen.Exported" (FLAG — see §6)
public record ReportExportResult(byte[] Content, string FileName, string ContentType);
```
Handler:
- `var isSuperadmin = currentUser.Role == "Superadmin"; var tenantId = isSuperadmin ? (cmd.TenantId ?? currentUser.TenantId!.Value) : currentUser.TenantId!.Value;` (mirror fcf5458/3773f53 — non-SA param IGNORED).
- Load the report: `repo.GetByIdWithWidgetsAsync(cmd.ReportId, bypassTenantFilter: isSuperadmin, ct)` → CROSS-TENANT (reuses the single-load fix 59933bd; 019e03e9). NotFound → friendly error.
- For each non-deleted widget in `screen.Widgets`: `var r = await mediator.Send(new RunReportWidgetQuery(widget.WidgetType, widget.ConfigJson, cmd.From, cmd.To, Page:1, TenantId: cmd.TenantId, AllRows: true), ct);` — extract the per-type Rows (QueueInterval.Rows / QueueWaitTime.Rows / AgentMonthly.Rows / AgentShiftDetail.Rows / Distribution.Buckets), `r.EffectiveColumns`, and the sheet title (ConfigJson title ?? a localized widget-type name).
- Build `IReadOnlyList<WidgetExportSheet>` { Title, Columns(effectiveColumns), Rows(value-arrays aligned to Columns), TotalCount } and call `IReportExporter.ExportXlsxAsync(screen.Name, sheets, ct)`.
- Filename: `{sanitized ReportName}_{From:yyyyMMdd}-{To:yyyyMMdd}_{UtcNow:yyyyMMddHHmmss}.xlsx`; ContentType `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.

### 4. Row→cell projection (generic, no per-type duplication)
The row records' property names == the effectiveColumns keys (e.g. QueueIntervalRow.IntervalStart/Offered/...). Project each typed row to a value array aligned to EffectiveColumns by property-name lookup (cache PropertyInfo per (rowType, column)). Distribution: map Label/Count/Percentage from DistributionBucket. Values typed (DateTime/int/long/double/string) so ClosedXML writes native cell types (numbers/dates), not strings.

### 5. ClosedXmlReportExporter (Infrastructure)
- One `IXLWorksheet` per sheet (name = Title, truncated/sanitised to Excel's 31-char + invalid-char rules). Row 1 = headers (localized columns, see §7). Data rows from §4. Native cell types.
- CAP: write at most 50000 data rows; if `TotalCount > 50000` → add a clearly-marked note row/cell ("Truncated: showing 50000 of {TotalCount}") + `logger.LogWarning`. Return the workbook as `byte[]` (MemoryStream).

### 6. Audit — FLAG (do NOT invent)
There is NO existing report-export audit event type (object-store: no ".Exported"). I PROPOSE `"ReportScreen.Exported"` (consistent with the ReportScreen.* family; EventType is varchar → NO migration, just a new string + add it to the §16 audit-event list in CLAUDE.md docs). Mark ExportReportCommand IAuditable with it. FLAG for the coordinator/operator to ratify the event name (or drop audit for v1).

### 7. Localization of headers — pragmatic
Map each effectiveColumn key → `localizer["Reports.Col.{ColumnName}"]` (IStringLocalizer<SharedResources>), FALLBACK to the raw column name if the resource is absent (so it never blanks). FLAG: not all Reports.Col.* resx keys exist yet → fallback covers it; full localization can be a follow-up.

## CONTRACT FOR SHELL (publish in RESULT)
`ExportReportCommand(Guid ReportId, DateTime From, DateTime To, Guid? TenantId = null) -> ReportExportResult(byte[] Content, string FileName, string ContentType)`. Shell wires the Export button → Send(command) → trigger a browser download of Content as FileName/ContentType. (Coordinator wires shell AFTER this contract lands.)

## ACCEPTANCE (DoD)
1. Build 0 (ClosedXML restores). 2. ExportReportCommand returns a VALID .xlsx with one sheet per tabular widget, REAL data for the range/scope (open it). 3. Cross-tenant Superadmin (019e03e9 + bypassTenantFilter) works; non-SA TenantId ignored. 4. 50k cap holds + truncation marked. 5. R2 factory-read isolation NOT broken (AllRows reuses the same read path). 6. NO migration. 7. NO push. Tests: AllRows returns all rows (capped); exporter writes a sheet per widget with headers+rows; cross-tenant load.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify post-commit. commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `feat: report Export to xlsx (ClosedXML, sheet-per-widget, sync, cross-tenant) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (files, the command contract, build/tests, object-store verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-06-26 · report Export (Ф6): ClosedXML(MIT) in Infra behind IReportExporter(Application); reuse RunReportWidgetQuery with AllRows (cap 50k) — no logic dup; cross-tenant via GetByIdWithWidgetsAsync(bypassTenantFilter:isSuperadmin)+RunReportWidgetQuery(TenantId); sheet-per-widget (cols=effectiveColumns); audit "ReportScreen.Exported" (varchar event, no migration). · SOURCE: coordinator R7 2026-06-26 · status: active`

## DO NOT
- Do NOT use EPPlus v5+ (commercial). Do NOT add ClosedXML to the Application project (Infra only).
- Do NOT duplicate the widget query/aggregation logic — reuse RunReportWidgetQuery(AllRows).
- Do NOT break R2 (read methods stay factory) or the single-load cross-tenant fix. NO migration / NO push.

## FLAGS — RATIFIED by coordinator 2026-06-26 (implement as designed; not open):
(a) Audit `ReportScreen.Exported` = RATIFIED → mark ExportReportCommand IAuditable + ADD the event line to CLAUDE.md §16 audit-event list (Dashboards/Reports section) IN THIS COMMIT. (b) Header localization fallback (raw key when resx absent) = ACCEPTED for v1. (c) ClosedXML in Infrastructure = YES.

## (original flag notes — now resolved)
(a) Audit event name "ReportScreen.Exported" — ratify or drop for v1. (b) Header localization fallback (raw key when resx missing) — accept for v1 or require full Reports.Col.* resx. (c) ClosedXML in Infrastructure vs a dedicated CcDashboard.Reporting project — I recommend Infra (smaller surface); say if you want a separate project.
