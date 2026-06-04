#!/usr/bin/env python3
"""Update SECURITY_VULNERABILITIES.md with scan results"""

path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\SECURITY_VULNERABILITIES.md"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Find the position to insert new section (before "## Open Issues (Non-Package)")
insert_marker = "## Open Issues (Non-Package)"

new_section = """## Open Package Vulnerabilities

> Scan date: 2026-05-31

### Summary Table

| Project | Package | Version | Severity | Advisory |
|---------|---------|---------|----------|----------|
| CcDashboard.Infrastructure | System.Security.Cryptography.Xml | 8.0.2 | **High** | GHSA-37gx-xxp4-5rgx |
| CcDashboard.Api | System.Security.Cryptography.Xml | 8.0.2 | **High** | GHSA-37gx-xxp4-5rgx |
| CcDashboard.Tests.Unit | System.Net.Http | 4.3.0 | **High** | GHSA-7jgj-8wvc-jh57 |
| CcDashboard.Tests.Unit | System.Text.RegularExpressions | 4.3.0 | **High** | GHSA-cmhx-cq75-c4mj |
| CcDashboard.Tests.Integration | System.Net.Http | 4.3.0 | **High** | GHSA-7jgj-8wvc-jh57 |
| CcDashboard.Tests.Integration | System.Security.Cryptography.Xml | 8.0.2 | **High** | GHSA-37gx-xxp4-5rgx |
| CcDashboard.Tests.Integration | System.Text.RegularExpressions | 4.3.0 | **High** | GHSA-cmhx-cq75-c4mj |
| CcDashboard.Tests.Architecture | System.Net.Http | 4.3.0 | **High** | GHSA-7jgj-8wvc-jh57 |
| CcDashboard.Tests.Architecture | System.Security.Cryptography.Xml | 8.0.2 | **High** | GHSA-37gx-xxp4-5rgx |
| CcDashboard.Tests.Architecture | System.Text.RegularExpressions | 4.3.0 | **High** | GHSA-cmhx-cq75-c4mj |
| CcDashboard.Tests.Security | System.Net.Http | 4.3.0 | **High** | GHSA-7jgj-8wvc-jh57 |
| CcDashboard.Tests.Security | System.Security.Cryptography.Xml | 8.0.2 | **High** | GHSA-37gx-xxp4-5rgx |
| CcDashboard.Tests.Security | System.Text.RegularExpressions | 4.3.0 | **High** | GHSA-cmhx-cq75-c4mj |

### Clean Projects (No Vulnerabilities)

- CcDashboard.Domain
- CcDashboard.Contracts
- CcDashboard.Application
- CcDashboard.Web (fixed in commit `7093d35`)
- RTM (fixed in commit `7093d35`)
- RTM.Tools (fixed in commit `8cdaf22`)

---

### V5. System.Security.Cryptography.Xml (Additional Projects)

| Field | Value |
|-------|-------|
| Package | `System.Security.Cryptography.Xml` |
| Affected Version | 8.0.2 (transitive) |
| Severity | **High** |
| Advisory | [GHSA-37gx-xxp4-5rgx](https://github.com/advisories/GHSA-37gx-xxp4-5rgx), [GHSA-w3x6-4m5h-cxqf](https://github.com/advisories/GHSA-w3x6-4m5h-cxqf) |
| Status | **Open** |
| Projects | `CcDashboard.Infrastructure`, `CcDashboard.Api`, `CcDashboard.Tests.*` |

**Recommendation:** Add explicit `System.Security.Cryptography.Xml` 8.0.3 package reference to affected projects.

---

### V6. System.Net.Http Remote Code Execution (Test Projects)

| Field | Value |
|-------|-------|
| Package | `System.Net.Http` |
| Affected Version | 4.3.0 (transitive) |
| Severity | **High** |
| Advisory | [GHSA-7jgj-8wvc-jh57](https://github.com/advisories/GHSA-7jgj-8wvc-jh57) |
| CVE | CVE-2018-8292 |
| Status | **Open** |
| Projects | All test projects (`Tests.Unit`, `Tests.Integration`, `Tests.Architecture`, `Tests.Security`) |

**Description:** WinHttpHandler in System.Net.Http allows NTLM credential leak to external services.

**Recommendation:** Add explicit `System.Net.Http` 4.3.4 package reference to test projects.

---

### V7. System.Text.RegularExpressions ReDoS (Test Projects)

| Field | Value |
|-------|-------|
| Package | `System.Text.RegularExpressions` |
| Affected Version | 4.3.0 (transitive) |
| Severity | **High** |
| Advisory | [GHSA-cmhx-cq75-c4mj](https://github.com/advisories/GHSA-cmhx-cq75-c4mj) |
| CVE | CVE-2019-0820 |
| Status | **Open** |
| Projects | All test projects (`Tests.Unit`, `Tests.Integration`, `Tests.Architecture`, `Tests.Security`) |

**Description:** Regular Expression Denial of Service (ReDoS) vulnerability.

**Recommendation:** Add explicit `System.Text.RegularExpressions` 4.3.1 package reference to test projects.

---

"""

# Insert new section before "## Open Issues (Non-Package)"
text = text.replace(insert_marker, new_section + insert_marker)

# Update Security Audit History - add new row
old_history = """| 2026-05-31 | Fixed Microsoft.Identity.Client, System.Text.Json, System.Security.Cryptography.Xml | `7093d35` | Claude Code |

---"""

new_history = """| 2026-05-31 | Fixed Microsoft.Identity.Client, System.Text.Json, System.Security.Cryptography.Xml | `7093d35` | Claude Code |
| 2026-05-31 | Full solution vulnerability scan - found 3 additional vuln types in 6 projects | - | Claude Code |

---"""

text = text.replace(old_history, new_history)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Updated SECURITY_VULNERABILITIES.md")
print(f"Total lines: {len(text.splitlines())}")
