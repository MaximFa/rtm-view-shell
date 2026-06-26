# CC task — UX colour/decoration consistency: dark header buttons + date-field palette + Save→primary (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Operator UX audit (2026-06-25, ux-ui-expert skill). Live computed-style audit of /reports View (light+dark) vs the overlay's own dark scheme + design tokens found 3 real items. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> SCOPE NOTE: this task INTENTIONALLY touches a shared selector (additive dark-mode header-button rule) AND the live dashboard editor Save colour — both operator-approved for cross-product consistency. This is NOT the reports-mirror parity-guard; it is a deliberate house-style alignment. Do NOT change anything else in ScreenEditorPage/ScreenFullscreenPage beyond the one Save class.

## INIT — branch v3 + role-shell §A/§C + §40 + integrity. §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push. Compile via /shell/start|restart (NOT /ops/build vs live watch — lesson 2026-06-25).

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/wwwroot/app.css (A: report-scoped date-input dark; B: NEW shared additive dark header-button rule)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor (C: Save btn-success→btn-primary, ONE line @ ~L92)
- src/CcDashboard.Web/Components/App.razor (app.css ?v bump)
- (role-shell.md via git add -f if CAPTURE)

## OVERLAY DARK SCHEME (the target palette — object-store app.css 2607+): container/canvas #121212; header/widget #1E1E1E; widget-header #2D2D2D; text #E4E4E7; borders rgba(255,255,255,0.08).

## THE WORK
### A. Date inputs — align dark palette to the overlay (report-scoped)
Current `.fullscreen-dashboard.dark-mode .report-header-datebar input[type="date"]` (app.css ~3504) uses SLATE tokens (#1e293b bg / #334155 border) — off-scheme vs the neutral-grey overlay; and the border doesn't win over `.form-control`. CHANGE that rule to the overlay palette WITH !important to beat .form-control:
```
.fullscreen-dashboard.dark-mode .report-header-datebar input[type="date"] {
    background-color: #2D2D2D !important;
    border-color: rgba(255,255,255,0.12) !important;
    color: #E4E4E7 !important;
}
```
(Keep the label-colour rule; ensure it reads #E4E4E7.)

### B. Header buttons — fix dark contrast (NEW shared additive rule)
In dark, `.fullscreen-header` buttons (dark toggle / close / Export / Schedule) render text #5f6368 + border #dadce0 on #1E1E1E (the global `.btn-outline-secondary`/btn base leaks through) → low contrast. ADD a NEW rule (does not exist today; additive — also corrects the dashboard viewer, operator-approved):
```
.fullscreen-dashboard.dark-mode .fullscreen-header .btn {
    color: #E4E4E7;
    border-color: rgba(255,255,255,0.15);
    background-color: transparent;
}
.fullscreen-dashboard.dark-mode .fullscreen-header .btn:hover:not(:disabled) {
    background-color: rgba(255,255,255,0.08);
    color: #FFFFFF;
}
.fullscreen-dashboard.dark-mode .fullscreen-header .btn:disabled { opacity: 0.5; }
```
Do NOT recolour `.btn-primary` (Apply stays blue). Place in a clearly-marked additive block; do NOT edit any existing selector.

### C. Save → primary (blue) everywhere (operator ruling: primary = btn-primary per skill §1)
- `Components/Dashboard/ScreenEditorPage.razor` ~L92: the Save button `class="btn btn-success btn-sm"` → `class="btn btn-primary btn-sm"`. ONE-line class change, nothing else in that file.
- (Ф5b-2 ReportEditorPage will use btn-primary Save from the start — handled in its own prompt.)
- Leave Publish (`btn-warning`)/Unpublish/Clone/Delete colours as-is; only Save changes green→blue.

## VERIFY / DoD (role-shell §A)
- Object-store: app.css date-input dark = #2D2D2D/rgba-white/#E4E4E7 (!important); NEW `.fullscreen-dashboard.dark-mode .fullscreen-header .btn` block present; ScreenEditorPage Save = btn-primary (diff = 1 line); App.razor ?v bumped; NO other existing selector edited.
- **Soma: compile via /shell/start|restart healthy + serilog [ERR]/[FTL] clean.**
- **VISUAL CHROME (light+dark):** /reports view — dark: toggle/close/Export now light & legible on the dark header; date fields neutral-grey (match scheme), not slate; Apply still blue. /screens editor — Save now blue; everything else unchanged. Screenshot dark before/after.

## §0.6b CAPTURE -> role-shell §B: "dark .fullscreen-header buttons inherited the light-theme .btn-outline-secondary override (#5f6368/#dadce0) — no dark rule existed → low contrast; date-bar used slate tokens off the neutral-grey overlay scheme. RULE: when reusing fullscreen-dashboard dark overlay, verify header buttons + added inputs against the overlay's #1E1E1E/#2D2D2D/#E4E4E7 palette, not Bootstrap/slate defaults." Commit fix:, NO push. Binding RESULT -> cc/shell.md (computed-style before/after + screenshots).
