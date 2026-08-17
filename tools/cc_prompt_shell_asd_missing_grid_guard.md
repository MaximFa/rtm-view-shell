# CC task — ASD durable missing-grid guard (shell-authored): recreate RTSGrid when a stale GridId points to a non-existent grid — AWAITING §4-BLESS
> Follow-up to ASD-NORENDER (coordinator greenlit 2026-07-04 17:05). Widget ffaaab90 stores GroupGridId=33 but `RTSGrid_Grid` has NO row 33. Re-save passes cmd.GridId=33 → `SaveQueueGridRtsCommand` Step 1 takes the `else` branch → `UpdateQueueGridAsync(33,…)` UPDATEs 0 rows (grid absent, NOT created) → columns/rows insert as ORPHANS under grid 33 → `RTSGrid_GetDataCells` INNER-JOINs FROM `RTSGrid_Grid` → invisible → still empty. GUARD: if cmd.GridId is set but the grid does NOT exist → treat as new → InsertQueueGrid (fresh GridId), so ANY re-save auto-heals a stale/missing GridId WITHOUT a prod data-fix. General: helps QueueGrid + ASD (all `SaveQueueGridRtsCommand` callers already write back result.GridId).
> ⚠ TERRITORY: this touches Application + Infrastructure (IRtsRepository / RtsRepository / SaveQueueGridRtsCommand), which may overlap bi/backend's claim. Shell AUTHORS per coordinator greenlight; coordinator to confirm claim/route at §4 (bi awareness if a bi session holds Application).
> Owner: role-shell (authoring). Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37).

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
## BINDING 2026-07-06T10:58:06Z | spec: shell | directive: tools/cc_prompt_shell_asd_missing_grid_guard.md | status: open
### DIRECTIVE (spec->CC): ASD durable guard — QueueGridExistsAsync + SaveQueueGridRtsCommand Step1 recreates grid when cmd.GridId points to a missing RTSGrid_Grid. v3, fix:, NO push, §4. Report build=0 + unit failed=0 WITH COUNTS. TERRITORY: Application/Infra (coord to confirm claim).
```

## §42.6 CLAIM (file-mode) — ⚠ Application/Infrastructure (coord-confirm)
- src/CcDashboard.Application/Interfaces/IRtsRepository.cs — ADD `Task<bool> QueueGridExistsAsync(int gridId, CancellationToken ct = default);`
- src/CcDashboard.Infrastructure/Persistence/Repositories/RtsRepository.cs — IMPLEMENT it
- src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs — guard Step 1
- tests/CcDashboard.Tests.Unit/... — ADD a unit test for the recreate path (if a mockable IRtsRepository seam exists)

## GROUNDING (object-store v3)
- IRtsRepository:30-31 `Task<int> InsertQueueGridAsync(string title, ct)` / `Task UpdateQueueGridAsync(int gridId, string title, ct)`.
- RtsRepository: `UpdateQueueGridAsync` = `UPDATE "RTSGrid_Grid" SET "Title"=@p0 WHERE "GridId"=@p1` (0 rows if absent — silent). `InsertQueueGridAsync` INSERTs a new grid, returns GridId.
- SaveQueueGridRtsCommand handler Step 1: `if (cmd.GridId is null or 0) { gridId = await InsertQueueGridAsync(...); } else { await UpdateQueueGridAsync(cmd.GridId.Value, ...); gridId = cmd.GridId.Value; }`.

## THE WORK
1. IRtsRepository: add `Task<bool> QueueGridExistsAsync(int gridId, CancellationToken ct = default);`
2. RtsRepository: implement — parameterised, no string-concat (CODE-01):
   ```csharp
   public async Task<bool> QueueGridExistsAsync(int gridId, CancellationToken ct = default)
   {
       // scalar existence check
       var rows = await db.Database.SqlQueryRaw<int>(
           @"SELECT 1 AS ""Value"" FROM ""RTSGrid_Grid"" WHERE ""GridId"" = {0} LIMIT 1", gridId).ToListAsync(ct);
       return rows.Count > 0;
   }
   ```
   (Use whatever scalar pattern matches the existing repo style — e.g. an existing `GetQueueGridColumnIdsAsync` shows the raw-SQL convention. Must be parameterised.)
3. SaveQueueGridRtsCommand Step 1 — recreate when missing:
   ```csharp
   if (cmd.GridId is null or 0 || !await rtsRepository.QueueGridExistsAsync(cmd.GridId.Value, ct))
   {
       gridId = await rtsRepository.InsertQueueGridAsync(cmd.Title, ct);
   }
   else
   {
       await rtsRepository.UpdateQueueGridAsync(cmd.GridId.Value, cmd.Title, ct);
       gridId = cmd.GridId.Value;
   }
   ```
   The caller already stores `result.GridId` back to config (ASD `_asdGroupGridId`/`_asdStateGridId`; QueueGrid preassignedGridId) → the fresh GridId is persisted.
4. (If a unit-test seam exists) add a test: cmd.GridId=999 (non-existent, QueueGridExistsAsync→false) → InsertQueueGridAsync called, returned GridId used; existing-grid case → UpdateQueueGridAsync path unchanged.
5. No behaviour change when the grid exists.

## VERIFY / DoD (role-shell §A)
- **Object-store:** IRtsRepository has QueueGridExistsAsync; RtsRepository implements it (parameterised); SaveQueueGridRtsCommand Step 1 recreates on missing/absent grid; caller write-back unchanged; v3.
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+W); /ops/test?suite=unit = **failed=0** (+passed); (+ the new recreate test passes). serilog clean + /ops/health.
- **Effect (operator, optional live):** with the guard deployed, re-saving the ASD widget on «12» (stale GroupGridId=33, grid absent) recreates a real grid + cells → renders — WITHOUT the manual (A) data-fix. (Coordinator's immediate (A) data-fix still fine pre-deploy.)

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): ASD durable guard — recreate RTSGrid when a stale GridId points to a missing grid (QueueGridExistsAsync) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "SaveQueueGridRtsCommand trusted a stored GridId and UPDATE-no-op'd when the grid was absent → orphan rows/cells invisible to RTSGrid_GetDataCells (INNER JOIN FROM RTSGrid_Grid). Guard: verify grid existence (QueueGridExistsAsync) and recreate on miss → any re-save self-heals a stale GridId, no prod data-fix. Rule: a persistence path keyed on a stored external id must verify that id still exists before UPDATE, else fall back to create." SOURCE:SaveQueueGridRtsCommand Step1 + RtsRepository.UpdateQueueGridAsync + 03_rtsgrid_read.sql:47. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . files IRtsRepository + RtsRepository + SaveQueueGridRtsCommand (+unit test) . status done|failed . blockers . verified: object-store + build/unit
```
