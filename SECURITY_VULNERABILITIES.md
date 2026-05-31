# Security Vulnerabilities Tracker — RTM View Shell

This document tracks identified security vulnerabilities, their status, and remediation details.

Last updated: 2026-05-31

---

## Fixed Vulnerabilities

### 1. log4net XML Injection (Moderate)

| Field | Value |
|-------|-------|
| Package | `log4net` |
| Affected Version | 2.0.15 |
| Fixed Version | 3.3.1 |
| Severity | **Moderate** |
| Advisory | [GHSA-4f7c-pmjv-c25w](https://github.com/advisories/GHSA-4f7c-pmjv-c25w) |
| CVE | CVE-2024-32480 |
| Project | `RTM/RTM.Tools/RTM.Tools.csproj` |
| Fixed In | Commit `8cdaf22` |
| Fixed Date | 2026-05-31 |

**Description:** XmlLayout in log4net vulnerable to XML injection attacks when logging untrusted input.

**Fix:** Updated log4net from 2.0.15 to 3.3.1.

---

### 2. Microsoft.Identity.Client Information Disclosure (Moderate + Low)

| Field | Value |
|-------|-------|
| Package | `Microsoft.Identity.Client` |
| Affected Version | 4.58.1 |
| Fixed Version | 4.67.2 |
| Severity | **Moderate** / Low |
| Advisory | [GHSA-m5vv-6r4h-3vj9](https://github.com/advisories/GHSA-m5vv-6r4h-3vj9), [GHSA-x674-v45j-fwxw](https://github.com/advisories/GHSA-x674-v45j-fwxw) |
| Project | `RTM/RTM/RTM.csproj` |
| Fixed In | Commit `7093d35` |
| Fixed Date | 2026-05-31 |

**Description:** Potential information disclosure through error messages and logging.

**Fix:** Updated Microsoft.Identity.Client from 4.58.1 to 4.67.2.

---

### 3. System.Text.Json Denial of Service (High)

| Field | Value |
|-------|-------|
| Package | `System.Text.Json` |
| Affected Version | 8.0.0 (transitive) |
| Fixed Version | 8.0.5 (explicit override) |
| Severity | **High** |
| Advisory | [GHSA-hh2w-p6rv-4g7w](https://github.com/advisories/GHSA-hh2w-p6rv-4g7w), [GHSA-8g4q-xg66-9fp4](https://github.com/advisories/GHSA-8g4q-xg66-9fp4) |
| CVE | CVE-2024-43485, CVE-2024-30105 |
| Project | `RTM/RTM/RTM.csproj` |
| Fixed In | Commit `7093d35` |
| Fixed Date | 2026-05-31 |

**Description:** Stack overflow vulnerability when deserializing deeply nested JSON. DoS possible via malformed JSON input.

**Fix:** Added explicit `System.Text.Json` 8.0.5 package reference to override vulnerable transitive dependency.

---

### 4. System.Security.Cryptography.Xml Signature Bypass (High)

| Field | Value |
|-------|-------|
| Package | `System.Security.Cryptography.Xml` |
| Affected Version | 8.0.2 (transitive) |
| Fixed Version | 8.0.3 (explicit override) |
| Severity | **High** |
| Advisory | [GHSA-37gx-xxp4-5rgx](https://github.com/advisories/GHSA-37gx-xxp4-5rgx), [GHSA-w3x6-4m5h-cxqf](https://github.com/advisories/GHSA-w3x6-4m5h-cxqf) |
| CVE | CVE-2025-21176, CVE-2024-43483 |
| Project | `src/CcDashboard.Web/CcDashboard.Web.csproj` |
| Fixed In | Commit `7093d35` |
| Fixed Date | 2026-05-31 |

**Description:** XML Signature verification bypass allowing attackers to forge signatures. Also DoS via malformed XML signatures.

**Fix:** Added explicit `System.Security.Cryptography.Xml` 8.0.3 package reference to override vulnerable transitive dependency.

---

---

### 5. RTM.Twilio Transitive Vulnerabilities (Multiple)

| Field | Value |
|-------|-------|
| Package | `log4net`, `System.Text.Json`, `Microsoft.IdentityModel.JsonWebTokens`, `System.IdentityModel.Tokens.Jwt` |
| Affected Versions | log4net 2.0.15, System.Text.Json 8.0.0, JWT libs 6.19.0 (all transitive) |
| Fixed Versions | log4net 3.3.1, System.Text.Json 8.0.5, JWT libs 8.0.2 |
| Severity | **High** (System.Text.Json), **Moderate** (others) |
| Advisory | GHSA-4f7c-pmjv-c25w, GHSA-hh2w-p6rv-4g7w, GHSA-8g4q-xg66-9fp4, GHSA-59j7-ghrg-fj52 |
| Project | `RTM/RTM.Twilio/RTM.Twilio.csproj` |
| Fixed In | Commit `03756f5` |
| Fixed Date | 2026-05-31 |

**Description:** Multiple transitive vulnerabilities from Twilio.AspNet.Core and RTM.Tools dependencies.

**Fix:** Added explicit package overrides: log4net 3.3.1, System.Text.Json 8.0.5, Microsoft.IdentityModel.JsonWebTokens 8.0.2, System.IdentityModel.Tokens.Jwt 8.0.2.

## Open Package Vulnerabilities

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

## Open Issues (Non-Package)

### 5. Hardcoded Database Credentials in Config Files

| Field | Value |
|-------|-------|
| Severity | **Medium** |
| Status | Open |
| Files Affected | `RTM/RTM/appsettings.json`, `tools/SignalRSimulator/appsettings.json` |
| Requirement | [CODE-05] from CLAUDE.md |

**Description:** Database passwords are stored in plain text in appsettings.json files committed to the repository.

**Recommendation:**
1. Move credentials to environment variables or User Secrets (development)
2. Use Azure Key Vault or HashiCorp Vault for production
3. Add affected files to `.gitignore` or use `appsettings.*.template.json` pattern

---

### 6. SSL Mode Not Enforced in All Connection Strings

| Field | Value |
|-------|-------|
| Severity | **Low** |
| Status | Open |
| Files Affected | Various appsettings.json files |
| Requirement | [CODE-06] from CLAUDE.md |

**Description:** Some PostgreSQL connection strings use `SSL Mode=Prefer` instead of `SSL Mode=VerifyFull`.

**Recommendation:** Change all production connection strings to use `SSL Mode=VerifyFull` to enforce encrypted connections with certificate verification.

---

## Vulnerability Check Commands

```powershell
# Check all projects for vulnerable packages
dotnet list package --vulnerable --include-transitive

# Check specific project
dotnet list src/CcDashboard.Web/CcDashboard.Web.csproj package --vulnerable --include-transitive
dotnet list RTM/RTM/RTM.csproj package --vulnerable --include-transitive
```

---

## Security Audit History

| Date | Action | Commit | Author |
|------|--------|--------|--------|
| 2026-05-31 | Fixed log4net 2.0.15 → 3.3.1 | `8cdaf22` | Claude Code |
| 2026-05-31 | Fixed Microsoft.Identity.Client, System.Text.Json, System.Security.Cryptography.Xml | `7093d35` | Claude Code |
| 2026-05-31 | Full solution vulnerability scan - found 3 additional vuln types in 6 projects | - | Claude Code |
| 2026-05-31 | Fixed RTM.Twilio transitive vulns (log4net, System.Text.Json, JWT libs) | `03756f5` | Claude Code |

---

## References

- [CLAUDE.md §25 — PR Security Checklist](./CLAUDE.md)
- [NuGet Advisories](https://github.com/advisories?query=ecosystem%3Anuget)
- [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)
