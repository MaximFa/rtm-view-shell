#!/usr/bin/env python3
"""Add DayTrend_TimeInterval localization key to all resx files."""
import os

FILES = {
    r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.en-US.resx": "Time Interval",
    r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.ru-RU.resx": "Интервал",
    r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.he-IL.resx": "מרווח זמן",
}

KEY_TEMPLATE = '''  <data name="DayTrend_TimeInterval" xml:space="preserve">
    <value>{value}</value>
  </data>
'''

# Insert after DayTrend_ChartStep entry
AFTER_PATTERN = '''  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>'''

def main():
    for path, value in FILES.items():
        print(f"Processing {path}")

        with open(path, "r", encoding="utf-8") as f:
            text = f.read()

        # Check if already exists
        if "DayTrend_TimeInterval" in text:
            print(f"  Key already exists, skipping")
            continue

        # Find DayTrend_ChartStep and its closing </data>
        idx = text.find('name="DayTrend_ChartStep"')
        if idx == -1:
            print(f"  ERROR: DayTrend_ChartStep not found")
            continue

        # Find the closing </data> after this entry
        close_idx = text.find('</data>', idx)
        if close_idx == -1:
            print(f"  ERROR: closing </data> not found")
            continue

        # Insert after </data>\n
        insert_pos = close_idx + len('</data>') + 1
        new_entry = KEY_TEMPLATE.format(value=value)
        text = text[:insert_pos] + new_entry + text[insert_pos:]

        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())

        print(f"  Added key with value: {value}")

if __name__ == "__main__":
    main()
