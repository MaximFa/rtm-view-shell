#!/usr/bin/env python3
"""Fix vulnerable packages in RTM and CcDashboard.Web projects"""

# 1. Update RTM.csproj - Microsoft.Identity.Client + add System.Text.Json
rtm_path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\RTM\RTM\RTM.csproj"

with open(rtm_path, "r", encoding="utf-8") as f:
    text = f.read()

# Update Microsoft.Identity.Client
text = text.replace(
    '<PackageReference Include="Microsoft.Identity.Client" Version="4.58.1" />',
    '<PackageReference Include="Microsoft.Identity.Client" Version="4.67.2" />'
)

# Add System.Text.Json 8.0.5 after Microsoft.Identity.Client
text = text.replace(
    '<PackageReference Include="Microsoft.Identity.Client" Version="4.67.2" />',
    '<PackageReference Include="Microsoft.Identity.Client" Version="4.67.2" />\n    <PackageReference Include="System.Text.Json" Version="8.0.5" />'
)

with open(rtm_path, "w", encoding="utf-8") as f:
    f.write(text)

print("Updated RTM.csproj")

# 2. Update CcDashboard.Web.csproj - add System.Security.Cryptography.Xml 8.0.3 (patched)
web_path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Web\CcDashboard.Web.csproj"

with open(web_path, "r", encoding="utf-8") as f:
    text = f.read()

# Add System.Security.Cryptography.Xml 8.0.3 after Serilog.Sinks.File
text = text.replace(
    '<PackageReference Include="Serilog.Sinks.File" Version="7.0.0" />',
    '<PackageReference Include="Serilog.Sinks.File" Version="7.0.0" />\n    <PackageReference Include="System.Security.Cryptography.Xml" Version="8.0.3" />'
)

with open(web_path, "w", encoding="utf-8") as f:
    f.write(text)

print("Updated CcDashboard.Web.csproj")
print("Done")
