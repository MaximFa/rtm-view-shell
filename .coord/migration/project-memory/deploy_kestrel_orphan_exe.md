---
name: deploy-kestrel-orphan-exe
description: "234/prod is all-Kestrel (no IIS); RTMViewShell service stops but its exe keeps running, locking DLLs on deploy"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9db921d7-ff36-45cb-b8ef-1eacba950afd
---

Production servers (e.g. 234) run the RTM Shell + RTM Service on **Kestrel as Windows services**
(`RTMViewShell`, `RTMService`), **NOT IIS**. Any deploy "app pool / IIS drive not found" warning is
noise — there is no IIS. Do not suggest `iisreset`.

**Recurring bug (operator-reported, multiple times):** the `RTMViewShell` service stops but its Kestrel
**exe keeps running orphaned**, holding `C:\RTMView\Shell\...\*.dll` (e.g. CcDashboard.Web.resources.dll)
→ binary copy in deploy Phase 3 fails with "file is being used by another process".

`Stop-ServiceAndExe` in `deploy/Apply-Server45Upgrade.ps1` kills the orphan by exe **NAME** derived from
the service PathName — works for RTMService, **fails for RTMViewShell** (wrapper/name mismatch) and then
always false-logs "exe clear". 

**Interim deploy guard (operator directive 2026-06-11):** in deploys, check and kill orphans by install
**PATH**, then verify before declaring clear:
`Get-Process | ? { $_.Path -like "C:\RTMView\*" } | Stop-Process -Force`.
**Source fix still owed:** RTMViewShell service stop must actually terminate its Kestrel child (file as a
tracked bug); the deploy kill-by-path is the interim guard. Devops to make kill-by-path + verify-before-clear
standing in Apply-Server45Upgrade.ps1. See [[project_rtm_devops_session]].
