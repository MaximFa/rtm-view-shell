# CC Task L1-A: catalogue localization machinery (RtsGridMetricTranslation + localized query)

> Stage-2 localization, machinery layer. Adds a per-locale translation table for catalogue text and
> makes GetRtsGridMetricsQuery return localized values (CurrentUICulture) with ENGLISH FALLBACK.
> No translation DATA yet (that is L1-B) — until rows are seeded, ru/he fall back to English, nothing breaks.
> Decisions LOCKED by operator: locales ru-RU + he-IL (en-US = base/fallback); translate DisplayName,
> ShortDescription, LongDescription, Comparison; keep MetricId/Family/Channel/CatalogCategory/StandardKpi/
> StandardRef canonical English.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (phantom-aware S3, S4b flush, S1 hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md   (§8 fields; catalogue is in BackendEmulationDbContext)
Read file: .claude/skills/widget-creator/widget-creator.md   (§24.x EF/migration notes; I18N from CLAUDE.md §22/§29.1)
Only after reading all three: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP. (Note: a known phantom request.md may
## linger on the Cowork mount; on the Windows/CC side it reflects the real state — trust the real FS.)

## Claims (file-mode, metrics-0605)
- web: src/CcDashboard.Domain/Domain/RtsGridMetricTranslation.cs (NEW)
       src/CcDashboard.Domain/Interfaces/INgcRepositories.cs (extend IRtsGridMetricRepository)
       src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs (DbSet + mapping)
       src/CcDashboard.Infrastructure/Persistence/Repositories/NgcRepositories.cs (RtsGridMetricRepository)
       new migration under src/CcDashboard.Infrastructure/Migrations/BackendEmulation/
       src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs (GetRtsGridMetricsQueryHandler)
       src/CcDashboard.Application/Services/Metrics/MetricLocalization.cs (NEW pure coalesce helper)
- tests: tests/CcDashboard.Tests.Unit/Metrics/MetricLocalizationTests.cs (NEW)
> Do NOT touch MetricsPage.razor (translation EDITING UI is L1-C, later). Do NOT touch ScreenEditorPage or
> any daytrend-claimed file. Do NOT change RtsGridMetricDto shape (the 4 fields already exist — only their VALUES become localized).

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block (slug + claims above; phantom-aware S3).

## Key facts (verified)
- Catalogue entity RtsGridMetric is mapped in BackendEmulationDbContext (table "RTSGrid_Metric", PK MetricId).
- Repo: RtsGridMetricRepository(BackendEmulationDbContext db) : IRtsGridMetricRepository in NgcRepositories.cs.
- Handler: GetRtsGridMetricsQueryHandler(IRtsGridMetricRepository repo) — currently culture-unaware.
- Migration context: BackendEmulationDbContext -> Migrations/BackendEmulation/.

## Deliverable 1 — Entity  src/CcDashboard.Domain/Domain/RtsGridMetricTranslation.cs
```csharp
namespace CcDashboard.Domain.Domain;
public class RtsGridMetricTranslation
{
    public string MetricId { get; set; } = string.Empty;   // FK -> RTSGrid_Metric
    public string Locale  { get; set; } = string.Empty;     // BCP-47, e.g. "ru-RU", "he-IL"
    public string? DisplayName { get; set; }
    public string? ShortDescription { get; set; }
    public string? LongDescription { get; set; }
    public string? Comparison { get; set; }
}
```
Cross-tenant (catalogue is platform-wide — no TenantId, no GQF), like RtsGridMetric.

## Deliverable 2 — Mapping (BackendEmulationDbContext.cs)
Add `public DbSet<RtsGridMetricTranslation> RtsGridMetricTranslations => Set<RtsGridMetricTranslation>();`
and:
```csharp
mb.Entity<RtsGridMetricTranslation>(e =>
{
    e.ToTable("RTSGrid_MetricTranslation");
    e.HasKey(x => new { x.MetricId, x.Locale });      // composite PK
    e.Property(x => x.MetricId).HasMaxLength(100);
    e.Property(x => x.Locale).HasMaxLength(10);
    e.Property(x => x.DisplayName).HasMaxLength(200);
    e.Property(x => x.ShortDescription).HasMaxLength(500);
    e.Property(x => x.LongDescription).HasColumnType("text");
    e.Property(x => x.Comparison).HasColumnType("text");
});
```

## Deliverable 3 — EF migration (BackendEmulationDbContext)
`dotnet ef migrations add AddRtsGridMetricTranslation --context BackendEmulationDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web`
Review Up() creates the table with composite PK; Down() drops it.

## Deliverable 4 — Pure coalesce helper  MetricLocalization.cs (Application/Services/Metrics)
```csharp
public static class MetricLocalization
{
    // Returns a localized copy: for the 4 translatable fields, use translation value when non-empty,
    // else fall back to the base (English). All other fields unchanged.
    public static RtsGridMetricDto Apply(RtsGridMetricDto base_, RtsGridMetricTranslation? tr);
}
```
Fallback rule per field: `!string.IsNullOrWhiteSpace(tr?.X) ? tr.X : base.X`.

## Deliverable 5 — Repo + handler (localized read)
- Extend `IRtsGridMetricRepository` with:
  `Task<IReadOnlyList<(RtsGridMetric Metric, RtsGridMetricTranslation? Translation)>> GetAllWithTranslationAsync(string locale, CancellationToken ct = default);`
  Impl: LEFT JOIN RtsGridMetricTranslations on MetricId where Locale == locale; AsNoTracking.
  (Keep existing GetAllAsync for callers that don't localize.)
- `GetRtsGridMetricsQueryHandler.Handle`: read `var locale = System.Globalization.CultureInfo.CurrentUICulture.Name;`
  -> `repo.GetAllWithTranslationAsync(locale, ct)` -> map each to RtsGridMetricDto then `MetricLocalization.Apply(dto, tr)`.
  For en-US (or any locale with no rows) it naturally returns base English (fallback). Do NOT special-case en.

## Deliverable 6 — Tests  MetricLocalizationTests.cs (Tests.Unit)
- translation present (all 4) -> localized values used.
- translation null -> base used.
- partial translation (e.g. only ShortDescription) -> that field localized, others fall back.
- non-translatable fields (Family, StandardKpi, MetricId, Channel, CatalogCategory) NEVER change.
Run: `dotnet test tests/CcDashboard.Tests.Unit --filter "FullyQualifiedName~MetricLocalization"`. All green.

## Build & commit
- Stop dotnet (§28) -> `dotnet build CcDashboard.sln` clean.
- Commits (lock §42.4; §39.3):
  * `web: RtsGridMetricTranslation entity + EF migration + localized GetRtsGridMetricsQuery (L1-A)`
  * `test: MetricLocalization coalesce/fallback tests`
  Each: pre-commit-check -> §0.6 verify -> journal -> S4b post-commit flush to coordinator -> release lock -> PD-007 re-sync. No push.
- Do NOT run Export-All (no DATA yet; L1-B seeds translations).

## Acceptance criteria
1. dotnet build clean; migration in Migrations/BackendEmulation/ (composite PK MetricId+Locale).
2. GetRtsGridMetricsQuery returns base English when no translation rows exist (fallback) — current behaviour preserved.
3. MetricLocalization unit tests green (full/null/partial/non-translatable-unchanged).
4. RtsGridMetricDto shape unchanged; MetricsPage/ScreenEditorPage untouched.
5. Commits per module; tree clean (ignore known false-M); journal + S4b; lock released; no push.
