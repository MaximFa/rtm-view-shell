# CC Task: Run UserWidgetSettings tests

## Git push
Do NOT run `git push`.

---

## Step 0 — Integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"; git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== OK ==="
```

---

## Step 1 — Check Docker is running

```powershell
docker info 2>&1 | Select-Object -First 3
```

If Docker is NOT running (error output) — start Docker Desktop and wait 30 seconds, then retry.
If Docker is running — proceed to Step 2.

---

## Step 2 — Run UserWidgetSettings tests

```powershell
cd "D:\Claude\Projects\RTM View Shell"
dotnet test tests/CcDashboard.Tests.Security `
  --filter "FullyQualifiedName~UserWidgetSettings" `
  --logger "console;verbosity=detailed" `
  2>&1
```

---

## Expected result

```
Passed! - Failed: 0, Passed: 8, Skipped: 0
```

**If all 8 pass:** report success with test names.

**If any fail:** report the FULL error output for each failing test.
Do NOT commit or push. Do NOT try to fix anything — report results only.

---

## Step 3 — If all pass: run full security test suite to check no regressions

```powershell
dotnet test tests/CcDashboard.Tests.Security `
  --logger "console;verbosity=minimal" `
  2>&1 | Select-Object -Last 10
```

Report: total passed/failed count.
