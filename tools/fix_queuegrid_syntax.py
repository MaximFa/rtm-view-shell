#!/usr/bin/env python3
"""Fix corrupted escape characters in QueueGridWidget.razor"""

path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\QueueGridWidget.razor"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix the corrupted escape sequences
text = text.replace(
    r'return h > 0 ? \$"{h}:{m:D2}:{s:D2}" : \$"{m:D2}:{s:D2}";',
    'return h > 0 ? $"{h}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Fixed QueueGridWidget.razor line 1348")
