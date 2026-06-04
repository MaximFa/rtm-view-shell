# CC Task: RTM Server — force UserManager metric refresh after LoadData

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `tail -3 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.
§0.4 — git index.lock workaround if needed.

---

## §0 — SESSION-RESUME INTEGRITY CHECK (run first)

```bash
python3 -c "
with open('.git/config', 'rb') as f: data = f.read()
if b'\x00' in data:
    with open('.git/config', 'wb') as f: f.write(data.replace(b'\x00', b''))
    print('Fixed null bytes in .git/config')
else:
    print('git/config OK')
"
git log --oneline -1
git status --short
```

For every `M` file: `tail -3 <path>` — restore truncated with `git show HEAD:<path> > <path>`.

---

## Root Cause

When a column is added to an Agent Grid widget and `/LoadData` is called on RTM Server:

1. `Engine.LoadData()` reads updated `RTSUserGridColumn` rows from DB
2. `union.UserGridMetrics.TryAdd(newMetricId, ...)` ← new MetricId added here ✅
3. **BUT** existing `UserManager.Metrics` is a snapshot taken at `refreshMetrics()` time.
   `refreshMetrics()` only runs inside `workgroupActivation()` — i.e., only when an agent
   joins or leaves a workgroup. It is NOT called from `LoadData()`.
4. Therefore `UserManager.getUserData()` iterates stale `Metrics` → `UserData` never contains
   the new MetricId → `updateUserGrid` push doesn't include it → widget shows "–" forever.

In a live CC with active agents, `refreshMetrics()` fires within seconds naturally.
In quiet environments it never fires → new column data never appears.

## Goal

After `LoadData()` finishes updating all union metrics, force all existing `UserManager`
instances to refresh their metric dictionaries and schedule a data recompute.

---

## File 1: `RTM/RTM/UserManager.cs`

### Change 1 — Add public `ForceRefreshMetrics()` method

Find:
```csharp
        // Refresh Metrics
        private void refreshMetrics()
        {      
            try
            { 
                Metrics = new ConcurrentDictionary<string, MetricDef>(UserViewMetrics);

                AsyncLogger.Info($"refreshMetrics UserId={userId} userUniuns.Count={userUniuns.Count()}");

                foreach (var union in userUniuns)
                {              
                    union.UserGridMetrics.ToList().ForEach(x => Metrics.TryAdd(x.Key, x.Value));
                }
            }
            catch (Exception ex)
```

Add AFTER the closing brace of `refreshMetrics()` (keep existing method unchanged):

```csharp
        /// <summary>
        /// Public entry point called by Engine.LoadData() after union metrics are updated.
        /// Rebuilds this UserManager's metric dictionary and marks it as changed so that
        /// the next CollectData cycle recomputes all metrics (including newly added columns).
        /// </summary>
        public void ForceRefreshMetrics()
        {
            try
            {
                refreshMetrics();
                IsChanged = true;
                AsyncLogger.Info($"ForceRefreshMetrics UserId={userId}");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ForceRefreshMetrics", ex);
            }
        }
```

---

## File 2: `RTM/RTM/Engine.cs`

### Change 2 — Call ForceRefreshMetrics on all UserManagers at end of LoadData

Find:
```csharp
                AsyncLogger.Info("LoadData End");
```

Replace with:
```csharp
                // Force all existing UserManagers to pick up newly added column metrics.
                // Without this, new metrics only appear after an agent's next workgroup event.
                AsyncLogger.Info("LoadData: ForceRefreshMetrics for all UserManagers");
                foreach (var userMng in _userManagerList.Values)
                {
                    userMng.ForceRefreshMetrics();
                }

                AsyncLogger.Info("LoadData End");
```

---

## Verification

```bash
# Build RTM project
dotnet build RTM/RTM.sln 2>&1 | tail -10

# ForceRefreshMetrics must be present in UserManager
grep -n "ForceRefreshMetrics\|public void ForceRefreshMetrics" RTM/RTM/UserManager.cs
# Expected: 2+ lines (declaration + call site in Engine)

# Engine calls it
grep -n "ForceRefreshMetrics" RTM/RTM/Engine.cs
# Expected: 1 line in LoadData

# Files end properly
tail -3 RTM/RTM/UserManager.cs
tail -3 RTM/RTM/Engine.cs
```

---

## Commit

```bash
bash tools/pre-commit-check.sh
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add RTM/RTM/UserManager.cs RTM/RTM/Engine.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(rtm-server): force UserManager metric refresh after LoadData — new columns appear immediately"
cp /tmp/cc-idx .git/index
git log --oneline -1
```
