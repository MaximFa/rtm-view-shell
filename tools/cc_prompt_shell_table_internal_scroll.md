# CC task — TABLE internal scroll + sticky header (shell): all admin/report list tables scroll inside, header fixed — §4 (4-edit batch)
> EDIT 3: currently the whole PAGE scrolls when a list table is long. Required: each table scrolls INSIDE its own container; the header row stays fixed (sticky thead) while the body scrolls; pagination stays visible (already a sibling footer). Applies to ALL admin/report LIST tables.
> SCOPE (object-store): all 17 list-table pages share the wrapper `<div class="table-responsive"><table class="table ..."><thead class="table-light">...` with a SIBLING `<div class="pagination-bar">` AFTER it (UserAdmin, BusinessUnits, Sites, Supergroups, Metrics, Categories, InfoSlotAdmin, PermissionGroups, Tenants, AuditLog, InfoSlotMessages, ScreenListPage, + Reports list pages). NONE lack `.table-responsive`. There is NO existing `.table-responsive` rule in app.css (Bootstrap default = overflow-x only). Grid widgets (`.agent-grid-body`/`.queue-grid-body`) + report widgets (`.report-widget-*`) use DIFFERENT wrappers → NOT affected (they keep their own internal scroll + Live/paging footer).
> FIX = one shared app.css rule on `.table-responsive` (bounded height + vertical scroll) + sticky thead. app.css changes → App.razor `app.css?v` bump. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**.

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
## BINDING 2026-07-14T08:47:04Z | spec: shell | directive: tools/cc_prompt_shell_table_internal_scroll.md | status: open
### DIRECTIVE (spec->CC): tables scroll internally + sticky thead — shared .table-responsive app.css rule + App.razor app.css?v bump. v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/app.css  (add `.table-responsive` bounded-scroll + sticky thead)
- src/CcDashboard.Web/Components/App.razor  (bump `app.css?v=30` -> `?v=31`)
- (ONLY if a specific page's table must opt out or needs a wrapper tweak — verify first; prefer the shared rule with zero page edits)

## GROUNDING (object-store)
- Pattern (all 17): `<div class="table-responsive" aria-busy="...">` > `<table class="table table-hover table-sm ...">` > `<thead class="table-light">` … then a SIBLING `<div class="pagination-bar">` (UserAdminPage.razor:88-90,153). Pagination-bar is OUTSIDE table-responsive → stays visible when the table scrolls internally.
- app.css currently has NO `.table-responsive` rule (grep empty). App.razor:28 `app.css?v=30`.
- Grid widgets = `.agent-grid-body table` / `.queue-grid-body table` (own scroll); report widgets = `.report-widget-*` (own bounded scroll from table-chrome v2). Neither uses `.table-responsive` → leave untouched.

## THE WORK
### A. app.css — add a shared bounded-scroll + sticky-header rule (RTL-safe, token-based):
```css
/* Internal table scroll + sticky header (admin/report list tables) */
.table-responsive {
    max-height: calc(100vh - 220px);   /* bounded so long tables scroll internally; short tables render fully (no scroll). Tune the offset to clear topbar + pagination-bar + page padding at the LIVE gate. */
    overflow-y: auto;
}
.table-responsive thead th {
    position: sticky;
    inset-block-start: 0;              /* logical 'top:0' (RTL-safe) */
    z-index: 2;
    background: var(--clr-surface);    /* SOLID bg so body rows don't show through the sticky header */
}
/* dark mode: token already flips --clr-surface */
```
- Use tokens (no hardcoded colors). Verify `--clr-surface` gives an opaque header in BOTH light + dark (thead.table-light may override — ensure the sticky bg wins; if needed target `.table-responsive thead.table-light th`).
- Keep Bootstrap's existing `.table-responsive` overflow-x behavior (do not remove horizontal scroll for genuinely wide tables).
### B. App.razor — `app.css?v=30` -> `?v=31` (only that line).
### C. Verify NON-regression (object-store + reason): grid widgets (`.agent-grid-body`/`.queue-grid-body`) and report widgets (`.report-widget-*`) do NOT use `.table-responsive` → unaffected. Check that no MODAL or the report/dashboard EDITOR relies on a `.table-responsive` that must not get a max-height (grep `.table-responsive` in modals/editors); if one does and would regress, scope it out (e.g., a `.table-responsive.no-scroll` opt-out class on that instance) — enumerate any such exception.

## VERIFY / DoD
- Object-store: app.css has the `.table-responsive` bounded max-height + overflow-y + sticky thead (logical props, tokens); App.razor app.css?v=31; grid/report-widget wrappers untouched; any opt-out enumerated.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): on a long admin list (e.g. Metrics/Users), the TABLE body scrolls while the HEADER ROW stays fixed/visible and pagination stays visible; the page itself does not scroll the table off; short tables render without an awkward inner scrollbar; RTL intact; grid/report widgets unchanged. Do NOT report GREEN without the visual.

## COMMIT
- pre-commit-check → commit.lock → stage app.css + App.razor (+ any enumerated page) → `fix(web): tables scroll internally with sticky header (.table-responsive) + app.css?v=31 [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. BATCH with the other 3 edits → ONE Shell rebuild.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files app.css + App.razor(?v=31) (+pages if any) . status . verified: object-store (LIVE sticky-scroll = coord 140)
```
