# CC Task: Fix DayTrend localization — wrong key names + missing keys

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md  ← see L-34 for verification rule

## Git push
Do NOT run `git push`. Commit only.

---

## Problem

CC previously added wrong keys to .resx files:
- Added: `Widget_DayTrend_ChartType`, `Widget_DayTrend_ChartLine`, etc.
- Template uses: `DayTrend_ChartType`, `DayTrend_ChartLine`, etc. (no `Widget_` prefix)

Also missing: `Apply`, `Loading`, `DayTrend_AgentMetrics`, `DayTrend_InteractionMetrics`,
`Widget_LocalViewSettings`, `Widget_ResetToDefault`, `Widget_UseDefault`.

---

## Step 1 — Fix SharedResources.en-US.resx

Using Python atomic write:
1. Remove the 5 wrongly-named entries: `Widget_DayTrend_ChartType/Line/Bar/Area/Step`
2. Add all 12 correct entries before `</root>`

Correct entries to ADD (exact key names — no deviation):

```xml
  <data name="Apply" xml:space="preserve">
    <value>Apply</value>
  </data>
  <data name="Loading" xml:space="preserve">
    <value>Loading...</value>
  </data>
  <data name="DayTrend_ChartType" xml:space="preserve">
    <value>Chart type</value>
  </data>
  <data name="DayTrend_ChartLine" xml:space="preserve">
    <value>Line</value>
  </data>
  <data name="DayTrend_ChartBar" xml:space="preserve">
    <value>Bar</value>
  </data>
  <data name="DayTrend_ChartArea" xml:space="preserve">
    <value>Area (filled)</value>
  </data>
  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>Step</value>
  </data>
  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
    <value>Call metrics</value>
  </data>
  <data name="DayTrend_AgentMetrics" xml:space="preserve">
    <value>Agent metrics</value>
  </data>
  <data name="Widget_LocalViewSettings" xml:space="preserve">
    <value>Local view settings</value>
  </data>
  <data name="Widget_UseDefault" xml:space="preserve">
    <value>Use default</value>
  </data>
  <data name="Widget_ResetToDefault" xml:space="preserve">
    <value>Reset to default</value>
  </data>
```

To remove the wrong entries, use `str.replace` to delete the entire `<data>` block for each:
- `<data name="Widget_DayTrend_ChartType">...</data>`
- `<data name="Widget_DayTrend_ChartLine">...</data>`
- `<data name="Widget_DayTrend_ChartBar">...</data>`
- `<data name="Widget_DayTrend_ChartArea">...</data>`
- `<data name="Widget_DayTrend_ChartStep">...</data>`

---

## Step 2 — Fix SharedResources.ru-RU.resx

Same removal of `Widget_DayTrend_*` entries, then add:

```xml
  <data name="Apply" xml:space="preserve">
    <value>Применить</value>
  </data>
  <data name="Loading" xml:space="preserve">
    <value>Загрузка...</value>
  </data>
  <data name="DayTrend_ChartType" xml:space="preserve">
    <value>Тип графика</value>
  </data>
  <data name="DayTrend_ChartLine" xml:space="preserve">
    <value>Линия</value>
  </data>
  <data name="DayTrend_ChartBar" xml:space="preserve">
    <value>Бар</value>
  </data>
  <data name="DayTrend_ChartArea" xml:space="preserve">
    <value>Область (заливка)</value>
  </data>
  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>Ступенчатый</value>
  </data>
  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
    <value>Метрики звонков</value>
  </data>
  <data name="DayTrend_AgentMetrics" xml:space="preserve">
    <value>Метрики агентов</value>
  </data>
  <data name="Widget_LocalViewSettings" xml:space="preserve">
    <value>Локальные настройки отображения</value>
  </data>
  <data name="Widget_UseDefault" xml:space="preserve">
    <value>Использовать по умолчанию</value>
  </data>
  <data name="Widget_ResetToDefault" xml:space="preserve">
    <value>Сбросить к настройкам</value>
  </data>
```

---

## Step 3 — Fix SharedResources.he-IL.resx

Same removal, then add:

```xml
  <data name="Apply" xml:space="preserve">
    <value>החל</value>
  </data>
  <data name="Loading" xml:space="preserve">
    <value>טוען...</value>
  </data>
  <data name="DayTrend_ChartType" xml:space="preserve">
    <value>סוג גרף</value>
  </data>
  <data name="DayTrend_ChartLine" xml:space="preserve">
    <value>קו</value>
  </data>
  <data name="DayTrend_ChartBar" xml:space="preserve">
    <value>עמודות</value>
  </data>
  <data name="DayTrend_ChartArea" xml:space="preserve">
    <value>שטח (מלא)</value>
  </data>
  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>מדרגות</value>
  </data>
  <data name="DayTrend_InteractionMetrics" xml:space="preserve">
    <value>מדדי שיחות</value>
  </data>
  <data name="DayTrend_AgentMetrics" xml:space="preserve">
    <value>מדדי סוכנים</value>
  </data>
  <data name="Widget_LocalViewSettings" xml:space="preserve">
    <value>הגדרות תצוגה מקומיות</value>
  </data>
  <data name="Widget_UseDefault" xml:space="preserve">
    <value>השתמש בברירת מחדל</value>
  </data>
  <data name="Widget_ResetToDefault" xml:space="preserve">
    <value>איפוס להגדרות</value>
  </data>
```

---

## Step 4 — Mandatory verification (L-34)

```bash
grep -Po '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor | sort -u > /tmp/razor_keys.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/resx_keys.txt
echo "=== Missing from en-US.resx ==="
comm -23 /tmp/razor_keys.txt /tmp/resx_keys.txt
```

Output must be EMPTY. If any key appears — fix it before committing.

---

## Implementation steps

1. Read skill files (pay attention to L-34)
2. `git status --short` + integrity check
3. Fix all 3 .resx files via Python atomic write + fsync
4. Run L-34 verification — must return empty output
5. `dotnet build CcDashboard.sln` — 0 errors
6. `bash tools/pre-commit-check.sh`
7. Commit: `fix: localization keys — correct names, remove Widget_DayTrend_ prefix, add missing`
8. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
