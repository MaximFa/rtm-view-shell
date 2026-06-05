#!/usr/bin/env python3
"""Fix DayTrend localization keys — remove duplicates, ensure correct entries exist."""
import os
import re

BASE = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources"

# All entries that should exist (key -> value per locale)
REQUIRED_ENTRIES = {
    "en-US": {
        "Loading": "Loading...",
        "DayTrend_ChartType": "Chart type",
        "DayTrend_ChartLine": "Line",
        "DayTrend_ChartBar": "Bar",
        "DayTrend_ChartArea": "Area (filled)",
        "DayTrend_ChartStep": "Step",
        "DayTrend_InteractionMetrics": "Call metrics",
        "DayTrend_AgentMetrics": "Agent metrics",
        "Widget_LocalViewSettings": "Local view settings",
        "Widget_UseDefault": "Use default",
        "Widget_ResetToDefault": "Reset to default",
        "Apply": "Apply",
    },
    "ru-RU": {
        "Loading": "Загрузка...",
        "DayTrend_ChartType": "Тип графика",
        "DayTrend_ChartLine": "Линия",
        "DayTrend_ChartBar": "Бар",
        "DayTrend_ChartArea": "Область (заливка)",
        "DayTrend_ChartStep": "Ступенчатый",
        "DayTrend_InteractionMetrics": "Метрики звонков",
        "DayTrend_AgentMetrics": "Метрики агентов",
        "Widget_LocalViewSettings": "Локальные настройки отображения",
        "Widget_UseDefault": "Использовать по умолчанию",
        "Widget_ResetToDefault": "Сбросить к настройкам",
        "Apply": "Применить",
    },
    "he-IL": {
        "Loading": "טוען...",
        "DayTrend_ChartType": "סוג גרף",
        "DayTrend_ChartLine": "קו",
        "DayTrend_ChartBar": "עמודות",
        "DayTrend_ChartArea": "שטח (מלא)",
        "DayTrend_ChartStep": "מדרגות",
        "DayTrend_InteractionMetrics": "מדדי שיחות",
        "DayTrend_AgentMetrics": "מדדי סוכנים",
        "Widget_LocalViewSettings": "הגדרות תצוגה מקומיות",
        "Widget_UseDefault": "השתמש בברירת מחדל",
        "Widget_ResetToDefault": "איפוס להגדרות",
        "Apply": "החל",
    },
}

# Wrong keys to remove
WRONG_KEYS = [
    "Widget_DayTrend_ChartType",
    "Widget_DayTrend_ChartLine",
    "Widget_DayTrend_ChartBar",
    "Widget_DayTrend_ChartArea",
    "Widget_DayTrend_ChartStep",
]

def fix_resx(locale):
    path = os.path.join(BASE, f"SharedResources.{locale}.resx")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)
    required = REQUIRED_ENTRIES[locale]

    # 1. Remove wrong Widget_DayTrend_* keys
    for key in WRONG_KEYS:
        pattern = rf'\s*<data name="{key}"[^>]*>.*?</data>\s*'
        count = len(re.findall(pattern, text, flags=re.DOTALL))
        if count > 0:
            print(f"  Removing {key} ({count} occurrences)")
            text = re.sub(pattern, '\n', text, flags=re.DOTALL)

    # 2. Remove ALL occurrences of required keys (to dedupe), then re-add once
    for key in required.keys():
        pattern = rf'\s*<data name="{key}"[^>]*>.*?</data>\s*'
        count = len(re.findall(pattern, text, flags=re.DOTALL))
        if count > 0:
            if count > 1:
                print(f"  Removing {count} duplicates of {key}")
            text = re.sub(pattern, '\n', text, flags=re.DOTALL)

    # 3. Add all required keys once before </root>
    entries_block = ""
    for key, value in required.items():
        entries_block += f'  <data name="{key}" xml:space="preserve">\n    <value>{value}</value>\n  </data>\n'

    text = text.replace("</root>", entries_block + "</root>")

    # 4. Clean up multiple consecutive newlines
    text = re.sub(r'\n{3,}', '\n\n', text)

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
