# CC Task: Fix NaN display in AgentGrid and QueueGrid widgets

## Problem
Metrics like `MonAgentTalkDurationPct` (TotalStatusGroupPercent) show **NaN** at the start
of a shift when the agent has not yet taken any call: `ONPHONE_time / total_login_time * 100`
with `total_login_time = 0` → division by zero → RTM sends the string `"NaN"`.
User wants to see `"-"` instead.

## Fix
Add a NaN guard at the top of `FormatTimeString` in both widgets. One line per file.

## Files
1. `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`
2. `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Environment rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — bash tools/pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change 1 — AgentGridWidget.razor

Find this exact block (FormatTimeString method):
```csharp
    private static string FormatTimeString(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;
        var parts = value.Split(':');
```

Replace with:
```csharp
    private static string FormatTimeString(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;
        if (value == "NaN" || value == "Infinity" || value == "-Infinity") return "-";
        var parts = value.Split(':');
```

## Change 2 — QueueGridWidget.razor

Find this exact block (FormatTimeString method):
```csharp
    private static string FormatTimeString(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;
        var parts = value.Split(':');
```

Replace with:
```csharp
    private static string FormatTimeString(string value)
    {
        if (string.IsNullOrEmpty(value)) return value;
        if (value == "NaN" || value == "Infinity" || value == "-Infinity") return "-";
        var parts = value.Split(':');
```

---

## Verification

```bash
grep -n "NaN.*Infinity" \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Must show 1 match per file
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  tools/cc_prompt_fix_nan_display.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: display '-' instead of NaN for zero-denominator percent metrics"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

---

## Re-sync from HEAD (§0.6 PD-007, mandatory last step)

```bash
for f in src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
          src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
          tools/cc_prompt_fix_nan_display.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
