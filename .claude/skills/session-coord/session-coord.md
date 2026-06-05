---
name: session-coord
description: "Multi-session coordination over the .coord/ file bus — registration, claims, commit serialisation, push barrier. Load at the START of EVERY Cowork session; apply to every CC prompt. Normative spec: CLAUDE.md §42."
type: process
updated: 2026-06-06
---

# session-coord — multi-session coordination

CLAUDE.md §42 is the normative spec. This skill is the operational layer: runbooks,
checklists and lessons from the first live run (2026-06-05/06: 3 sessions on the bus,
4 protocol commits, 6-commit consensus push, **zero lost artefacts** — vs 3 artefact
classes lost in the pre-protocol push).

## 1. Session start runbook

1. §0.2 integrity check. Known false-M (hash==HEAD, do not touch):
   `db/data/02_metrics.sql`, `db/schema.sql` — always verify with
   `git hash-object <f>` vs `git rev-parse HEAD:<f>` before "restoring" anything.
2. Read ALL `.coord/sessions/*.md` — who is active, what is claimed.
3. Read `.coord/journal.md` tail. If another slug committed since your last work —
   hash-check YOUR claimed files vs HEAD (PD-007 cross-session truncation).
4. Check `.coord/push/request.md`. Present → barrier active: no new CC tasks,
   write your ack first (§6).
5. Write/refresh your session file (template §7.1). Slug: `<name-without-RTM>-MMDD`.

## 2. Claims (hybrid, §42.3)

- Module claims by default (`rtm` / `web` / `db` / `docs`). Two sessions need one
  module → BOTH switch that module to file-mode; file lists must not overlap.
- **Never combine** `modules: [X]` with `files:` inside X — a module claim excludes
  ALL its files (live incident: peer review caught the initiator doing this).
- `CLAUDE.md`: claim as a file only while actually writing; concurrent additions are
  resolved as separate §-sections.

## 3. Commit discipline

- **ALL commits via CC tasks. NEVER commit from the Cowork side.**
  L-SC-02: the Cowork mount cannot unlink files — a `commit.lock` acquired by a
  Cowork session stays orphaned forever (observed live). Lock acquire AND release
  are CC-only operations.
- Lock: atomic `open(path, "x")` with owner+UTC timestamp. Busy → retry 5 × 60 s.
  Stale > 15 min → report contents, NEVER auto-delete a lock you do not own.
- The lock covers §0.4 plumbing commits too — concurrent direct writes to
  `refs/heads/<branch>` silently destroy a commit.
- After every commit: journal line → release lock → `sync` → PD-007 re-sync.
- L-SC-04: journal lines appended by CC may be invisible or lost through the mount.
  The initiator cross-checks `.coord/journal.md` against `git log` and restores
  missing lines (Python + fsync). Journal is a convenience view; git log is truth.

## 4. CC prompt requirements + peer-review checklist

Every CC prompt: §0.6a integrity block first, then the sync block from
`tools/cc_prompt_sync_block.md` (slug + claims filled). When reviewing another
session's prompt, check:

- [ ] S1 barrier check present (`.coord/push/request.md` → STOP)
- [ ] claims explicit; no file outside them
- [ ] lock acquire has retry 5×60 s (not fail-fast)
- [ ] journal append via Python+fsync (not `echo >>`)
- [ ] §0.6 post-commit verification + PD-007 re-sync present
- [ ] no `git push` (§37)
- [ ] anything under `.claude/` staged with `git add -f` (`.gitignore` blocks it —
      three artefacts were lost to this before the protocol)

## 5. Push barrier runbook (initiator)

**ORDER MATTERS (L-SC-01): `request.md` FIRST (freeze), acks AFTER.**
Collecting acks before the freeze lets the commit set drift — in run 1 the set
changed twice and one session had to re-ack three times.

1. Verify no `commit.lock` held → write `.coord/push/request.md` (template §7.3).
   Barrier is now ON: sync block S1 stops all new CC tasks.
2. Operator notifies sessions; each passes the ack checklist (§6) and writes its
   OWN ack. L-SC-03: an ack is written ONLY by the owning slug — impersonation
   occurred in run 1 and the ack had to be re-issued by the owner.
3. Quorum: READY from EVERY active session, each `valid_for` == the frozen set.
4. Push via `tools/cc_prompt_push_barrier.md`: verifies quorum → removes orphaned
   lock (owner check) → runs `tools/cc_prompt_push.md` (incl. Step 1b untracked
   pickup) → cleans barrier files → journals `PUSHED`.
5. Every other session, on its next CC task: `git fetch` + verify local HEAD is an
   ancestor of (or equal to) origin (§42.7.6).

## 6. Ack checklist (before writing READY)

- `cc_task: none` in your session file
- claimed paths: no real `M` (hash-object vs HEAD; known false-M on `db/*.sql`)
- no `??` untracked artefacts of YOUR session — commit them NOW (`.claude/` → `git add -f`)
- key files hash-verified vs HEAD (PD-007 after other sessions' commits)

Format: `READY` / `valid_for: <exact frozen commit list>` / `checked: <UTC>` / notes.
`valid_for` MUST match `request.md`. Otherwise `HOLD: <reason>`.

## 7. Templates

### 7.1 Session file — `.coord/sessions/<slug>.md`
```markdown
---
session: RTM <Name>
slug: <slug>
started: <UTC>
heartbeat: <UTC>
status: active            # active | pushing | done
modules: []               # or [rtm] etc. — never combine with files of same module
files: [<explicit paths>]
cc_task: none             # none | running:<prompt-file>
---
```

### 7.2 Ack — `.coord/push/acks/<slug>.md`
```
READY
valid_for: origin/<branch>..HEAD = <hashes, newest first>
checked: <UTC>
notes: <checklist summary>
```

### 7.3 Push request — `.coord/push/request.md`
```markdown
---
initiator: <slug>
created: <UTC>
---
PUSH BARRIER ACTIVE — no new CC tasks (sync block S1).
Exception: the push prompt itself.
Commits to push (origin/<branch>..HEAD): <list>
```

## 8. Lessons learned — run 1 (2026-06-05/06)

| # | Lesson |
|---|---|
| L-SC-01 | `request.md` first = freeze; acks collected before it go stale as the set drifts |
| L-SC-02 | Cowork cannot unlink on the mount → commit.lock is CC-only; never design a step requiring Cowork to delete a file |
| L-SC-03 | Ack only by owning slug — impersonation happened, even well-meant |
| L-SC-04 | Journal↔mount divergence: CC-appended lines may vanish from the mount view; reconcile against `git log` |
| L-SC-05 | The ack checklist caught 3 lost-artefact classes in one run: untracked docs, second untracked doc set, `.gitignore`-blocked skill |
| L-SC-06 | Peer-review every CC prompt against §4 — first foreign prompt missed S1, retry, fsync-journal and §0.6 |
| L-SC-07 | Stray undeletable files exist on the mount (`.sync`, root junk) — name around them, ask operator to clean manually |
| L-SC-08 | Claude Code Tasks API is a different layer (work items, `~/.claude/tasks/` invisible to Cowork VMs); `.coord/` covers the git-resource layer. See `docs/Multi-Session_Coordination_TasksAPI_vs_Coord.docx` |
