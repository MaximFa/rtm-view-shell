# CC Task W2-fix: MetricWizard renders BEHIND config modal (z-index) — Queue Grid pilot

> Bug found at runtime: in the Queue Grid Columns tab, clicking a column's metric button does
> "nothing" — the wizard IS opening (Visible=true) but renders BEHIND the configurator modal.
> Root cause (verified): config modal `.editor-modal` z-index 10001 (!important), its
> `.editor-modal-backdrop` 10000 (app.css ~2515-2525); wizard `.metric-wizard-overlay` z-index only
> 1050 (MetricWizard.razor.css). The wizard is stacked under the config modal.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (phantom-aware S3, S4b flush, S1 hard-stop)
Read file: .claude/skills/widget-creator/widget-creator.md   (§16 dark mode)
Only after reading: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has content -> STOP.

## Claims (file-mode, metrics-0605) — component CSS only (no ScreenEditorPage needed)
- web: src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css
Run coord_check_claims on it first.

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block (slug + claim above)

## Fix (Python+fsync, §0.3)
In `src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css`, raise the overlay above the
configurator modal. The wizard is opened FROM the config modal and must sit on top of it:
```css
.metric-wizard-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10050;   /* above .editor-modal (10001) and its backdrop (10000) */
}
```
Change ONLY the z-index value (1050 -> 10050). Leave everything else intact.

## Build & manual verify
- Stop dotnet (§28) -> `dotnet build CcDashboard.sln` clean.
- Manual (report): Queue Grid config -> Columns tab -> click a column metric button -> the wizard now
  appears ON TOP of the config modal, Data metrics only, search/facets/detail work, selecting sets the
  column metric. Cancel/backdrop closes the wizard and returns to the still-open config modal.

## Commit
`fix: MetricWizard overlay z-index above config modal (W2 pilot was rendering behind it)`
pre-commit-check -> §0.6 verify -> journal -> S4b post-commit flush to coordinator -> release lock -> PD-007 re-sync. No push.

## Acceptance criteria
1. `.metric-wizard-overlay` z-index = 10050 (> 10001).
2. dotnet build clean.
3. Manual: wizard visible on top of the Queue Grid config modal; selection works; close returns to config.
4. One fix: commit; tree clean (ignore known false-M); journal + S4b; lock released; no push.
