# CC Task L1-C: translation-edit UI in MetricsPage (DB-direct + export-to-JSON round-trip)

> Operator decision (2026-06-07): translations are edited LIVE in the admin UI, written straight to
> RTSGrid_MetricTranslation (same pattern as the existing SaveRtsGridMetricCommand for metrics), AND a
> dev tool exports DB -> docs/metrics-catalog.<locale>.json so the JSON source-of-truth stays in sync
> (a future re-seed/Restore-All would otherwise overwrite live edits). Variant A.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md  (phantom-aware S3, S4b wrapper, S1 hard-stop, L-SC-09 same-file)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (metric/translation data contract, DisplayName vs Description)
Read file: .claude/skills/blazor-frontend-design/SKILL.md  (Blazor edit UI, RTL he-IL, a11y)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP.

## Claims (file-mode, metrics-2-0607)
- web:  src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor   (already mine)
- app:  src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs
        src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs
- contracts: src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs
- domain: src/CcDashboard.Domain/Interfaces/INgcRepositories.cs
- infra: src/CcDashboard.Infrastructure/Persistence/Repositories/NgcRepositories.cs
- tools: tools/export_translations_from_db.py   (NEW)
- tests: tests/CcDashboard.Tests.Unit/Commands/Configuration/SaveMetricTranslationCommandHandlerTests.cs (NEW)
> Run coord_check_claims on ALL of the above FIRST (S2). test-5-0607 holds the 3 SharedResources resx +
> ScreenEditorPage + MetricWizard + app.css — DO NOT TOUCH ANY of those (L-SC-09 lost-update).
> ==> Therefore: DO NOT add new .resx keys in this task (see Deliverable 4 i18n constraint).
> No EF migration: RTSGrid_MetricTranslation already exists (L1-A + the 20260607_001 migration);
> editing rows = data only = no schema change = no BackendEmulation snapshot change.

## Step 0 — §0.6a integrity + git fetch (§42.7.6) + coord sync block (slug + claims).

## Deliverable 1 — Application: upsert + delete a metric translation
In ConfigurationCommands.cs MIRROR the existing SaveRtsGridMetricCommand/Handler pattern exactly
(ITransactional + IAuditable, Result return, DI of IRtsGridMetricRepository + IUnitOfWork):
- `record SaveMetricTranslationCommand(SaveMetricTranslationRequest Request) : IRequest<Result>, ITransactional, IAuditable`
  Request fields: MetricId, Locale (ru-RU|he-IL), DisplayName?, ShortDescription?, LongDescription?, Comparison?.
  Validate: MetricId exists (repo.GetByIdAsync); Locale in the supported set; empty string -> NULL (so EN-fallback works).
  Upsert into RTSGrid_MetricTranslation (composite PK MetricId+Locale): if row exists update fields else add.
  Audit event: reuse the metric-config audit type used by SaveRtsGridMetricCommand (or a new
  `MetricTranslation.Saved` if the family already has per-type names — match the existing convention, don't invent loosely).
- `record DeleteMetricTranslationCommand(string MetricId, string Locale) : IRequest<Result>, ITransactional, IAuditable`
  Delete the row if present (idempotent). Audit `MetricTranslation.Deleted` (or matching convention).
- FluentValidation validators if the metric commands have them (mirror).

## Deliverable 2 — Domain interface + Infra repo
INgcRepositories.cs (IRtsGridMetricRepository): add
  `Task<RtsGridMetricTranslation?> GetTranslationAsync(string metricId, string locale, CancellationToken ct = default);`
  `Task UpsertTranslationAsync(RtsGridMetricTranslation t, CancellationToken ct = default);`
  `void DeleteTranslation(RtsGridMetricTranslation t);`
NgcRepositories.cs (RtsGridMetricRepository, uses BackendEmulationDbContext): implement them
(tracked query for upsert/delete; AsNoTracking for GetTranslation reads is fine). Keep style consistent with the file.

## Deliverable 3 — Query: load all locales for one metric (for the editor)
ConfigurationQueries.cs: add `GetMetricTranslationsQuery(string MetricId) : IRequest<IReadOnlyList<MetricTranslationDto>>`
+ handler returning one row per supported locale (existing rows + empty placeholders for missing locales so the editor
shows all locales). Add `record MetricTranslationDto(string MetricId, string Locale, string? DisplayName,
string? ShortDescription, string? LongDescription, string? Comparison)` in ConfigurationDtos.cs.

## Deliverable 4 — MetricsPage UI: per-metric translation editor
In MetricsPage.razor add a "Translations" action per metric row (button/icon) opening an edit panel/modal:
- For each supported locale (ru-RU, he-IL) show editable fields: DisplayName, ShortDescription, LongDescription, Comparison.
  (en-US is the metric's own Description/DisplayName — NOT in this table; show it READ-ONLY as reference.)
- Load via GetMetricTranslationsQuery(metricId); Save per-locale via SaveMetricTranslationCommand;
  a "Clear locale" -> DeleteMetricTranslationCommand. On save: refresh and show success/concurrency errors like the
  existing metric Save flow.
- he-IL fields must render RTL (App.razor sets dir by culture; the input values are he text — ensure no layout break).
i18n CONSTRAINT (HARD): test-5-0607 holds all 3 .resx — DO NOT add or edit any .resx key here.
  Use ONLY existing SharedResources keys (search the resx; reuse Common_Save/Common_Cancel/Common_Close/etc.).
  For labels with no existing key, use a neutral existing key OR a plain literal, and add a
  `<!-- TODO L1-C-i18n: localise after test-5 releases resx -->` note. A follow-up task localises them once resx is free.

## Deliverable 5 — Export tool (DB -> JSON round-trip)
tools/export_translations_from_db.py (NEW): the REVERSE of tools/gen_translation_backfill.py.
- Connect to the DB (reuse the connection-arg style of other tools/*.py in this repo; accept --password / --conn).
- Read RTSGrid_MetricTranslation for each locale in {ru-RU, he-IL}.
- Merge into docs/metrics-catalog.<locale>.json (update displayName/shortDescription/longDescription/comparison per
  MetricId; preserve other fields/structure; stable key order so git diff is clean).
- Print a summary (rows exported per locale, files written). Idempotent. Document at the top the WORKFLOW:
  edit in UI (DB) -> run this tool -> regenerate db/data/05 via gen_translation_backfill.py -> commit JSON + 05.
  (This tool is run in DEV; it does NOT touch the DB and only WRITES the JSON files.)

## Tests
SaveMetricTranslationCommandHandlerTests.cs: insert-path (no existing row -> added) and update-path
(existing row -> fields updated; empty string -> NULL). Mirror SaveRtsGridMetricCommandHandlerTests style.

## Build & verify
- Stop dotnet (§28) -> `dotnet build CcDashboard.sln` clean -> `dotnet test tests/CcDashboard.Tests.Unit` green.
- Manual (report): open /admin/configuration/metrics, edit a ru-RU DisplayName, save, reopen -> persisted;
  the MetricWizard/configurator now shows the edited ru-RU DisplayName (live from DB). he-IL renders RTL.
- Run `python3 tools/export_translations_from_db.py --password <pw>` (report: rows exported, JSON diff sane).
  (Do NOT commit JSON/db/data/05 in THIS task unless the operator asks — the export round-trip is a separate
  dev step; this task delivers the capability, not a data refresh.)

## Commit (one web: + dependents in a single commit, OR split web/app — keep to ONE commit set under the lock)
`web: L1-C metric translation editor (DB-direct upsert + export-to-JSON tool)`
(MetricsPage.razor, ConfigurationCommands.cs, ConfigurationQueries.cs, ConfigurationDtos.cs,
 INgcRepositories.cs, NgcRepositories.cs, tools/export_translations_from_db.py, the new test)
S3 lock -> pre-commit-check -> git add (claimed files only; new files explicit) -> commit -> §0.6 verify ->
`bash tools/cc_post_commit.sh metrics-2-0607 $(git log -1 --format=%h)` -> sync. No push.

## Acceptance criteria
1. dotnet build clean; unit tests green (insert + update paths).
2. SaveMetricTranslationCommand upserts; DeleteMetricTranslationCommand idempotent; both audited + transactional.
3. MetricsPage shows a per-metric translation editor (ru-RU + he-IL editable, en-US read-only ref); edits persist to DB
   and are visible in the wizard/configurator live.
4. NO .resx changed (test-5 owns them); no new EF migration; no Export-All; no JSON/05 data commit.
5. tools/export_translations_from_db.py reverses gen_translation_backfill.py (DB -> JSON), idempotent, documented workflow.
6. he-IL editor renders RTL without breakage.
7. One commit; tree clean (ignore known false-M); journal + S4b via wrapper; lock released; no push.
