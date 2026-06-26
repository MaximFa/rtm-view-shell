# CC task — R9 (shell): ARBITRARY rows-per-page in widget footer, editable in view mode — AWAITING §4-BLESS (lands WITH bi validator relax)
> Operator: rows-per-page must be **ARBITRARY** (free numeric input), NOT a fixed 25/50/100 list, and editable in the widget FOOTER in VIEW mode (not in config-modal General). (Supersedes the earlier fixed-select R9.)
> CAP DECISION (operator): **MAX = 1000**. Client clamp **1..1000**.
> STATE: the earlier fixed-select R9 ALREADY LANDED (commit 3eb2b59 — footer 25/50/100 `<select>` added + General rows-per-page control removed). This task CHANGES that footer select → a FREE numeric input clamped 1..1000. (Do NOT re-remove the General control if 3eb2b59 already removed it — verify.)
> ⚠ CROSS-TERRITORY DEPENDENCY: the server validator currently REJECTS anything but {25,50,100} — `ReportWidgetConfigValidator` (`ValidPageSizes = {25,50,100}`). bi is relaxing it to **InclusiveBetween(1, 1000)**. **This shell half lands WITH bi's validator relax** — confirm bi's relaxed bound (1..1000) is in the tree; if not, STOP and flag.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). claim=frontend (web). Report-scoped.
> IMPLEMENTATION (shell-only at the query level): RunReportWidgetQuery reads PageSize from ConfigJson; the widget rebuilds it live via the record `with` (PageSize = chosen) before Send. No new backend param. NOT persisted v1 (live, session-scoped).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`. Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_r9_footer_pagesize.md | status: open
### DIRECTIVE (spec->CC): R9 ARBITRARY rows-per-page free input in footer (live, Config-with-override); remove General select; lands WITH bi validator relax. fix:, NO push, §4 + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/ReportWidgets/{QueueInterval,QueueWaitTime,AgentMonthly,AgentShiftDetail}ReportWidget.razor — MODIFY (footer free numeric page-size input + _pageSize state + live override)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor — MODIFY (REMOVE General rows-per-page select; keep PageSize field/default)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY ONLY IF footer input style needed (report-scoped, additive)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (footer "rows" label / out-of-range message if new)
- DistributionReportWidget.razor — NO change (no pagination)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
- The 4 paginated type widgets load: `var configJson = Config?.ToJson() ?? "{}"; Mediator.Send(new RunReportWidgetQuery(type, configJson, From, To, _page, TenantId))`. They have `_page`, `.report-widget-footer` (footer-info "Showing X of Y" + footer-pager prev/next "p/N"), `TotalPages`/`PrevPage`/`NextPage`.
- `ReportWidgetConfig` is a `record` with `PageSize` (int?); handler pages by `config.PageSize`.
- `ReportWidgetConfigModal` General: rows-per-page `<select @bind="_pageSize">` (~:135-149) + `_pageSize` (~:360) + `PageSize=_pageSize` on Save (~:650).
- **Server bound:** `ReportWidgetConfigValidator` ValidPageSizes={25,50,100} → bi is relaxing to a range. CONFIRM bi's relaxed min/max in the tree before setting the client clamp; if bi's relax is NOT yet in the tree → STOP and flag (lands together).

## THE WORK
### A. Type widgets (4 paginated) — footer FREE numeric input + live override
1. `_pageSize` state init from `Config?.PageSize ?? 25`.
2. In `.report-widget-footer`, REPLACE the existing 25/50/100 `<select>` (from 3eb2b59) with a small free numeric `<input type="number" min="1" max="1000" step="1" @bind="_pageSize" @bind:event="onchange">` (NOT a select), near footer-info/pager, with a "rows" label. Clamp client-side to **1..1000**; empty/invalid/non-positive → fall back to the previous value (or default 25); show a brief hint if a >1000 value is clamped down.
3. On change: clamp `_pageSize`, RESET `_page=1`, re-run LoadData with override:
   `var eff = (Config ?? new ReportWidgetConfig()) with { PageSize = _pageSize }; var configJson = eff.ToJson();` → `RunReportWidgetQuery(type, configJson, From, To, _page, TenantId)`.
4. `TotalPages = ceil(TotalCount / _pageSize)`; "Showing X of Y" + "p/N" recompute. Reset `_page=1` also on From/To/Config change (keep existing).
5. Distribution: NO change.

### B. Config modal — remove the General rows-per-page control
6. REMOVE the General rows-per-page `<select>` + label. Keep `ReportWidgetConfig.PageSize` (model) as default/initial; on Save PRESERVE existing PageSize (write `InitialConfig?.PageSize`, like Columns). Remove now-unused `_pageSize` modal bindings if fully unused.

## VERIFY / DoD (role-shell §A — ⛔ LIVE on Test66/Prod Mirror, NOT object-store)
- **Object-store:** the 4 paginated widgets have a FREE numeric footer input (not a select) bound to `_pageSize`, clamped to bi's relaxed range, reset-to-1 + Config-with-override re-query; config-General rows-per-page control GONE; PageSize model kept; Distribution unchanged; report-scoped only.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator):** in view mode the footer has a free numeric rows input; type an arbitrary value (e.g. 37) → server ACCEPTS it (bi validator relaxed) → re-queries, "Showing X of Y"/"p/N" recompute, page resets to 1; config-General no longer shows the control; out-of-range value is clamped with a hint. Do NOT report without live confirmation.
- **Coordinate:** lands WITH bi's validator relax (arbitrary fails server-side without it). Match the client clamp to bi's allowed range.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — arbitrary rows-per-page free input in widget footer (live) + remove from config General [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Arbitrary rows-per-page: free numeric footer input (view-mode) clamped to the server validator's relaxed range; live override via `Config with { PageSize }` → RunReportWidgetQuery. Required bi to relax ValidPageSizes={25,50,100} → range — shell+validator land together." SOURCE:<commit> + operator 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files 4 type widgets + ReportWidgetConfigModal (+resx/app.css) . status done|failed . blockers . verified: object-store (LIVE arbitrary footer page-size = operator gate, pending)
```
