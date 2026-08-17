# CC task — BUILD RTM Service package from v3 tip 7ae4507 (PORT-2026-07-10-A) — also the BUILD-0 GATE

> RTM UserManager legacy port (7ae4507) landed object-store-verified but build-0 was NOT captured (CC binding dropped, L-SC-04). This RTM publish IS the build gate: publish fails if it does not compile. Owner: devops. Native CC. Branch v3. NO push (§37). Report-scoped.

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §27 (RTM publish path), §33, §35, §DEPLOY-16.

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be 7ae4507...
git status --short; sync
```

## §0.6b BINDING preamble → .coord/cc/devops.md (Python+fsync): status open, directive tools/cc_prompt_build_rtm_port.md.

## THE WORK — build RTM Service package (publish = compile gate)
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode RTM
```
(If -Mode RTM unavailable, fall back to the fixed publish path per §27:
`dotnet publish RTM/RTM -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\rtm"` then package.)

## DoD — REPORT NUMBERS (this is the truth-duty build gate for 7ae4507)
- **dotnet build/publish of RTM = 0 errors** (report warning count). If it FAILS to compile (e.g. Hebrew-literal encoding, missing member) → report the exact error verbatim, do NOT package, flag to coordinator (the port would need a fix).
- Confirm the port compiled: RTM/RTM/UserManager.cs @7ae4507 is in the build (wait-for-call machine + guards).
- zip: newest Installations\*_RTM*.zip (or the RTM package) → full path + size + SHA256.
- zip contains the RTM Service deploy tooling (Update-RTMView.ps1 or the RTM install/update path) + RTM.exe self-contained.
- PS1 UTF-8 BOM+CRLF (§35).

## NO commit, NO push.
## §0.6b BINDING postamble → .coord/cc/devops.md: RESULT (build 0 err/W n from 7ae4507 . RTM pkg path/size/SHA . status done|failed . blockers).
