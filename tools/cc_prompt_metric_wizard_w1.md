# CC Task W1: MetricWizard standalone component (no configurator wiring yet)

> Stage-2 metrics catalogue — metric-selection wizard. W1 builds the REUSABLE component + a pure
> testable filter + unit tests + localization. It is NOT wired into any widget configurator yet
> (that is W2 pilot). Design approved from mockup: search + facets (category, family, channel,
> threshold) + detail card; pre-filtered by widget MetricType; hides duplicate/deprecated.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (v1.x: phantom-aware S3, S4b post-commit flush, S1 barrier stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md   (§3 conventions, §5 description layers, §8 fields)
Read file: .claude/skills/widget-creator/widget-creator.md   (§16 dark mode, §18 searchable dropdowns, §30/L-36 draggable modal, L-34 localization verify)
Only after reading all three: proceed.

## Git push
Do NOT run `git push`. Commit only (§37).

## BARRIER CHECK (S1) — HARD STOP
If `.coord/push/request.md` has content (content-based, L-SC-10), a push barrier is ACTIVE → STOP, do
nothing, report "barrier active". Only proceed when it is absent/empty.

## Claims (file-mode, metrics-0605) — all NEW files except the 3 shared .resx
- web:  src/CcDashboard.Web/Components/Shared/MetricWizard.razor
        src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css
        src/CcDashboard.Web/Resources/SharedResources.en-US.resx (+ ru-RU, he-IL) — shared; if a
        REQUEST/GRANT in .coord/queue.md or another active session holds them, §9-queue first.
- app:  src/CcDashboard.Application/Services/Metrics/MetricCatalogFilter.cs
- tests: tests/CcDashboard.Tests.Unit/Metrics/MetricCatalogFilterTests.cs
> Do NOT touch ScreenEditorPage.razor or any widget .razor (that is W2). Do NOT touch any daytrend-claimed file.

## Step 0 — §0.6a integrity + post-push sync (§42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin 2>&1 | tail -1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/v2)" && echo "HEAD==origin/v2 OK" || echo "DIVERGED - reconcile"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l < "$f" 2>/dev/null)
  if [ $((H-W)) -gt 0 ]; then git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync
```
Then the coord sync block from `tools/cc_prompt_sync_block.md` (slug + claims; phantom-aware S3).

**Review note (coordinator §4):** SharedResources.{en-US,ru-RU,he-IL}.resx are SHARED and may show false-M at start. BEFORE editing each, confirm `git hash-object <f>` == `git rev-parse HEAD:<f>` (if equal = false-M, leave as is; do NOT restore-truncate a clean file). Add new keys ADDITIVELY (append <data> entries), never rewrite the file. Run coord_check_claims on ALL claimed paths INCLUDING the 3 resx; §9-queue only if another active session claims them meanwhile.

## Data source
Metrics come from `GetRtsGridMetricsQuery` (already returns the 12 catalogue fields after D3b:
DisplayName, ShortDescription, LongDescription, Comparison, StandardKpi, StandardRef, CatalogCategory,
Family, Channel, ThresholdSec, CatalogStatus, CatalogNotes). Inject `IMediator`, query once on open.

## Deliverable 1 — Pure filter  `MetricCatalogFilter.cs` (Application/Services/Metrics)
Pure, UI-free, fully unit-testable. No EF, no MediatR.
```csharp
public record MetricFilterCriteria(string? MetricType, string? Category, string? Family,
    string? Channel, int? ThresholdSec, string? Search);

public static class MetricCatalogFilter
{
    // DisplayName ?? Description ?? MetricId
    public static string Label(RtsGridMetricDto m) => ...;
    // Excludes CatalogStatus in {"duplicate","deprecated"} ALWAYS.
    // Applies MetricType pre-filter (Agent|Data|null), then Category/Family/Channel/ThresholdSec,
    // then Search (case-insensitive over Label + ShortDescription + StandardKpi + Family).
    public static IReadOnlyList<RtsGridMetricDto> Apply(IReadOnlyList<RtsGridMetricDto> all, MetricFilterCriteria c);
    // Facet option helpers over the CURRENT pool (after MetricType+Category):
    public static IReadOnlyList<string> Families(IReadOnlyList<RtsGridMetricDto> pool);
    public static IReadOnlyList<string> Channels(IReadOnlyList<RtsGridMetricDto> pool); // non-null only
    public static IReadOnlyList<int> Thresholds(IReadOnlyList<RtsGridMetricDto> pool);   // non-null, sorted
    public static bool IsDefect(RtsGridMetricDto m) => m.CatalogStatus == "defect-candidate";
}
```

## Deliverable 2 — Component  `MetricWizard.razor` (Components/Shared)
Parameters:
```csharp
[Parameter] public string? MetricTypeFilter { get; set; }   // "Agent" | "Data" | null
[Parameter] public string? CurrentMetricId { get; set; }    // preselect
[Parameter] public bool DarkMode { get; set; }
[Parameter] public bool Visible { get; set; }
[Parameter] public EventCallback<string> OnSelected { get; set; }  // returns chosen MetricId
[Parameter] public EventCallback OnCancel { get; set; }
```
Behaviour (mirror the approved mockup):
- On first open (Visible true): query metrics, apply MetricTypeFilter, preselect CurrentMetricId.
- Layout: header (title + close) · search input (ti-search) · category chips (All + the categories
  present in the pool, with counts) · three searchable `<select>`s Family / Channel / Threshold
  (Channel & Threshold disabled when the pool has none, §18) · two columns: result list (Label +
  "Category · KPI" subline) | detail card · footer (Cancel + "Use this metric").
- Detail card: status dot, Label, ShortDescription, taxonomy chips (Category, Family, Channel?, Threshold?),
  LongDescription, a "Related fields / how it differs" box (Comparison), KPI + StandardRef, MetricId in
  mono small. For `defect-candidate` show an amber warning row (still selectable).
- "Use this metric" → `OnSelected.InvokeAsync(chosen.MetricId)`. Cancel/close → `OnCancel`.
- Reuse Components/Shared building blocks where they fit (AppModal/AppBadge/AppButton/AppEmptyState) —
  inspect them first; if AppModal supports a header + custom body, use it, else self-contained modal.
- **Draggable by header** (L-36): call `ccApp.makeModalDraggable` in OnAfterRenderAsync when Visible;
  reset on close.
- **Dark mode** (§16): use CSS variables / Effective colours; works in both modes.
- **Localization** (L-34): ALL chrome labels via `@L["..."]` (MetricWizard_Title, _Search, _Family,
  _Channel, _Threshold, _AnyChannel, _AnyThreshold, _Use, _Cancel, _NoMatch, _Related, _Defect,
  Common_All if it exists else MetricWizard_AllCategories). Add keys to en-US, ru-RU, he-IL with EXACT
  matching names; then run the L-34 verification (grep @L keys vs <data name>, comm -23 empty).
  Metric content (DisplayName, Family, KPI, descriptions) is catalogue DATA — do NOT translate.
- Category display labels: "Queue", "Agent Group", "Agent" (platform terms, may stay literal or be keys —
  your call, but keep L-34 consistent).

## Deliverable 3 — Tests  `MetricCatalogFilterTests.cs` (Tests.Unit)
Cover with a small in-memory DTO list:
- MetricType pre-filter (Agent vs Data) excludes the other.
- duplicate/deprecated always excluded; defect-candidate retained + IsDefect true.
- Category / Family / Channel / ThresholdSec narrowing.
- Search matches Label, ShortDescription, StandardKpi (case-insensitive); no match → empty.
- Label fallback: DisplayName → Description → MetricId.
- Facet helpers return distinct, sorted (thresholds) values over the pool.
Run: `dotnet test tests/CcDashboard.Tests.Unit --filter "FullyQualifiedName~MetricCatalogFilter"`. All green before commit.

## Build & commit
- Stop dotnet (widget-creator §28) → `dotnet build CcDashboard.sln` clean.
- Commits (lock §42.4; §39.3):
  * `web: MetricWizard reusable component (search + taxonomy facets + detail card)`
  * `web: MetricCatalogFilter pure filter + SharedResources keys`  (or fold into one web: commit)
  * `test: MetricCatalogFilter unit tests`
  Each: pre-commit-check → §0.6 verify → journal → S4b post-commit flush to coordinator.md → release lock → PD-007 re-sync. No push.

## Acceptance criteria
1. `dotnet build CcDashboard.sln` clean; no widget/ScreenEditorPage files touched.
2. MetricCatalogFilter unit tests green (filter ~MetricCatalogFilter).
3. Component compiles and is self-contained (not yet referenced by any configurator — that is intended).
4. Hides duplicate/deprecated; defect-candidate shown with warning; MetricType pre-filter works.
5. Draggable header; dark-mode safe; L-34 localization verification passes (3 .resx, no raw keys).
6. Commits per module; tree clean (ignore known false-M); journal + S4b per commit; lock released; no push.
