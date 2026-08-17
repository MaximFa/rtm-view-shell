---
name: feedback-codebox-scripts
description: Max wants all scripts and prompt-run commands presented in a code box
metadata: 
  node_type: memory
  type: feedback
  originSessionId: daa8b771-e75d-4a7d-9e7e-75cf6df6aab3
---

Max's standing instruction (2026-06-06): always present scripts and the commands to run prompts/scripts inside a code box (```code block```), not inline prose.

**Why:** he copies them straight into a terminal / CC; a code box is unambiguous and copy-paste safe.

**How to apply:** any runnable command — psql/PowerShell scripts, `Выполни задачу из файла tools/cc_prompt_*.md` CC-prompt invocations, shell one-liners — goes in a fenced code block. Also save the script as a file and share it via present_files when it is more than a couple of lines. Prod PostgreSQL on the server is at `C:\Program Files\PostgreSQL\18` (psql at `...\18\bin\psql.exe`). Related: [[project-rtm-view-shell]].
