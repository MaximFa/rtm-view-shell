# CC task — ASD-NORENDER fix (B) (shell): persist ASD GroupRts*/StateRts* wiring from RTS result + BU-required validation — AWAITING §4-BLESS
> Prod (234, screen «12»): Agent State Distribution renders empty. Root (shell-diagnosed, coordinator+operator confirmed): (Layer-1 data — repaired separately by operator re-save) grid 33 had 0 rows/cells; (Layer-2 CODE, THIS fix) the ASD save path captures ONLY `groupRtsResult.GridId`/`stateRtsResult.GridId` and NEVER writes the returned Row/Column/Cell ids into `config.GroupRts*`/`config.StateRts*` (declared WidgetConfig ~5452-5463, assigned NOWHERE) → those are always empty. Also: when BU is not set the ASD RTS block is SILENTLY skipped (gate ScreenEditorPage:4342-4343) → a half-wired ASD widget can be saved. Operator ruling: ASD group metric = `UsersInStatusGroupCount` (current code correct — no metric change here).
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Report-scoped.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3 (checkout v3 if not); verify HEAD == v3 tip
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED. `D Installations/*` = not ours.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-05T08:23:17Z | spec: shell | directive: tools/cc_prompt_shell_asd_norender_fixB.md | status: open
### DIRECTIVE (spec->CC): ASD-NORENDER (B) — persist GroupRts*/StateRts* from SaveQueueGridRtsCommand result + BU-required validation (no silent skip). v3, fix:, NO push, §4 + LIVE gate. Report build=0 + unit failed=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — MODIFY (ASD save block + newConfig + validation)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (add `Widget_Asd_BuRequired`)

## GROUNDING (object-store v3, ScreenEditorPage.razor)
- ASD save block :4342-4428. Group: `groupColumns` = List<(localId "asd-g{N}", label=GroupName, metricId)>; group data row LocalId = **"asd-gr1"**; call → `groupRtsResult`; today only `_asdGroupGridId = groupRtsResult.GridId` (4380). State: `stateColumns` (localId "asd-s{N}", label=AgentStateName); state data row LocalId = **"asd-sr1"**; `stateRtsResult`; only `_asdStateGridId` (4416).
- `SaveQueueGridRtsResult(int GridId, int HeaderRowId, Dictionary<string,int> SavedColumnIds, Dictionary<string,int> HeaderCellIds, Dictionary<string,int> SavedRowIds, Dictionary<string,Dictionary<string,int>> SavedCellIds)` — SavedColumnIds/HeaderCellIds keyed by COLUMN LocalId; SavedRowIds by ROW LocalId; SavedCellIds by ROW LocalId → { column LocalId → CellId }.
- Config fields (WidgetConfig ~5452-5463): `GroupRtsHeaderRowId int?`, `GroupRtsDataRowId int?`, `GroupRtsColumnIds/GroupRtsHeaderCellIds/GroupRtsDataCellIds Dictionary<string,int?>` + the `StateRts*` counterparts. newConfig ASD assignments live ~4568-4591 (GroupGridId/StateGridId/GroupColumnMetricIds keyed by GroupName).
- Gate (skip-if-no-BU): `if (IsAgentStateDistributionWidget(ConfiguringWidget) && int.TryParse(ConfigBusinessUnit, out var asdBuId) && asdBuId > 0)` (4342-4343).

## THE WORK
### A. Capture RTS wiring into fields (key by GroupName/StateName for consistency with GroupColumnMetricIds)
1. Add private fields (near `_asdGroupGridId`): `_asdGroupRtsHeaderRowId int?`, `_asdGroupRtsDataRowId int?`, `_asdGroupRtsColumnIds/_asdGroupRtsHeaderCellIds/_asdGroupRtsDataCellIds Dictionary<string,int?>=new()` + the 5 `_asdStateRts*` counterparts. Clear the dicts + null the rowids at the top of the ASD block (like `_asdGroupColumnMetricIds.Clear()`).
2. GROUP — right after `_asdGroupGridId = groupRtsResult.GridId;` (4380), populate (map column LocalId → GroupName via `groupColumns`):
   ```csharp
   _asdGroupRtsHeaderRowId = groupRtsResult.HeaderRowId;
   _asdGroupRtsDataRowId = groupRtsResult.SavedRowIds.TryGetValue("asd-gr1", out var gdr) ? gdr : (int?)null;
   foreach (var c in groupColumns) {
       if (groupRtsResult.SavedColumnIds.TryGetValue(c.localId, out var cid)) _asdGroupRtsColumnIds[c.label] = cid;
       if (groupRtsResult.HeaderCellIds.TryGetValue(c.localId, out var hc)) _asdGroupRtsHeaderCellIds[c.label] = hc;
       if (groupRtsResult.SavedCellIds.TryGetValue("asd-gr1", out var rowCells) && rowCells.TryGetValue(c.localId, out var dc)) _asdGroupRtsDataCellIds[c.label] = dc;
   }
   ```
3. STATE — same pattern after `_asdStateGridId = stateRtsResult.GridId;` (4416), using `stateColumns` + row LocalId "asd-sr1" + `_asdStateRts*`.
### B. newConfig — assign the config fields when IsASD (near 4568-4575)
   ```csharp
   GroupRtsHeaderRowId = IsAgentStateDistributionWidget(ConfiguringWidget) ? _asdGroupRtsHeaderRowId : null,
   GroupRtsDataRowId   = IsAgentStateDistributionWidget(ConfiguringWidget) ? _asdGroupRtsDataRowId   : null,
   GroupRtsColumnIds   = IsAgentStateDistributionWidget(ConfiguringWidget) && _asdGroupRtsColumnIds.Count>0 ? new(_asdGroupRtsColumnIds) : new(),
   GroupRtsHeaderCellIds = IsAgentStateDistributionWidget(ConfiguringWidget) && _asdGroupRtsHeaderCellIds.Count>0 ? new(_asdGroupRtsHeaderCellIds) : new(),
   GroupRtsDataCellIds = IsAgentStateDistributionWidget(ConfiguringWidget) && _asdGroupRtsDataCellIds.Count>0 ? new(_asdGroupRtsDataCellIds) : new(),
   ```
   + the 5 `StateRts*` equivalents. (Match the EXACT field names/types in WidgetConfig ~5452-5463; the dict fields are `Dictionary<string,int?>`.)
### C. BU-required validation (replace the silent skip)
   Restructure the gate so an ASD widget without a valid BU FAILS instead of silently skipping RTS creation:
   ```csharp
   if (IsAgentStateDistributionWidget(ConfiguringWidget))
   {
       if (!(int.TryParse(ConfigBusinessUnit, out var asdBuId) && asdBuId > 0))
       {
           Error = L["Widget_Asd_BuRequired"];
           return;   // do NOT save a half-wired ASD widget
       }
       try { /* existing group+state RTS block, using asdBuId */ } catch (Exception ex) { Error = $"Agent State Distribution RTS save failed: {ex.Message}"; return; }
   }
   ```
   Keep the existing inner logic; just hoist the BU check to a hard validation. `Widget_Asd_BuRequired` = e.g. EN "Select a Business Unit for the Agent State Distribution widget." / RU "Выберите Business Unit для виджета распределения состояний агентов." / HE (RTL) equivalent.
### D. No change to metric resolution (UsersInStatusGroupCount stays), render path, or non-ASD widgets.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** ASD block populates `_asdGroupRts*`/`_asdStateRts*` from the results (keyed by Group/State name); newConfig assigns all `GroupRts*`/`StateRts*`; BU-missing → `Error=Widget_Asd_BuRequired`+return (no save); metric resolution unchanged; non-ASD untouched; resx key in 3 locales.
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+warnings); /ops/test?suite=unit = **failed=0** (+passed). If unit still blocked by the Reports/HistoricalReports compile drift → report that verbatim + coordinate (do NOT call green).
- **⛔ LIVE GATE (operator/coordinator on 234, after deploy):** save a fresh ASD group widget with a BU → its config now carries populated groupRts*/stateRts* AND grid cells exist → renders the distribution; saving an ASD widget with NO BU shows the validation error (not a silent empty widget). Do NOT report GREEN without live.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY ScreenEditorPage.razor + 3 resx (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): ASD-NORENDER — persist Group/State RTS wiring from RTS result + BU-required validation [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "ASD group/state save created the RTSGrid via SaveQueueGridRtsCommand but only captured GridId — the returned Row/Column/Cell ids were dropped, so config.GroupRts*/StateRts* stayed empty (declared, never assigned). Also BU-missing silently skipped RTS creation → half-wired widget saved. FIX: map result SavedColumnIds/HeaderCellIds/SavedRowIds/SavedCellIds into config keyed by Group/State name; hard-validate BU. Lesson: when a save spawns child RTS objects, persist ALL returned ids into config, and never let a missing prerequisite silently skip a persistence step." SOURCE:ScreenEditorPage:4342-4428 + SaveQueueGridRtsResult + operator 2026-07-04. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n | blocked:reports-drift> . files ScreenEditorPage.razor + 3 resx . status done|failed . blockers . verified: object-store (LIVE ASD render + BU-validation = operator gate, pending)
```
