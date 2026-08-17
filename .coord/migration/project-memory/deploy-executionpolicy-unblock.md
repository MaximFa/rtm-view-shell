---
name: deploy-executionpolicy-unblock
description: Every deploy package (zip-extracted on a Windows server) MUST run ExecutionPolicy Bypass + Unblock-File before the orchestrator — make it a mandatory INSTALL.txt step
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1478718f-e3ac-40b4-9327-c3068a5002be
---

Operator directive (2026-06-12, server-45 deploy): the ExecutionPolicy bypass + Unblock-File pair must ALWAYS be inserted as **mandatory** first steps of every deployment, and flagged so it lands in the standing deploy procedure (every package INSTALL.txt):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File
```

**Why:** Our deploy packages ship as a `.zip`. When extracted on a Windows server, every `.ps1` gets the "mark of the web" (Zone.Identifier ADS), and Windows PowerShell's execution policy blocks unsigned scripts → `Apply-Server45Upgrade.ps1 ... is not digitally signed. You cannot run this script` (PSSecurityException). This bit the live server-45 deploy. `Set-ExecutionPolicy -Scope Process Bypass` is session-only (no admin, reverts on window close); `Unblock-File` strips the zone mark.

**How to apply:** Put this 2-line preamble as STEP 0 of every package `INSTALL.txt` (before the pre-flight probe / Apply command). When walking an operator through a deploy, always include it. The package-build prompt (`tools/cc_prompt_build_45.md` / INSTALL.txt generation) should emit it automatically. Flagged to coordinator-0612 for the standing deploy procedure. Related: [[deploy_kestrel_orphan_exe]].
