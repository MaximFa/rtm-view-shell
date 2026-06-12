# CC Task — ApplyService: enable Windows Service hosting (UseWindowsService) + rebuild

> Fix for 234 DG-2. CcDashboard.ApplyService cannot run as a Windows service (SCM Event 7009 timeout)
> because it lacks UseWindowsService — it runs fine as a console app, only SCM integration is missing.
> Scope: exactly 2 source edits + an ApplyService-only self-contained publish. No other changes. No push.

## 0. Integrity (mount)
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# For any M source file under src/CcDashboard.ApplyService: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>.

## 1. csproj — add the Windows Service hosting package
File: src/CcDashboard.ApplyService/CcDashboard.ApplyService.csproj
Inside the <ItemGroup> that holds the <PackageReference> entries, ADD:
    <PackageReference Include="Microsoft.Extensions.Hosting.WindowsServices" Version="8.0.1" />

## 2. Program.cs — enable the Windows Service host
File: src/CcDashboard.ApplyService/Program.cs
IMMEDIATELY AFTER the line:
    var builder = WebApplication.CreateBuilder(args);
ADD a new line:
    builder.Host.UseWindowsService();

WRITES: use Python read -> str.replace -> write + os.fsync (CLAUDE.md §0.3 — Edit tool BANNED on this mount).
Verify after each write: tail/grep the changed region.

## 3. Restore + publish (ApplyService ONLY, self-contained win-x64, FIXED output dir)
dotnet restore src/CcDashboard.ApplyService
dotnet publish src/CcDashboard.ApplyService -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\applysvc"

## 4. Verify the fix compiled
- grep Program.cs -> 'builder.Host.UseWindowsService();' present
- grep csproj    -> 'Microsoft.Extensions.Hosting.WindowsServices' present
- Test-Path "D:\Claude\Projects\RTM View Shell\publish\applysvc\CcDashboard.ApplyService.exe"  (and .dll)

## 5. Commit — web: scope, NO PUSH (§37)
bash tools/pre-commit-check.sh
# stage ONLY the 2 source files:
#   src/CcDashboard.ApplyService/CcDashboard.ApplyService.csproj
#   src/CcDashboard.ApplyService/Program.cs
git commit -m "web: ApplyService UseWindowsService (234 DG-2 — fix SCM 7009 service hosting)"
# Do NOT push. Post-commit verify (git status clean, diff HEAD empty).

## Report back
publish path + CcDashboard.ApplyService.exe size; the 2-file diff; commit hash; confirm UseWindowsService present.
The operator then transfers publish\applysvc\* to 234 and redeploys (preserving the ApplyService appsettings.json).
