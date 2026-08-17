# CC task — BUILD RTM Service pkg from v3 tip 116416c (Part B pipe-name) — BUILD-0 GATE

> Part B (configurable pipe-name 116416c) landed object-store-verified; build-0 not captured. This RTM publish = build gate. Owner: devops. Native CC. Branch v3. NO push (§37).

## Mandatory reads
Read: role-devops (§A+§C); session-coord; CLAUDE.md §24/§27/§33/§35/§DEPLOY-16.

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be 116416c...
git status --short; sync
```
## §0.6b BINDING preamble → .coord/cc/devops.md: status open, directive tools/cc_prompt_build_rtm_partb.md.

## THE WORK
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode RTM
```
(fallback §27: dotnet publish RTM/RTM -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\rtm")

## DoD — REPORT NUMBERS (build-0 truth-duty gate for 116416c)
- dotnet build/publish RTM = **0 errors** (report W). If compile FAILS → verbatim + flag, do NOT package.
- Confirm from 116416c: AppConfig.PipeName + RTMAdapter uses it (build success implies).
- zip: newest Installations\*_RTM*.zip → full path + size + SHA256; contains Update-RTMView.ps1 + RTM.exe.
- Deploy path (later) = RTM Service: Update-RTMView -SkipShell -SkipDrift (restart RTMService), backward-compat default pipe "rtmpipe" so 234 (single, no legacy) unchanged.

## NO commit/push. §0.6b postamble → RESULT (build 0 err/W from 116416c . RTM pkg path/size/SHA . status).
