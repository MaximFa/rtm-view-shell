# Curator discipline-lessons harvest (curator-0611)
> Lessons stewarded into CLAUDE.md §0 / curator-charter §4 / session-coord L-SC-*. Coordinate harvest with lab.

## L-CUR-01 | 2026-06-12T09:24Z | quoted-content write doubling
Writing SQL or any single-quoted content via Python STRING EMBEDDING can DOUBLE single quotes ('' ) -> psql
syntax error. Incident: commit 5c6a535, 02_catowner_role.sql, server-45 deploy fail (delegated fix+repackage
to devops-2-0607, byte-verify gate baked in). Sibling of the 65e6ca1 quote-doubling lesson.
MITIGATION: write SQL/quoted content via a QUOTED heredoc (<<'EOF') straight to file, NOT via Python string
embedding; add a byte gate before packaging -> the doubled-apostrophe count must be 0.
ENFORCE: candidate for CLAUDE.md §0.3 (writes) + curator-charter §4 bite-list. Flagged to coordinator-0612 for §0 codification.

## NORM-CUR-01 | 2026-06-12T09:32Z | decisions are UNIFORM across ALL projects
Operator directive: every protocol/discipline decision + bus-norm change applies IDENTICALLY to ALL projects
(RTM View Shell + Agent Desktop, and any future). No per-project divergence. The curator applies each change to
every project's bus + docs in the same pass, and keeps them at PARITY. (Origin: permanent-mailbox change 2026-06-12T09:32Z —
must hit Shell as well as AD.) Apply-to-all is now the default for command-registry, mailbox norms, §0 discipline,
push-barrier rules, runbook.

## NORM-CUR-02 | 2026-06-12T10:08Z | CC-prompt discipline — tools/<name>.md + code box
Every CC task prompt is written to a `.md` file under `tools/` and issued to operator/CC ONLY as a code box:
`Выполни задачу из файла tools/<name>.md`. Never inline in chat; never a non-tools folder. Rationale: git-versioned,
§4-reviewable before run, no chat truncation, one canonical location. UNIFORM all projects (AD was on tasks/ -> tools/).
Codify: RTM CLAUDE.md §0.7 (reaffirm), AD CLAUDE.md §22 (tasks/->tools/). Broadcast re-read to all role inboxes both buses.

## NORM-CUR-03 | 2026-06-12T10:27Z | skills are edited via CC prompt (repo file), NOT 'read-only / operator-only'
The `.claude/skills/**` files are NORMAL versioned repo files — edit them via a CC prompt (native CC, Python+fsync,
docs: commit, no push), like any other file. The 'read-only cache' caveat applies ONLY to the Cowork agent's plugin
cache (a Cowork session can't persist a skill edit), NOT to the repo copy. A running session's CACHED skill refreshes
via L-SC-15 cache-bump (re-read note + operator коорд: входящие), not by Settings. CORRECTS my earlier 'skill §10 edit
needs the operator via Settings' framing. UNIFORM all projects. Codify into session-coord §8/§10 (this CC pack).

## NORM-CUR-04 | 2026-06-12T12:38Z | F1 ruling: `коорд: сбрось` = FLUSH only; pause is natural-language, NOT a verb
Operator ruling: `коорд: сбрось` keeps its RTM-canon meaning = flush current status/question/handoff to the bus
(session form `сброс`=`статус`). There is NO pause verb in the registry — the operator pauses/stands-down via natural
language («пауза»). A one-off operator use of `сбрось` meaning pause was a misuse, not a registry change. Both registries
(RTM §10 + AD §27) keep `сбрось`=flush; optionally add a one-line note 'сбрось≠pause; pause = plain language' to prevent recurrence.

## NORM-CUR-05 | 2026-06-12T12:55Z | session-coord is THE canonical coordination skill — every project adopts it
session-coord (the §10 command registry + §1-12 bus protocol + generic L-SC lessons) is the CANONICAL coordination
core. EVERY project MUST carry an IDENTICAL agnostic copy at .claude/skills/session-coord/session-coord.md (operative
source = §10). CLAUDE.md §27/§26 = POINTER to it, NEVER a re-derived subset (subsets = the AD divergence). Project-specific
bindings (branch names, §-numbers, incidents) live in a thin project layer (CLAUDE.md), not the agnostic core. Any change
to the core PROPAGATES to ALL project copies (CC per project, curator owns parity, L-SC-15 cache-bump). New-project P1 =
adopt the core. CONTEXT: AD had NO session-coord skill (inlined §27) → codification 1799534 siloed in RTM. Root fix = port the core to AD, §27→pointer.

## NORM-CUR-06 | 2026-06-13T08:32Z | Inbox auto-archival — inboxes self-prune to archive/, never bloat
Role mailboxes self-prune: keep header + last N blocks + any block within last 24h; MOVE older to inbox/archive/<role>.md
(append-only, durable, never deleted). Mechanism = tools/inbox_archive.py. Triggers (no daemon): (a) the auto-inbox-hook after
processing, if oversized; (b) coordinator коорд: разбери/проверь шину bus-wide; (c) explicit коорд: чистка [<role>]. UNIFORM both
projects (script in each repo's tools/; skill+CLAUDE codify it). One-time pass done 2026-06-13: RTM coordinator.md 6605->519 lines
(394 blocks archived), AD/role inboxes pruned. Finding: coordinator inboxes bloat with UNMARKED blocks -> age-based archival (last N + 24h), not handled-only.

## NORM-CUR-07 | 2026-06-13T08:43Z | CC<->Spec binding - formalize the execution leg
Each CC-session-open creates a BINDING (spec-role <-> CC run <-> directive) in .coord/cc/<role>.md (rolling, append-only,
auto-archived). CC opens it (preamble), executes, writes the RESULT into the binding (commits/build-test/files/status/blockers/
object-store) - NOT to inbox/coordinator.md. The spec consumes the RESULT on its turn (auto-inbox-hook reads .coord/cc/<role>.md),
marks > consumed, relays a digest to the coordinator. Operator stops carrying CC results by hand. UNIFORM both projects; codified
into the CC-prompt TEMPLATE (sec0.6a/sec22 + skill sec4/sec10). Decided 2026-06-13 (operator GO, recommended design).

## L-CUR-02 | 2026-06-13T09:19Z | PostgreSQL UNQUOTED identifier folds to lowercase
Mixed-case PG identifiers MUST be double-quoted in SQL: `WHERE "TenantId" = ...`. Unquoted `WHERE TenantId` is folded to
`tenantid` -> 'column tenantid does not exist' (incident: Phase 5c B2, server-45 deploy 2026-06-13). Sibling of L-CUR-01
(apostrophe/quote-doubling). RULE: any SQL touching mixed-case columns/tables quotes the identifier; a deploy/test gate greps
for unquoted mixed-case identifiers in generated SQL.

## NORM-CUR-07b | 2026-06-13T09:59Z | binding write-routing + git-fallback (coordinator-0612 confirmed)
CC RESULTS -> binding native, NOT operator-relayed (local CC). Operator-relay = backstop only for no-repo contexts (server deploy
-> result-artifact ingested by a local session). Small bus chatter stays Cowork Python+fsync. AMENDMENT: the binding is an INDEX
to git (same-mount L-SC-04 read-loss), not a source of truth; spec-consume falls back to object-store if RESULT absent but commits exist.

## L-DEPLOY-01..03 + NORM-CUR-08 | 2026-06-13T10:40Z | anti-staleness of reference artifacts (PD-008 deploy 45 post-mortem)
L-DEPLOY-01: verify environment facts (PG version, server config, paths) FROM THE SERVER, never from the doc.
L-DEPLOY-02: a clean from-scratch rebuild (DB, deploy) is a TRUTH-TEST - it exposes stale reference artifacts that live/
incremental servers mask. Run it periodically, not only at first install.
L-DEPLOY-03: hand-maintained mirrors (db/functions/, schema.sql, deploy docs) DRIFT silently -> they MUST be GENERATED from the
authoritative source (Export-All from the live DB per sec39; pg_dump for schema), never hand-edited.
NORM-CUR-08 (anti-staleness / freshness-audit): any artifact that mirrors live or generated state is GENERATED/exported from its
authoritative source and carries a 'generated from X at <ts>' provenance line; never hand-maintained. A freshness-audit (folded
into koord: razberi / proverь shiny) compares reference artifacts to their source and FLAGS drift; the clean-rebuild truth-test
is the backstop. Headline (operator, PD-008): OUR reference truth (deploy docs + db/functions + schema.sql) rotted undetected.
UNIFORM both projects. Codify into CLAUDE.md (deploy/DB sections sec38/sec39) + the coordinator sweep via CC.

## L-SC-27 | 2026-06-13T10:54Z | auto-inbox-hook is BEST-EFFORT (sharpen §42.8 / L-SC-13)
the auto-inbox-hook is BEST-EFFORT, NOT autonomous: the turn-start auto-peek runs ONLY when the session is given a turn (an LLM session has no background daemon and does not poll). It does NOT replace the explicit `коорд: входящие`/`коорд: статус` triggers - those remain the RELIABLE delivery path; the operator stays the scheduler. A block arriving while a session has no turn is NOT seen until the next poke - a message missed without a poke is the EXPECTED behaviour, not an anomaly. No session (including the coordinator) may assume the auto-peek caught everything.
Evidence: coordinator-0612 missed dba 10:11 + techwriter 10:55 until an explicit peek (2026-06-13). Wording change only, no
mechanism change. Codify into CLAUDE.md §42.8/§26.9 + skill L-SC-13; UNIFORM both projects; BUNDLE into the pending NORM-06/07 pass.

## NORM-CUR-06b | 2026-06-13T11:00Z | inbox auto-archival must be concurrency-safe (L-SC-09)
The archival whole-file rewrite is L-SC-09-vulnerable (a concurrent append can be clobbered). HARDENED (inbox_archive.py v3):
(a) CALLER holds .coord/locks/commit.lock (serialize vs commits + other archival); (b) RE-READ immediately before write and keep
any block appended during the window; (c) write via temp + os.replace (atomic; dodges L-SC-17 phantom). Triggers (auto-hook /
коорд: разбери / коорд: чистка) MUST acquire commit.lock. Separately: plain INBOX blocks have NO git backstop -> a cross-view
drop (L-SC-04/L-SC-18) is unrecoverable from other views; the writer RE-ASSERTS and the recipient's handled-marker is the receipt
(L-SC-19: git + operator are the reliable channels; the file-bus is best-effort).

## NORM-CUR-07c | 2026-06-13T11:25Z | binding-open is MANDATORY in the §0.6a CC-prompt template (not opt-in)
Every CC prompt OPENS a binding (.coord/cc/<role>.md) right after the integrity block + WRITES a RESULT at the end - via the
§0.6a mandatory blocks + koord: prompt drafting, no longer per-prompt opt-in. The binding remains an INDEX to git (L-SC-04 drop
-> reconcile from object store / artifact, NORM-CUR-07b). Cause: devops iter1c_b2 binding RESULT dropped (L-SC-04) + some deploy
prompts carried no binding at all -> inconsistent. UNIFORM both projects (CC prompt tools/cc_prompt_binding_mandatory.md).

## NORM-CUR-09 | 2026-06-13T11:50Z | trigger-list parallelism annotation + п.N=§N convention
(a) When the coordinator hands the operator a TRIGGER-LIST (which sessions to poke `коорд: входящие`), annotate each:
    '||' = may run in PARALLEL (sessions independent: no output-dependency, no shared exclusive claim/lock);
    '->' = MUST run SEQUENTIALLY (one feeds another, or they contend on a shared exclusive claim / commit.lock). Default '->' when unsure.
(b) Operator convention: `п.N` == `§N` (the operator keyboard has no §; 'пункт N' is the semantic equivalent of section N). Treat identical.
Origin: coordinator-0612 peer-share 2026-06-13 (operator allows RTM-coord to peer-flush practice to AD-coord; curator owns the norm text + parity). UNIFORM both projects.

## NORM-CUR-10 | 2026-06-13T11:57Z | mandatory documentation by the Tech Writer (PERMANENT)
NORM-CUR-10 - Mandatory documentation by the Tech Writer (PERMANENT operator rule). Any decision, change, or addition -
protocol norm, code/feature, deploy/DB change, ADR, architecture, registry/command change - is ALWAYS documented by the Tech
Writer. Nothing is "done/complete" until its documentation is updated and current. The norm log (discipline-lessons.md) captures
protocol norms live; the Tech Writer synthesizes ALL changes into the project docs (runbook, ADRs, SRS, user/admin/ops docs) and
keeps them current. Enforced BOTH at the push-barrier doc-sync gate (TW READY/HOLD, sec42.7/sec26.5) AND as a standing between-
barrier duty. The coordinator routes every decision/change to the Tech Writer; the curator verifies doc-coverage at filing. UNIFORM both projects.

## NORM-CUR-07d | 2026-06-13T12:03Z | §4-review must verify binding presence (operator standing)
NORM-CUR-07d (§4-review must check binding presence). Every CC-prompt §4 review MUST verify the NORM-CUR-07 binding is in the
prompt: (a) PREAMBLE opens a BINDING block to .coord/cc/<role>.md (status: open, directive ref); (b) POSTAMBLE writes the RESULT
to the binding on commit (commits/build-test/files/status/blockers, object-store-verified) + cc_post_commit. Binding ABSENT or
PARTIAL -> §4 verdict = REVISE, not PASS. Enforces NORM-CUR-07c at REVIEW time, not by assumption.
UNIFORM both projects; into skill §4 review-checklist + coordinator §4 duty. Fold into bundle #3.



## L-SC-29 — push-prompt is CHRONICALLY STALE; verify-or-replace every barrier (recorded 2026-06-13T20:37Z)
**Symptom (recurred ≥2×: barrier #3 2026-06-10, barrier 2026-06-13):** `tools/cc_prompt_push.md` keeps reverting to an UNSAFE state and
gets re-patched by hand each barrier instead of being fixed once. Stale hazards it ships with:
 1. **Wrong push target** `git push origin v2` — our branch is `v2-backend` (§44). Pushing v2 = wrong trunk.
 2. **Broad `git add docs/ db/migrations/`** — commits PD-007-TRUNCATED working-tree over correct HEAD (corrupts migrations) AND sweeps
    HELD/unpublished drafts (techwriter editing/ package) into the push.
 3. **Unwanted Export-All** — regenerates schema.sql/data from the LOCAL dev DB (with a hardcoded password) as a push side-effect; the
    schema.sql regen is a deliberate durable task, NOT a push side-effect.
 4. Hardcoded stale file list + stale commit message from a prior barrier.
**Why it recurs:** barrier #3 rewrote the prompt correctly (v2->v2-backend, narrow staging, skip Export-All) but the fix DID NOT PERSIST
(uncommitted / PD-007 write-back reverted it) AND no durable lesson was recorded -> next coordinator re-discovers from scratch.
**MANDATORY every push barrier (NO exceptions):** do NOT run cc_prompt_push.md blindly. Before any push prompt runs, verify:
 (a) push target == the session's actual branch (`git rev-parse --abbrev-ref HEAD`; here v2-backend), NEVER a hardcoded `v2`;
 (b) EXPLICIT narrow `git add <paths>` ONLY — NEVER `git add docs/`, `git add db/`, `git add staging/`, `git add -A`, `git add .`
     (review `git diff --cached --name-only` before commit; unstage anything unexpected);
 (c) §0.2 integrity FIRST — restore PD-007-truncated WT (esp. db/migrations + staging) from HEAD before staging; the committed HEAD objects
     are what ship;
 (d) SKIP Export-All unless tracked DB-M is intended AND reviewed; no secrets in the prompt.
**DURABLE FIX:** maintain a VERIFIED canonical push prompt that is COMMITTED + carries a self-check of (a)-(d) at the top; OR author a fresh
per-barrier prompt (e.g. tools/cc_prompt_push_45green.md, 2026-06-13) and commit it. Either way the safe prompt must be tracked so it can't
silently revert. Curator: codify (a)-(d) as a push-prompt preflight into session-coord skill (§push / §42.7).
