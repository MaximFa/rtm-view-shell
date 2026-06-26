# CC task — Reports editor FIX-E (shell): Scope = BU-only, searchable MULTI-select (remove queue toggle+picker) — AWAITING §4-BLESS
> Operator architecture decision: report-widget scope is **BU only** (the system measures by Business Unit; BU→queues is resolved server-side via NGC_BusinessUnitQueueClassification). REMOVE direct queue selection entirely. Operator UI ruling: BU select must be a **searchable MULTI-select** (multi BU per widget) — mirror the dashboard's searchable-dropdown UX, but MULTI (not single, not a plain checkbox list).
> This dissolves the earlier "Save disabled (queues)" symptom and the queue-id type bug (both MOOT — no queue mode).
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> COORDINATED with bi: bi drops Mode+QueueIds from the Application ReportScope + resolves queues server-side from BU; canonical scope JSON = `{"scope":{"businessUnitIds":[<int>...],"agentAxis":"detail|cumulative"}}`. **This shell half and bi's half land TOGETHER** (no half-fix). Match that exact JSON shape.
> Parity-guard: mirror the dashboard's searchable-dropdown markup/CSS/helpers as the reference but REPORT-SCOPED — ZERO edits to ScreenEditorPage/ScreenFullscreen/widget-resize/shared selectors. Reuse the EXISTING global `.searchable-select`/`.searchable-dropdown` CSS (don't edit it).

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
- §0.3 Python+fsync for ALL writes; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_fixe_bu_only_scope.md | status: open
### DIRECTIVE (spec->CC): FIX-E BU-only scope, searchable MULTI-select BU, remove queue toggle+picker, web ReportScope businessUnitIds[]+agentAxis. Claims: ReportWidgetConfigModal.razor, ReportWidgetConfig.cs, (resx). fix:, NO push, §4 + lands-with-bi + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor — MODIFY (Scope tab + @code)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfig.cs — MODIFY (ReportScope: drop Mode+QueueIds)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY only if removing now-unused queue strings / adding BU-search labels (optional; leaving unused strings is fine)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — READ-ONLY reference (BU searchable dropdown: markup :333-362; @code BuSearchText:2491, BuDropdownOpen:2493, FilteredBusinessUnits:2496, OnBuSearchInput:4137, OnBuSearchBlur:4143, SelectBusinessUnit:4164)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## THE WORK
### A. web ReportScope (ReportWidgetConfig.cs) — match bi's canonical shape
- In `ReportScope`: **REMOVE** `Mode` and `QueueIds`. KEEP `BusinessUnitIds` (List<int>?, json `businessUnitIds`) and `AgentAxis` (json `agentAxis`). Result serializes as `{"businessUnitIds":[...],"agentAxis":...}`. (Confirm against bi's published shape before finalizing; if bi names/types differ, match bi.)

### B. ReportWidgetConfigModal.razor — Scope tab
- REMOVE the Data Source mode toggle (the `scopeMode` Queues/BU radio group) entirely.
- REMOVE the queue picker block (the `_scopeMode == "queues"` branch, queue checkboxes, the "Select Queues" section).
- BU select = a **searchable MULTI-select**, mirroring the dashboard `.searchable-select`/`.searchable-dropdown` (ScreenEditorPage:333-362) but MULTI:
  - A search `<input class="form-control">` with `value="@_buSearch"`, `@oninput` → set `_buSearch`, `@onfocus="() => { _buSearch = string.Empty; _buDropdownOpen = true; }"` (clear-search-on-focus — role-shell §A#7), `@onblur` → `Task.Delay(150)` then close (mirror OnBuSearchBlur).
  - `@if (_buDropdownOpen)` → `.searchable-dropdown` listing `FilteredBusinessUnits` (BusinessUnits filtered by `_buSearch`, case-insensitive Contains). Each item = `.dropdown-item` with a checked indicator (`_selectedBuIds.Contains(bu.BusinessUnitId)` → show ✓/checkbox), `@onmousedown:preventDefault="true"` + `@onmousedown="() => ToggleBu(bu.BusinessUnitId, !_selectedBuIds.Contains(bu.BusinessUnitId))"` — toggles selection and KEEPS the dropdown open (multi-select).
  - Show the SELECTED BUs as removable chips (or a checked summary) above/below the input so the user sees their multi-selection (e.g. `@foreach (var id in _selectedBuIds) { <span class="badge ...">@name <button @onclick=remove>×</button></span> }`).
  - Keep the agent-axis `<select>` for agent widgets (`IsAgentWidget`).
  - Keep the empty/loading states for the BU list.
- Reuse the EXISTING global `.searchable-select` / `.searchable-dropdown` CSS (do NOT edit it; if a multi-select chip style is needed, add a NEW report-scoped class, additive).
### C. ReportWidgetConfigModal.razor — @code
- REMOVE `_scopeMode`, `_selectedQueueIds`, `ToggleQueue`, the queue checkbox `checked` binding, and the queues data load (drop `GetQueuesQuery` / `_queues` / `_queuesLoading` if now unused — keep BU load `GetMyBusinessUnitsQuery`).
- ADD BU-search state: `_buSearch` (string), `_buDropdownOpen` (bool), `FilteredBusinessUnits` (filter `_businessUnits` by `_buSearch`), and an `OnBuSearchBlur` (Task.Delay(150)+close) — mirror the dashboard helpers but for multi.
- KEEP `_selectedBuIds` (List<int>), `ToggleBu`, `_businessUnits`, `_busLoading`.
- `CanSave` → `_selectedBuIds.Count > 0` (drop the `_scopeMode == "queues" ? … : …` expression).
- `Save()` → `scope = new ReportScope { BusinessUnitIds = _selectedBuIds.ToList(), AgentAxis = IsAgentWidget ? _agentAxis : null }` (no Mode, no QueueIds).
- `OnParametersSetAsync` load: drop `_scopeMode`/`_selectedQueueIds` from InitialConfig.Scope; load `_selectedBuIds = InitialConfig.Scope.BusinessUnitIds?.ToList() ?? new()`, `_agentAxis`.

## VERIFY / DoD (role-shell §A — ЧП: LIVE gate, NOT object-store; lands WITH bi)
- **Object-store:** Scope tab has NO queue mode toggle + NO queue picker; BU = searchable multi-select (search input + .searchable-dropdown + multi ToggleBu + selected chips); web ReportScope has NO Mode/QueueIds (businessUnitIds+agentAxis only); CanSave on _selectedBuIds; ScreenEditorPage/shared/widget-resize untouched.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE — MANDATORY (operator/coordinator, WITH bi's half deployed):** report widget config → Scope tab shows ONLY a searchable BU multi-select (no queue toggle/list) — type to filter, pick MULTIPLE BUs (chips show), Save ENABLES on ≥1 BU → Save → the widget renders data for the selected BUs (BU→queues resolved server-side by bi). Searchable-dropdown UX matches the dashboard (clear-on-focus, click-to-select). Do NOT report fixed from object-store.
- **Coordinate:** confirm with the coordinator that bi's Application half (ReportScope shape + server-side BU→queue resolution) is landing in the SAME bundle; the JSON `businessUnitIds`/`agentAxis` element names/types match.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — Scope = BU-only searchable multi-select; remove queue toggle/picker; ReportScope businessUnitIds+agentAxis [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Report scope simplified to BU-only (operator: system measures by BU; BU→queues resolved server-side). BU select = searchable MULTI-select mirroring the dashboard's .searchable-select/.searchable-dropdown (clear-search-on-focus §A#7, @onmousedown:preventDefault to fire before blur) but multi (ToggleBu, keep-open, chips). Queue selection + queue-id type bug removed entirely." SOURCE:<commit> + operator 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportWidgetConfigModal.razor + ReportWidgetConfig.cs (+resx) . status done|failed . blockers . verified: object-store (LIVE BU-scope = operator gate w/ bi half, pending)
```
