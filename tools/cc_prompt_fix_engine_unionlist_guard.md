# CC Task — RTM Engine: guard UnionList/_gridList indexers in the agent-grid serve path (fixes "whole agent list killed")

Session: backend-0609
Bug: an unguarded dictionary indexer `UnionList[unionId]` (and `_gridList[gridId]`) in the RTM-engine
runtime path throws KeyNotFoundException on a missing key; the surrounding try/catch swallows it, so the
ENTIRE agent grid / user list comes back empty ("kills the whole agent list") instead of degrading gracefully.
Fix shape (operator/coord-confirmed): replace the indexer with `TryGetValue` + a guard that logs a warning
and returns/skips on miss. RTM-engine territory only — does NOT touch UserManager.cs / Union.cs.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/rtm-service-expert/rtm-service-expert.md
Only after reading all four: proceed.

## Git push (§37)
Do NOT run `git push`. Commit only.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) + fetch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
# restore truncated M files; SKIP known false-M/binary (hash differs but content==HEAD; never line-count):
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  case "$f" in db/data/02_metrics.sql|db/schema.sql|docs/RTMViewShell_SecurityOverview.docx) echo "SKIP false-M/binary: $f"; continue;; esac
  HL=$(git show HEAD:"$f" 2>/dev/null | wc -l); WL=$(wc -l < "$f" 2>/dev/null)
  if [ "$((HL-WL))" -gt 0 ]; then echo "TRUNCATED $f (HEAD=$HL wt=$WL)"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f ($WL)"; fi
done
sync
```

## Multi-session sync (§42) — slug: backend-0609
Claims: RTM/RTM/Engine.cs
```bash
# S1 barrier (MARKER-based, tombstone-safe): block ONLY on "FREEZE ACTIVE"; a non-empty tombstone
# ("BARRIER CLEARED"/"FREEZE LIFTED" — current state) does NOT block.
if grep -q "FREEZE ACTIVE" ".coord/push/request.md" 2>/dev/null; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
# S2 claims
python3 tools/coord_check_claims.py backend-0609 RTM/RTM/Engine.cs
# exit 1 -> STOP (queue). Touch ONLY RTM/RTM/Engine.cs (+ /tmp named /tmp/backend-0609_*). Edit tool BANNED (§0.3): Python+fsync.
```
- S3 commit.lock: phantom-aware acquire (the /tmp acquire_lock.py from tools/cc_prompt_sync_block.md; retry 5x60s).
- S4+S4b: after the commit + §0.6 verify, the LAST step is the Track 2 wrapper:
  `bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)`
  (journal + coordinator flush + lock release, exit-gated). Do NOT hand-write journal/flush inline.
- S5: NO git push (§37).

---

# TASK — 3 guarded lookups in RTM/RTM/Engine.cs (Python+fsync only, Edit BANNED)

All three are in the runtime agent-grid serve/subscribe path. Logger API: `AsyncLogger.Warn(string)`
(exists in RTM/RTM.Tools/AsyncLogger.cs alongside Info/Error). Use Python read->replace->write+fsync.

## Change 1 — AddGridConnection, union branch (~line 2035)
Currently:
```csharp
                if (gridId[0] == 'u')
                {
                    int unionId = Convert.ToInt32(gridId.Substring(1));
                    Union union = UnionList[unionId];
                    union.Connections.TryAdd(connectionId, 0);
                    union.InUse = true;
                    AsyncLogger.Info("Union " + unionId + " In use");
```
Replace the `Union union = UnionList[unionId];` line with a TryGetValue guard:
```csharp
                    int unionId = Convert.ToInt32(gridId.Substring(1));
                    if (!UnionList.TryGetValue(unionId, out Union union))
                    {
                        AsyncLogger.Warn("AddGridConnection: union " + unionId + " not found; connection " + connectionId + " not registered (agent grid not nuked)");
                        return;
                    }
                    union.Connections.TryAdd(connectionId, 0);
                    union.InUse = true;
                    AsyncLogger.Info("Union " + unionId + " In use");
```
(Keep the rest of the union branch unchanged.)

## Change 2 — AddGridConnection, data-grid else branch (~line 2054)
Currently:
```csharp
                else
                {
                    var grid = _gridList[Convert.ToInt32(gridId)];
                    grid.Connections.TryAdd(connectionId, 0);
                    grid.InUse = true;
                    AsyncLogger.Info("Data Grid " + grid.GridId + " In use");
                }
```
Replace with:
```csharp
                else
                {
                    int dataGridId = Convert.ToInt32(gridId);
                    if (!_gridList.TryGetValue(dataGridId, out var grid))
                    {
                        AsyncLogger.Warn("AddGridConnection: data grid " + dataGridId + " not found; connection " + connectionId + " not registered");
                        return;
                    }
                    grid.Connections.TryAdd(connectionId, 0);
                    grid.InUse = true;
                    AsyncLogger.Info("Data Grid " + grid.GridId + " In use");
                }
```

## Change 3 — getUsers (~line 1333)
Currently:
```csharp
            try
            {
                Union union = UnionList[unionId];
```
Replace `Union union = UnionList[unionId];` with:
```csharp
                if (!UnionList.TryGetValue(unionId, out Union union))
                {
                    AsyncLogger.Warn("getUsers: union " + unionId + " not found; returning null");
                    return null;
                }
```
(The existing `if (!union.InUse) return null;` and the rest stay unchanged.)

## OUT OF SCOPE (do NOT change in this task)
The config-LOAD indexers (lines ~433, 520, 565, 636, 651, 664, 728, 738, 740, 2206, 2216) are in
startup/LoadData paths, not the runtime agent-list serve path. Leave them as-is — separate follow-up.
Do NOT touch UserManager.cs or Union.cs (metrics quarantine).

## Verify before commit
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build RTM/RTM -c Debug 2>&1 | tail -6
# the three indexers in the serve path are now guarded:
grep -nE "UnionList.TryGetValue\(unionId, out Union union\)" RTM/RTM/Engine.cs   # >=2 (AddGridConnection + getUsers)
grep -nE "_gridList.TryGetValue\(dataGridId, out var grid\)" RTM/RTM/Engine.cs   # 1
grep -cE "AsyncLogger.Warn\(\"(AddGridConnection|getUsers)" RTM/RTM/Engine.cs    # 3
```
Build MUST succeed before commit.

## Commit (under commit.lock)
One commit, prefix §39.3:
- `rtm: guard UnionList/_gridList indexers in agent-grid serve path (TryGetValue, fixes whole-list-killed)`
After commit: §0.6 post-commit verify + PD-007 re-sync of RTM/RTM/Engine.cs, then LAST step the Track 2 wrapper:
  `bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)`

## Deploy (operator, after commit — RTM Service rebuild)
This is RTM-engine code: publish RTM Service and restart the Windows Service on prod:
```
dotnet publish RTM/RTM -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\rtm"
# stop RTM Service, copy publish\rtm, start RTM Service
```
No DB change — no migration, no signature-change ordering concern.
