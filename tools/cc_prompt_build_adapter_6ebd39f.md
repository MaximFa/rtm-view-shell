# CC task — BUILD + §48 WIRE gate + publish RTM.Twilio from adapters tip 6ebd39f (auto-reconnect)
> adapters HEAD = 6ebd39f (feat: auto-reconnect per-target supervisor infinite retry/30s cap + pipe-disconnect harden; 8abd19a->6ebd39f). Object-store verified, no wire-format change. This is the standing [WIRE-VALIDATION] gate (§48) — backend can't run dotnet from Cowork. Owner: devops. Native CC. Branch: **adapters** (worktree). NO push (§37).

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §48 (WIRE contract), §35.

## INIT — adapters worktree
```bash
cd "D:\Claude\Projects\RTMView-adapters-wt"
git rev-parse --abbrev-ref HEAD    # adapters
git rev-parse HEAD                  # MUST be 6ebd39fb081eed097db2d6e6fe4ae32d9c3bf62c
git status --short
```
(If the worktree is missing: `git worktree add "D:\Claude\Projects\RTMView-adapters-wt" adapters`.)
## §0.6b BINDING preamble -> .coord/cc/devops.md: status open, directive tools/cc_prompt_build_adapter_6ebd39f.md.

## THE WORK — build + WIRE test + publish
```powershell
cd "D:\Claude\Projects\RTMView-adapters-wt"
dotnet build "RTM.Twilio\RTM.Twilio.csproj" -c Release
dotnet test  "RTM.Adapter.Common.Tests\RTM.Adapter.Common.Tests.csproj" -c Release
dotnet publish "RTM.Twilio\RTM.Twilio.csproj" -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTMView-adapters-wt\publish\twilio"
```

## DoD — REPORT NUMBERS (truth-duty gate for 6ebd39f)
- RTM.Twilio build = **0 errors** (report W). If FAILS -> verbatim + flag, do NOT publish.
- **§48 WIRE round-trip test = 14/14 PASS** (WireContractTests). If any FAIL -> verbatim + flag (wire-format regression); do NOT proceed to deploy.
- publish -> report the output path + confirm RTM.Twilio.exe (self-contained) + appsettings.json present.
- Confirm 6ebd39f in the build (auto-reconnect supervisor) — build success implies.

## NO commit/push. §0.6b postamble -> RESULT (build 0/W + WIRE 14/14 + publish path . from 6ebd39f . status).
