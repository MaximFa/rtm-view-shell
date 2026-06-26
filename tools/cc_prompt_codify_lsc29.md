# CC task — codify L-SC-29 (push-prompt preflight) into session-coord skill + decide canonical-vs-per-barrier
> Author: curator-0611 (protocol steward). §4-DRAFTED by coordinator-0612 2026-06-14T03:59Z — curator to confirm/own before issue.
> Executor: native CC in the RTM View Shell repo. Commit prefix `docs:`. **NO push** (rides next barrier).
> Writes Python+os.fsync (§0.3); verify by object store (§0.5). Append-only NEW subsections / new table row; do NOT rewrite existing prose.
> SCOPE = RTM ONLY (this repo). AD parity applied SEPARATELY by AD coordinator (NORM-CUR-01).

## Why
L-SC-29 (push-prompt chronic staleness) is recorded in journal + coordinator memory but is NOWHERE in tracked docs/skill
(verified 2026-06-14: grep L-SC-29 = absent in .claude/, docs/, CLAUDE.md). Every barrier we hand-re-verify the same 4 things
from memory. Codify it so the preflight is a standing checklist, not tribal knowledge.

## 0. Pre (coord discipline)
Read CLAUDE.md §0 + §42.7. §0.6a integrity first (git status; hash-verify the skill file vs HEAD — mount false-M).
Binding PREAMBLE -> .coord/cc/curator.md (status: open, directive ref). commit.lock around the commit; cc_post_commit.sh after; §0.7 re-sync.

## ITEM 1 — add lesson L-SC-29 to session-coord skill lessons table (after L-SC-27 row)
Edit `.claude/skills/session-coord/session-coord.md` (Python+os.fsync), append ONE row:
| L-SC-29 | **Push-prompt preflight (chronic staleness).** NEVER run a push prompt blind. Before every push barrier verify, in order: (1) branch == `v2-backend` (NOT `v2`); (2) staging only EXPLICIT narrow adds — never `git add -A` / `git add docs/` / `git add db/`; (3) §0.2-restore any truncated working-tree file from HEAD BEFORE staging (PD-007 cross-session truncation); (4) NO `Export-All` in the push path; (5) no secrets in the prompt/log. A push prompt is the ONLY prompt allowed to `git push` (§37) — keep its guard inside the standing prompt so it cannot drift. |

## ITEM 2 — push-area note (near §42.7 / `коорд: пуш` verb, line ~223)
Add a one-line pointer so the verb references the preflight: "`коорд: пуш` first runs the L-SC-29 preflight (branch / explicit-adds / restore-truncated / no Export-All / no secrets); no quorum or failed preflight -> do NOT push."

## ITEM 3 — DECISION node: canonical vs per-barrier (curator to resolve, record outcome in skill)
Recommendation (coordinator): **CANONICAL.** Bake the L-SC-29 preflight INTO the standing `tools/cc_prompt_push.md`
(and its caller `tools/cc_prompt_push_barrier.md`) so it is maintained in ONE place and cannot go stale per-barrier.
Retire one-off copies (`tools/cc_prompt_push_45green.md` = historical, do NOT use as a template). Record the chosen
policy as a sentence in the skill push section. (Actually editing cc_prompt_push.md to embed the guard = a SEPARATE small
follow-on prompt after this codify lands — keep this task skill-only so it commits cleanly.)

## Acceptance (object-store verified)
- session-coord lessons table carries L-SC-29 (exact 5-step preflight); push section / `коорд: пуш` references it.
- Decision sentence (canonical, bake into cc_prompt_push.md next) present in the skill push section.
- Commit `docs:`; binding RESULT written; journal appended; NO push.

## Binding RESULT postamble -> .coord/cc/curator.md (status: done): commit <hash>; L-SC-29 row + push-note + decision sentence present (grep-verified); NO push; verified: object-store.
