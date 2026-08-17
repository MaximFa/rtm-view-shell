---
name: feedback-git-mount-distrust
description: "Don't trust .git reads via the Cowork mount — they can truncate; verify HEAD/refs via native CC or origin"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ee2d05ad-bd00-45fa-826c-89df7177513b
---

The Cowork workspace mount can return TRUNCATED reads of `.git` internals, not just project files (PD-007 class). Live incident 2026-06-08 (RTM project): `cat .git/HEAD` and even workspace-bash `git rev-parse HEAD` / `git symbolic-ref HEAD` returned `refs/heads/v2-` — a truncation of the real `refs/heads/v2-backend` (the mount dropped `backend`). I wrongly escalated this as "HEAD corrupted, all commits blocked." Native git (CC on Windows) read HEAD correctly: `refs/heads/v2-backend` = 8c22a9e, healthy.

**Why:** This RTM project is split across two Cowork instances (CLAUDE.md §44): branch `v2-backend` (Backend: RTM/Metrics/DBA/Devops — my side) and `v2-frontend`. Long branch names get truncated by the mount view.

**How to apply:** Before declaring a git-integrity incident from a mount read, VERIFY against native CC or `origin` (`git rev-parse origin/<branch>` is reliable). Never run `git symbolic-ref HEAD ...` or any `.git` repair based on a mount-truncated read. The rule (operator, Max): **.git via mount = untrusted; trust native/origin only.** Commits run via CC (native) which sees the correct HEAD. Related: [[feedback_development_process]] (PD-007 mount truncation, §0.2/§0.3).
