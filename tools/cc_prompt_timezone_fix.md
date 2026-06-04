# CC Task: Fix getLocalDateTime for named timezone strings

## Problem

`IDInteraction.getLocalDateTime()` and `UserManager.getLocalDateTime()` crash with:
```
System.FormatException: String 'Israel' was not recognized as a valid TimeSpan.
```

The `TimeZone` field contains Windows timezone IDs (e.g. `"Israel"`, `"UTC"`, `"US Eastern Standard Time"`)
in addition to UTC offset strings (e.g. `"+03:00"`, `"-05:00"`).

Current code:
```csharp
TimeSpan offset = TimeSpan.Parse(TimeZone.Replace("+", "").Replace("-", ""));
```

This only works for offset format. Fails for named timezone IDs.

## Fix

In BOTH files:
- `RTM/RTM/IDInteraction.cs` (line ~259)
- `RTM/RTM/UserManager.cs` (line ~180)

Replace the `TimeSpan.Parse` line with a helper that tries:
1. Parse as offset string (`+03:00` format) — existing behavior
2. Fallback: `TimeZoneInfo.FindSystemTimeZoneById(TimeZone)` → get UTC offset
3. If both fail: return UTC, log as DEBUG (not ERROR)

New implementation:

```csharp
public DateTime getLocalDateTime()
{
    DateTime localTime = DateTime.UtcNow;

    if (string.IsNullOrWhiteSpace(TimeZone))
        return localTime;

    try
    {
        TimeSpan offset;

        // Try offset format first: "+03:00", "-05:00", "03:00"
        string cleaned = TimeZone.Trim();
        bool negative = cleaned.StartsWith("-");
        string stripped = cleaned.TrimStart('+').TrimStart('-');

        if (TimeSpan.TryParse(stripped, out offset))
        {
            if (negative) offset = offset.Negate();
        }
        else
        {
            // Fallback: Windows / IANA timezone ID (e.g. "Israel", "UTC")
            var tzi = TimeZoneInfo.FindSystemTimeZoneById(TimeZone);
            offset = tzi.GetUtcOffset(DateTime.UtcNow);
        }

        localTime = localTime.Add(offset);
    }
    catch
    {
        // Unknown timezone format — return UTC silently
    }

    return localTime;
}
```

## Rules (MANDATORY)

- Work ONLY in `RTM/` directory — do NOT touch `src/` or `tests/`
- Edit tool is BANNED — all file writes via Python atomic read→modify→write + `os.fsync()`
- Before commit: `bash tools/pre-commit-check.sh`
- After commit: `git status --short` must be empty

## Steps

**1. Session-resume integrity check (§0.2)**
```bash
git status --short
git log --oneline -3
```

**2. Fix IDInteraction.cs**

Find `getLocalDateTime()` method (~line 253) and replace its body with the implementation above.
Keep the method signature unchanged.

**3. Fix UserManager.cs**

Find `getLocalDateTime()` method (~line 175) and apply the same replacement.

**4. Verify both files compile (build check)**
```powershell
cd RTM
dotnet build RTM\RTM.csproj -c Release --no-restore 2>&1 | tail -5
```

**5. Commit**
```bash
bash tools/pre-commit-check.sh RTM/RTM/IDInteraction.cs RTM/RTM/UserManager.cs
```

Commit message:
```
fix(RTM): handle named timezone IDs in getLocalDateTime

TimeZone field contains both UTC offsets (+03:00) and Windows timezone
IDs (Israel, UTC, US Eastern Standard Time). Added TryParse fallback
via TimeZoneInfo.FindSystemTimeZoneById. Unknown formats return UTC
silently instead of logging FormatException as ERROR.
```

**6. Re-sync from HEAD (§0.6 PD-007)**
```bash
for f in RTM/RTM/IDInteraction.cs RTM/RTM/UserManager.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
