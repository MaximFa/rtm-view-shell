# CC task — BUILD RTM Service pkg from v3 tip cf18c8b (NGC_Queues live-populate) — BUILD-0 GATE
> cf18c8b (`rtm: populate NGC_Queues on live workgroup-add — BU queue picker [backend]`, RTM/RTM/Engine.cs +2) is v3 HEAD, object-store verified, ONE commit ahead of 72882f0 (the 0323 pkg). This RTM publish = build-0 gate for cf18c8b (backend can't run dotnet from Cowork). Owner: devops. Native CC. Branch v3. NO push (§37).

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §27, §33, §35, §DEPLOY-16.

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be cf18c8bcfaa769bb38176fb776d645881584a002
git status --short; sync
```
## §0.6b BINDING preamble -> .coord/cc/devops.md: status open, directive tools/cc_prompt_build_rtm_cf18c8b.md.

## THE WORK
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode RTM
```
(fallback §27: dotnet publish RTM/RTM -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\rtm")

## DoD — REPORT NUMBERS (build-0 truth gate for cf18c8b)
- dotnet build/publish RTM = **0 errors** (report W). If compile FAILS -> verbatim + flag, do NOT package.
- Confirms cf18c8b Engine.cs (getOrCreateQueue in getOrAddWGManager) is in the build (build success implies).
- newest Installations\*_RTM*.zip -> full path + size + SHA256; contains Update-RTMView.ps1 + RTM.exe self-contained.
- PS1 in zip UTF-8 BOM+CRLF (§35).

## NO commit/push. §0.6b postamble -> RESULT (build 0 err/W from cf18c8b . RTM pkg path/size/SHA . status).
