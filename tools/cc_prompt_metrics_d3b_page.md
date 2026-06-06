# CC Task D3b: MetricsPage catalogue read/edit + DTO/query/commands + UUIDv7-dashless ADD

> Stage-2 metrics catalogue, UI layer. Builds on D3a (12 catalogue columns already on RtsGridMetric,
> backfilled). Surfaces & edits the catalogue card in the admin Metrics page; new metrics get a
> server-generated UUIDv7-dashless MetricId. Design locked with operator (all-in-DB, editable page).

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (v1.4: phantom-aware S3, S4b post-commit flush)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md   (§3 conventions, §10 fields)
Read file: .claude/skills/widget-creator/widget-creator.md   (§18 searchable dropdowns, L-34 localization key verify)
Only after reading all three: proceed.

## Git push
Do NOT run `git push`. Commit only (§37).

## Claims for this session (file-mode, metrics-0605)
- web: src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs,
       src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs,
       src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs,
       src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor
- tests: tests/CcDashboard.Tests.Security/Configuration/RtsGridMetricCatalogueTests.cs (new)
> Do NOT touch NavMenu.razor / Program.cs / RtsEntities.cs (route + DI already exist; if you find you
> need them, STOP and request via §9 queue — daytrend may hold web files). Do NOT touch any
> daytrend-claimed file. Do NOT touch the entity/migration (D3a, done).

## Step 0 — §0.6a integrity block + post-push sync (§42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin 2>&1 | tail -1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/v2)" && echo "HEAD==origin/v2 OK" || echo "DIVERGED - STOP, reconcile"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l); W=$(wc -l < "$f" 2>/dev/null)
    if [ $((H-W)) -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync
# Recurring mount truncation: db/data/02_metrics.sql, db/schema.sql, tools/lint_metrics.py, and large .cs.
# Verify hash (git hash-object vs git rev-parse HEAD:<f>) before "restoring"; known false-M on db/*.sql.
```
Then the coord sync block from `tools/cc_prompt_sync_block.md` (running slug + claims above; phantom-aware S3).

## Catalogue fields (the 12 D3a columns) — carry through all layers
DisplayName, ShortDescription, LongDescription, Comparison, StandardKpi, StandardRef (editorial);
CatalogCategory, Family, Channel, ThresholdSec(int?), CatalogStatus, CatalogNotes (taxonomy+lifecycle).

## Deliverable 1 — DTO (ConfigurationDtos.cs)
Append the 12 fields to BOTH records (all nullable; ThresholdSec int?):
- `RtsGridMetricDto` — add the 12 (after MetricType).
- `SaveRtsGridMetricRequest` — add the 12 (keep existing fields + IsNew). For ADD, MetricId from the
  client is IGNORED (server generates) — keep the param for the record shape but the handler overrides it.

## Deliverable 2 — Query (ConfigurationQueries.cs)
`GetRtsGridMetricsQuery` handler: project the 12 new columns from RtsGridMetric into RtsGridMetricDto.

## Deliverable 3 — Command (ConfigurationCommands.cs)
`SaveRtsGridMetricCommandHandler`:
- ADD branch: `using UUIDNext;` → `var newId = Uuid.NewSequential().ToString("N");` (UUIDv7, 32 hex, NO
  dashes — REQUIRED: engine Calc does Replace("-"," - ") which corrupts dashed ids, rtm-metrics-expert §2/§12).
  Use newId as MetricId (ignore req.MetricId). Set all 12 catalogue fields from req.
- EDIT branch: set all 12 catalogue fields on the loaded entity (MetricId stays the PK, never changed).
- Keep existing operational-field handling and the apiHook call.
- Trim string fields; CatalogStatus default "active" if null on ADD.

## Deliverable 4 — Page (MetricsPage.razor)
The page is **editable** (Superadmin-only, already). Changes:
- ADD modal: REMOVE the hand-typed MetricId input (server generates UUIDv7-dashless). Show a read-only
  note "ID auto-generated" instead. Keep MetricId read-only display on EDIT (already disabled).
- Add inputs for the 12 catalogue fields, grouped "Catalogue" section in the modal:
  * DisplayName, ShortDescription — text inputs
  * LongDescription, Comparison, CatalogNotes — textareas
  * StandardKpi, StandardRef, Family, Channel — text inputs
  * CatalogCategory — select (Queue | AgentGroup | Agent)
  * CatalogStatus — select (active | duplicate | deprecated | defect-candidate)
  * ThresholdSec — number input
- List table: add a "Name" column showing DisplayName (fallback to Description).
- All visible labels via `@L["..."]` — after adding keys to ALL .resx, run L-34 key-verification
  (grep @L keys in .razor vs <data name> in SharedResources.en-US.resx; comm -23 must be empty).
- Localization: add keys Metrics_DisplayName, Metrics_ShortDescription, Metrics_LongDescription,
  Metrics_Comparison, Metrics_StandardKpi, Metrics_StandardRef, Metrics_CatalogCategory, Metrics_Family,
  Metrics_Channel, Metrics_ThresholdSec, Metrics_CatalogStatus, Metrics_CatalogNotes, Metrics_IdAutoGenerated
  to en-US, ru-RU, he-IL (exact key match, L-34).

## Deliverable 5 — Tests (L-38, mandatory)
New `tests/CcDashboard.Tests.Security/Configuration/RtsGridMetricCatalogueTests.cs`:
- ADD generates a MetricId that is 32 lowercase hex chars, NO dashes (Regex ^[0-9a-f]{32}$), and ignores any client-supplied MetricId.
- ADD persists all 12 catalogue fields.
- EDIT updates catalogue fields without changing MetricId.
- (if feasible) duplicate-id guard still works.
Run: `dotnet test tests/CcDashboard.Tests.Security --filter "FullyQualifiedName~RtsGridMetricCatalogue"`.
All green before commit; fix implementation (not tests) on failure.

## Build & commit
- Stop dotnet processes (widget-creator §28) → `dotnet build CcDashboard.sln` clean.
- Commits (lock per §42.4; §39.3):
  * `web: RtsGridMetric catalogue fields in DTO/query/command + MetricsPage edit + UUIDv7-dashless ADD`
  * `test: RtsGridMetric catalogue + UUID-dashless generation tests`
  Each: pre-commit-check → §0.6 post-commit verify → journal → **S4b post-commit flush to coordinator.md**
  (commit hash, claims releasable, blocker, next) → release lock → PD-007 re-sync. No push.

## Notes / caveats (state in completion report, do not act on)
- Catalogue fields are Shell-only (live for Viewer/wizard immediately). Editing operational fields
  (MetricFunction/Parameter/etc.) still needs an RTM Service restart to activate and Export-All to
  version into db/data/02_metrics.sql — until the hot-reload stage. Mention in the report; do NOT
  add restart/export logic here.
- Do NOT run Export-All in this task (no metric DATA change; only code).

## Acceptance criteria
1. `dotnet build CcDashboard.sln` clean.
2. GET returns the 12 catalogue fields; page shows/edits them; ADD modal has no MetricId input.
3. ADD persists with a server-generated 32-hex dashless MetricId (verify in DB + test).
4. EDIT updates catalogue fields; MetricId unchanged.
5. Tests green (filter RtsGridMetricCatalogue).
6. L-34 localization key verification passes (no raw keys in UI; all 3 .resx have the new keys).
7. Two commits (web:, test:); tree clean (ignore known false-M); journal + S4b flush per commit; lock released; no push.
