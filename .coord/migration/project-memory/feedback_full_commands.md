---
name: feedback-full-commands
description: "Operator wants operator-run steps given as complete copy-paste commands, not descriptions"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6b86cb5e-3842-4b5f-8d5e-85d212427c5a
---

When I hand the operator/devops steps to run (esp. on the deployed 140/prod server: config toggles, service restarts, log greps, DB checks), give them as **complete, copy-paste-ready commands** (full PowerShell with real paths/service names), not prose descriptions of what to do.

**Why:** Max Wait F5 diagnosis 2026-07-16 — I described the DiagPushLogging steps in prose; operator said "выдавай подробные задачи с полными командами."

**How to apply:** ground the commands in the repo's real deploy conventions. 140/prod layout (from deploy/Install-RTMView.ps1): InstallRoot `C:\RTMView`; Shell dir `C:\RTMView\Shell`; deployed appsettings `C:\RTMView\Shell\appsettings.json`; Windows service `RTMViewShell` (+ RTM service `RTMService`); Serilog file sink `C:\RTMView\Shell\logs\log-<date>.txt` (Day rolling). Kestrel orphan-exe services (not IIS). §43: CC has no external-server access → the OPERATOR runs them; I supply exact commands.
