# CC TASK: RTM Security Fixes -- F-1 (Parameter/Format whitelist) + F-3 (RTMHub token auth)
# Session: backend-0609 | Branch: v2-backend
# Claims: RTM/RTM/Engine.cs, RTM/RTM/RTMHub.cs

## Mandatory -- read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three files: proceed with the task below.

---

## §0.6a Mandatory integrity check (FIRST STEP, NO EXCEPTIONS)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 5 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF lines)"
        git show HEAD:"$f" > "$f"
        echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync
echo "=== Integrity check complete ==="
```

---

## Step 1: Pre-flight -- claims + symbol asserts

```bash
cd "D:\Claude\Projects\RTM View Shell"

python3 tools/coord_check_claims.py backend-0609 RTM/RTM/Engine.cs RTM/RTM/RTMHub.cs
# Must print: OK: no claim conflicts

grep -c "ValidateMetricSafetyForHotReload" RTM/RTM/Engine.cs
# Must be 0 (not already patched)

grep -n "setMetricFunctions(metric);" RTM/RTM/Engine.cs
# Must find exactly 1 match inside HotReloadMetrics

grep -n "void setMetricFunctions(MetricDef" RTM/RTM/Engine.cs
# Must find 1 match

grep -n "public void HotReloadMetrics" RTM/RTM/Engine.cs
# Must find 1 match

grep -n "OnConnectedAsync" RTM/RTM/RTMHub.cs
# Must find at least 1 match

grep -n "public RTMHub(" RTM/RTM/RTMHub.cs
# Must show single-arg constructor: public RTMHub(RTMAdapter hubAdapter)

grep -c "CryptographicOperations" RTM/RTM/RTMHub.cs
# Must be 0 (not already patched)

echo "=== All asserts OK ==="
```

---

## Step 2: Read HEAD snapshots

```bash
cd "D:\Claude\Projects\RTM View Shell"
git show HEAD:RTM/RTM/Engine.cs > /tmp/engine_head.cs
git show HEAD:RTM/RTM/RTMHub.cs > /tmp/rtmhub_head.cs
echo "Engine.cs HEAD: $(wc -l < /tmp/engine_head.cs) lines"
echo "RTMHub.cs HEAD:  $(wc -l < /tmp/rtmhub_head.cs) lines"
```

---

## Step 3: F-1 -- Engine.cs patch

Write this script to /tmp/patch_engine.py and run it:

```
import os, sys

with open("RTM/RTM/Engine.cs", "r", encoding="utf-8") as f:
    text = f.read()

if "ValidateMetricSafetyForHotReload" in text:
    print("ERROR: F-1 already applied. Aborting.")
    sys.exit(1)

ANCHOR_A = "        public void HotReloadMetrics(string[] metricIds)"
assert ANCHOR_A in text, "ASSERT FAILED: HotReloadMetrics anchor not found"

# Validator block inserted before HotReloadMetrics
VALIDATOR = (
    "        // F-1 SECURITY: Parameter/Format whitelist (hot-reload path only)\n"
    "        // Note: startup setMetricFunctions() is NOT gated here -- it uses curated seed data.\n"
    "        private static readonly System.Text.RegularExpressions.Regex _safeParamRegex =\n"
    '            new System.Text.RegularExpressions.Regex(\n'
    '                @"^[\\w\\s\\.\\=\\!\\&\\|\\<\\>\\+\\-\\*\\%\\,\\"\\\'\\(\\)\\/\\?:]+$",\n'
    "                System.Text.RegularExpressions.RegexOptions.Compiled);\n"
    "\n"
    "        private static readonly System.Text.RegularExpressions.Regex _safeFormatRegex =\n"
    '            new System.Text.RegularExpressions.Regex(\n'
    '                @"^[\\w\\{\\}\\:\\.\\#\\,\\s\\-\\%\\+]*$",\n'
    "                System.Text.RegularExpressions.RegexOptions.Compiled);\n"
    "\n"
    "        private static readonly string[] _forbiddenCompileKeywords = new[] {\n"
    '            "typeof", "Assembly", "Reflection", "Process", "File.", "Directory.",\n'
    '            "Environment.", "Thread", "Task.", "Delegate", "Emit", "Activator",\n'
    '            "AppDomain", "Marshal", "Unsafe", "GC.", "dynamic", "var ", "return ",\n'
    '            "throw ", "new ", "using ", "#", "//", "/*"\n'
    "        };\n"
    "\n"
    "        private const int MaxMetricParameterLength = 500;\n"
    "        private const int MaxMetricFormatLength    = 50;\n"
    "\n"
    "        /// <summary>\n"
    "        /// Validates Parameter and Format before Roslyn compilation.\n"
    "        /// Returns false (and logs error) if value could escape the expression sandbox.\n"
    "        /// Called ONLY from HotReloadMetrics (runtime path), not startup compile.\n"
    "        /// </summary>\n"
    "        private bool ValidateMetricSafetyForHotReload(MetricDef metric, string metricId)\n"
    "        {\n"
    '            string param = metric.Parameter ?? "";\n'
    '            string fmt   = metric.Format   ?? "";\n'
    "\n"
    "            if (param.Length > MaxMetricParameterLength)\n"
    "            {\n"
    "                AsyncLogger.Error(\n"
    '                    $"HotReloadMetrics: SAFETY REJECT MetricId={metricId} -- "\n'
    '                    + $"Parameter too long ({param.Length} > {MaxMetricParameterLength})");\n'
    "                return false;\n"
    "            }\n"
    "            if (fmt.Length > MaxMetricFormatLength)\n"
    "            {\n"
    "                AsyncLogger.Error(\n"
    '                    $"HotReloadMetrics: SAFETY REJECT MetricId={metricId} -- "\n'
    '                    + $"Format too long ({fmt.Length} > {MaxMetricFormatLength})");\n'
    "                return false;\n"
    "            }\n"
    "            if (param.Length > 0 && !_safeParamRegex.IsMatch(param))\n"
    "            {\n"
    "                AsyncLogger.Error(\n"
    '                    $"HotReloadMetrics: SAFETY REJECT MetricId={metricId} -- Parameter contains unsafe characters");\n'
    "                return false;\n"
    "            }\n"
    "            if (fmt.Length > 0 && !_safeFormatRegex.IsMatch(fmt))\n"
    "            {\n"
    "                AsyncLogger.Error(\n"
    '                    $"HotReloadMetrics: SAFETY REJECT MetricId={metricId} -- Format contains unsafe characters");\n'
    "                return false;\n"
    "            }\n"
    "            string combined = (param + \" \" + fmt).ToLowerInvariant();\n"
    "            foreach (var kw in _forbiddenCompileKeywords)\n"
    "            {\n"
    "                if (combined.Contains(kw.ToLowerInvariant()))\n"
    "                {\n"
    "                    AsyncLogger.Error(\n"
    '                        $"HotReloadMetrics: SAFETY REJECT MetricId={metricId} -- forbidden keyword in Parameter/Format");\n'
    "                    return false;\n"
    "                }\n"
    "            }\n"
    "            return true;\n"
    "        }\n"
    "        // end F-1 validator\n"
    "\n"
)
text = text.replace(ANCHOR_A, VALIDATOR + ANCHOR_A)

# Patch B: call validator before setMetricFunctions
OLD_B = "                    setMetricFunctions(metric);"
count = text.count(OLD_B)
assert count == 1, f"Expected 1 occurrence of setMetricFunctions anchor, got {count}"

NEW_B = (
    "                    // F-1: validate before Roslyn compile (fail-closed)\n"
    "                    if (!ValidateMetricSafetyForHotReload(metric, metricId))\n"
    "                    {\n"
    "                        AsyncLogger.Error(\n"
    '                            $"HotReloadMetrics: MetricId={metricId} rejected by safety validator");\n'
    "                        continue;\n"
    "                    }\n"
    "                    setMetricFunctions(metric);"
)
text = text.replace(OLD_B, NEW_B)

with open("RTM/RTM/Engine.cs", "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Engine.cs written OK -- {len(text.splitlines())} lines")
print("Validator occurrences:", text.count("ValidateMetricSafetyForHotReload"))
```

```bash
cd "D:\Claude\Projects\RTM View Shell"
python3 /tmp/patch_engine.py && sync && tail -5 RTM/RTM/Engine.cs && wc -l RTM/RTM/Engine.cs
```

---

## Step 4: F-3 -- RTMHub.cs patch

Write this script to /tmp/patch_rtmhub.py and run it.

```
import os, re, sys

with open("RTM/RTM/RTMHub.cs", "r", encoding="utf-8") as f:
    text = f.read()

if "CryptographicOperations" in text:
    print("ERROR: F-3 already applied. Aborting.")
    sys.exit(1)

# Add usings after "using Microsoft.AspNetCore.SignalR;"
OLD_U = "using Microsoft.AspNetCore.SignalR;"
assert OLD_U in text, "ASSERT: SignalR using not found"
NEW_U = (
    "using Microsoft.AspNetCore.SignalR;\n"
    "using Microsoft.Extensions.Configuration;\n"
    "using System.Security.Cryptography;\n"
    "using System.Text;"
)
text = text.replace(OLD_U, NEW_U, 1)

# Add _hubToken field after _hubAdapter field
OLD_F = "        private RTMAdapter _hubAdapter;"
assert OLD_F in text, "ASSERT: _hubAdapter field not found"
NEW_F = (
    "        private RTMAdapter _hubAdapter;\n"
    "        private readonly string _hubToken; // F-3: connection auth token"
)
text = text.replace(OLD_F, NEW_F, 1)

# Update constructor to accept IConfiguration and init _hubToken
OLD_CTOR = (
    "        public RTMHub(RTMAdapter hubAdapter)\n"
    "        {\n"
    "            _hubAdapter = hubAdapter;\n"
    "        }"
)
NEW_CTOR = (
    "        public RTMHub(RTMAdapter hubAdapter, IConfiguration configuration)\n"
    "        {\n"
    "            _hubAdapter = hubAdapter;\n"
    '            _hubToken = configuration["RTM:HubToken"] ?? ""; // F-3\n'
    "        }"
)
assert OLD_CTOR in text, "ASSERT: RTMHub constructor body not found"
text = text.replace(OLD_CTOR, NEW_CTOR, 1)

# Replace OnConnectedAsync
# Find existing body via regex (single {} block)
pattern = r'        public override async Task OnConnectedAsync\(\)\s*\{[^{}]*\}'
m = re.search(pattern, text, re.DOTALL)
if not m:
    # Literal fallback
    OLD_OCA = (
        "        public override async Task OnConnectedAsync()\n"
        "        {\n"
        "            string connectionId = Context.ConnectionId;\n"
        '            AsyncLogger.Info("OnConnected ConnectionId=" + connectionId);\n'
        "            await base.OnConnectedAsync();\n"
        "        }"
    )
    assert OLD_OCA in text, "ASSERT: OnConnectedAsync literal not found"
    old_block = OLD_OCA
else:
    old_block = m.group(0)

NEW_OCA = (
    "        public override async Task OnConnectedAsync()\n"
    "        {\n"
    "            string connectionId = Context.ConnectionId;\n"
    "\n"
    "            // F-3: bearer-token validation -- fail-closed\n"
    "            if (string.IsNullOrWhiteSpace(_hubToken))\n"
    "            {\n"
    '                AsyncLogger.Error($"RTMHub: RTM:HubToken not configured -- rejecting {connectionId}");\n'
    "                Context.Abort();\n"
    "                return;\n"
    "            }\n"
    "\n"
    '            string? authHeader = Context.GetHttpContext()?.Request.Headers["Authorization"].FirstOrDefault();\n'
    "            bool authorized = false;\n"
    "            if (!string.IsNullOrEmpty(authHeader) &&\n"
    '                authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))\n'
    "            {\n"
    '                string provided = authHeader["Bearer ".Length..];\n'
    "                byte[] expectedBytes = Encoding.UTF8.GetBytes(_hubToken);\n"
    "                byte[] providedBytes = Encoding.UTF8.GetBytes(provided);\n"
    "                authorized = expectedBytes.Length == providedBytes.Length\n"
    "                    && CryptographicOperations.FixedTimeEquals(expectedBytes, providedBytes);\n"
    "            }\n"
    "\n"
    "            if (!authorized)\n"
    "            {\n"
    '                AsyncLogger.Error($"RTMHub: invalid/missing Bearer token -- rejecting {connectionId}");\n'
    "                Context.Abort();\n"
    "                return;\n"
    "            }\n"
    "\n"
    '            AsyncLogger.Info($"RTMHub: authorized connection {connectionId}");\n'
    "            await base.OnConnectedAsync();\n"
    "        }"
)
text = text.replace(old_block, NEW_OCA, 1)

with open("RTM/RTM/RTMHub.cs", "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"RTMHub.cs written OK -- {len(text.splitlines())} lines")
print("CryptographicOperations count:", text.count("CryptographicOperations"))
```

```bash
cd "D:\Claude\Projects\RTM View Shell"
python3 /tmp/patch_rtmhub.py && sync && tail -5 RTM/RTM/RTMHub.cs && wc -l RTM/RTM/RTMHub.cs
```

**Cross-session dependency (for shell-0609):**
RtmRelayService must pass hub token when connecting. Shell config key: RtmHub:Token.
Must match RTM RTM:HubToken. Provisioned by devops per server.

```csharp
// In RtmRelayService, when building HubConnection:
var hubToken = _configuration["RtmHub:Token"] ?? "";
var conn = new HubConnectionBuilder()
    .WithUrl(hubUrl, opts =>
    {
        if (!string.IsNullOrWhiteSpace(hubToken))
            opts.Headers.Add("Authorization", $"Bearer {hubToken}");
    })
    .Build();
```

---

## Step 5: Build verify

```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build RTM/RTM/RTM.csproj --no-restore -c Release 2>&1 | tail -15
# Must end: Build succeeded. 0 Error(s)
# If errors: report verbatim and STOP -- do NOT commit
```

---

## Step 6: Pre-commit check (§0.5 MANDATORY)

```bash
cd "D:\Claude\Projects\RTM View Shell"
bash tools/pre-commit-check.sh RTM/RTM/Engine.cs RTM/RTM/RTMHub.cs
# Must exit 0 -- if exit 1: restore from HEAD, retry write
```

---

## Step 7: Commit with §42.4 lock

**S3 -- Acquire commit.lock** (save as /tmp/acquire_lock.py):

```
import os, time, sys

lock = ".coord/locks/commit.lock"
os.makedirs(os.path.dirname(lock), exist_ok=True)

for attempt in range(5):
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        body = f"holder: backend-0609\ntask: rtm-security-f1f3\nacquired: {time.strftime('%Y-%m-%dT%H:%MZ', time.gmtime())}\n"
        os.write(fd, body.encode())
        os.fsync(fd)
        os.close(fd)
        print(f"Lock acquired attempt={attempt+1}")
        sys.exit(0)
    except FileExistsError:
        try:
            with open(lock) as lf: body = lf.read().strip()
        except Exception: body = ""
        if not body:
            os.unlink(lock)
            print("Phantom lock cleared, retrying...")
            continue
        print(f"Lock held: {body}")
        if attempt < 4:
            print(f"Waiting 60s (attempt {attempt+1}/5)...")
            time.sleep(60)
        else:
            print("ABORT: lock held too long")
            sys.exit(1)
```

```bash
cd "D:\Claude\Projects\RTM View Shell"
python3 /tmp/acquire_lock.py

cp .git/index /tmp/cc-sec-idx
GIT_INDEX_FILE=/tmp/cc-sec-idx git add RTM/RTM/Engine.cs RTM/RTM/RTMHub.cs
GIT_INDEX_FILE=/tmp/cc-sec-idx git commit -m "rtm: F-1 Parameter/Format whitelist + F-3 RTMHub bearer-token auth"
cp /tmp/cc-sec-idx .git/index
```

**S4 -- Release lock + journal:**

```bash
cd "D:\Claude\Projects\RTM View Shell"
bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)
```

---

## Step 8: Post-commit verification (§0.6, NO EXCEPTIONS)

```bash
cd "D:\Claude\Projects\RTM View Shell"

git status --short
# Must be empty

git diff HEAD -- RTM/RTM/Engine.cs RTM/RTM/RTMHub.cs
# Must be empty

git show HEAD:RTM/RTM/Engine.cs | wc -l && wc -l RTM/RTM/Engine.cs
# Both numbers must match

git show HEAD:RTM/RTM/RTMHub.cs | wc -l && wc -l RTM/RTM/RTMHub.cs
# Both numbers must match

git log --oneline -3
```

---

## Step 9: Re-sync (§0.6 PD-007)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in RTM/RTM/Engine.cs RTM/RTM/RTMHub.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
echo "=== Re-sync complete ==="
```

---

## Step 10: Report to coordinator

After commit, append to .coord/inbox/coordinator.md via Python+fsync:

```
import os, time

path = ".coord/inbox/coordinator.md"
ts = time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime())
import subprocess
h = subprocess.check_output(["git","log","-1","--format=%h"]).decode().strip()
block = (
    f"\n## {ts} | from: backend-0609 | to: coordinator\n\n"
    f"F-1 + F-3 commit DONE: {h}\n\n"
    f"F-1 (Engine.cs): ValidateMetricSafetyForHotReload() added before setMetricFunctions(metric) in HotReloadMetrics.\n"
    f"  - whitelist regex for Parameter + Format\n"
    f"  - forbidden keyword list (Assembly, Reflection, Process, File, etc)\n"
    f"  - length limits (500 / 50)\n"
    f"  - fail-closed: continue (skip compile) on reject\n\n"
    f"F-3 (RTMHub.cs): OnConnectedAsync bearer-token validation.\n"
    f"  - IConfiguration injected, _hubToken read from RTM:HubToken\n"
    f"  - CryptographicOperations.FixedTimeEquals constant-time compare\n"
    f"  - Fail-closed: Context.Abort() on missing config OR wrong token\n\n"
    f"Cross-dep: shell-0609 must add Authorization: Bearer <RtmHub:Token> to RtmRelayService HubConnectionBuilder.\n"
    f"Build: 0 errors.\n"
    f"Ready for security-0609 review.\n"
)
with open(path, "a", encoding="utf-8") as fh:
    fh.write(block)
    fh.flush()
    os.fsync(fh.fileno())
print(f"Flushed report to coordinator inbox")
```

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.
