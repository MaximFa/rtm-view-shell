#!/usr/bin/env python3
"""Add DayTrend_TimeInterval to he-IL resx."""
import os

PATH = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Resources\SharedResources.he-IL.resx"

def main():
    with open(PATH, "r", encoding="utf-8") as f:
        text = f.read()

    if "DayTrend_TimeInterval" in text:
        print("Key already exists")
        return

    # Find DayTrend_ChartStep closing tag
    old = '''  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>מדרגות</value>
  </data>
  <data name="DayTrend_InteractionMetrics"'''

    new = '''  <data name="DayTrend_ChartStep" xml:space="preserve">
    <value>מדרגות</value>
  </data>
  <data name="DayTrend_TimeInterval" xml:space="preserve">
    <value>מרווח זמן</value>
  </data>
  <data name="DayTrend_InteractionMetrics"'''

    text = text.replace(old, new)

    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print("Done")

if __name__ == "__main__":
    main()
