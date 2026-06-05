# CC Task: Service not found — log as Warning, not Error

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Problem

`RTMAdapter.cs` logs `ERROR Failed to restart RTMView.Nayax` with full stack trace
when the service doesn't exist. Should be a clean `WARN` with no stack trace.

---

## Fix — RTMAdapter.cs

File: `RTM/RTM/RTMAdapter.cs`

Find this catch block (~line 87):

```csharp
                    catch (Exception ex)
                    {
                        AsyncLogger.Error($"Failed to restart {AppConfig.AdapterServiceName}", ex);
                        // Do NOT re-throw — missing service name is non-fatal in dev
                    }
```

Replace with:

```csharp
                    catch (InvalidOperationException ex)
                        when (ex.InnerException is System.ComponentModel.Win32Exception w32
                              && w32.NativeErrorCode == 1060)
                    {
                        AsyncLogger.Warn(
                            $"Service '{AppConfig.AdapterServiceName}' not found on this machine — skipped (non-fatal)");
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error($"Failed to restart {AppConfig.AdapterServiceName}", ex);
                        // Do NOT re-throw — missing service name is non-fatal in dev
                    }
```

Win32 error 1060 = `ERROR_SERVICE_DOES_NOT_EXIST`. The pattern catch filters exactly this case.
No changes to `WindowsServiceHelper.cs` needed.

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Write fix via Python atomic write + fsync (Edit tool BANNED)
4. `dotnet build RTM/RTM/RTM.csproj` — 0 errors
5. `bash tools/pre-commit-check.sh RTM/RTM/RTMAdapter.cs`
6. Commit: `fix: log WARN instead of ERROR when adapter service not found (Win32 1060)`
7. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
git show HEAD:"RTM/RTM/RTMAdapter.cs" > "RTM/RTM/RTMAdapter.cs"
echo "Re-synced: RTM/RTM/RTMAdapter.cs ($(wc -l < RTM/RTM/RTMAdapter.cs) lines)"
sync
```
