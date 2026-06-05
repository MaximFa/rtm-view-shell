# CC Task: Fix ArgumentOutOfRangeException in ScheduleNextCheck — DateTime.MaxValue guard

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push` automatically. Commit only.

---

## Problem

`RTM/RTM/Engine.cs` crashes at startup with:
```
ArgumentOutOfRangeException: dueTime ('251621635242169') must be <= 4294967294
  at ScheduleNextCheck() line 1029
  at startMidnightTimer() line 978
  at Engine..ctor() line 352
```

**Root cause:**
- `GetNextClearTime()` returns `DateTime` (not `DateTime?`)
- When `UnionList` is empty at startup, the `foreach` never executes
- Result: returns `DateTime.MaxValue`
- `ScheduleNextCheck` assigns it to `DateTime?` — always `.HasValue == true`
- Null check `!nextClearTime.HasValue` never triggers
- `dueTime = DateTime.MaxValue - DateTime.Now` ≈ 9000 years in ms
- Exceeds `Timer` limit of 4,294,967,294 ms (~49.7 days) → crash

---

## Fix — Engine.cs

File: `RTM/RTM/Engine.cs`

In `ScheduleNextCheck()`, find the block after `GetNextClearTime()`:

```csharp
DateTime? nextClearTime = GetNextClearTime();

if (!nextClearTime.HasValue)
{
    AsyncLogger.Error("ScheduleNextCheck | nextClearTime is null", null);
    return;
}

var now = DateTime.Now;
TimeSpan dueTime = nextClearTime.Value - now;
```

Replace with:

```csharp
DateTime? nextClearTime = GetNextClearTime();

if (!nextClearTime.HasValue || nextClearTime.Value == DateTime.MaxValue)
{
    AsyncLogger.Info("ScheduleNextCheck | no unions loaded yet, timer skipped");
    return;
}

var now = DateTime.Now;
TimeSpan dueTime = nextClearTime.Value - now;

// Safety cap: Timer max is ~49.7 days (4294967294 ms)
var maxDue = TimeSpan.FromMilliseconds(4_294_967_294);
if (dueTime > maxDue)
{
    AsyncLogger.Warn($"ScheduleNextCheck | dueTime {dueTime.TotalDays:F1}d exceeds Timer max, capping to 49d");
    dueTime = maxDue;
}
```

The safety cap handles any future case where a valid clear time is > 49 days away.

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Write fix using Python atomic write + fsync (Edit tool BANNED)
4. Build: `dotnet build RTM/RTM/RTM.csproj` — 0 errors
5. `bash tools/pre-commit-check.sh RTM/RTM/Engine.cs`
6. Commit: `fix: ScheduleNextCheck guards DateTime.MaxValue and caps dueTime to Timer limit`
7. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
git show HEAD:"RTM/RTM/Engine.cs" > "RTM/RTM/Engine.cs"
echo "Re-synced: RTM/RTM/Engine.cs ($(wc -l < RTM/RTM/Engine.cs) lines)"
sync
```
