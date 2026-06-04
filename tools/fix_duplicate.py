#!/usr/bin/env python3
"""Remove duplicate System.Text.Json line"""

path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\RTM\RTM\RTM.csproj"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Remove duplicate line
text = text.replace(
    '    <PackageReference Include="System.Text.Json" Version="8.0.5" />\n    <PackageReference Include="System.Text.Json" Version="8.0.5" />',
    '    <PackageReference Include="System.Text.Json" Version="8.0.5" />'
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Fixed duplicate in RTM.csproj")
