# CC TASK — fold Two-Cowork protocol into skill + CLAUDE.md §44 (coordinator-0608)

Branch: **v2-backend** (Cowork-A, captain). Commit only — **NO push** (§37).

## 0. Mandatory — read before starting (§40)
Read: `.claude/skills/widget-planner/widget-planner.md`
Read: `.claude/skills/widget-creator/widget-creator.md`
Read: `.claude/skills/session-coord/session-coord.md`

## 0.6a Integrity check — run FIRST (per CLAUDE.md §0.6a)
Run the mandatory integrity block from CLAUDE.md §0.6a (git status; restore any truncated M file
from HEAD via `git show HEAD:<f> > <f>`). Then proceed.

## Sync block (§42.6)
Apply `tools/cc_prompt_sync_block.md` with:
- slug: `coordinator-0608`
- claims (docs module): `.claude/skills/session-coord/session-coord.md`, `CLAUDE.md`,
  `docs/Two-Cowork-Coordination.md`, `docs/Two-Cowork-Coordination.ru.md`,
  `tools/cc_prompt_two_cowork_protocol.md`
- S1: if `.coord/push/request.md` is present with an active FREEZE -> STOP.

## Git push
Do NOT run `git push` automatically. Commit only.

---

## TASK

All file writes via Python + `os.fsync` (CLAUDE.md §0.3 — Edit tool BANNED). Append-only edits
(add at end of file) to avoid mid-file truncation risk.

### Step 1 — append a new section to `.claude/skills/session-coord/session-coord.md`
Append EXACTLY this block at the very end of the file:

```
## 13. Two-Cowork layer — cross-coordinator coordination (summary)

Full spec: docs/Two-Cowork-Coordination.md (RU: .ru.md) + CLAUDE.md §44.
Applies when TWO Cowork instances run, each its own clone/branch + coordinator. Intra-Cowork §42 unchanged.

- Topology: Cowork-A "Backend" (v2-backend: RTM/Metrics/DBA/Devops), Cowork-B "Frontend"
  (v2-frontend: Shell/UX-UI/Widget/QA). Trunk v2. Release captain = A.
- Cross-channel = git orphan branch `coord`, files under `.coord/cross/`
  (ownership.md, inbox-coord-A.md, inbox-coord-B.md, ledger.md, barrier.md).

**L-SC-20 (read=VM / write=native):** a Cowork coordinator's VM can READ coord via
`git fetch origin coord` + `git show origin/coord:<file>`, but CANNOT push from the mount
(git-write corrupts the index, L-SC-02 class — observed 2026-06-08). Cross-channel WRITES go via
native git (operator) or a CC task, NEVER from the Cowork VM. Each coordinator host keeps a coord
worktree (`git worktree add <path> coord`) for native writes.

Cross commands (prefix `коорд:`):
| Command | Addressee | Action |
|---|---|---|
| `коорд: кросс-статус` | a coordinator | `git fetch origin coord` -> report cross state (branches, barrier, integration debt, own inbox-coord-X) |
| `коорд: кросс-ack` | a coordinator | confirm own branch clean + L1-pushed at <sha>; coordinator drafts the ack, OPERATOR pushes it to coord |
| `коорд: интеграция` | captain | propose/run L2 integration (merge v2-backend + v2-frontend -> v2) |
| `коорд: релиз` | captain | run L2 release barrier incl. mandatory Security ack + prod push |

Two-level barrier: L1 = §42.7 inside each Cowork (pushes its own branch); L2 = captain merges both
branches to v2 + Security ack + prod push (Two-Cowork doc §5).
```

### Step 2 — append CLAUDE.md §44
Append EXACTLY this block at the very end of `CLAUDE.md`:

```
---

## 44. Two-Cowork coordination (cross-coordinator layer)

When the project is split across TWO Cowork instances (decided 2026-06-08), each runs its own
clone/branch + coordinator; §42 is unchanged INTRA-Cowork. The cross layer is specified in
**docs/Two-Cowork-Coordination.md** (RU: docs/Two-Cowork-Coordination.ru.md) and summarized in the
session-coord skill §13.

- Cowork-A "Backend" (branch `v2-backend`): RTM Server, Metrics, DBA, Devops.
- Cowork-B "Frontend" (branch `v2-frontend`): Shell, UX-UI, Widget, QA.
- Security: shared release gate, mandatory ack before any prod release.
- Integration trunk: `v2`. Release captain: Cowork-A.
- Cross-channel: git orphan branch `coord`, files under `.coord/cross/`.
- **[L-SC-20]** Cowork VM reads `coord` via `git fetch`; CANNOT push from the mount -> cross writes
  are native-git/CC only. Each coordinator host keeps a `coord` worktree for native writes.
- Two-level barrier: L1 = §42.7 per Cowork (own branch); L2 = captain merges both branches to `v2`
  + Security ack + prod push.
- A whole release stays in ONE Cowork (e.g. the Server-234 upgrade = wholly A).

*TZ version: 2.7 | CLAUDE.md last updated: 2026-06-08 (§44 Two-Cowork coordination layer)*
```

### Step 3 — verify writes (§0.3)
```bash
sync
tail -5 .claude/skills/session-coord/session-coord.md
tail -8 CLAUDE.md
wc -l .claude/skills/session-coord/session-coord.md CLAUDE.md
```
Both must end with the appended block (proper closing line). The two docs
`docs/Two-Cowork-Coordination.md` and `docs/Two-Cowork-Coordination.ru.md` already exist in the
working tree (created by Cowork) — they are committed as-is in this task.

### Step 4 — pre-commit check + commit (NO push)
```bash
bash tools/pre-commit-check.sh
# exit 0 required. If exit 1: restore truncated files from HEAD, redo Python write, re-check.
```
Stage and commit (use §0.4 index.lock workaround if needed):
- `.claude/skills/session-coord/session-coord.md` (use `git add -f` — `.claude/` is gitignored)
- `CLAUDE.md`
- `docs/Two-Cowork-Coordination.md`
- `docs/Two-Cowork-Coordination.ru.md`
- `tools/cc_prompt_two_cowork_protocol.md`

Commit message:
`docs: two-Cowork coordination layer (skill §13 cross-commands + L-SC-20, CLAUDE.md §44, protocol doc)`

### Step 5 — post-commit verify + PD-007 re-sync (§0.6)
```bash
git status --short          # working tree clean vs HEAD
git show HEAD:CLAUDE.md | wc -l ; wc -l CLAUDE.md   # match
# PD-007 re-sync committed files from HEAD:
for f in .claude/skills/session-coord/session-coord.md CLAUDE.md docs/Two-Cowork-Coordination.md docs/Two-Cowork-Coordination.ru.md tools/cc_prompt_two_cowork_protocol.md; do
    git show HEAD:"$f" > "$f"; echo "re-synced: $f ($(wc -l < "$f") lines)";
done
sync
```

### Step 6 — sync-block close-out (§42.6)
Journal append + commit.lock release per the sync block. Report back: commit hash, line counts,
`git status --short` (must be empty). NO push.
