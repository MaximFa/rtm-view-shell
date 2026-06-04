#!/usr/bin/env python3
"""Update commit hash in SECURITY_VULNERABILITIES.md"""

path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\SECURITY_VULNERABILITIES.md"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("| Fixed In | Commit `pending` |", "| Fixed In | Commit `03756f5` |")
text = text.replace("| `pending` | Claude Code |", "| `03756f5` | Claude Code |")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Updated commit hash to 03756f5")
