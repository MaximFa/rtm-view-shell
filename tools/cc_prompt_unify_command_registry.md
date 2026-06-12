# CC Task — Unify the protocol command registry (single source = session-coord §10)

> Operator-approved canon: RTM names = CANON, AD short names = ALIASES; adopt `ревью` + `промпт` as canonical verbs.
> Goal: ONE operative source = the session-coord skill §10 (sessions load it). Short .coord registries + docs are
> POINTERS/MIRRORS to §10, never partial copies. Cross-project = PARITY of each project's §10 (separate files).
> Scope: RTM repo only (skill §10 + the two .coord registries). NO push (§37). Commit prefix: docs:.
> WRITES: Python read->replace->write + os.fsync (CLAUDE.md §0.3, Edit BANNED on mount). Verify each with grep.

## 0. Integrity
cd "D:\Claude\Projects\RTM View Shell"; git status --short  # restore truncated M vs HEAD before editing.

## FILE A — .claude/skills/session-coord/session-coord.md  (§10 = the master registry)
Read the §10 command table first. It already has ~21 коорд: + сессия: verbs. Apply EXACTLY these changes:

A1. ADD two canonical verbs (rows in the §10 table), with these definitions:
  - `коорд: ревью`  (any session asks; coordinator acts) — Coordinator §4 review of a CC prompt OR a returned result:
    checks mandatory blocks (§0.6a integrity, §40 skill-loads, sync block), claim correctness, acceptance criteria, and
    fact-consistency vs code/object-store. Verdict PASS / REVISE-with-notes -> writes verdict to the requester's inbox.
  - `коорд: промпт <role> <task>` (coordinator) — Coordinator drafts a FULL self-contained directive (mandatory reads +
    integrity block + the specialist's claim + task + acceptance criteria + commit.lock/journal/no-push), writes it into
    `.coord/inbox/<role-slug>.md`, and hands the operator the trigger-list. The coordinator does NOT execute or trigger.

A2. ADD alias annotations to the existing rows (canon name first, alias in parens):
  - `коорд: готовим пуш`  (alias: `коорд: барьер`)
  - `коорд: сессия <slug> мертва`  (alias: `коорд: разлок`)
  - `коорд: проверь шину`  (superset of: `коорд: журнал` — bus integrity incl. journal<->git reconcile)
  - `коорд: входящие`  (alias: `коорд: прочитай`)  [if not already noted]
  - `сессия: статус`  (alias: `сессия: сброс`)  [if not already noted]

A3. Ensure a SINGLE-SOURCE header at the top of §10 (add if missing):
  "§10 is the SINGLE OPERATIVE SOURCE of protocol commands for THIS project. Every short registry
   (.coord/coordinator-commands.md, .coord/session-commands.md) and every doc (runbook, UNIFIED mirror) is a POINTER or
   MIRROR of this section — NEVER a partial copy (partial copies caused the `сбрось` drift, 2026-06-10/11). Cross-project
   parity: the OTHER project's session-coord §10 must carry the identical verb set; keep both in sync, do not share one file.
   A running session caches the skill at start (L-SC-15): after any §10 change, the coordinator drops a 're-read skill'
   note into each active inbox and the operator triggers `коорд: входящие`."

## FILE B — .coord/coordinator-commands.md
Confirm it DEFERS to §10 (it already has the warning header + сбрось/статус). Add `коорд: ревью` and `коорд: промпт`
to its short list (or keep them under the "see §10" catch-all). Do NOT let it present a partial set as complete — keep
the "ИСТОЧНИК ПРАВДЫ = §10" header. No name should contradict §10.

## FILE C — .coord/session-commands.md
Confirm it defers to §10 and lists `сессия: входящие | статус(сброс) | handoff | takeover` consistent with §10. No drift.

## Commit (docs:, NO push)
bash tools/pre-commit-check.sh
Stage: .claude/skills/session-coord/session-coord.md .coord/coordinator-commands.md .coord/session-commands.md
Commit: "docs: unify command registry — §10 canonical superset (RTM-canon + AD aliases + ревью/промпт); short registries are pointers to §10"
Post-commit verify clean. NO push.

## Report
The §10 verb table after edit (full list) ; the 2 new verbs present ; the 3 alias annotations present ; single-source header present ;
both short registries defer to §10 ; commit hash. NO push. (Operator then: same canon -> AD-coordinator applies to AD's §10; techwriter mirrors in docs/runbook; coordinator cache-bumps active RTM sessions.)
