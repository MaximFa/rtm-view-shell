---
name: feedback-poke-dotdot-check-result
description: "Max's shorthand — \"..\" means \"check the result now\" (via object store), not \"wait\""
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dab62ab9-93dc-4f3e-9e26-fdaaa3f53baa
---

When Max sends **`..`** (or a bare `.` / `,`) it means **"check the result now / continue"** — proactively go verify the outcome of whatever was running (a CC task, a deploy step) via the OBJECT STORE (git log / git show / .coord/cc/<role>.md), then report.

Do NOT respond with "waiting for the result" (`жду результат`). The poke IS the signal to check.

**Why:** Max runs CC tasks / commands on his side and pokes `..` to say "it ran, look." Established 2026-07-13 during the RTM 140 install (he'd run a CC prompt, wrote `..`, and expected me to verify the commit rather than wait). Relates to [[feedback_git_mount_distrust]] (verify via object store, not mount status).
