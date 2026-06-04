#!/usr/bin/env python3
"""Upgrade log4net from 2.0.15 to 3.3.1"""

path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\RTM\RTM.Tools\RTM.Tools.csproj"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    '<PackageReference Include="log4net" Version="2.0.15" />',
    '<PackageReference Include="log4net" Version="3.3.1" />'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"Updated {path}")
print(f"Total lines: {len(text.splitlines())}")
