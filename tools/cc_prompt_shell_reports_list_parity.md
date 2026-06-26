# CC task — ReportsListPage parity (+New / Reports-Trash tabs / Settings gear) + HARD-DEL-01c reports purge icon (role-shell) — §4-PASS R2 (coordinator-0624) — CLEARED TO RUN
> Operator parity audit (2026-06-25, screenshots): Reports list is missing vs Dashboards list — (1) the "+" on the New button, (2) the Reports/Trash tabs, (3) the per-row Settings gear (with a settings modal). Make ReportsListPage mirror ScreenListPage. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). Parity-guard: ZERO edits to ScreenListPage.razor / existing shared app.css selectors.

## ✅ BACKEND LANDED — bind these exact signatures (no gate)
- Trash list (A, v3 `63e46b1`): `GetDeletedReportScreensQuery(string? Search, int Page = 1, int PageSize = 25) : IRequest<PagedResult<DeletedReportScreenDto>>`; `DeletedReportScreenDto(Guid Id, string Name, string? Description, DateTime DeletedAt, string? DeletedByName, int DaysUntilPermanentDelete)`. Mirrors GetDeletedDashboards.
- Restore: existing `RestoreReportScreenCommand(Guid Id)`. **UX note:** a restored report's schedules stay INACTIVE (user re-enables) — surface this near the Restore action (small hint/tooltip).
- Hard-delete (HARD-DEL-01c, v3 `f343b43`): `PurgeReportScreenCommand(Guid Id) : IRequest` — permanent cascade delete; throws NotFound (not in Trash) / DomainException (not IsDeleted) / Forbidden (lacks Delete&4, non-Superadmin). Server-enforced perm (CODE-03) — show the icon per row, server is the gate.

## INIT — branch v3 + role-shell §A/§C + §40 + integrity. §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push.

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Reports/ReportsListPage.razor (MODIFY)
- 3x Resources/SharedResources.{en-US,ru-RU,he-IL}.resx (Reports_New value + new Trash/Settings strings)
- src/CcDashboard.Web/wwwroot/app.css (additive ONLY if needed — nav-tabs are Bootstrap) ; App.razor (?v if css changed)
- (role-shell.md via git add -f if CAPTURE)
- ZERO edits to ScreenListPage.razor / existing shared app.css selectors.

## THE MODEL TO MIRROR (object-store v3 — ScreenListPage.razor)
- **"+ New"**: dashboard button text = `@L["Screens_New"]` whose resx VALUE = "+ New Dashboard". Reports `Reports_New` value = "New report" (no +). → change `Reports_New` VALUE to "+ New report" (en) / "+ Новый отчёт" (ru) / he equivalent. (Same mechanism as dashboards — the + is in the resx string.)
- **Tabs** (`<ul class="nav nav-tabs mb-3">`): Reports tab (`ActiveTab=="screens"`→"reports") + Trash tab (`bi-trash3` + `@L["Reports_Trash"]` + count badge `DeletedReports?.TotalCount`). SwitchTab("reports"/"trash") loads the matching list. Mirror ScreenListPage lines ~30-42 + the trash table (Name / DeletedAt / DeletedBy / **Restore** `bi-arrow-counterclockwise` → RestoreReportScreenCommand + **Hard-delete** `bi-trash3` → PurgeReportScreenCommand behind a MANDATORY confirmation dialog: "Permanently delete — cannot be undone") + trash empty-state + trash pagination + the retention info line (DaysUntilPermanentDelete per row).
- **Settings gear**: in the row ACTIONS, mirror dashboard's three icons: View (`bi-eye`→/reports/{id}), Edit (`bi-pencil`→/reports/{id}/edit, AccessLevel&Edit; note Ф5b-2 lands the editor — until then it 404s, keep per slice order), **Settings (`bi-gear`)→OpenEdit(r)** opening a settings modal.
- **Settings modal** (mirror ScreenListPage Edit modal, lines ~364-426): Name* / Description / Category (GetReportCategories) / Status (Draft|Published) / IsPublic checkbox + Danger-Zone Delete (`DeleteReportScreenCommand`, confirm-inline). Save → `UpdateReportScreenCommand`. All over EXISTING Ф5a commands.
- **Create modal** (mirror OpenCreate): "+ New report" opens a Create modal (Name*/Description/Category/IsPublic) → `CreateReportScreenCommand`. POST-CREATE: reload the list (do NOT navigate to /reports/{id}/edit — the editor is Ф5b-2, would 404). (This also fixes the current create→404 flow.) Confirm with operator only if ambiguous; default = reload list + toast/highlight new row.

## THE WORK
- Add ActiveTab state + SwitchTab; load GetReportScreensQuery (reports tab) and GetDeletedReportScreensQuery (trash tab, bi Ф5a.2). 
- Row actions: View + Edit + Settings(gear). Settings → OpenEdit modal (Update/Delete). 
- "+ New report" → Create modal (Create) → reload list.
- Trash table + Restore (RestoreReportScreenCommand) + **Hard-delete (PurgeReportScreenCommand) behind a confirmation modal (mandatory; "cannot be undone")** + count badge + empty-state + retention info (use DTO DaysUntilPermanentDelete). Restore UX: hint that schedules stay inactive after restore.
- @L all new strings en/ru/he (Reports_Trash, Reports_Settings, Reports_EditModal, Reports_DeletedAt, Reports_DeletedBy, Reports_Restore, Reports_TrashEmpty, Reports_DangerZone, Reports_HardDelete, Reports_HardDeleteConfirm, Reports_PermanentWarning, etc — reuse Common_*/Screens_* where identical). RTL; a11y (tab roles, modal focus-trap, th scope). Dark/light.

## OUT OF SCOPE: ReportEditorPage (Ф5b-2); export/schedule (Ф6/Ф7).

## VERIFY / DoD (role-shell §A)
- Object-store: Reports_New value has "+"; nav-tabs Reports/Trash present; Trash binds GetDeletedReportScreensQuery + Restore + Hard-delete(PurgeReportScreenCommand) w/ confirm; row has bi-gear→settings modal (Update/Delete); Create modal→CreateReportScreenCommand (no /edit nav); ScreenListPage + shared selectors UNTOUCHED; @L 3 locales.
- **Soma: bring host up via /shell/start|restart (NOT /ops/build against live watch — lesson 2026-06-25); confirm compile by healthy start + live render; serilog [ERR]/[FTL] clean.**
- **VISUAL CHROME (light+dark):** /reports shows "+ New report", Reports/Trash tabs (switch works, Trash lists deleted + Restore + Hard-delete w/ confirmation dialog), row gear opens settings modal. + parity: /screens list byte-identical.

## §0.6b CAPTURE -> role-shell §B if real lesson. Commit fix:, NO push, commit.lock. Binding RESULT -> cc/shell.md. Report: commit, files, build/serilog, screenshots light+dark, parity confirm.
