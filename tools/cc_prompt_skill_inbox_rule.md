# CC Task — session-coord skill: pin inbox read/write asymmetry (§10 входящие + §11 + L-SC-22)

> docs: change to .claude/skills/session-coord/session-coord.md. Closes a read-hygiene incident (2026-06-09):
> backend-0609 read coordinator.md (its OUTBOX) instead of its own inbox file -> missed coordinator directives
> (option-2 full-fix, push-first) -> re-asked answered questions. Push-independent, low-risk.

## 0. §0.6a integrity FIRST. §40 reads. §37 NO push. §0.3 Python+fsync (Edit BANNED). Touch ONLY the skill file.
## Sync slug coordinator-0609 (or whoever issues). Claims: .claude/skills/session-coord/session-coord.md.
S1 marker barrier; S2 coord_check_claims; S3 commit.lock; S4 cc_post_commit.sh.

## EDIT 1 — §10 row `коорд: входящие`
Find the `коорд: входящие` row in the §10 command table. APPEND to its action text (Python str.replace,
anchor on the existing row text) this clarification:
  "READ the file named after YOUR OWN slug = `.coord/inbox/<your-slug>.md` (messages TO you), IN FULL.
   `.coord/inbox/coordinator.md` is your OUTBOX (you WRITE there), NEVER your read-source. Rule: READ the file
   named after YOU; WRITE to the file named after the RECIPIENT. Do NOT reconstruct your directives from
   coordinator.md tail."

## EDIT 2 — §11 mailbox structure
Right after the `.coord/inbox/<slug>.md` / `.coord/inbox/coordinator.md` structure lines, INSERT a bold note:
  "**READ/WRITE ASYMMETRY (read-hygiene):** a session READS the file named after ITS OWN slug (its inbox) and
   WRITES to the file named after the RECIPIENT (coordinator.md for the coordinator, <peer> for a peer). Reading
   coordinator.md to find your own directives is the classic mistake — coordinator.md is everyone's OUTBOX to the
   coordinator, not your inbox. Read your own slug file IN FULL; skip blocks already marked `> handled by <your-slug>`."

## EDIT 3 — append lesson to the §8 / §9 lessons table
Add a row:
  "| L-SC-22 | Session read coordinator.md (its OUTBOX) instead of its own `.coord/inbox/<slug>.md` inbox ->
   missed coordinator directives, re-asked answered questions (backend 2026-06-09). Fix: READ the file named after
   YOU, WRITE to the file named after the RECIPIENT; pin this in each session file; read own inbox IN FULL + skip
   handled-marked blocks (no tail-only shortcut on your own small inbox). |"

## Verify + commit
- grep the 3 additions present; tail -3 proper close; the skill still parses (headings intact).
- `git add -f .claude/skills/session-coord/session-coord.md` (.gitignore blocks .claude/) ; commit:
  `docs: session-coord inbox read/write asymmetry (§10/§11 + L-SC-22, read-hygiene fix)`
- §0.6 verify + cc_post_commit.sh + HEAD re-sync. NO push (rides next barrier).

## Report: the 3 edits located + commit hash. NO push.
