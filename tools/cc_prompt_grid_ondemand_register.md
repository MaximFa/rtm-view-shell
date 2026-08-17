# CC task — On-demand GRID+CELL registration: runtime-created QueueGrid works WITHOUT RTM restart

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Read file: .claude/skills/rtm-service-expert/rtm-service-expert.md
Only after reading all: proceed.

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
Every M file: if HEAD line-count > working → `git show HEAD:"$f" > "$f"`. sync.

## Git push
Do NOT run `git push`. Commit only.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_grid_ondemand_register.md | status: open`
`### DIRECTIVE: on-demand grid+cell registration on subscribe (runtime-created QueueGrid, no restart). Claim: RTM/RTM/Engine.cs. prefix fix(rtm).`

## ROOT (confirmed, object-store)
LoadData is STARTUP-ONLY: it reads dataCells = RealtimeData.getDataCells() and registers grids into _gridList + cells into union.Metrics (Engine.cs DataCells loop ~618-680, gated on UnionList.ContainsKey(unionId)). A QueueGrid CREATED AT RUNTIME (Shell writes RTSGrid_Grid/Row/Cell) is NOT in _gridList until the next LoadData. AddGridConnection (Engine.cs ~2063-2074, data-grid else-branch) HARD-REJECTS a data grid absent from _gridList ("data grid N not found") → grid never InUse → Union.getData metric gate (Cells.Any(c=>c.Grid.InUse)) never computes → refreshCells pushes cells with EMPTY values. Confirmed on 140 (grid 9 US: 120 cells pushed, all empty; only fixed by an RTM restart).

## GOAL
When a subscribe targets a data gridId NOT in _gridList, register that grid + its cells ON DEMAND (mirror what LoadData does, scoped to the single gridId), then mark InUse — so the fresh subscription delivers computed updateGridData WITHOUT an RTM restart.

## SCOPE
- GRID case ONLY. Do NOT expand to BU/SG/union/metrics live-reload (separate hot-reload epic).
- Must NOT regress the startup LoadData path or existing grids. Idempotent (no dup if already registered). Thread-safe (the target collections _gridList/_cellList/UnionList are ConcurrentDictionary — use the same TryAdd/GetOrAdd idempotent ops LoadData uses; do NOT introduce a new lock or modify the LoadData loop).

## CLAIM (touch ONLY this)
- RTM/RTM/Engine.cs

## CHANGE 1 — add method Engine.RegisterGridOnDemand(int gridId)
Add a private method that DUPLICATES the DataCells per-cell registration logic (Engine.cs ~619-677) but scoped to the requested gridId (do NOT modify the existing LoadData DataCells loop — leave it exactly as is to avoid any startup regression):
```csharp
private void RegisterGridOnDemand(int gridId)
{
    try
    {
        var dataCells = RealtimeData.getDataCells();   // same source LoadData uses
        foreach (var cell in dataCells)
        {
            if (Convert.ToInt32(cell["GridId"]) != gridId) continue;

            int cellId  = Convert.ToInt32(cell["CellId"]);
            string metric = cell["Metric"];
            int unionId = Convert.ToInt32(cell["UnionId"]);

            if (!UnionList.ContainsKey(unionId)) continue;   // union must be built (same gate as LoadData)

            // Note-1 (§4 REQUIRED — first-subscribe race fix): race-safe single-instance registration via GetOrAdd.
            // The dictionary keeps exactly ONE Grid; every thread uses the STORED instance (no loser mis-linking
            // cells to a Grid absent from _gridList → the old !ContainsKey/new/TryAdd race that left cells empty
            // until restart). GridEvent is wired inside the factory so the stored instance always has it wired;
            // any instance from a factory re-run under contention is discarded (GC'd) and harmless.
            Grid grid = _gridList.GetOrAdd(gridId, id =>
            {
                var g = new Grid(id);
                g.GridEvent += Grid_GridEvent;
                return g;
            });

            Cell newCell;
            if (!_cellList.ContainsKey(cellId))
            {
                newCell = new Cell(cellId, grid, unionId, metric);
                _cellList.TryAdd(cellId, newCell);
            }
            else
            {
                newCell = _cellList[cellId];
                if (UnionList.ContainsKey(newCell.UnionId))
                {
                    Union oldUnion = UnionList[newCell.UnionId];
                    if (oldUnion.Metrics.ContainsKey(newCell.Metric))
                        oldUnion.Metrics[newCell.Metric].Cells.TryRemove(cellId, out _);
                }
                newCell.UnionId = unionId;
                newCell.Metric  = metric;
            }

            Union union = UnionList[unionId];
            Metric unionMetric = union.Metrics.GetOrAdd(metric, new Metric(union));
            unionMetric.Cells.TryAdd(cellId, newCell);

            try
            {
                union.addDataMetric(_metrics[metric]);
                unionMetric.setCellValue(newCell);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("RegisterGridOnDemand union=" + union.UnionId + " Metric=" + metric, ex);
            }
        }
        AsyncLogger.Info("RegisterGridOnDemand gridId=" + gridId + " registered=" + _gridList.ContainsKey(gridId));
    }
    catch (Exception ex)
    {
        AsyncLogger.Error("RegisterGridOnDemand gridId=" + gridId, ex);
    }
}
```
IMPORTANT: match the EXACT field/method names used by the LoadData DataCells loop (cell["CellId"]/["GridId"]/["Metric"]/["UnionId"], _cellList, _metrics, Grid, Cell, Metric, Grid_GridEvent, union.addDataMetric, unionMetric.setCellValue). If any differ in the real file, use the real ones — this must compile and mirror LoadData's behavior 1:1.

## CHANGE 2 — AddGridConnection data-grid branch (Engine.cs ~2063-2074)
In the `else` (data grid) branch, when the grid is not found, call RegisterGridOnDemand then re-check; only reject if still absent:
```csharp
else
{
    int dataGridId = Convert.ToInt32(gridId);
    if (!_gridList.TryGetValue(dataGridId, out var grid))
    {
        RegisterGridOnDemand(dataGridId);   // runtime-created grid: register its cells on demand (no restart)
        if (!_gridList.TryGetValue(dataGridId, out grid))
        {
            AsyncLogger.Warn("AddGridConnection: data grid " + dataGridId + " not found after on-demand register; connection " + connectionId + " not registered");
            return;
        }
    }
    grid.Connections.TryAdd(connectionId, 0);
    grid.InUse = true;
    AsyncLogger.Info("Data Grid " + grid.GridId + " In use");
}
```

## WHY THIS WORKS
After RegisterGridOnDemand: the grid is in _gridList and its cells are attached to union.Metrics; AddGridConnection then sets grid.InUse=true. The next CollectData cycle (Union.getData) sees Cells on an InUse grid → computes the queue metrics → updateGridData carries values. refreshCells (called on init/subscribe) then pushes the computed cells. No restart needed. Existing grids: unaffected (already in _gridList → RegisterGridOnDemand not triggered). Startup LoadData: untouched.

## CONSTRAINTS
- RTM/RTM/Engine.cs ONLY. No legacy/adapter/DB/Shell touch. No new lock; no change to the LoadData loop. No `git push`.
- Edit via Python + os.fsync (§0.3). After write: `sync; tail -3 <f>; wc -l <f>`.

## GATE / ACCEPTANCE
- `dotnet build RTM/RTM` = 0 errors (build0). Unit tests: `dotnet test` failed=0 (add a unit/integration test if feasible: subscribing to an unregistered gridId whose cells reference a built union registers grid+cells and sets InUse).
- grep confirms RegisterGridOnDemand exists + AddGridConnection calls it before rejecting.
- FUNCTIONAL SEAL (140/nayax, operator): create a NEW QueueGrid widget on a dashboard → open it → cells populate WITHOUT an RTM restart (today requires restart).
  - Note-3 (§4): the FUNCTIONAL SEAL MUST use a queue whose BU/union ALREADY EXISTED at RTM startup (on-demand relies on UnionList.ContainsKey(unionId) — the union-guard, same as LoadData). A grid on a brand-NEW BU/union is the separate BU/SG hot-reload epic (out of scope) and will still need a restart until that epic. State this in the RESULT so the operator tests the right queue.
- pre-commit-check.sh green.

## COMMIT (commit.lock)
`bash tools/pre-commit-check.sh` → if exit 1 restore+retry.
prefix: `fix(rtm): on-demand grid+cell registration on subscribe — runtime-created QueueGrid renders without RTM restart`
NO push. Journal append + lock release + §0.7 re-sync of Engine.cs from HEAD.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hash, Engine.cs line delta, build/test result, RegisterGridOnDemand + AddGridConnection change quoted, verified: object-store.


## ⚠ COORDINATOR §4 AMENDMENT (REQUIRED before commit — subagent review 2026-07-16)
§4 = PASS-WITH-NOTES. Fold in Note 1 BEFORE committing:
**Note 1 (REQUIRED, lock-free race fix):** two simultaneous FIRST subscribes to the same new gridId can both enter the `!_gridList.ContainsKey` branch, each build its own `Grid`, and the TryAdd LOSER then attaches its cells to a Grid instance NOT in `_gridList` → AddGridConnection sets InUse on the winner but the loser's mis-linked cells leave the grid empty until restart. FIX: make both threads use the CANONICAL stored Grid — replace the `if(!ContainsKey){new Grid;+=GridEvent;TryAdd} else {get}` with `_gridList.GetOrAdd(gridId, factory)` AND ensure `GridEvent += Grid_GridEvent` is wired exactly ONCE on the instance actually stored (GetOrAdd's factory may build-then-discard under contention → subscribe the event on `_gridList[gridId]` after add, guarded so it's not double-wired). Same pattern the LoadData copy uses, but read-back the winner. Lock-free, no LoadData-loop change. → FOLDED into CHANGE 1 above: use `_gridList.GetOrAdd(gridId, factory)` with `GridEvent += Grid_GridEvent` wired INSIDE the factory. GetOrAdd returns the STORED instance to all threads; the stored instance is wired exactly once (from its own factory run); any instance discarded under contention is GC'd → NO double-wire, NO post-add guard needed. Implement EXACTLY the CHANGE 1 code.
**Note 3 (scope — reflect in the functional seal, not a code change):** RegisterGridOnDemand only registers cells whose unionId is already in UnionList (correct guard). ⇒ a QueueGrid pointing at a union/BU that did NOT exist at RTM startup still won't populate (that's the broader BU/SG hot-reload epic, OUT of scope). 140 functional-seal MUST use a queue whose BU existed at RTM start.
Note 2 (perf, non-blocking): getDataCells() full-catalog per new-grid first-subscribe — fine now, SQL-scope later.
After folding Note 1: RUN-CLEARED.
