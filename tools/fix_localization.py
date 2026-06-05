#!/usr/bin/env python3
"""Fix DayTrend localization keys — remove Widget_DayTrend_* prefix, add missing keys."""
import os
import re

BASE = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources"

# Wrong keys to remove (regex patterns for the entire <data> block)
WRONG_KEYS = [
    "Widget_DayTrend_ChartType",
    "Widget_DayTrend_ChartLine",
    "Widget_DayTrend_ChartBar",
    "Widget_DayTrend_ChartArea",
    "Widget_DayTrend_ChartStep",
]

# New entries to add per locale (before </root>)
NEW_ENTRIES = {
    "en-US": """  <data name="Loading" xml:space="preserve">
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
""",
    "ru-RU": """  <data name="Loading" xml:space="preserve">
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
""",
    "he-IL": """  <data name="Loading" xml:space="preserve">
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
""",
}

def fix_resx(locale):
    path = os.path.join(BASE, f"SharedResources.{locale}.resx")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # Remove wrong keys (entire <data> block including value)
    for key in WRONG_KEYS:
        # Pattern: <data name="key" ...>...</data> including possible whitespace/newlines
        pattern = rf'\s*<data name="{key}"[^>]*>.*?</data>\s*'
        text = re.sub(pattern, '\n', text, flags=re.DOTALL)

    # Check if new keys already exist (avoid duplicates)
    keys_to_add = ["Loading", "DayTrend_ChartType", "DayTrend_ChartLine",
                   "DayTrend_ChartBar", "DayTrend_ChartArea", "DayTrend_ChartStep",
                   "DayTrend_InteractionMetrics", "DayTrend_AgentMetrics"]

    missing = []
    for key in keys_to_add:
        if f'name="{key}"' not in text:
            missing.append(key)

    if missing:
        print(f"  Adding missing keys: {missing}")
        # Add new entries before </root>
        new_entries = NEW_ENTRIES[locale]
        text = text.replace("</root>", new_entries + "</root>")
    else:
        print(f"  All keys already present")

    # Write back
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done: {original_len} -> {len(text)} bytes")

if __name__ == "__main__":
    for locale in ["en-US", "ru-RU", "he-IL"]:
        fix_resx(locale)
    print("All .resx files fixed!")
