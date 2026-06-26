# CC — role-bi §A#9/§D two-tier -> THREE-tier (curator-blessed verbatim apply)

> Owner: role-bi (bi-0619), curator-blessed (curator-0611 20:50). Execute: NATIVE CC. Branch: v3. docs: commit.
> §4-PASS (coordinator-0612 21:09 — apply verbatim). Single-source skill edit (NORM-CUR-03): only CC writes the skill.
> Scope: ONE file — .claude/skills/role-bi/role-bi.md. NO push.

## STEP 0 — integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git status --short
f=.claude/skills/role-bi/role-bi.md; H=$(git show HEAD:"$f"|wc -l); W=$(wc -l <"$f"); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo RESTORED; } || echo OK; sync
```
## STEP 1 — sync block + binding PREAMBLE (slug bi-0619, claim .claude/skills/role-bi/role-bi.md).

## THE EDIT (verbatim, curator-blessed)
### A. REPLACE §A#9 (current single line "9. TWO-TIER (architect verdict 2026-06-19, FOUNDATIONAL): ...") with this SINGLE line
(keep it ONE physical line, same style as the other cardinal truths, so §A stays within its ~40-line cap):

9. THREE-TIER (operator 2026-06-21, FOUNDATIONAL, supersedes two-tier): (1) RT working set RTSData_* (4 tables, ~1mo, module-owned purge A2, contour-gated; MidnightClear superseded — never re-enable, dead Engine.cs:957). (2) DURABLE RAW archive — reporting-owned IMMUTABLE copies of ALL 4 RTSData_ tables (Interaction/UserStatusLog/ChatMessage/UserStatus), 7yr monthly RANGE partitions, idempotent archiver from RTSData_* (COPY out, no contour touch); the SOURCE OF TRUTH for re-aggregation when reports are added/changed; INVARIANT archive-FIRST-purge-SECOND. (3) Aggregates hist_* 7yr, FAST report path, RE-DERIVABLE from tier 2. Aggregates are LOSSY -> raw persists 7yr. · SOURCE: operator 2026-06-21, ADDENDUM A rev1.2, Reports_v1_Scope §5b

### B. UPDATE §D "TWO-TIER CONTRACT" bullet -> THREE-TIER
In §D, find the bullet beginning "- TWO-TIER CONTRACT (architect verdict 2026-06-19 ...)" and revise it to a THREE-TIER
contract: (1) RT working set RTSData_* (~1mo, module-owned purge A2, contour-gated; MidnightClear dead Engine.cs:957 —
keep the established cause trace as-is); (2) NEW durable RAW archive — reporting-owned IMMUTABLE copies of all 4 RTSData_
tables, 7yr monthly RANGE partitions, idempotent archiver (COPY out of RTSData_*, no contour touch), archive-FIRST ->
purge-SECOND, the re-aggregation source; (3) aggregates hist_* 7yr, re-derivable from tier 2. Retitle the bullet
"THREE-TIER CONTRACT". Preserve all existing domain facts (MidnightClear cause, RT-purge=contour-gated) — only add tier 2
and relabel. Domain facts otherwise unchanged.

## ACCEPTANCE
- §A still <= ~40 lines (the new #9 is ONE line, same as the old #9 it replaces -> net 0 line change).
- SOURCE pin present on §A#9; "supersedes two-tier" explicit; §D bullet retitled THREE-TIER with tier-2 added.
- No other skill content changed. `git show HEAD:...role-bi.md` matches after commit (object-store verify).
- docs: commit on v3 (e.g. `docs: role-bi §A#9/§D two-tier -> three-tier (curator-blessed; raw-fact 7yr archive)`), commit.lock.

## STEP 2 — binding POSTAMBLE RESULT -> .coord/cc/bi.md. STEP 3 — journal + §0.7 re-sync. NO git push (§37).
