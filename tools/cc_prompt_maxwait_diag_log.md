# Task: Max Wait '+'-duration — LOG-ONLY diagnostic instrumentation (RTM engine)

> ⛔ЧП discipline. This task is **instrumentation only — NO logic change, NO fix**. We are capturing a
> live log on server 140 to disambiguate WHY the Max Wait ('+'-duration) cells re-base to ~0 on a Shell
> F5/re-subscribe. Do NOT change any computation, emit, or control flow. Add log lines ONLY.
> Territory: **rtm**. NO `git push`. Commit prefix: `rtm:`.

---

## STEP 0 — MANDATORY integrity check (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then echo "TRUNCATED: $f (HEAD=$HEAD_LINES wt=$WT_LINES)"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f ($WT_LINES)"; fi
done
sync; echo "=== integrity complete ==="
```

## STEP 1 — MANDATORY reads (§40 + §0.8)
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-backend/role-backend.md   (§A CORE + §C VERIFY)
```
Only after reading all four: proceed.

## STEP 2 — BINDING preamble (§0.6b) — append to `.coord/cc/backend.md` via Python+fsync
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_maxwait_diag_log.md | status: open
### DIRECTIVE: LOG-ONLY max-wait '+'-duration instrumentation (3 sites). Claims: RTM/RTM/Engine.cs, RTM/RTM/Union.cs. Prefix rtm:.
```

## STEP 3 — SYNC block (§42.6): slug `backend-0626`, claim `rtm`. Abort if `.coord/push/request.md` exists. commit.lock around the commit. Journal + lock-release after. NO push (§37).

---

## THE INSTRUMENTATION — add these log lines ONLY (Python-write per §0.3, Edit tool BANNED)

All writes to `RTM/RTM/Engine.cs` and `RTM/RTM/Union.cs` via an atomic Python read→replace→write with
`os.fsync`, then `tail -3` + `wc -l` verify. Use the logger already present in these files:
`AsyncLogger.Info(...)` (same as existing calls, e.g. Engine.cs:369). If `AsyncLogger` is not in scope
in Union.cs, use the same logging mechanism that file already references; do NOT add new usings beyond
what compiles. Guard EVERY log with a null/try so instrumentation can never throw into the hot path.

### Site 1 — RECOMPUTE base + bag state — `RTM/RTM/Union.cs`, in `getWaitDurationCurMax` (~line 381)
After `string result = metric.MetricFunction(QueueInteractions.Bag, Applics.Any());` add:
```csharp
try {
    AsyncLogger.Info($"MAXWAIT-RECOMPUTE union={UnionId} metric={metric.ID} bagCount={QueueInteractions.Bag.Count} result=[{result}]");
} catch { }
```
(If `UnionId` is not the exact property name on Union, use the union's id property that already exists in this class. Do NOT invent a field.)

### Site 2 — STREAMING emit (Grid_GridEvent) — `RTM/RTM/Engine.cs` (~line 911, the `'+'` branch)
Inside `Grid_GridEvent`, INSIDE the `if (!string.IsNullOrWhiteSpace(value) && (value[0] == '+'))` block,
AFTER `value = firstChr + signonTimeTS.ToString(@"hh\:mm\:ss");` add:
```csharp
try {
    AsyncLogger.Info($"MAXWAIT-STREAM grid={e.GridId} cell={cellId} base=[{cell.Value2}] emitted=[{value}]");
} catch { }
```

### Site 3 — REFRESHCELLS emit — `RTM/RTM/Engine.cs`, in `refreshCells` (~line 1383)
(3a) At method entry, right after `public void refreshCells(int gridId) {`, add:
```csharp
try { AsyncLogger.Info($"MAXWAIT-REFRESH-ENTER grid={gridId}"); } catch { }
```
(3b) Inside the `if (!string.IsNullOrWhiteSpace(value) && (value[0] == '+'))` block, AFTER
`value = firstChr + signonTimeTS.ToString(@"hh\:mm\:ss");` add:
```csharp
try {
    AsyncLogger.Info($"MAXWAIT-REFRESH grid={gridId} cell={cellId} servedBase=[{cellValue.Value.Value2}] emitted=[{value}]");
} catch { }
```

> ⚠ Do NOT change any existing line. Only INSERT the guarded log statements above. No behavior change.
> The three tags (MAXWAIT-RECOMPUTE / -STREAM / -REFRESH-ENTER / -REFRESH) let us correlate, on an F5,
> whether refreshCells serves a `servedBase` different from the last streamed `base`, and whether the
> bag's recompute base went recent — disambiguating (a) LoadData/refresh path vs (c) stale/changed-oldest.

---

## STEP 3.5 — C1 ANTI-SILENT-NOOP grep-confirm (MANDATORY before build/commit)
After the Python writes, confirm every anchor actually matched (an unmatched anchor = silent no-op that
still builds 0-err but logs NOTHING). ALL must pass or FAIL the task (do NOT commit):
```bash
cd "D:\Claude\Projects\RTM View Shell"
E=$(grep -c 'MAXWAIT-' RTM/RTM/Engine.cs); U=$(grep -c 'MAXWAIT-' RTM/RTM/Union.cs)
echo "Engine MAXWAIT- count=$E (expect 3: STREAM + REFRESH-ENTER + REFRESH)"
echo "Union  MAXWAIT- count=$U (expect 1: RECOMPUTE)"
[ "$E" = "3" ] && [ "$U" = "1" ] && echo "C1 PASS" || { echo "C1 FAIL — an anchor did not match; do NOT commit"; exit 1; }
```

## STEP 4 — build0 (compile only, no deploy)
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build RTM/RTM/RTM.csproj -c Release 2>&1 | tail -20
```
Must be Build succeeded, 0 errors. (Warnings OK.)

## STEP 5 — pre-commit + commit (rtm:) — NO PUSH
```bash
bash tools/pre-commit-check.sh RTM/RTM/Engine.cs RTM/RTM/Union.cs
# exit 0 required. commit.lock (§42.4). Prefix:
#   rtm: MAXWAIT diag log-only (Engine.cs stream/refresh + Union.cs recompute) — temporary, revert after 140 capture
```
Post-commit: §0.6 verify (git status clean, git show HEAD:<f> | wc -l matches), journal append, lock release, §0.7 re-sync.

## STEP 6 — BINDING postamble (§0.6b): write RESULT into `.coord/cc/backend.md`
```
### RESULT: commit <hash> . build succeeded 0-err . files RTM/RTM/Engine.cs (+~4 log lines), RTM/RTM/Union.cs (+~3) . status done . blockers none . verified: object-store
```

## Acceptance criteria
- [ ] Zero logic/behavior change — only guarded `AsyncLogger.Info` inserts at the 3 sites.
- [ ] **C1:** `grep -c 'MAXWAIT-'` == **3** in Engine.cs and **1** in Union.cs BEFORE commit (no silent no-op).
- [ ] `dotnet build RTM/RTM` = Build succeeded, 0 errors.
- [ ] Commit prefix `rtm:`, NO push, working tree clean vs HEAD after.
- [ ] Binding RESULT written, object-store verified.
- [ ] Note in commit body: TEMPORARY diagnostic, to be reverted after 140 capture.

## Notes
- This is diagnostic instrumentation for a fast, safe deploy to 140 (no logic risk). After deploy, the
  operator F5s the US grid; we grep RTM.log for `MAXWAIT-` and correlate by timestamp.
- **C2 capture hygiene:** MAXWAIT-STREAM is high-volume (~10 cells/grid/calcInterval); RTM.log rotates in 5-10 min. Keep the 140 window SHORT — operator F5s the US grid promptly after RTM is back, grep `MAXWAIT-` immediately, THEN revert this temporary diag commit. Deploy restarts RTM (LoadData) but does NOT confound the F5 test (F5 = Shell re-subscribe, independent of RTM lifecycle) — capture after RTM is back and streaming normally.
- ⛔ЧП: no legacy touch. RTM territory only. No fix in this task.
