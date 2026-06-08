# CC Task L1-C-i18n: localise the translation-editor modal chrome (MetricsPage)

> Follow-up to L1-C (ea46ef4): the new translation-editor modal in MetricsPage.razor has hardcoded
> English chrome (TODO L1-C-i18n markers). Localise them. GATED: test-5-0607 owns the 3 SharedResources
> resx — this task may ONLY be issued AFTER test-5 releases them (its charttype/dark-mode commit). At issue
> time run coord_check_claims on the resx; if still held -> §9-queue, do NOT proceed.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md  (phantom-aware S3, S4b wrapper, S1 hard-stop, §9 queue)
Read file: .claude/skills/blazor-frontend-design/SKILL.md  (Blazor localization, RTL he-IL, a11y)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP.

## Claims (file-mode, metrics-2-0607)
- web: src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor  (mine — ongoing)
- web: src/CcDashboard.Web/Resources/SharedResources.en-US.resx (+ ru-RU, he-IL)  (SHARED — test-5 territory;
       claim ONLY after test-5 RELEASES them; coord_check_claims FIRST; §9-queue if still held; confirm ==HEAD/false-M before edit; add keys ADDITIVELY)
> Touch NOTHING else. Do NOT touch ScreenEditorPage / MetricWizard / app.css (test-5).

## Step 0 — §0.6a integrity + git fetch (§42.7.6) + coord sync block (slug + claims).

## Deliverable — localise the translation modal (MetricsPage.razor, the ShowTranslationModal block ~line 289-377 + the row button ~line 81)
Wrap every hardcoded user-visible English string in `@L["..."]`:
 - Row icon button `title="Translations"` (~81) and modal title `Translations: @TranslationMetricId` (~296) -> new key `Metrics_Translations` (e.g. "Translations" / "Переводы" / he).
 - EN reference card: "(Reference - read only)" -> new key `Metrics_TranslationRef` ; the `en-US` literal stays as-is (locale code, not translatable).
 - "Clear" button title (~336) -> reuse existing `Common_Clear` if present, else new `Common_Clear`.
 - Per-locale + EN field labels DisplayName / ShortDescription / LongDescription / Comparison -> **REUSE EXISTING keys**
   `Metrics_DisplayName`, `Metrics_ShortDescription`, `Metrics_LongDescription`, `Metrics_Comparison` (already in the resx,
   used by the metric edit modal ~196-208). Do NOT create duplicates.
 - Modal footer Close/Cancel (~377+) -> reuse `Common_Close` / `Cancel`.
RULES (L-34): search the resx FIRST and reuse; add a NEW key only when none exists. Add EVERY new key to ALL THREE
resx (en-US source; ru-RU + he-IL translated, CC English-in-parens convention; he is RTL). Remove the
`<!-- TODO L1-C-i18n -->` comment(s) once done. The he-IL field inputs already set dir per locale — keep that.

## L-34 verification (MANDATORY before commit)
```bash
grep -hPo '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor | sort -u > /tmp/l1ci_razor.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/l1ci_resx.txt
comm -23 /tmp/l1ci_razor.txt /tmp/l1ci_resx.txt   # MUST be empty
```
Repeat the key-presence check for ru-RU and he-IL (same key set). Any missing -> add before commit.

## Build & verify
- Stop dotnet (§28) -> `dotnet build CcDashboard.sln` clean.
- Manual (report): /admin/configuration/metrics -> open Translations modal under ru-RU then he-IL: title, "Reference",
  field labels, Clear/Close localised; he-IL renders RTL; en-US unchanged.

## Commit
`web: localise metric translation editor modal chrome (L1-C-i18n)`
(MetricsPage.razor + SharedResources.{en-US,ru-RU,he-IL}.resx)
S3 lock -> pre-commit-check -> git add (claimed only) -> commit -> §0.6 verify ->
`bash tools/cc_post_commit.sh metrics-2-0607 $(git log -1 --format=%h)` -> sync. No push.
RELEASE the 3 resx immediately after commit.

## Acceptance criteria
1. dotnet build clean; L-34 comm -23 empty for all 3 resx.
2. Translation modal fully localised (no hardcoded English; TODO comment removed); field labels REUSE existing Metrics_* keys.
3. New keys (Metrics_Translations, Metrics_TranslationRef, Common_Clear if new) in all 3 resx; he-IL RTL intact; en-US unchanged.
4. resx NOT edited until test-5 released them (coord_check_claims clean / §9-grant); released after commit.
5. One web: commit; tree clean (ignore false-M); journal + S4b via wrapper; lock released; no push.
