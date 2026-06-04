#!/usr/bin/env python3
"""Fix remaining NuGet vulnerabilities in src/ and tests/ projects"""

import os

base = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell"

# 1. Infrastructure - add System.Security.Cryptography.Xml 8.0.3
infra_path = os.path.join(base, r"src\CcDashboard.Infrastructure\CcDashboard.Infrastructure.csproj")
with open(infra_path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    '<PackageReference Include="UUIDNext" Version="4.2.4" />',
    '<PackageReference Include="UUIDNext" Version="4.2.4" />\n    <PackageReference Include="System.Security.Cryptography.Xml" Version="8.0.3" />'
)

with open(infra_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Updated Infrastructure.csproj")

# 2. Api - add System.Security.Cryptography.Xml 8.0.3
api_path = os.path.join(base, r"src\CcDashboard.Api\CcDashboard.Api.csproj")
with open(api_path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    '<PackageReference Include="Swashbuckle.AspNetCore" Version="6.9.0" />',
    '<PackageReference Include="Swashbuckle.AspNetCore" Version="6.9.0" />\n    <PackageReference Include="System.Security.Cryptography.Xml" Version="8.0.3" />'
)

with open(api_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Updated Api.csproj")

# Security override ItemGroup for test projects
security_itemgroup = """
  <ItemGroup>
    <PackageReference Include="System.Net.Http" Version="4.3.4" />
    <PackageReference Include="System.Text.RegularExpressions" Version="4.3.1" />
  </ItemGroup>

</Project>"""

# 3. Tests.Unit
unit_path = os.path.join(base, r"tests\CcDashboard.Tests.Unit\CcDashboard.Tests.Unit.csproj")
with open(unit_path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("</Project>", security_itemgroup)

with open(unit_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Updated Tests.Unit.csproj")

# 4. Tests.Integration
integ_path = os.path.join(base, r"tests\CcDashboard.Tests.Integration\CcDashboard.Tests.Integration.csproj")
with open(integ_path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("</Project>", security_itemgroup)

with open(integ_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Updated Tests.Integration.csproj")

# 5. Tests.Architecture
arch_path = os.path.join(base, r"tests\CcDashboard.Tests.Architecture\CcDashboard.Tests.Architecture.csproj")
with open(arch_path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("</Project>", security_itemgroup)

with open(arch_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Updated Tests.Architecture.csproj")

# 6. Tests.Security
sec_path = os.path.join(base, r"tests\CcDashboard.Tests.Security\CcDashboard.Tests.Security.csproj")
with open(sec_path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("</Project>", security_itemgroup)

with open(sec_path, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Updated Tests.Security.csproj")

print("All 6 project files updated")
