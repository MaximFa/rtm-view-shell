---
name: session-coord
description: "Multi-session coordination over the .coord/ file bus — registration, claims, commit serialisation, push barrier. Load at the START of EVERY Cowork session; apply to every CC prompt. Normative spec: CLAUDE.md §42."
type: process
updated: 2026-06-06 (v1.6 — Track 2 cc_post_commit.sh wrapper — §12 coordinator handoff + commands; L-SC-11..17)
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
- After every commit: journal line → **post-commit flush to coordinator.md** (S4b: commit hash, claims-releasable, blocker, next) → release lock → `sync` → PD-007 re-sync. The journal says WHAT committed; the flush says what the coordinator must ACT on (free claims, blockers).
- L-SC-04: journal lines appended by CC may be invisible or lost through the mount.
  The initiator cross-checks `.coord/journal.md` against `git log` and restores
  missing lines (Python + fsync). Journal is a convenience view; git log is truth.
- **[Track 2]** After every commit the LAST step is `bash tools/cc_post_commit.sh <slug> <hash>` — it performs
  journal(S4)+flush(S4b)+lock-release atomically and is exit-gated; inline journal/flush is removed.
  Skipping it is a protocol violation (L-SC-17).

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

## 9. File-claim queue (.coord/queue.md) — contention protocol

When you need a path that another ACTIVE session holds (detected by
`python3 tools/coord_check_claims.py <my-slug> <paths...>` — run it BEFORE writing
any CC prompt):

1. Append a REQUEST line to `.coord/queue.md` (Python+fsync, append-only):
   `<UTC> | REQUEST | <path> | wants: <slug> | holder: <slug> | <why, 1 line>`
   Do NOT claim the path, do NOT write prompts touching it.
2. The holder (notified by operator or seeing the queue on next bus read):
   finishes the CURRENT CC task involving the path, commits, removes the path
   from its `files:` claims, appends: `<UTC> | GRANT | <path> | to: <slug>`.
3. The grantee: re-reads the path from fresh HEAD (it changed!), adds it to its
   claims, proceeds. FIFO order if several waiters.
4. Coordinator arbitrates: priority disputes, stale holders (heartbeat > 3 h →
   §42.2 takeover with operator confirmation), deadlocks (A waits B, B waits A →
   coordinator picks who goes first; both cannot hold).
5. `CLAUDE.md` is exempt — short-lived file-claim per write, append-only §-sections.

Remember WHY this matters: one shared working tree means no merge conflicts —
the second writer silently destroys the first one's edits (L-SC-09). The queue
is the only protection for same-file work.

| # | Lesson |
|---|---|
| L-SC-09 | Same-file contention = silent lost-update, not a git conflict; serialise via queue, never parallel |
| L-SC-10 | Mount keeps phantom dirents: `test -f request.md` true while `cat`/`ls` show it gone. Barrier checks (S1) and any `.coord/` presence test MUST be content-based (`-s` + successful `cat`), never `-f` alone. Phantom clears only from the Windows side or by re-sync — like the stray `.sync`. |
| L-SC-11 | An ACTIVE session with EMPTY claims is a hole: its real working territory is unprotected, so another session enters it legally (test wandered into metrics' RtsGridMetric.cs because metrics declared nothing). The role obliges declaring territory BEFORE starting work; a stale "stage complete" session file with no claims is the trap. |
| L-SC-12 | A file-claim inside a module forces EVERY other claimant of that module into file-mode (§42.3.2). Verify with the checker BEFORE a new session registers: metrics held RTM/RTM/Union.cs, so DayTrend could no longer take the whole `rtm` module — it had to switch to rtm file-mode. Catch cross-session module collisions at registration, not at commit. |
| L-SC-13 | Mailbox (§11) decouples content from the operator but not turns — sessions don't poll. The operator shifts from courier (carries payloads) to scheduler (sends `коорд: входящие`/`сбрось` pokes). Design any "session will notice X" step around explicit triggers, never around autonomous polling. |
| L-SC-14 | Phantom dirents (L-SC-10) hit commit.lock too: `open(lock,"x")`/`os.path.exists` see the ghost and block ALL commits forever. Lock-acquire (S3) must be content-based — treat an empty/unreadable lock as phantom, clear and retry. A live session committing fine while a "held lock" lingers = phantom, not a real holder. Never declare a session dead on lock age alone; check its recent commits + cc_task first. |
| L-SC-15 | A running session caches the skill it read at start; later skill edits (new commands/sections) do NOT reach it. Bump = the coordinator drops a "re-read skill vX" note into each active inbox; operator triggers `коорд: входящие`. New sessions read the current file fresh at registration. |
| L-SC-16 | A leftover /tmp script with a generic name (write_prompt.py) re-ran from another session and wrote OUTSIDE its claims (touched another session's untracked file). Claim discipline (S2) guards INTENDED writes, not accidental ones from stale scripts. Name /tmp scripts per-session (/tmp/<slug>_*.py) and never reuse generic names. |
| L-SC-17 | A phantom dirent (L-SC-10) blocks even `open(path,"w")` and `rm`/`os.remove` ("Operation not permitted") — you cannot overwrite or delete it directly. Workaround that WORKS: write to a temp file then `os.replace(tmp, path)` (atomic rename overwrites the phantom). Used to write .coord/push/request.md over its ghost. |

## 10. Operator command set — EXECUTE LITERALLY

The operator (Max) drives the protocol with short commands prefixed `коорд:`.
Every session MUST recognise them and execute the exact semantics below —
no improvisation, no clarifying questions unless data is genuinely missing.
Replies must be SHORT: result + what the operator should do next (if anything).

| Command | Addressed to | Exact action |
|---|---|---|
| `коорд: ты координатор` | new session | Register on the bus with `role: coordinator`, empty work claims. Read all bus state. Reply: bus summary + "готов". |
| `коорд: регистрируйся. задача: <text>` | new work session | Load this skill, §1 runbook, derive slug + initial claims from the task, register. Reply: slug, claims, conflicts found (checker), ready/blocked. |
| `коорд: статус` | any session | Own state: slug, claims, cc_task, last journal lines relevant to me. Coordinator instead: FULL bus audit (sessions+heartbeats, locks, queue, journal↔git reconciliation, unpushed count). |
| `коорд: проверь шину` | coordinator | Same as coordinator `статус` + actively FIX: restore lost journal lines, flag stale locks/sessions, claim violations, queue deadlocks. Reply: findings + required operator actions. |
| `коорд: очередь` | session holding a contested file | Read `.coord/queue.md`. If a REQUEST targets my claims: finish current CC task, ensure path committed, remove from my claims, append GRANT. Reply: what was granted, to whom. |
| `коорд: файл твой` | session waiting in queue | Verify GRANT exists for me, re-read path from fresh HEAD, add to claims, resume work. Reply: confirmed + next step. |
| `коорд: готовим пуш` | coordinator | Verify no commit.lock → write `push/request.md` (freeze) → reply with the exact ack-request text for the operator to paste into each work session. |
| `коорд: дай ack` | work session | Run §6 ack checklist, write own ack (READY or HOLD+reason). Reply: one line — READY / HOLD: reason. |
| `коорд: пуш` | coordinator | Verify quorum (every active session READY, valid_for == frozen set) → reply with the CC command (`Выполни задачу из файла tools/cc_prompt_push_barrier.md`). If no quorum: who is missing. |
| `коорд: завершаю сессию` | any session | Set `status: done`, claims released. Reply: final summary (commits made, loose ends). |
| `коорд: сессия <slug> мертва` | coordinator | Operator-confirmed takeover (§42.2): delete that session file, list orphaned claims/locks now free, schedule orphan-lock removal via next CC task. |
| `коорд: сбрось` | any session | Flush current status / question / handoff to the bus: update own session file, and append a message block to `.coord/inbox/<recipient>.md` (recipient = `coordinator` for decisions, or a peer slug). Reply: what was written, to whom. |
| `коорд: входящие` (alias: `коорд: прочитай`) | any session | Read own `.coord/inbox/<slug>.md`; act on each unhandled block; append `> handled <UTC> by <slug>` per block. THEN auto-flush (implicit `коорд: сбрось`): write ONE response block to `.coord/inbox/coordinator.md` — what was done, answers to any questions, new questions/blockers, current status. One operator poke = read + respond. Chat reply: short summary. |
| `коорд: разбери` | coordinator | Read ALL `.coord/inbox/*.md` + session files, reconcile, then write directives into each recipient's inbox. Reply: per-session directives placed + what the operator must trigger (`коорд: входящие` to whom). |
| `коорд: передай координацию` | outgoing coordinator | Write a HANDOFF block to `.coord/inbox/coordinator.md` capturing what is NOT derivable from the bus (see §12), set own session `status: done`. Reply: handoff written, safe to open a fresh coordinator. |
| `коорд: ты координатор` (on a FRESH session) | new session | Register as coordinator; read skill + FULL bus audit + the HANDOFF block in coordinator.md; reconstruct state. Reply: reconstructed picture + any gaps. |

Default duty regardless of commands: at the start of EVERY turn each session re-reads
the bus (§1 items 2–4) and acts on what it finds (barrier → ack; foreign journal
lines → hash-check own files; queue REQUEST against own claims → mention it).

**Operator return convention (NORM):** the operator opens every RETURN to a session
(after working in other sessions) with `коорд: статус`. Treat it as a forced full
resynchronisation: re-read ALL bus state ignoring anything remembered from earlier
in the conversation — context may be stale or degraded. This convention exists
because the "default duty" above is best-effort for an LLM in a long conversation;
the explicit command is the reliable trigger. Sessions must EXPECT it and never
answer from memory.

## 11. Mailbox (.coord/inbox/) — directed messages without operator copy-paste

Problem it solves: the operator was carrying full message BODIES between sessions
(lossy, slow, distortion-prone). The mailbox moves content to files; the operator
carries only short turn-triggers.

Structure:
- `.coord/inbox/<slug>.md` — append-only messages TO that session.
- `.coord/inbox/coordinator.md` — questions/escalations TO the coordinator.
Message block format (Python+fsync, append-only):
```
## <UTC> | from: <slug> | to: <slug>
<body>
---
```
Mark handled by appending `> handled <UTC> by <slug>` under the block. Never delete.

Flow (operator triggers in brackets):
1. Coordinator → [`коорд: разбери`] → reads all inboxes + session files, writes directives
   into each recipient's inbox.
2. Recipient → [`коорд: входящие`] → reads its inbox, acts on each block, AND auto-flushes a
   response block to `.coord/inbox/coordinator.md` (implicit `коорд: сбрось` — no separate poke).
3. Coordinator → [`коорд: разбери`] → collects the responses, issues next directives.
This closes the loop with ONE poke per session per round. `коорд: сбрось` stays available for
an unsolicited status/question outside this loop.

**Hard limit — sessions do NOT poll.** A session sees its inbox only when the operator
gives it a turn. The mailbox removes content-carrying, NOT turn-triggering. The
operator remains the scheduler (short pokes), no longer the courier (full payloads).
The "default duty" turn-start bus read (incl. inbox) is best-effort (LLM memory);
`коорд: входящие` / `коорд: статус` are the reliable triggers.

**Reliability:** inbox files live on the same mount → subject to L-SC-04 (lost lines)
and L-SC-10 (phantom dirents). Always write with fsync; coordinator reconciles inbox
content against session files during `коорд: разбери`; presence checks are content-based
(`-s` + `cat`), never `-f`.

## 12. Coordinator handoff (fresh coordinator session)

The coordinator is almost stateless — nearly everything lives on the bus and is
re-derivable by a new coordinator. But some context lives ONLY in the outgoing
coordinator's chat and is LOST if not written down before it dies.

### Derivable from the bus (new coordinator just reads):
- Active sessions, claims, heartbeats — `.coord/sessions/*.md`
- Commit history — `.coord/journal.md` + `git log`
- Queue / handoffs — `.coord/queue.md`
- Barrier state — `.coord/push/`
- Pending messages — `.coord/inbox/*.md`
- The protocol — this skill

### NOT derivable — must be in the HANDOFF block:
- Pending peer-reviews not yet posted; open ASKs awaiting decision
- Decisions agreed with the operator verbally but not yet written to the bus
- **Uncommitted coordinator artefacts in the working tree** (skill edits, operator-guide,
  new lessons, rewritten prompts) — list them so they are NOT lost to PD-007 / a new session
- The "why" behind recent arbitrations; operator preferences expressed in chat
- Next expected actions per session

### Handoff procedure
1. Outgoing: `коорд: передай координацию` → append a HANDOFF block to
   `.coord/inbox/coordinator.md` (the next coordinator reads its own inbox), then set
   own session `status: done` (releases its coord claims — but FIRST ensure uncommitted
   coordinator artefacts are either committed or explicitly listed in the handoff).
2. Operator opens a fresh session: `коорд: ты координатор`.
3. New coordinator: read skill → full bus audit (`коорд: проверь шину`) → read the HANDOFF
   block → reconcile (esp. hash-check any files the handoff says are uncommitted) → report
   reconstructed state and ask the operator to confirm anything ambiguous.
4. If the old coordinator died WITHOUT a handoff: the new one rebuilds from the bus alone
   (it will miss in-flight reviews and uncommitted edits — recoverable via §0.2 integrity +
   git status, but slower). This is why writing the handoff before planned retirement matters.

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
