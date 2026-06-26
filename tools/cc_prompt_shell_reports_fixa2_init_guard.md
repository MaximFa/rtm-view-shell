# CC task — Reports editor FIX-A2 (shell): widgetResize.init never runs → G-MOVE/G-RESIZE silently dead at runtime — AWAITING §4-BLESS
> Live authed-VISUAL gate (operator's own mouse, post-reload) = ⛔RED: a placed report widget does NOT move (header or drag-handle) and does NOT resize, with NO JS console error (silent no-op). FIX-A's object-store tokens were all present (init/startMove/startResize/JSInvokable) but the feature is non-functional — object-store ≠ functional.
> ROOT CAUSE (object-store, reasoned — NOT a selector mismatch): the markup classes (`.dashboard-widget`/`data-widget-id`/`.widget-drag-handle`/`.resize-handle.resize-*`) are byte-identical to the working dashboard. The real defect is the **init guard**:
> `ReportEditorPage.razor` OnAfterRenderAsync (~:289): `if (firstRender && Report is not null) { _dotNetRef = ...; await JS.InvokeVoidAsync("widgetResize.init", _dotNetRef); }`
> At **firstRender**, `OnInitializedAsync` is still awaiting `Mediator.Send` for `Report`, so the component is in its Loading state and **`Report` is null** → the guard is FALSE → `widgetResize.init` is **never called** (not on firstRender, and firstRender never recurs). Therefore the document `mousemove`/`mouseup`/`mousedown` listeners are never attached: `startMove`/`startResize` set `activeWidget` but nothing moves it → silent no-op, no error. The WORKING dashboard (ScreenEditorPage.razor:2897) calls init on `if (firstRender)` with NO `Report` guard.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / widget-resize.js / shared app.css selectors. ONE-file surgical change to ReportEditorPage.razor.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync for ALL writes; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_fixa2_init_guard.md | status: open
### DIRECTIVE (spec->CC): FIX-A2 remove the `&& Report is not null` init guard so widgetResize.init runs on firstRender (G-MOVE/G-RESIZE). Claim: ReportEditorPage.razor. fix:, NO push, §4-PASS + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor — **MODIFY** (sole target; ~line 289 init guard)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — **READ-ONLY reference** (:2895-2901, the correct unguarded init — do NOT edit)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## THE WORK (ReportEditorPage.razor — surgical)
Current (~:287-293):
```csharp
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender && Report is not null)
    {
        _dotNetRef = DotNetObjectReference.Create(this);
        await JS.InvokeVoidAsync("widgetResize.init", _dotNetRef);
    }
    ...
}
```
Change the guard to drop `&& Report is not null` so init runs on firstRender unconditionally (exactly like ScreenEditorPage:2897):
```csharp
    if (firstRender)
    {
        _dotNetRef = DotNetObjectReference.Create(this);
        await JS.InvokeVoidAsync("widgetResize.init", _dotNetRef);
    }
```
- Do NOT change anything else (the position-apply block, the handlers, the JSInvokable callbacks, dispose() — all already correct from FIX-A a963d73).
- Rationale: init only attaches document-level listeners + creates guide elements; it does NOT require the canvas/Report to exist yet (cacheAlignTargets/querySelector run later at drag time). Running it on firstRender during Loading is safe and is exactly what the dashboard does.

## VERIFY / DoD (role-shell §A — ЧП: the gate is LIVE, NOT object-store)
- **Object-store (necessary, NOT sufficient):** the init guard is now `if (firstRender)` (no `&& Report`); dispose()/handlers/JSInvokable unchanged; ScreenEditorPage/shared/widget-resize UNTOUCHED.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE FUNCTIONAL GATE — MANDATORY, this is what closes the defect (operator/QA + coordinator, real mouse):** on the running build, `/reports/{id}/edit` → place a widget → **grab the header/drag-handle and drag → the widget MOVES and STAYS where dropped (repeatable, post-reload)**; **grab a corner/edge handle → the widget RESIZES**; add a 2nd widget → both move independently (no top-left stacking). Do NOT report this fixed from object-store/token-greps — the previous FIX-A passed token-greps yet failed live. Readiness = the operator-verified live move+resize only.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY ReportEditorPage.razor (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports editor — call widgetResize.init on firstRender (drop Report-null guard) so move/resize work [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed file from HEAD.

## §0.6b CAPTURE -> role-shell §B (MANDATORY — this is a hard ЧП lesson): "object-store tokens present ≠ functional: FIX-A had init/startMove/startResize all present but `widgetResize.init` was guarded by `&& Report is not null`, false at firstRender (Report still loading) → init never ran → move/resize silent-dead. An init that attaches document listeners must run on `firstRender` UNCONDITIONALLY (match the working analogue), never gated on async-loaded state. A JS-interactivity fix is only 'done' after a LIVE operator move+resize, never a token-grep." SOURCE:<commit> + coordinator live gate 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportEditorPage.razor . status done|failed . blockers . verified: object-store (LIVE move+resize = operator gate, pending)
```
