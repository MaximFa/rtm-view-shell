# CC task — TASK A: T1-fix — align guides BOTH product-floor bugs (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T08:04Z (operator PHASE-2 dispatch, OBSERVED RUN). Owner: role-shell. Executor: native CC.
> Claim: src/CcDashboard.Web/wwwroot/js/widget-resize.js (JS-only). Commit `fix:`. **NO push** (§37).
> T1 shipped at 9734252 but BROKEN in the LIVE product (operator + Маяк on https://localhost:5239). Two one-area fixes.

## INIT (role-shell) + §40
- role-shell INIT: read .claude/skills/role-shell/role-shell.md §A (cardinal truths) + §C verify-green before acting.
- §40: read widget-planner / widget-creator / session-coord skills.

## §0.6a integrity + POST-VERIFY norm (operator 2026-06-17) — RELIABLE FLOOR ONLY
- Verify by `ls`-listing + `cat`-content + git object-store (`git show HEAD:<f>` / `git hash-object` vs `git rev-parse HEAD:<f>`).
- Do NOT trust `-f`/`-s` stat or `git status` line-count alone — the Cowork mount PHANTOMS stat (L-SC-10/14). Mount-ambiguous -> ESCALATE to operator real-FS, do NOT assert.
- §0.6a: confirm branch v2-backend; hash-verify widget-resize.js vs HEAD before editing.

## §42.6 sync — slug role-shell (apply tools/cc_prompt_sync_block.md)
- S1: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> match STOP. (NOTE: operator lifted freeze for THIS shell task.)
- S2: `python3 tools/coord_check_claims.py shell-0609 src/CcDashboard.Web/wwwroot/js/widget-resize.js` -> exit1 STOP.
- S3: commit.lock around git add/commit (owner shell-0609). NOTE: lock confirmed CLEARED by operator real-FS; if mount shows it, that is a PHANTOM — re-check by `cat` (empty/absent) + escalate if ambiguous, never assert held from `-f`/`-s`.
- S4: cc_post_commit.sh shell-0609 <hash> ; sync. S5: NO push.
## §0.3 — Edit BANNED. Python read->modify->write + os.fsync; verify by `cat`/git, not stat.

## Binding PREAMBLE -> .coord/cc/shell.md: ## 2026-06-17T08:04Z | binding: shell <-> CC | directive: tools/cc_prompt_t1fix_align_guides.md | status: open / ### DIRECTIVE: T1-fix 2 bugs (.widget->.dashboard-widget + hideGuides in onMouseUp). fix:. NO push.

## THE WORK — 2 bugs in wwwroot/js/widget-resize.js
**Bug #1 (widget-to-widget guides never appear):** in `cacheAlignTargets` (~L83), line ~102
`canvas.querySelectorAll('.widget')` -> change to `canvas.querySelectorAll('.dashboard-widget')`.
(Widgets render as `.dashboard-widget`, ScreenEditorPage.razor:190 — `.widget` matched nothing, so sibling targets were empty.)
Keep the `.filter`/exclude-dragged logic; only the class string changes.

**Bug #2 (guide lines STUCK on screen after release):** in `onMouseUp` (~L283), BEFORE `this.activeWidget = null;` (~L319),
ADD `this.hideGuides();`. (`hideGuides` exists ~L403; it was never called on drag-end, so the last shown lines persisted.)
Place it so it runs on every mouseup that had an activeWidget (after the position commit, before nulling).

Do NOT change anything else (no app.css/razor needed; pure JS).

## VERIFY
- Code: `git show`/`cat` widget-resize.js -> line 102 now `.dashboard-widget`; onMouseUp contains `this.hideGuides();` before `activeWidget = null`.
- JS parses (no syntax error). `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors (JS not compiled, but build confirms no razor breakage).
- **PRODUCT ACCEPTANCE (operator + Маяк, on https://localhost:5239 — NOT a commit claim):** drag a widget toward another -> H/V guide line APPEARS on edge/centre align; RELEASE -> guide line DISAPPEARS. CC reports the code change is correct + flags that live-product verification is operator/Маяк's floor (CC cannot see 5239).

## §0.6b CAPTURE (mandatory) -> role-shell §B (`git add -f .claude/skills/role-shell/role-shell.md`)
Append dated, source-pinned lesson, e.g.:
`<date> · JS canvas selectors must match the RENDERED class — widgets are .dashboard-widget not .widget (ScreenEditorPage.razor:190); a wrong selector silently no-ops (move works, feature dead). + always hideGuides() on drag-end or shown lines stick. · RULE: grep the actual razor class before querySelectorAll; pair every show-guide with a drag-end hide. · SOURCE: widget-resize.js:102 + onMouseUp; commit 9734252 broke, fixed <hash>. · status: active`

## Commit (fix:, NO push) under commit.lock
bash tools/pre-commit-check.sh ; git add src/CcDashboard.Web/wwwroot/js/widget-resize.js .claude/skills/role-shell/role-shell.md (the CAPTURE line, `-f`) ; git commit -m "fix: T1 align-guides product bugs — .widget->.dashboard-widget selector + hideGuides on drag-end [shell-0609]" ; git rev-parse HEAD
§0.6 post-commit (verify by git show HEAD:<f>, not stat) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync from HEAD -> sync.

## Binding RESULT -> .coord/cc/shell.md (status: done): commit <hash>; bug#1 .dashboard-widget @102, bug#2 hideGuides in onMouseUp; build 0 err; CAPTURE appended; PRODUCT-verify = operator/Маяк on 5239 (cited as their floor, not mine). NO push. verified: object-store (git show HEAD).

## Report (chat): commit hash; both fixes confirmed via git show HEAD (not stat); CAPTURE line; build; note product-acceptance is operator/Маяк live-floor. NO push.
