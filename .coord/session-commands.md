# .coord/session-commands.md — working-session lifecycle commands
> For SPECIALIST (non-coordinator) sessions. Parallel to coordinator-commands.md. Prefix `сессия:`.
> Read at session start alongside session-coord skill + own inbox. All writes Python+fsync (§0.3).

| Command | What the session does |
|---|---|
| `сессия: входящие` | Process OWN slug inbox (inbox/<slug>.md). Read-back-verify, act, mark handled, flush status to coordinator. |
| `сессия: статус` / `сброс` | Flush a status block to inbox/coordinator.md: slug, status, cc_task, claims held, blockers, next. Refresh heartbeat. |
| `сессия: handoff` | **Produce a session handoff** before ending or handing to a successor → spec below. |
| `сессия: takeover` | **Adopt a predecessor session** cleanly → spec below. |

---

## `сессия: handoff` — outgoing session (end-of-shift OR pre-takeover)

**Steps (Python+fsync §0.3):**
1. **Integrity:** hash-verify OWN claimed files vs HEAD via object store (NOT line-count — false-M on mount, §0.2);
   restore any truncated (`git show HEAD:<f> > <f>`).
2. **HANDOFF block** in own session file (set `status: done` or `→<successor>`) + a TAKEOVER-HANDOFF in own inbox:
   delivered this session (commits + **pushed/unpushed**), claims held → **release-now vs successor-inherits**, cc_task,
   in-flight CC prompts + their §4 status, parked/pending items, loose ends, open seams.
3. **⚠ INBOX MIGRATION (MANDATORY — L-SC-21, the metrics-2→metrics-3 lesson 2026-06-09):**
   a successor reads its OWN slug inbox. If a successor slug exists, the OUTGOING session (or coordinator) MUST:
   - CREATE `inbox/<successor-slug>.md` immediately (header: "successor of <old-slug>");
   - COPY-FORWARD every UN-handled coordinator directive from the old inbox into it;
   - leave a pointer line at the end of the old inbox ("SUCCESSOR INBOX = inbox/<successor-slug>.md").
   An un-migrated inbox = the successor silently misses directives (it happened: metrics-3 missed a NO-IDLE GO).
4. **Flush** a short status to inbox/coordinator.md so the coordinator updates the roster.

## `сессия: takeover` — incoming successor

1. **Inbox:** confirm/CREATE own slug inbox (if the outgoing session didn't). Until migration is confirmed, read BOTH
   the predecessor's adopted inbox AND own slug inbox.
2. **Claims:** re-list inherited files in own session-file `files:` (don't rely on the predecessor's claim staying valid).
3. **Re-read** the coordinator's recent directives yourself — do NOT assume the predecessor's `> handled` markers cover you.
4. **Flush** TAKEOVER-COMPLETE to inbox/coordinator.md (slug, claims adopted, own inbox confirmed).

**Coordinator's reciprocal duty (codified):** on observing a takeover, ensure the successor inbox exists and route
ALL future messages there; re-deliver any directive sent to the adopted inbox after the takeover.

---
### Lesson L-SC-21 (candidate — fold into session-coord skill §11)
On takeover/handoff the successor inbox MUST be created and routing migrated, BEFORE the next directive. Successors
read own-slug inbox only; writing to the adopted inbox after takeover = lost message (metrics-2→metrics-3, 2026-06-09).
Sibling of the backlog CRITICAL "session↔coordinator delivery reliability" item.
