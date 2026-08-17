# CC task — PAGINATION UNIFICATION (shell): one shared AppPagination component on ALL list screens — §4-CONFIRMED
> Operator: pagination must be IDENTICAL on every list screen. Coordinator confirmed: reference = Users; page-size 10/25/50/100 default 25; ONE shared component + reuse `.pagination-bar` CSS; apply to ALL list screens (server pages keep their query & render via the component; the load-all pages get client-side Skip/Take on the FILTERED list, Option B). Sibling below `.table-responsive` (edit-3 offset keeps it visible).
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**. Enumerated claim (shared component + all list pages + resx).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — .coord/cc/shell.md
```
## BINDING 2026-07-14T13:25:02Z | spec: shell | directive: tools/cc_prompt_shell_pagination_unify.md | status: open
### DIRECTIVE (spec->CC): shared AppPagination component + apply to all list screens (server keep-query, client Skip/Take on filtered list); Users-canonical, 10/25/50/100 def 25. v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web) — ENUMERATED
- NEW: src/CcDashboard.Web/Components/Shared/AppPagination.razor
- src/CcDashboard.Web/Components/Admin/UserAdminPage.razor            (server — replace inline bar)
- src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor (server — replace inline bar)
- src/CcDashboard.Web/Components/Admin/AuditLogPage.razor             (server — replace inline bar; gains '10')
- src/CcDashboard.Web/Components/Reports/ReportsListPage.razor        (add bar via component; wire to its PageSize/paging)
- src/CcDashboard.Web/Components/Dashboard/ScreenListPage.razor       (Dashboards — verify list model; unify to component)
- src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor  (client — Skip/Take on filtered)
- src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor    (client)
- src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor          (client)
- src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor                    (client)
- src/CcDashboard.Web/Components/Admin/CategoriesPage.razor                   (client — verify genuine list)
- src/CcDashboard.Web/Components/Admin/PermissionGroupsPage.razor             (client — verify)
- src/CcDashboard.Web/Components/Admin/TenantsPage.razor                      (client — verify)
- src/CcDashboard.Web/Components/Dashboard/InfoSlots/InfoSlotMessages.razor   (client — verify)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx      (only if a NEW key is needed — reuse Common_Records which EXISTS)
> If any enumerated page is NOT a genuine paginable list (e.g. a small fixed/grouped view), do NOT force it — note it in the RESULT and skip.

## GROUNDING (object-store)
- Users canonical bar (UserAdminPage ~:153-166): `<div class="pagination-bar"><span class="pagination-info">@TotalCount @L["Common_Records"]</span><div class="pagination-controls"><select class="pagination-size" @bind=PageSize @bind:after=ResetAndLoad>10/25/50/100</select><button disabled=@(CurrentPage<=1) @onclick=PrevPage>&#8249;</button><span class="pagination-counter">@PageLabel</span><button disabled=@(CurrentPage>=TotalPages) @onclick=NextPage>&#8250;</button></div></div>`. State: `TotalCount`, `TotalPages=ceil(TotalCount/PageSize)`, `CurrentPage`, `PageSize`, `PageLabel`.
- CSS classes exist: `.pagination-bar/.pagination-info/.pagination-controls/.pagination-size/.pagination-counter` (app.css:1050+). `Common_Records` resx EXISTS. Shared/ uses `App*` naming.

## THE WORK
### 1. NEW shared component — Components/Shared/AppPagination.razor
```razor
@inject Microsoft.Extensions.Localization.IStringLocalizer<CcDashboard.Web.Resources.SharedResources> L
@if (TotalCount > 0)
{
<div class="pagination-bar">
    <span class="pagination-info">@TotalCount @L["Common_Records"]</span>
    <div class="pagination-controls">
        <select class="pagination-size" value="@PageSize" @onchange="OnSize">
            @foreach (var o in PageSizeOptions) { <option value="@o" selected="@(o == PageSize)">@o</option> }
        </select>
        <button class="btn btn-sm btn-outline-secondary" disabled="@(Page <= 1)" @onclick="() => PageChanged.InvokeAsync(Page - 1)">&#8249;</button>
        <span class="pagination-counter">@Page / @TotalPages</span>
        <button class="btn btn-sm btn-outline-secondary" disabled="@(Page >= TotalPages)" @onclick="() => PageChanged.InvokeAsync(Page + 1)">&#8250;</button>
    </div>
</div>
}
@code {
    [Parameter] public int TotalCount { get; set; }
    [Parameter] public int Page { get; set; } = 1;
    [Parameter] public int PageSize { get; set; } = 25;
    [Parameter] public int[] PageSizeOptions { get; set; } = [10, 25, 50, 100];
    [Parameter] public EventCallback<int> PageChanged { get; set; }
    [Parameter] public EventCallback<int> PageSizeChanged { get; set; }
    private int TotalPages => Math.Max(1, (int)Math.Ceiling((double)TotalCount / PageSize));
    private async Task OnSize(ChangeEventArgs e) { if (int.TryParse(e.Value?.ToString(), out var s)) await PageSizeChanged.InvokeAsync(s); }
}
```
(Keep counter as `@Page / @TotalPages` for identical look everywhere; if the existing Users PageLabel differs, this canonicalizes it.)
### 2. SERVER pages (Users, Metrics, Audit, Reports, Dashboards) — render via the component, keep the server query
Replace each page's inline `.pagination-bar` with:
`<AppPagination TotalCount="TotalCount" Page="CurrentPage" PageSize="PageSize" PageChanged="OnPageChanged" PageSizeChanged="OnPageSizeChanged" />`
and wire: `OnPageChanged(int p){ CurrentPage = p; await LoadData(); }`, `OnPageSizeChanged(int s){ PageSize = s; CurrentPage = 1; await LoadData(); }` (reuse each page's existing load/query method name). Audit: options now include 10 (component default). Reports/Dashboards: add the component; if they currently load-all, wire as CLIENT (below) instead.
### 3. CLIENT load-all pages (BU/SG/Sites/InfoSlots/Categories/PermGroups/Tenants/InfoSlotMessages) — Option B
Add `private int _page = 1; private int _pageSize = 25;`; compute the paged view from the ALREADY-FILTERED list:
`var Paged = Filtered.Skip((_page - 1) * _pageSize).Take(_pageSize);` and iterate `Paged` in the table `@foreach` (was Filtered). Add below `.table-responsive`:
`<AppPagination TotalCount="Filtered.Count()" Page="_page" PageSize="_pageSize" PageChanged="p => { _page = p; StateHasChanged(); }" PageSizeChanged="s => { _pageSize = s; _page = 1; StateHasChanged(); }" />`
Reset `_page = 1` whenever search/filter changes (add to the existing search/filter change path). For BU/SG/Sites/InfoSlots this composes with the search+filters shipped in baf8968 (filter → page).
### 4. i18n: reuse `Common_Records` (exists). No new resx unless a page needs a new label — avoid; no hard-coded strings; RTL-safe (bar uses existing classes).

## VERIFY / DoD
- Object-store: AppPagination.razor exists with the API; EVERY enumerated list screen renders `<AppPagination .../>` (server: wired to query; client: Skip/Take on filtered list + reset page on filter change); removed each page's divergent inline bar; Audit has 10; no hard-coded strings; skipped pages (if any) noted.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): pagination IDENTICAL (look + behavior) on Dashboards, Users, Metrics, Audit, Reports, BU/SG/Sites/InfoSlots, Categories, PermGroups, Tenants — page-size 10/25/50/100, prev/next, page X/N, N records; client pages paginate the filtered list + reset to page 1 on search/filter; server pages re-query.

## COMMIT
- pre-commit-check → commit.lock → stage the enumerated files → `fix(web): unify pagination — shared AppPagination component on all list screens [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. Coordinator sequences the rebuild (batches with db5af40 + baf8968).

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files AppPagination.razor + <list pages touched> (+resx if any) . skipped: <pages not paginable, if any> . status . verified: object-store (LIVE identical pagination = coord 140)
```
