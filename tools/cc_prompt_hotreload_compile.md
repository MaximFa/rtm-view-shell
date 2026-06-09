# CC Task: Hot-Reload Metrics — Engine incremental compile

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three files: proceed.

## Mandatory integrity check (§0.6a) — Step 0
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2-backend
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show v2-backend:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 5 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, WT=$WT_LINES)"
        git show v2-backend:"$f" > "$f" && echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync && echo "=== Integrity check complete ==="
```

## Multi-session sync — MANDATORY (§42)

Session slug: `backend-0609`
Claims: `RTM/RTM/Engine.cs, RTM/RTM/Union.cs, RTM/RTM/RTMAdapter.cs, RTM/RTM/RTMHub.cs`

### S1. Push barrier check
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE — STOP."; exit 1
fi
echo "S1-CLEAR"
```

### S2. Claim check
```bash
python3 tools/coord_check_claims.py backend-0609 RTM/RTM/Engine.cs RTM/RTM/Union.cs RTM/RTM/RTMAdapter.cs RTM/RTM/RTMHub.cs
# exit 1 -> STOP
```

## Context
Hot-reload metrics — Backend territory. Gate docs:
- docs/metrics-hot-reload-contract.md (FINAL v1.0)
- docs/metrics-apply-endpoint-contract.md

Contract:
- Shell sends EXACTLY `appliedRtMetricIds[]` (RT-only) from apply-endpoint response.
- Shell fires `compileMetrics(string[])` over RtmRelay HubConnection (Option A, fire-and-forget).
- RTM compiles ONLY passed MetricIds (incremental, additive). NO full scan/reload.
- Idempotent: ContainsKey → skip. Recompile (R2) = re-fire same method, no re-apply.
- History defense-in-depth: dotted MetricId → skip (contract guarantees RT-only on wire).
- Tenant-scope: RTM is 1:1 tenant (§33.1) — no TenantId param on this internal hub.
- RTM-SEC-002: no SQL routines in this task — not applicable.

## Step 1 — Read HEAD files + ASSERT symbol existence

```bash
git show v2-backend:RTM/RTM/Engine.cs > /tmp/engine_head.cs
git show v2-backend:RTM/RTM/Union.cs > /tmp/union_head.cs
git show v2-backend:RTM/RTM/RTMAdapter.cs > /tmp/rtmadapter_head.cs
git show v2-backend:RTM/RTM/RTMHub.cs > /tmp/rtmhub_head.cs
wc -l /tmp/engine_head.cs /tmp/union_head.cs /tmp/rtmadapter_head.cs /tmp/rtmhub_head.cs
```

**Assert symbols the patch relies on — STOP if any are absent:**
```bash
echo "=== Symbol assertions ==="

grep -n "private static Dictionary<string, MetricDef> _metrics" /tmp/engine_head.cs || \
    { echo "ASSERT FAIL: _metrics Declaration not found"; exit 1; }

grep -n "_metrics = RealtimeData.GetAllMetrics()" /tmp/engine_head.cs || \
    { echo "ASSERT FAIL: _metrics init not found"; exit 1; }

grep -n "private void setMetricFunctions(MetricDef" /tmp/engine_head.cs || \
    { echo "ASSERT FAIL: setMetricFunctions(MetricDef) overload not found — compile path invalid, stop and report"; exit 1; }

grep -n "private void setMetricFunctions()" /tmp/engine_head.cs || \
    { echo "ASSERT FAIL: setMetricFunctions() no-param anchor not found"; exit 1; }

grep -n "addDataMetric" /tmp/union_head.cs || \
    { echo "ASSERT FAIL: union.addDataMetric not found — compile path invalid, stop and report"; exit 1; }

grep -n "private Dictionary<string, MetricDef> AllDataMetrics" /tmp/union_head.cs || \
    { echo "ASSERT FAIL: AllDataMetrics Dictionary field not found"; exit 1; }

grep -n "public Union(int unionId, Dictionary<string, MetricDef> allDataMetrics)" /tmp/union_head.cs || \
    { echo "ASSERT FAIL: Union constructor Dictionary param not found"; exit 1; }

grep -n "public bool LoadData()" /tmp/rtmadapter_head.cs || \
    { echo "ASSERT FAIL: LoadData() anchor not found in RTMAdapter"; exit 1; }

echo "=== All symbol assertions PASSED ==="
```

## Step 2 — Engine.cs: 2 substitutions + HotReloadMetrics method

Write and run /tmp/patch_engine.py:

```python
import os

with open('/tmp/engine_head.cs', 'r', encoding='utf-8') as f:
    text = f.read()

# Change 1: _metrics field type
OLD1 = 'private static Dictionary<string, MetricDef> _metrics = null;'
NEW1 = 'private static ConcurrentDictionary<string, MetricDef> _metrics = null;'
assert OLD1 in text, "ASSERT FAIL: _metrics Dictionary declaration not found"
text = text.replace(OLD1, NEW1, 1)

# Change 2: _metrics initialisation in LoadData
OLD2 = '_metrics = RealtimeData.GetAllMetrics();'
NEW2 = '_metrics = new ConcurrentDictionary<string, MetricDef>(RealtimeData.GetAllMetrics());'
assert OLD2 in text, "ASSERT FAIL: _metrics = RealtimeData.GetAllMetrics() not found"
text = text.replace(OLD2, NEW2, 1)

# Change 3: add HotReloadMetrics before the no-param setMetricFunctions() overload
ANCHOR = '        private void setMetricFunctions()\n'
assert ANCHOR in text, "ASSERT FAIL: 'private void setMetricFunctions()' anchor not found"

HOT_RELOAD = '''
        /// <summary>
        /// Incrementally compiles ONLY the supplied RT MetricIds and adds them to the live engine.
        /// Called by RTMHub.compileMetrics (fire-and-forget, Option A) after Shell deploy.
        /// Idempotent: repeated call on the same MetricId is a safe no-op (skip-if-ContainsKey).
        /// Defense-in-depth: dotted ids (history metrics) skipped — contract guarantees RT-only on wire.
        /// </summary>
        public void HotReloadMetrics(string[] metricIds)
        {
            if (metricIds == null || metricIds.Length == 0) return;
            AsyncLogger.Info($"Engine.HotReloadMetrics: requested compile for {metricIds.Length} metric(s)");

            Dictionary<string, MetricDef> allDbMetrics;
            try { allDbMetrics = RealtimeData.GetAllMetrics(); }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.HotReloadMetrics: DB fetch failed", ex);
                return;
            }

            foreach (var metricId in metricIds)
            {
                // Defense-in-depth: skip history metrics (dotted id)
                if (metricId.Contains('.'))
                {
                    AsyncLogger.Warn($"Engine.HotReloadMetrics: skipping history metric id={metricId}");
                    continue;
                }

                // Idempotent: skip if already compiled
                if (_metrics != null && _metrics.ContainsKey(metricId))
                {
                    AsyncLogger.Info($"Engine.HotReloadMetrics: {metricId} already compiled, skip");
                    continue;
                }

                if (!allDbMetrics.TryGetValue(metricId, out MetricDef metric))
                {
                    AsyncLogger.Warn($"Engine.HotReloadMetrics: MetricId={metricId} not found in RTSGrid_Metric");
                    continue;
                }

                try
                {
                    setMetricFunctions(metric);
                    if (_metrics != null) _metrics.TryAdd(metricId, metric);

                    // Propagate to all active Unions so live grids see the new metric immediately
                    foreach (var union in UnionList.Values)
                        union.addDataMetric(metric);

                    AsyncLogger.Info($"Engine.HotReloadMetrics: compiled and registered {metricId}");
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error($"Engine.HotReloadMetrics: compile failed for {metricId}", ex);
                }
            }
        }

'''
text = text.replace(ANCHOR, HOT_RELOAD + ANCHOR, 1)

# Write to repo-relative path (CC runs native on Windows, cd'd into repo)
with open('RTM/RTM/Engine.cs', 'w', encoding='utf-8') as f:
    f.write(text); f.flush(); os.fsync(f.fileno())
print(f"Engine.cs written ({len(text.splitlines())} lines)")
```

```bash
python3 /tmp/patch_engine.py && sync
tail -3 RTM/RTM/Engine.cs
wc -l RTM/RTM/Engine.cs
grep -n "HotReloadMetrics\|ConcurrentDictionary.*_metrics\|ConcurrentDictionary.*GetAllMetrics" RTM/RTM/Engine.cs | head -10
```

## Step 3 — Union.cs: 2 substitutions

Write and run /tmp/patch_union.py:

```python
import os

with open('/tmp/union_head.cs', 'r', encoding='utf-8') as f:
    text = f.read()

OLD1 = 'private Dictionary<string, MetricDef> AllDataMetrics { get; set; } = new Dictionary<string, MetricDef>();'
NEW1 = 'private ConcurrentDictionary<string, MetricDef> AllDataMetrics { get; set; } = new ConcurrentDictionary<string, MetricDef>();'
assert OLD1 in text, "ASSERT FAIL: AllDataMetrics Dictionary field not found"
text = text.replace(OLD1, NEW1, 1)

OLD2 = 'public Union(int unionId, Dictionary<string, MetricDef> allDataMetrics)'
NEW2 = 'public Union(int unionId, ConcurrentDictionary<string, MetricDef> allDataMetrics)'
assert OLD2 in text, "ASSERT FAIL: Union constructor Dictionary param not found"
text = text.replace(OLD2, NEW2, 1)

with open('RTM/RTM/Union.cs', 'w', encoding='utf-8') as f:
    f.write(text); f.flush(); os.fsync(f.fileno())
print(f"Union.cs written ({len(text.splitlines())} lines)")
```

```bash
python3 /tmp/patch_union.py && sync
grep -n "ConcurrentDictionary.*AllDataMetrics\|ConcurrentDictionary.*allDataMetrics" RTM/RTM/Union.cs
```

## Step 4 — RTMAdapter.cs: add CompileMetrics bridge

Write and run /tmp/patch_adapter.py:

```python
import os

with open('/tmp/rtmadapter_head.cs', 'r', encoding='utf-8') as f:
    text = f.read()

ANCHOR = '        public bool LoadData()'
assert ANCHOR in text, "ASSERT FAIL: LoadData() not found in RTMAdapter.cs"

NEW_METHOD = '''        public void CompileMetrics(string[] metricIds)
        {
            _engine?.HotReloadMetrics(metricIds);
        }

'''
text = text.replace(ANCHOR, NEW_METHOD + ANCHOR, 1)

with open('RTM/RTM/RTMAdapter.cs', 'w', encoding='utf-8') as f:
    f.write(text); f.flush(); os.fsync(f.fileno())
print(f"RTMAdapter.cs written ({len(text.splitlines())} lines)")
```

```bash
python3 /tmp/patch_adapter.py && sync
grep -n "CompileMetrics\|HotReloadMetrics" RTM/RTM/RTMAdapter.cs
```

## Step 5 — RTMHub.cs: add compileMetrics hub method

Write and run /tmp/patch_hub.py:

```python
import os

with open('/tmp/rtmhub_head.cs', 'r', encoding='utf-8') as f:
    text = f.read()

# Find class closing brace (second-to-last closing brace block)
CLASS_CLOSE = '\n    }\n'
last_idx = text.rfind(CLASS_CLOSE)
assert last_idx != -1, "ASSERT FAIL: class closing brace not found in RTMHub.cs"

NEW_HUB = '''
        /// <summary>
        /// Triggered by Shell after successful metric deploy (Option A, metrics-hot-reload-contract.md §6).
        /// Fire-and-forget: failure is non-fatal; Shell Recompile affordance handles recovery (R2).
        /// Idempotent: same MetricId set can be re-fired without re-apply (skip-if-ContainsKey in Engine).
        /// Tenant-scope: this RTM instance is 1:1 with tenant (CLAUDE.md §33.1) — no TenantId param.
        /// </summary>
        public void compileMetrics(string[] metricIds)
        {
            if (metricIds == null || metricIds.Length == 0) return;
            AsyncLogger.Info($"RTMHub.compileMetrics: received {metricIds.Length} MetricId(s): {string.Join(", ", metricIds)}");
            // Fire-and-forget — failure logged; Shell offers Recompile for recovery (R2)
            Task.Run(() => _hubAdapter.CompileMetrics(metricIds))
                .ContinueWith(
                    t => AsyncLogger.Error("RTMHub.compileMetrics: unhandled exception", t.Exception!.InnerException),
                    TaskContinuationOptions.OnlyOnFaulted);
        }

'''
text = text[:last_idx] + NEW_HUB + text[last_idx:]

with open('RTM/RTM/RTMHub.cs', 'w', encoding='utf-8') as f:
    f.write(text); f.flush(); os.fsync(f.fileno())
print(f"RTMHub.cs written ({len(text.splitlines())} lines)")
```

```bash
python3 /tmp/patch_hub.py && sync
grep -n "compileMetrics\|CompileMetrics" RTM/RTM/RTMHub.cs
tail -5 RTM/RTM/RTMHub.cs
```

## Step 6 — Build verification

```bash
dotnet build RTM/RTM/RTM.csproj -c Release --no-restore 2>&1 | tail -20
# Must show: Build succeeded. 0 Error(s)
# On ConcurrentDictionary type mismatch: check Union constructor call sites in Engine.cs
# (new Union(id, _metrics) — _metrics is now ConcurrentDict, constructor param matches)
```

## Step 7 — Pre-commit check + commit (§42.4 lock via sync_block S3)

```bash
bash tools/pre-commit-check.sh RTM/RTM/Engine.cs RTM/RTM/Union.cs RTM/RTM/RTMAdapter.cs RTM/RTM/RTMHub.cs
# Exit code MUST be 0 — if not, restore from HEAD and re-patch
```

S3 — acquire commit.lock (phantom-aware):
```python
# Save as /tmp/acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
def real_lock():
    try:
        with open(lock) as f: return f.read().strip() != ""
    except OSError: return False
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: backend-0609\nacquired: "
                    + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        if not real_lock():
            print("PHANTOM lock — clearing")
            try: os.remove(lock)
            except OSError: pass
            time.sleep(2); continue
        print("BUSY: " + open(lock).read().strip()); time.sleep(60)
print("FAILED after 5 attempts"); sys.exit(1)
```

```bash
python3 /tmp/acquire_lock.py
# Then commit:
cp .git/index /tmp/cc-idx-hr
GIT_INDEX_FILE=/tmp/cc-idx-hr git add RTM/RTM/Engine.cs RTM/RTM/Union.cs RTM/RTM/RTMAdapter.cs RTM/RTM/RTMHub.cs
GIT_INDEX_FILE=/tmp/cc-idx-hr git commit -m "rtm: hot-reload metrics — Engine.HotReloadMetrics + RTMHub.compileMetrics (incremental compile, ConcurrentDict)"
cp /tmp/cc-idx-hr .git/index
```

## Step 8 — Post-commit verification + wrapper (§0.6 + S4)

```bash
git status --short
git diff v2-backend -- RTM/RTM/Engine.cs RTM/RTM/Union.cs RTM/RTM/RTMAdapter.cs RTM/RTM/RTMHub.cs
# Expected: empty

# S4 — mandatory wrapper (journal + coordinator flush + lock release)
bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)
sync
```

## Step 9 — Re-sync from HEAD (PD-007)

```bash
for f in RTM/RTM/Engine.cs RTM/RTM/Union.cs RTM/RTM/RTMAdapter.cs RTM/RTM/RTMHub.cs; do
    git show v2-backend:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Git push
Do NOT run `git push`. Commit only. Push requested separately.

## Report
- Commit hash
- Line counts: Engine.cs before/after, Union.cs, RTMAdapter.cs, RTMHub.cs
- Build result (0 errors, warnings if any)
- grep: HotReloadMetrics in Engine.cs + RTMAdapter.cs; compileMetrics in RTMHub.cs
