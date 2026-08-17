# CC task — BUILD prod-release (Shell only) from v3 tip 12480b2 — batch-2 (ASD polish) for 234 deploy

> Batch: 7a8a4a8 blur + 21ecb84 guard + 12480b2 recreate-test. Runtime = Shell (JS + Application/Infra guard compiled in). NO migration, NO RTM change. Owner: devops. Native CC. Branch v3. NO push (§37). Report-scoped.

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §35, §DEPLOY-16

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be 12480b2...
git status --short; sync
```

## §0.6b BINDING preamble → .coord/cc/devops.md (Python+fsync): status open, directive tools/cc_prompt_build_shell_batch2.md.

## THE WORK
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Shell
```
Publishes CcDashboard.Web (self-contained win-x64) + packages zip under Installations\ with Update-RTMView.ps1.

## DoD — REPORT NUMBERS
- build = 0 err (report W count). If publish fails → report verbatim, do NOT package.
- zip: newest Installations\*_Shell.zip → full path + size + SHA256.
- zip contains Update-RTMView.ps1 (root, §DEPLOY-16).
- verify from 12480b2: agentStateDistributionChart.js + daytrendChart.js + reportDistributionChart.js contain `devicePixelRatio: Math.max(2, window.devicePixelRatio||1)`; App.razor 3 chart JS `?v=2`; guard compiled (RtsRepository QueueGridExistsAsync in the DLL — build success implies).
- PS1 UTF-8 BOM+CRLF (§35).

## NO commit, NO push.
## §0.6b BINDING postamble → RESULT (zip path/size/SHA + build 0/W + from 12480b2 + Update-RTMView present).
