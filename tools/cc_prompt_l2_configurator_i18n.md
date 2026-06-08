# CC Task L2: localize the widget configurator modal (UI strings) + metric button -> DisplayName

> Operator-found gap: the widget config modal chrome is hardcoded English (I18N-03 violation) — it ignores
> ru/he UI culture. The catalogue DATA is already localized (L1, live-verified); this is pure UI-STRING i18n
> of ScreenEditorPage.razor's config modal. Also: the metric picker button shows the raw English Description;
> switch it to the localized DisplayName (the wizard already shows DisplayName).

## Mandatory — read before starting
Read file: .claude/skills/blazor-frontend-design/SKILL.md  (Blazor localization, RTL, design-system, a11y for THIS project)
Read file: .claude/skills/frontend-design/SKILL.md          (general frontend-design + RTL/he-IL)
Read file: .claude/skills/session-coord/session-coord.md   (phantom-aware S3, S4b flush, S1 hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (§5; metric DisplayName vs Description)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP (known phantom may linger on mount; trust Windows/CC FS).

## Claims (file-mode, metrics-0605)
- web: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor  (EXCLUSIVE — most-contended file, shared with
       the dark-mode session; hold exclusive, RELEASE right after commit; dark-mode waits = L2 BEFORE dark-mode)
       src/CcDashboard.Web/Resources/SharedResources.en-US.resx (+ ru-RU, he-IL)  (SHARED — confirm hash==HEAD/false-M
       before editing, add keys ADDITIVELY, run the L-34 comm -23 verify)
> Run coord_check_claims on ScreenEditorPage FIRST; if any active session holds it (e.g. dark-mode), §9-queue.
> Do NOT touch any daytrend/devops-claimed file.

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block (slug + claims).

## Deliverable 1 — Localize ALL hardcoded user-visible strings in the widget config modal
The modal is the `ConfiguringWidget` block in ScreenEditorPage.razor (~lines 255-2050). AUDIT it fully and wrap
EVERY hardcoded user-visible English string in `@L["..."]`. Known offenders (NON-exhaustive — do a full pass):
 - Tab labels: General, Appearance, Thresholds, Rows, Columns, Call Metrics, Agent Metrics
 - Column/section headers: Name, Metric, Column, Colors, Typography, Display Options, Score, Filters
 - "columns (QM / Agent Group metrics)"; labels: Business Unit, Queue Name, Grid ID, Header Text, Text Color,
   Widget Background, Table Background, Light Mode, Dark Mode, Light, Dark
 - Empty/placeholder/operator text: "No matches", "No Business Units available", "AND", "OR", "Select metric..." (reuse Common_SelectMetric)
 - Any button text, tooltips, helper text in the modal.
Rules (frontend-design + L-34):
 - Reuse an existing SharedResources key if present (search the .resx FIRST); add a new key only if none.
 - Key naming: prefer existing patterns; for new config-modal keys use `WidgetCfg_<Label>` (e.g. WidgetCfg_General,
   WidgetCfg_Appearance, WidgetCfg_Name, WidgetCfg_Metric, WidgetCfg_BusinessUnit, WidgetCfg_NoMatches, ...).
 - Do NOT localize: metric DATA (DisplayName/descriptions come from the DB/query), MetricId, raw status/state names,
   "QM"/"Agent Group" platform prefixes inside metric descriptions.
 - Add EVERY new key to ALL THREE resx (en-US, ru-RU, he-IL) with EXACT matching names. en-US = English source;
   ru-RU + he-IL = translated (CC-terms English-in-parentheses convention; he is RTL).

## Deliverable 2 — metric button shows localized DisplayName (not raw Description)
The Queue/Agent/DataSlot metric buttons (and any col.Name default) currently use GetMetricDescription(col.MetricId),
which returns the raw English Description. The `Metrics` list is `List<RtsGridMetricDto>` loaded via the localized
GetRtsGridMetricsQuery (so DisplayName is already localized). Change the displayed label to prefer DisplayName:
 - Add/adjust a helper: `GetMetricDisplayName(id) => Metrics.FirstOrDefault(m=>m.MetricId==id)?.DisplayName
   ?? GetMetricDescription(id)` (fallback chain DisplayName -> Description -> id).
 - Use it for the 3 metric buttons (DataSlot ~391, Agent ~1606, Queue ~1995) and the col.Name default on selection.
 - Keep GetMetricDescription where it is genuinely needed; do not break other callers.

## Deliverable 3 — RTL (he-IL)
Confirm the modal renders correctly RTL under he-IL. The app sets dir on <html> per culture (CLAUDE.md §29.1,
App.razor). Verify labels/inputs don't break in RTL; if a config-modal element hardcodes left/right, switch to CSS
logical properties (frontend-design RTL guidance). Do NOT restyle beyond what RTL correctness needs (dark-mode is a
separate session).

## Step — L-34 localization verification (MANDATORY before commit)
```bash
grep -hPo '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | sort -u > /tmp/l2_razor.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/l2_resx.txt
comm -23 /tmp/l2_razor.txt /tmp/l2_resx.txt   # MUST be empty
```
Repeat the resx-key presence for ru-RU and he-IL (same key set). Any missing key -> add before commit.

## Build & manual verify
- Stop dotnet (§28) -> `dotnet build CcDashboard.sln` clean.
- Manual (report): set UI culture ru-RU then he-IL, open a widget config modal -> tabs + headers + labels localized;
  metric button shows localized DisplayName; he-IL renders RTL; en-US unchanged. (metrics-0605 will also live-verify via Chrome.)

## Commit
`web: localize widget configurator modal UI strings + metric button -> DisplayName (L2)`
(ScreenEditorPage.razor + SharedResources.{en-US,ru-RU,he-IL}.resx)
pre-commit-check -> §0.6 verify -> journal -> S4b post-commit flush to coordinator -> release lock -> PD-007 re-sync. No push.
RELEASE ScreenEditorPage.razor immediately after commit (dark-mode session waits).

## Acceptance criteria
1. dotnet build clean; L-34 verify empty (no raw @L keys missing in any of the 3 resx).
2. Config modal chrome fully localized (no hardcoded English labels remain in the modal region) for ru/he; en-US unchanged.
3. Metric button shows localized DisplayName (fallback Description -> id); col.Name default uses it too.
4. he-IL renders RTL without broken layout.
5. One web: commit; ScreenEditorPage released after commit; tree clean (ignore known false-M); journal + S4b; lock released; no push.
