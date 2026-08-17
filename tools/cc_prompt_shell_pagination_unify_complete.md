# CC task — PAGINATION UNIFY COMPLETION (shell): add AppPagination to the 7 list pages e9f847f MISSED — §4 (completes the unify)
> ⚠ e9f847f ("unify pagination…") is INCOMPLETE: it added Shared/AppPagination.razor + wired only 6 pages (UserAdmin, Metrics, Audit, ScreenListPage, ReportsListPage, Categories). It SILENTLY SKIPPED 7 enumerated list pages — verified they have 0 `AppPagination`: BusinessUnits, SuperGroups, Sites, InfoSlots (the 4 that must compose with the baf8968 search/filters), PermissionGroups, Tenants, InfoSlotMessages. Operator wants pagination IDENTICAL on ALL list screens. This task adds AppPagination to those 7 (client-side, Option B) using the SAME already-committed component. Do NOT re-touch the 6 done pages or the component.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**.

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
## BINDING 2026-07-14T14:22:06Z | spec: shell | directive: tools/cc_prompt_shell_pagination_unify_complete.md | status: open
### DIRECTIVE (spec->CC): pagination-unify COMPLETION — add AppPagination (client Skip/Take) to the 7 pages e9f847f missed (BU/SG/Sites/InfoSlots/PermGroups/Tenants/InfoSlotMessages). v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web) — the 7 MISSED pages only
- src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor
- src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor
- src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor
- src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor
- src/CcDashboard.Web/Components/Admin/PermissionGroupsPage.razor
- src/CcDashboard.Web/Components/Admin/TenantsPage.razor
- src/CcDashboard.Web/Components/Dashboard/InfoSlots/InfoSlotMessages.razor
> Do NOT modify AppPagination.razor or the 6 already-done pages (UserAdmin/Metrics/Audit/ScreenListPage/ReportsListPage/Categories) — they are DONE in e9f847f.

## GROUNDING (object-store)
- Shared component already committed: `Components/Shared/AppPagination.razor` — `[Parameter] int TotalCount, int Page(1-based), int PageSize, int[] PageSizeOptions=[10,25,50,100]; EventCallback<int> PageChanged, PageSizeChanged`. Renders `.pagination-bar` (only when TotalCount>0), counter `@Page / @TotalPages`.
- Reference client wiring = Categories page (done in e9f847f) — mirror its `_page/_pageSize` + Skip/Take + `<AppPagination>` usage for consistency.
- BU/SG/Sites/InfoSlots already have search+filters (baf8968): each has a `Filtered` (or equivalent `.Where`) enumerable iterated by the table `@foreach`.

## THE WORK — for EACH of the 7 pages (client-side, Option B)
1. Add `private int _page = 1; private int _pageSize = 25;`.
2. Compute the paged view from the ALREADY-FILTERED list (or the raw loaded list where there's no filter): 
   `var Paged = <Filtered>.Skip((_page - 1) * _pageSize).Take(_pageSize);` and iterate **Paged** in the table `@foreach` (was the filtered/raw list).
3. Add BELOW `.table-responsive` (sibling, same place as Users/Categories):
   `<AppPagination TotalCount="<Filtered>.Count()" Page="_page" PageSize="_pageSize" PageChanged="p => { _page = p; StateHasChanged(); }" PageSizeChanged="s => { _pageSize = s; _page = 1; StateHasChanged(); }" />`
4. Reset `_page = 1` on any search/filter change (BU/SG/Sites/InfoSlots — add to the existing search/filter change path so filtering resets to page 1) and on tenant-selector change / reload.
5. Per page:
   - **BusinessUnits / SuperGroups / Sites / InfoSlots**: use the existing `Filtered` list from baf8968 (filter → page). 
   - **PermissionGroups / Tenants / InfoSlotMessages**: use the page's loaded list; if a page is genuinely NOT a paginable flat list (e.g. a grouped/nested view), SKIP it and NOTE in RESULT — but PermGroups/Tenants/InfoSlotMessages are flat lists → paginate. Verify each has a `.table-responsive` list; if InfoSlotMessages is a sub-panel not a top list, note it.
6. Namespace: AppPagination is in `Components/Shared` — ensure it's resolvable (global `_Imports.razor` likely already imports `...Components.Shared`; if not, add `@using`).

## VERIFY / DoD
- Object-store: each of the 7 pages renders `<AppPagination …/>` below `.table-responsive`, iterates a Skip/Take paged view, resets page-1 on filter/tenant change; the 6 done pages + AppPagination.razor UNCHANGED; any genuinely-skipped page noted.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): pagination IDENTICAL across ALL list screens now (the 7 + the 6). On BU/SG/Sites/InfoSlots: filtering resets to page 1 + paginates the filtered set.

## COMMIT
- pre-commit-check → commit.lock → stage the 7 pages → `fix(web): pagination unify completion — AppPagination on BU/SG/Sites/InfoSlots/PermGroups/Tenants/InfoSlotMessages [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. Batches with e9f847f (+ db5af40/baf8968 already live) → coordinator's next rebuild.

## §0.6b CAPTURE -> role-shell §B: "A multi-file enumerated refactor (13 pages) committed only 7 files (component + 6 pages), silently dropping 7 enumerated targets with no skip-note (binding dropped, L-SC-04). Lesson: for an ENUMERATED N-file directive, verify `git show --stat` covers ALL N (or an explicit skip-note per omission) on consume; a partial commit of an 'all screens' task is incomplete even if it builds." SOURCE:e9f847f (7 files vs 13 enumerated). Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files <7 pages touched> . skipped: <if any + why> . status . verified: object-store (LIVE identical pagination all screens = coord 140)
```
