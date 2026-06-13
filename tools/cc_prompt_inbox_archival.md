# CC task — inbox auto-archival (NORM-CUR-06): commit script + fold into auto-inbox-hook + add `коорд: чистка`
> Author: curator-0611. Executor: native CC in THIS repo. docs: commit, NO push (§0.6). Python+fsync (§0.3). §4-review first.
> UNIFORM (NORM-CUR-01): the OTHER project applies the identical change to its own skill copy + CLAUDE.md (parity owned by curator).

## Steps
1. Commit `tools/inbox_archive.py` (already placed by curator). It keeps header + last N blocks + any block within last 24h;
   moves older blocks to `.coord/inbox/archive/<role>.md` (append-only, durable; never deletes).
2. Edit `.claude/skills/session-coord/session-coord.md` — in the auto-inbox-hook (§10) + lessons (§8):
   add: "AUTO-ARCHIVAL: after processing your inbox, if `inbox/<role>.md` exceeds ~40 blocks (or ~250 lines), run
   `python3 tools/inbox_archive.py .coord/inbox/<role>.md` — prunes handled/old blocks to `inbox/archive/<role>.md`,
   keeping the last N + last 24h. The coordinator runs it bus-wide during `коорд: разбери` / `коорд: проверь шину`."
   Add lesson L-SC-25 (inbox auto-archival norm).
3. Add verb to §10 registry: `коорд: чистка [<role>]` (any session / coordinator) = run inbox auto-archival on own inbox
   (or, coordinator, on all role inboxes). Alias `сессия: чистка`.
4. CLAUDE.md auto-inbox-hook section (RTM §42.8 / AD §26.9): add the one-line auto-archival clause.
5. Commit `docs(coord): inbox auto-archival (NORM-CUR-06) — script + hook clause + коорд: чистка verb`; journal; NO push; re-sync.

## Acceptance
- tools/inbox_archive.py committed; skill §10 has the auto-archival clause + `коорд: чистка` verb + L-SC-25; CLAUDE.md hook clause present.
- Curator confirms RTM<->AD skill parity after both repos apply.

## CONCURRENCY HARDENING (NORM-CUR-06b — REQUIRED)
inbox_archive.py is now v3: re-read-before-write (preserves concurrent appends) + atomic temp+os.replace + CALLER MUST hold
.coord/locks/commit.lock. The trigger (auto-hook / коорд: разбери / коорд: чистка) acquires commit.lock around the archival.
Codify this requirement in the skill/CLAUDE auto-archival clause. Re-pull tools/inbox_archive.py (v3) before running this prompt.
