# CC Task — fix pre-existing missing localization key Widget_DayTrend_ChartType

> DEFECT (pre-existing, found during frontend-bundle verification; confirmed at 7f60288, NOT from 536415b):
> ScreenEditorPage.razor:604 renders `<h6 class="section-label">@L["Widget_DayTrend_ChartType"]</h6>`
> (the DayTrend chart-type selector header), but the key `Widget_DayTrend_ChartType` is ABSENT from ALL THREE
> resx (en-US, ru-RU, he-IL). At runtime the raw key "Widget_DayTrend_ChartType" shows instead of "Chart type"
> — even in English. Sibling option keys (Widget_DayTrend_Line/Bar/Area/Step) already exist in en-US.
> FIX: add the one missing key to all three resx. NO .razor change (the @L ref already exists).

## Mandatory — read before starting (§40)
Read file: .claude/skills/session-coord/session-coord.md   (S1 hard-stop, phantom-aware S3, cc_post_commit wrapper)
Read file: .claude/skills/blazor-frontend-design/SKILL.md  (resx conventions: capital-first, CC English-in-parentheses, he RTL)
Only after reading both: proceed.

## Git push: NONE (§37). Commit only.

## Step 0 — §0.6a integrity check (first), then `git fetch origin v2` + verify HEAD ancestor/equal of origin/v2 (§42.7.6).
Known false-M (verify hash-object vs HEAD before restoring): db/data/02_metrics.sql, db/schema.sql.

## Multi-session sync — MANDATORY
Session slug: `test-5-0607`
Claims (file-mode):
- src/CcDashboard.Web/Resources/SharedResources.en-US.resx
- src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
- src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
- tools/cc_prompt_fix_daytrend_charttype.md (this file)

### S1. Push barrier check
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; echo "STOP — report to operator."; exit 1
fi
```
### S2. Claim discipline
```bash
python3 tools/coord_check_claims.py test-5-0607 \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
# exit 1 -> STOP (conflict -> queue §9).
```
Modify ONLY the three resx (plus /tmp/test-5-0607_* throwaway scripts). All writes via Python + os.fsync (§0.3); Edit BANNED.

## The fix — add exactly ONE key to each resx (ADDITIVE; confirm hash==HEAD/false-M before editing)
Insert a `<data name="Widget_DayTrend_ChartType" xml:space="preserve"><value>…</value></data>` entry,
placed near the other `Widget_DayTrend_*` entries (keep file ordering/style consistent with neighbours):
- en-US: `Chart type`
- ru-RU: `Тип графика (Chart type)`   (CC English-in-parentheses convention)
- he-IL: `סוג תרשים (Chart type)`       (Hebrew, RTL; English in parentheses)
Rules: capital-first; do NOT alter any other entry; preserve the exact .resx XML format (xml:space="preserve",
indentation, line endings) so the diff is exactly +1 data block per file.

## Verify before commit
```bash
for l in en-US ru-RU he-IL; do echo "$l: $(grep -c 'data name=\"Widget_DayTrend_ChartType\"' src/CcDashboard.Web/Resources/SharedResources.$l.resx)"; done
# each MUST print 1
# L-34 spot: ChartType no longer missing
git show HEAD:src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor >/dev/null  # ref already exists; no razor edit
```
Optional build sanity if .NET available: `dotnet build src/CcDashboard.Web` clean (resx-only change is low-risk).

## Commit (single web:)
Message: `web: add missing Widget_DayTrend_ChartType localization key (en/ru/he) [pre-existing fix]`
Files: SharedResources.{en-US,ru-RU,he-IL}.resx
Procedure: acquire commit.lock (phantom-aware, retry 5x60s) -> `bash tools/pre-commit-check.sh` -> `git add` (3 resx only)
-> `git commit` -> §0.6 post-commit verification -> LAST: `bash tools/cc_post_commit.sh test-5-0607 $(git log -1 --format=%h)`
(journal + S4b flush + lock release; if non-zero, reconcile journal vs git log + re-run) -> `sync` -> PD-007 re-sync the 3 resx.
RELEASE all 3 resx claims right after commit. NO git push.

## Acceptance
1. Each resx has exactly one Widget_DayTrend_ChartType entry (grep = 1 x3).
2. Only +1 data block per resx in the diff; no other entry changed.
3. One web: commit; claims released; tree clean (ignore known false-M); journal + S4b via wrapper; lock released; no push.
NOTE (out of scope — do NOT fix here): the broader ru-RU/he-IL DayTrend/InfoSlot/Widgets untranslated debt is
pre-existing L1 translation work owned by metrics (L1-C); this task fixes ONLY the wholly-missing ChartType key.
