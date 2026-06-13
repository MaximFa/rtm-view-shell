# CC task — codify 2 protocol items into RTM CLAUDE.md §42 + session-coord skill §10/§8
> Author: curator-0611 (protocol steward), 2026-06-12T10:27Z. Operator-GO via coordinator-0612 (RTM curator inbox 10:11Z).
> Executor: native CC in the RTM View Shell repo. Commit prefix `docs:`. **NO push** (rides next barrier).
> Writes Python+os.fsync (§0.3); verify by object store (§0.5). Append-only NEW subsections; do NOT rewrite existing prose.
> SCOPE = RTM ONLY (this repo). AD §26 equivalents are applied SEPARATELY by the AD coordinator's pending CC pack (NORM-CUR-01).

## 0. Pre
Read CLAUDE.md §0 (discipline) + §42. commit.lock around the commit; journal line after; post-commit re-sync from HEAD (§0.7).

## ITEM 1 — Doc-governance → extend CLAUDE.md §42.7 (push-barrier) with:
- **Tech Writer = MANDATORY doc-sync gate in EVERY push-barrier quorum** (peer of Security/DBA). Barrier NOT complete without it.
- **Product Release ID = `RTM-REL-YYYY.MM[.patch]`** (release train, NOT a git hash). COORDINATOR assigns; Tech Writer REQUESTS.
  Every approved doc carries an in-doc revision-history table: Version | Date | Summary | Product Release ID | Shipped-with
  (commit/barrier) — Shipped-with filled post-hoc.
- **Doc-sync = IMPACT TRIAGE at each barrier:** no-impact -> instant READY; minor/internal -> READY + doc-debt ticket;
  doc-blocking (user-facing / schema / API / install-upgrade / security) -> HOLD until the doc is in `approved/`. Writer cites
  the changed/added/deleted blocks mapped to doc-sections; coordinator review = change->doc fit + cross-fact, NOT editing.
- **Folder layout:** `approved/{doc,pdf}` + `editing/` per doc area; each approved doc saved as BOTH `.docx` and `.pdf` at the
  same version; the in-doc revision-history table is mandatory.

## ITEM 2 — Auto inbox-check lifecycle hook → add a NEW §42.8. Reads the PERMANENT role mailbox `inbox/<role>.md`.
Cowork sessions act only on their turn (no daemon) -> turn-start + completion hooks. **DEFAULT = SAFE variant:**
 1. TURN-START PEEK (cheap): each turn check whether new content exists in the permanent role inbox after the last
    `> handled` marker — light "N new" check, NOT full processing.
 2. IDLE -> auto-process (`коорд: входящие` semantics) if new exists AND the session is idle between tasks.
 3. MID-TASK -> do NOT interrupt; hold "N pending".
 4. COMPLETION HOOK: on finishing a task, end the reply with "разобрать входящие? (N новых)".
 **Operator toggle (state in text):** STRICT variant (auto-process even mid-task) = operator opt-in; default SAFE.

## ITEM 3 — Reflect in the session-coord skill (edit the REPO file directly; it is a normal versioned file, NOT read-only):
Edit `.claude/skills/session-coord/session-coord.md` (Python+os.fsync):
 - §10: add a note that the inbox-hook (turn-start peek / idle auto-process / completion "разобрать входящие?") is the standing
   default, reading the PERMANENT role mailbox `inbox/<role>.md`.
 - §8 / lessons table: record (a) the permanent-role-mailbox norm, (b) the Tech-Writer mandatory doc-sync gate, (c) skills are
   edited via CC prompts (repo file), refreshed in running sessions by L-SC-15 cache-bump.
(The running sessions' cached skill refreshes via the L-SC-15 cache-bump — re-read note + operator `коорд: входящие` — NOT by editing a "read-only cache".)

## Acceptance (object-store verified)
- §42.7 carries doc-gate + Release-ID + impact-triage + folder rules; new §42.8 carries the SAFE inbox-hook + toggle line.
- session-coord §10/§8 carries the inbox-hook note + the 3 lessons.
- ONE `docs:` commit under commit.lock; journal line; NO push; working tree re-synced from HEAD.

## ITEM 4 — Retire the obsolete 'mandatory inbox-migration' (permanent role mailboxes made it unnecessary)
Edit `.claude/skills/session-coord/session-coord.md` §10/§14 (сессия: handoff/takeover) AND `.coord/session-commands.md`:
 - The `сессия: handoff` step "MANDATORY inbox migration (L-SC-21)" is RETIRED. With PERMANENT role mailboxes (`inbox/<role>.md`)
   a successor reads the same stable file — no migration, no copy-forward, no lost directive. Replace the MANDATORY-migration
   row with a one-liner: "Inbox migration RETIRED — role mailbox is permanent (see permanent-mailbox norm)."
 - Keep L-SC-21 in the lessons table as HISTORICAL (the reason the norm exists), marked superseded-by permanent mailboxes.
This makes the skill match the techwriter runbook mirror (already shows RETIRED) — removes the flagged disagreement.

## ITEM 5 — Reaffirm/tighten CLAUDE.md §0.7 — CC-prompt discipline (NORM-CUR-02)
Tighten §0.7: every CC task prompt is a `.md` file under `tools/`, issued to operator/CC ONLY as a code box
`Выполни задачу из файла tools/<name>.md` — the ONLY accepted form; NO inline prompts in chat; one canonical location.
(Editing skills is also via a CC prompt per NORM-CUR-03 — already in ITEM 3.)

## Acceptance (full pass, object-store verified)
- CLAUDE.md: §42.7 (doc-gate+Release-ID+triage+folders), new §42.8 (SAFE inbox-hook+toggle), §0.7 tightened (tools/ only).
- session-coord skill: §10/§8 inbox-hook note + 3 lessons (ITEM 3); §10/§14 + .coord/session-commands.md inbox-migration RETIRED (ITEM 4).
- ONE `docs:` commit under commit.lock; journal line; NO push; working tree re-synced from HEAD.
