# Task: Fix RTM publish error and produce deployment package

## Goal

`.\RTM\deployment\Publish-RTM.ps1` fails with exit code 1.
Diagnose the error, fix it, and produce a working publish output in `RTM\deployment\publish\`.

## Working directory

`D:\Claude\Projects\RTM View Shell`

## Step 1 — Diagnose

Run directly to see the full error:

```powershell
dotnet publish RTM\RTM\RTM.csproj -c Release -r win-x64 --self-contained true -o RTM\deployment\publish 2>&1
```

Also check build errors:

```powershell
dotnet build RTM\RTM\RTM.csproj -c Release 2>&1
```

## Step 2 — Fix

Fix whatever errors are reported. Typical causes:
- Missing NuGet packages → `dotnet restore RTM\RTM\RTM.csproj`
- Compilation errors → fix the C# code
- Missing project references → fix `.csproj`

**File write rules:** use Python + `os.fsync()` for ALL writes. Edit tool is BANNED.
After every write: `sync && tail -3 <path> && wc -l <path>`

## Step 3 — Publish

After fixing, run publish again and confirm success:

```powershell
dotnet publish RTM\RTM\RTM.csproj -c Release -r win-x64 --self-contained true -o RTM\deployment\publish
```

Verify key files exist in output:
```powershell
Test-Path "RTM\deployment\publish\RTM.exe"
Test-Path "RTM\deployment\publish\RTM.dll"
```

## Pre-commit check (MANDATORY if any code was changed)

```bash
bash tools/pre-commit-check.sh
```
Only commit if exit code 0.

## Post-commit re-sync (MANDATORY if committed)

```bash
for f in <changed files>; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
