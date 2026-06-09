# CC Task — session-coord skill: formalize lifecycle commands + L-SC-21 (inbox migration)

> Author: coordinator-0609. Folds the coordinator/session lifecycle commands created on the bus this shift
> into the repo skill `.claude/skills/session-coord/session-coord.md`. The canonical specs already live in
> `.coord/coordinator-commands.md` + `.coord/session-commands.md`; this makes the skill point to them + adds the lesson.
> Pure docs/skill edit — no code, no behavior change. docs: commit, NO push.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## Git push (§37)
Do NOT run `git push`. Commit only.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) + fetch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
# restore truncated M files; SKIP known false-M/binary (hash differs but content==HEAD):
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  HL=$(git show HEAD:"$f" 2>/dev/null | wc -l); WL=$(wc -l < "$f" 2>/dev/null)
  if [ "$((HL-WL))" -gt 0 ]; then echo "TRUNCATED $f (HEAD=$HL wt=$WL)"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f ($WL)"; fi
done
sync
```

## Multi-session sync (§42.6) — slug: coordinator-0609
Claims: .claude/skills/session-coord/session-coord.md
```bash
# S1 barrier (marker-based, tombstone-safe): block ONLY on "FREEZE ACTIVE"
if grep -q "FREEZE ACTIVE" ".coord/push/request.md" 2>/dev/null; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
# S2 claims
python3 tools/coord_check_claims.py coordinator-0609 .claude/skills/session-coord/session-coord.md
# exit 1 -> STOP. Touch ONLY this file (+ /tmp/coordinator-0609_*). Edit tool BANNED (§0.3): Python+fsync.
```
- S3 commit.lock: phantom-aware acquire (the /tmp/acquire_lock.py from tools/cc_prompt_sync_block.md; retry 5x60s).
- S4: after commit + §0.6 verify, LAST step: `bash tools/cc_post_commit.sh coordinator-0609 $(git log -1 --format=%h)` then `sync`.
- S5: NO git push (§37).

---

# TASK — two anchored insertions into .claude/skills/session-coord/session-coord.md (Python+fsync, Edit BANNED)

Write /tmp/coordinator-0609_patch_skill.py:

```python
import os
P = ".claude/skills/session-coord/session-coord.md"
with open(P, "r", encoding="utf-8") as f:
    text = f.read()
lines = text.split("\n")

# --- Insertion 1: add L-SC-21 to the §8 lessons list, right after the L-SC-20 entry ---
i20 = next((i for i,l in enumerate(lines) if "L-SC-20" in l), None)
assert i20 is not None, "ASSERT FAIL: L-SC-20 line not found (lessons section)"
assert "L-SC-21" not in text, "ASSERT FAIL: L-SC-21 already present — abort (idempotency)"
LSC21 = ("- **[L-SC-21] Inbox migration on takeover/handoff (MANDATORY).** A successor reads ONLY its own-slug "
         "inbox. On takeover/handoff the successor inbox MUST be created and routing migrated (copy-forward "
         "unhandled directives + pointer in the old inbox) BEFORE the next directive; the coordinator re-delivers "
         "any directive written to the adopted inbox post-takeover. Writing to the adopted inbox after takeover = "
         "lost message (metrics-2->metrics-3, 2026-06-09). Sibling of the backlog CRITICAL delivery-reliability item.")
lines.insert(i20 + 1, LSC21)

# --- Insertion 2: append a consolidated lifecycle-commands section at END of file ---
SECTION = """
---

## 14. Lifecycle commands — registries (canonical) + summary

Canonical command specs live in two bus registries (read at session start):
- `.coord/coordinator-commands.md` — operator->coordinator verbs: `коорд: входящие | разбери | проверь шину | дай ack | handoff`.
- `.coord/session-commands.md` — specialist-session verbs: `сессия: входящие | статус | handoff | takeover`.

### `коорд: handoff` (extends §12)
Coordinator writes a verified resume checkpoint to `.coord/coordinator_handoff.md` (truth = bus + git object store,
NOT chat): git tip/origin/unpushed, push/freeze, roster (stale>3h flagged), in-flight + §4 queue, operator to-dos,
untracked->git-home (E-023), lessons. + journal line + MEMORY pointer. Read+snapshot only — never raises a barrier
or issues a CC prompt.

### `сессия: handoff` / `сессия: takeover` (works WITH §11 mailbox)
Outgoing: hash-verify own claimed files vs HEAD (object store, not line-count), write a HANDOFF block (delivered +
pushed/unpushed, claims release-vs-inherit, cc_task, in-flight prompts + §4 status, loose ends), and — MANDATORY —
migrate the inbox (L-SC-21). Incoming: confirm/create own slug inbox, adopt claims in own session file, RE-READ the
coordinator's recent directives (do not trust the predecessor's `> handled` markers), flush TAKEOVER-COMPLETE.
Coordinator reciprocal duty: on observing a takeover, ensure the successor inbox exists + route there.
"""
if "## 14. Lifecycle commands" not in text:
    if not text.endswith("\n"):
        lines.append("")
    text2 = "\n".join(lines) + SECTION
else:
    text2 = "\n".join(lines)

with open(P, "w", encoding="utf-8") as f:
    f.write(text2); f.flush(); os.fsync(f.fileno())
print(f"session-coord.md patched ({len(text2.splitlines())} lines)")
```

```bash
python3 /tmp/coordinator-0609_patch_skill.py && sync
tail -3 .claude/skills/session-coord/session-coord.md
wc -l .claude/skills/session-coord/session-coord.md
grep -n "L-SC-21\|## 14. Lifecycle commands\|coordinator-commands.md\|session-commands.md" .claude/skills/session-coord/session-coord.md
```

## Pre-commit + commit (docs:)
```bash
bash tools/pre-commit-check.sh .claude/skills/session-coord/session-coord.md
# exit 1 -> restore (git show HEAD:<f> > <f>), retry Python, re-check. Only on exit 0 proceed.
# acquire commit.lock (S3), then:
cp .git/index /tmp/coordinator-0609-idx
GIT_INDEX_FILE=/tmp/coordinator-0609-idx git add -f .claude/skills/session-coord/session-coord.md
GIT_INDEX_FILE=/tmp/coordinator-0609-idx git commit -m "docs: session-coord skill — §14 lifecycle commands (коорд:/сессия: handoff, takeover) + L-SC-21 inbox migration"
cp /tmp/coordinator-0609-idx .git/index
```
(If HEAD.lock blocks: use the §0.4 commit-tree + Python ref-write plumbing path. `git add -f` is REQUIRED — `.claude/` may be gitignored.)

## §0.6 post-commit verify + S4 + PD-007 re-sync
```bash
git status --short
git diff HEAD -- .claude/skills/session-coord/session-coord.md   # expect empty
git show HEAD:.claude/skills/session-coord/session-coord.md | wc -l ; wc -l .claude/skills/session-coord/session-coord.md  # must match
bash tools/cc_post_commit.sh coordinator-0609 $(git log -1 --format=%h)
git show HEAD:.claude/skills/session-coord/session-coord.md > .claude/skills/session-coord/session-coord.md  # PD-007 re-sync
sync
```

## Report
- Commit hash + line count before/after.
- grep output confirming L-SC-21 + §14 + both registry references present.
- Confirm: only .claude/skills/session-coord/session-coord.md changed; no push.
