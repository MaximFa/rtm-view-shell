# CC task — SEARCH + per-field FILTERS (client-side) on BU / SuperGroups / Sites / InfoSlots — §4-CONFIRMED (Option B)
> Operator/coordinator confirmed Option B (client-side, Web-only): filter the ALREADY-LOADED per-tenant list in the Razor via LINQ. No server-side query/repo/pagination changes. Model the UI on the Users page. These are small reference tables already loaded-for-tenant (§PERF-02 targets large lists, not these). Keep each page's existing Tenant selector + load flow.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**. Narrow claim (4 admin pages + resx). Batches with the tune (db5af40) → ONE rebuild.

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
## BINDING 2026-07-14T10:36:04Z | spec: shell | directive: tools/cc_prompt_shell_admin_search_filters.md | status: open
### DIRECTIVE (spec->CC): client-side search + per-field filters (LINQ on loaded list) for BU/SuperGroups/Sites/InfoSlots, Users-style UI, resx i18n. v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor
- src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor
- src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor
- src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx  (new search/filter labels)

## REFERENCE (Users pattern to mirror for LOOK)
UserAdminPage.razor: a filter toolbar with `<input class="form-control form-control-sm" @bind="Search" @bind:event="oninput" />` + `<select class="form-select form-select-sm" @bind="XFilter">`. Reuse these classes for consistency.

## THE WORK — for EACH page (client-side LINQ; do NOT touch the Get<X>Query / repos / load flow / tenant selector):
General pattern per page:
1. Add state fields: `private string _search = "";` + the page's dropdown filter field(s) (nullable). 
2. Add a filter toolbar row ABOVE the `.table-responsive` (after the existing tenant-selector row): a search `<input ... @bind="_search" @bind:event="oninput" />` (placeholder from resx) + the dropdown filter `<select ... @bind="_filterX">` (first option = "All", from resx). No server call — binding just re-renders.
3. Add a computed filtered view and iterate IT in the table `@foreach` (replace the raw-list foreach):
   `private IEnumerable<TDto> Filtered<X> => <List>.Where(x => Match(x));` where Match = (search empty OR case-insensitive Contains on the search fields) AND (each filter null/empty OR equals).
   Use `string.IsNullOrWhiteSpace(_search) || (field ?? "").Contains(_search, StringComparison.OrdinalIgnoreCase)`.
4. If the current list is empty-after-filter, the existing "no rows" state should still render sensibly (reuse existing empty markup; filtering an empty result is fine).

### Per-page specifics (real DTO fields):
| Page | List field / @foreach | Search fields (Contains, OrdinalIgnoreCase) | Dropdown filter(s) |
|---|---|---|---|
| **BusinessUnitsPage** (`BusinessUnits: IReadOnlyList<BusinessUnitDto>`, @foreach ~:74) | `bu` | `BusinessUnitName`, `Description` | **Site**: `<select @bind="_siteFilter">` options = the loaded `Sites` (SiteDto.SiteId → SiteName); match `_siteFilter==null || bu.SiteId==_siteFilter` |
| **SupergroupsPage** (`Supergroups: IReadOnlyList<SupergroupDto>`, @foreach ~:73) | `sg` | `SupergroupName`, `Description` | (none — Tenant selector only) |
| **SitesPage** (`Sites: IReadOnlyList<SiteDto>`, @foreach ~:73) | `s` | `SiteId`, `SiteName` | **TimeZone**: `<select @bind="_tzFilter">` options = distinct non-null `Sites.Select(x=>x.TimeZone)`; match `_tzFilter==null || s.TimeZone==_tzFilter` |
| **InfoSlotAdmin** (`InfoSlots: List<InfoSlotListDto>`, @foreach ~:73) | `s` | `Name` | **DisplayMode**: `<select @bind="_displayModeFilter">` options = distinct `InfoSlots.Select(x=>x.DisplayMode)`; **Status**: `<select @bind="_statusFilter">` (All / Active / Inactive) match on `IsActive` |

### i18n / resx (add keys in en-US, ru-RU, he-IL; RTL logical props already via Bootstrap):
- Generic reusable: `Common_SearchPlaceholder` ("Search…"), `Common_All` ("All"), `Common_StatusActive`, `Common_StatusInactive` (reuse if they already exist — grep first).
- Filter labels as needed: `BU_FilterSite`, `Sites_FilterTimeZone`, `InfoSlots_FilterDisplayMode`, `Common_Status`. Reuse existing keys where present (e.g. `Common_Status`, `BU_Site`, `Sites_TimeZone`, `InfoSlots_DisplayMode` already exist as column headers — reuse them for the filter labels). NO hard-coded strings.

## VERIFY / DoD
- Object-store: each page has search state + filter state, a filter toolbar (Users classes), a computed filtered enumerable iterated by the table @foreach; NO change to Get<X>Query/repos/tenant-load; resx keys in 3 locales; no hard-coded strings; RTL-safe.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): each page — typing in search narrows the list (Name/Description etc.); each dropdown filter narrows correctly; clearing returns to full (tenant) list; existing add/edit/tenant-selector behavior intact.

## COMMIT
- pre-commit-check → commit.lock → stage the 4 pages + 3 resx → `fix(web): admin search + per-field filters (client-side) on BU/SuperGroups/Sites/InfoSlots [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. BATCH with db5af40 (tune) → ONE Shell rebuild.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files BusinessUnitsPage + SupergroupsPage + SitesPage + InfoSlotAdmin (+3 resx) . status . verified: object-store (LIVE search+filters = coord 140)
```
