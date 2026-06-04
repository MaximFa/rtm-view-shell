# CC Task: Fix NuGet version conflict — NewtonsoftJson 10.0.8 → 8.0.16

## MANDATORY RULES (CLAUDE.md §0)

§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `sync && tail -3 <path> && wc -l <path>`
§0.5 — Before commit: `bash tools/pre-commit-check.sh` (exit 0)

---

## Problem

Build fails with NU1605 (downgrade warning treated as error):

  CcDashboard.Infrastructure references
    Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson 10.0.8
  CcDashboard.Web references
    Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson 8.0.16

Project targets .NET 8. Version 10.0.8 was added by mistake (latest at install time).
Fix: downgrade to 8.0.16 to match the rest of the solution.

---

## Change

**File:** `src/CcDashboard.Infrastructure/CcDashboard.Infrastructure.csproj`

Find:
```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson" Version="10.0.8" />
```
Replace with:
```xml
<PackageReference Include="Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson" Version="8.0.16" />
```

---

## Verification

```bash
dotnet restore src/CcDashboard.Web
dotnet build src/CcDashboard.Web --no-restore 2>&1 | tail -3
# Expected: Build succeeded. 0 Error(s).
```

---

## Commit

```
fix: downgrade SignalR.Protocols.NewtonsoftJson 10.0.8 → 8.0.16 (project targets .NET 8)
```
