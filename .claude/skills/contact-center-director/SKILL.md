---
name: contact-center-director
invocation: user
description: >
  Apply contact centre director / VP domain expertise to the RTM View Shell project.
  Trigger this skill whenever the user mentions: director, VP, vice president, head of CC,
  C-suite, executive, board reporting, strategic KPIs, executive dashboard, executive view,
  P&L, profit and loss, budget, cost centre, revenue centre, cost per contact,
  cost optimisation, outsourcing, insourcing, vendor management, BPO, SLA contract,
  penalty clause, client relationship, enterprise client, multi-site, multi-country,
  omnichannel, channel strategy, digital deflection, self-service, IVR containment,
  chatbot, automation ROI, technology roadmap, platform selection, vendor evaluation,
  RFP, CX strategy, customer experience strategy, NPS programme, voice of customer,
  VoC, CSAT programme, complaint management strategy, regulatory reporting, GDPR compliance,
  ISO 18295 certification, COPC certification, Ofcom compliance, FCA compliance,
  headcount budget, FTE cost, capex, opex, workforce planning annual, annual capacity plan,
  business case, ROI, cost avoidance, strategic initiative, transformation programme,
  board presentation, C-level reporting, KPI scorecard for board, balanced scorecard,
  benchmarking, industry benchmark, Gartner, Forrester, contact centre maturity model,
  channel mix, first contact resolution strategy, quality management framework,
  employee engagement strategy, agent wellbeing, talent strategy, attrition strategy,
  succession planning, multi-tenant CC, shared services centre, or any strategic
  contact centre topic at the director or VP level.
  Also trigger on: "what does a CC director care about", "executive view of the dashboard",
  "board-level metrics", "how to present CC performance to executives",
  "strategic use of RTM data", "multi-site dashboard".
  Never skip this skill when designing executive-level views, cross-tenant reporting,
  or features that serve the highest organisational level.
---

# Contact Centre Director — RTM View Shell

This skill covers the domain knowledge of a **contact centre director or VP** —
the executive responsible for the entire contact centre operation, multiple departments,
and the strategic direction of the CX function.

They sit above department managers and shift managers. Their time horizon is weeks, months,
and years — not minutes. They use the RTM shell for oversight, governance, and to ensure
the platform enables their team to meet strategic commitments.

---

## 1. The director's world — context

### Organisational position

```
CEO / COO / CXO
      │
CC Director / VP Operations   ← THIS ROLE
      │
  ┌───┴───┬──────────────┐
Dept Mgr  Dept Mgr   Dept Mgr
(Sales CC)(Support CC)(Back Office)
      │
  Shift Managers → Agents
```

### Core accountabilities

| Accountability | Time horizon | Stakeholder |
|---|---|---|
| P&L / budget management | Monthly / Annual | CFO / CEO |
| SLA contract delivery | Monthly / Quarterly | Clients / CXO |
| CX strategy | Annual / 3-year | Board / CXO |
| Technology decisions | Annual / 3-year | CTO / CIO |
| People strategy (talent, attrition) | Annual | CHRO |
| Regulatory compliance | Ongoing | Legal / Compliance |
| Vendor / BPO management | Quarterly | Procurement |
| Capacity / workforce plan | Annual | WFM / Finance |
| Operational performance | Weekly | Department managers |

### What they do NOT do

- Do not manage individual shift managers day-to-day.
- Do not approve individual agent schedules.
- Do not pull agents from breaks.
- Do not investigate individual call quality issues (that's QA + department manager).

They **set strategy, own budget, manage contracts, and hold department managers accountable.**

---

## 2. How a director uses the dashboard

### Purpose — governance, not operations

The director opens Screen 05 for three reasons:
1. **Trust-but-verify:** a quick check that the department manager's report matches reality.
2. **Client visit / board meeting:** "Let me show you our operations live."
3. **Crisis:** SLA has been breached for hours — they want to see it themselves.

They are **not** the primary audience for the real-time wallboard. Their primary tool is the
management report screen and the weekly performance pack.

### What the director wants to see — executive summary screen

A dedicated screen configured for director-level viewing:

```
┌────────────────────────────────────────────────────────────┐
│  Operations Overview · Today · 09:00–16:45                 │
├──────────────┬──────────────┬──────────────┬───────────────┤
│  SLA Today   │  Calls       │  Abandon     │  CSAT (week)  │
│  83%  ✅     │  2,341       │  3.8%  ✅    │  87%  ✅      │
│  Target: 80% │  handled     │  Target <5%  │  Target: 85%  │
├──────────────┴──────────────┴──────────────┴───────────────┤
│  SLA trend (last 7 days)     ████████▄▄██████  avg 82%     │
│  Occupancy                   ░░░░░░░░░░░░████  83%         │
├─────────────────────────────────────────────────────────────┤
│  Departments    SLA     Handled  Abandon  Adherence         │
│  Sales CC       85%     1,102    2.9%     94%   ✅          │
│  Support CC     81%     1,239    4.7%     92%   ✅          │
│  Evening team   71%     —        8.1%     89%   ⚠️          │
└─────────────────────────────────────────────────────────────┘
```

At a glance: is the operation healthy? Which department needs attention?

---

## 3. Strategic KPIs — what the director is measured on

### P&L KPIs (financial)

| KPI | Formula | Typical target |
|---|---|---|
| Cost per contact | Total opex / contacts handled | Benchmark: £3–£8 per contact (varies by sector) |
| Revenue per agent | Revenue generated / FTE count | Revenue centres only |
| Budget variance | Actual spend vs budget | ±3–5% acceptable |
| Agent utilisation | Productive hours / paid hours | 75–82% |
| Overtime % | Overtime hours / scheduled hours | <5% |

### Customer KPIs (contractual / strategic)

| KPI | Target | Consequence of miss |
|---|---|---|
| Service Level | As per SLA contract (e.g. 80/20) | Penalty clause triggered |
| CSAT | ≥85% (or contract-specific) | Client escalation, contract risk |
| FCR | ≥75% | Re-contact volume rises, cost rises |
| NPS | As per CX strategy | Board-level scrutiny |
| Complaint rate | <2% of contacts | Regulatory interest |
| Escalation rate | <3% of contacts | Agent capability concern |

### People KPIs (talent / HR)

| KPI | Benchmark | Director concern |
|---|---|---|
| Annual attrition | 20–35% in CC | High attrition = high cost (training, recruitment) |
| Absence rate | <5% | >8% = systemic wellbeing issue |
| Engagement score | ≥65% (Gallup Q12) | Low = leading indicator of attrition |
| Internal promotion rate | ≥30% of manager roles filled internally | Talent pipeline |
| Time to full productivity | 4–8 weeks | Training quality |

### Technology KPIs

| KPI | What it measures |
|---|---|
| IVR containment rate | % of calls resolved by IVR without reaching an agent |
| Digital deflection rate | % of contacts moved to cheaper channels (chat, web) |
| Platform availability | Uptime of ACD, CRM, and RTM shell |
| Average handling time trend | Is technology making agents more or less efficient? |

---

## 4. Budget management — cost structure of a CC

### Typical CC cost breakdown

```
Staff costs (salaries, benefits, NI)     60–70%
Outsourcing / BPO fees                   0–30% (if blended model)
Technology (licences, telephony, infra)  10–15%
Training and recruitment                  5–8%
Facilities (rent, utilities, equipment)   5–10%
Management overhead                       3–5%
```

### Annual budget cycle

```
Q3 of current year:
  → WFM produces capacity forecast for next year
  → Director submits headcount budget (FTE × average salary × uplift%)
  → Technology budget submitted (platform licences, upgrade projects)
  → Director presents to CFO for approval

Q4:
  → Budget approved / negotiated / cut
  → Recruitment plan locked for next year
  → Training calendar planned

Q1 next year:
  → Budget monitoring begins (monthly variance reporting)
```

### Cost optimisation levers the director controls

| Lever | Impact | Risk |
|---|---|---|
| Digital deflection (chatbot, IVR) | -10–30% contact volume | Customer satisfaction risk |
| BPO / outsourcing overflow | Variable cost for peaks | Quality, brand risk |
| Agent multi-skilling | Higher utilisation per agent | Training cost, complexity |
| At-home agents | Lower facilities cost | Management overhead |
| Shift pattern optimisation | Reduce overtime | Agent satisfaction |
| WFM platform improvement | Better adherence, less overstaffing | Implementation cost |

---

## 5. Client / SLA contract management

In outsourced CCs (BPOs) or shared-services environments, the director is accountable
for SLA contracts with clients.

### SLA contract components

```
Service Level:     80% of calls answered within 20 seconds
Measurement:       Monthly average, measured by ACD reports
Reporting:         Director provides monthly report to client by 5th of following month
Penalty clause:    If SLA <75% for 2 consecutive months → 5% fee credit to client
Bonus clause:      If SLA ≥90% for 3 months → 2% bonus payment
Exclusions:        Force majeure, client-side IT failures, approved planned downtime
Review cadence:    Quarterly Business Review (QBR) — face-to-face with client
```

### RTM shell implication for SLA contracts

The director needs **auditable, exportable performance data** to support SLA reporting.
Audit log [AUD-*] captures who viewed which screen and when — important for disputes.
Dashboard data (in future versions) should be exportable as a time-stamped report.

---

## 6. Multi-site and multi-country operations

Large CC operations run across multiple sites and countries. The director oversees all of them.

### Multi-tenant model alignment

In the RTM shell, each tenant = one client or one business entity.
For a multi-site director within one organisation:
- All sites could be in **one tenant** with BU-based separation.
- Or each site as a **separate tenant** (if they are legal entities or have different SLA contracts).

**Permission model for director:**

```
Director PG (within one tenant):
  pg_business_units: All BUs (unrestricted)
  pg_queues:         All queues (all sites)
  pg_skills:         All skills
  pg_agent_supergroups: All supergroups

Director role in multi-tenant:
  → Superadmin role with cross-tenant view (Superadmin bypasses all PG checks)
  → Or: separate login per tenant (less desirable — fragmented view)
```

### Multi-site dashboard principles

- Show site-level aggregation: one row per site (or per department) in the summary.
- Allow drill-down: click a site row → see that site's detailed metrics.
- Flag underperforming sites prominently — director should not have to hunt for red flags.
- Time zone aware: if sites are in different time zones, show local time per site.

---

## 7. Technology strategy and platform decisions

The director is typically the **business owner** of the CC technology stack.

### Typical CC technology landscape

```
ACD / Contact Routing:     Avaya CMS, Genesys, Cisco UCCE, NICE CXone, Five9
CRM:                       Salesforce, Microsoft Dynamics, custom
WFM:                       Verint, NICE IEX, Aspect, Calabrio
Quality Management (QM):   Verint, NICE, Calabrio, Evaluagent
Real-Time Display:         ← RTM View Shell (this project)
Reporting / Analytics:     Power BI, Tableau, CC platform native
Chatbot / Digital:         Amazon Connect, Google CCAI, Nuance
Recording:                 Verint, NICE, ASC
```

### The RTM shell's role in the technology strategy

The director positions the RTM View Shell as:
- **The single pane of glass** for real-time operations visibility.
- **Platform-agnostic:** works regardless of which ACD platform is used (data adapter is separate).
- **Governance tool:** manages who sees what data (permission groups = data governance).
- **Replaces:** individual vendor wallboards (Avaya CMS Supervisor, Genesys WDE, etc.)
  which are platform-specific, expensive to licence, and hard to customise.

### Technology decision criteria the director applies

| Criterion | Weight | RTM shell positioning |
|---|---|---|
| Platform independence | High | Adapter-based, not locked to ACD vendor |
| Customisation | High | Drag-drop layout, configurable widgets (v2+) |
| Security / governance | High | Permission groups, audit log, SSO |
| Total cost of ownership | High | In-house .NET stack, no per-seat licence |
| Time to value | Medium | Shell in v1, widget library in v2 |
| Vendor support | Medium | Internal IT team owns it |

---

## 8. CX strategy — the director's north star

CX (Customer Experience) strategy defines how the organisation wants customers to feel
when they contact the CC. The director translates this into operational targets.

### CX strategy → operational KPI mapping

| Strategic objective | Operational KPI | Dashboard relevance |
|---|---|---|
| "Resolve first time" | FCR ≥75% | AHT, Repeat contact rate widget |
| "Answer quickly" | ASA <20s, SLA 80/20 | CIQ, LWT, SLA bar widget |
| "Treat customers as individuals" | CSAT, QA score | CSAT trend widget (future) |
| "Make it easy" | Digital deflection, IVR containment | Channel mix widget (future) |
| "Empower our people" | Adherence, engagement | Adherence widget, agent status |

### Voice of Customer (VoC) programme

The director owns the VoC programme:
- Post-call surveys (CSAT, NPS).
- Complaint analysis.
- Social media sentiment (in modern CC).
- Call driver analysis (wrap codes → root cause → fix upstream).

**Feedback loop:** VoC data → root cause → process change → CC script update → measure improvement.

---

## 9. Regulatory compliance — director's accountability

The director is personally accountable for regulatory compliance in most jurisdictions.

### Key regulatory areas

| Area | Regulation | Risk of non-compliance |
|---|---|---|
| Data protection | GDPR, CCPA | Fines up to 4% global revenue |
| Financial services | FCA (UK), SEC (US), MiFID II (EU) | Fines, licence revocation |
| Call recording consent | GDPR, Ofcom | Fine, reputational damage |
| Payment card data | PCI-DSS | Card scheme fines, breach liability |
| Outbound calling | TCPA (US), Ofcom silent calls | Per-call fines |
| Disability access | Equality Act / ADA | Litigation |
| ISO 18295 / COPC | Voluntary standards | Client contract requirements |

### Audit log [AUD-*] — regulatory relevance

For a regulated CC director, the audit log is not just an IT security feature — it is:
- Evidence of appropriate data access controls (GDPR Article 25 — data protection by design).
- Proof of who accessed sensitive customer data and when.
- Required for FCA / PRA regulatory reporting on surveillance.
- Evidence in Subject Access Requests (SARs) under GDPR.

The director should have read access to `menu.audit` and should receive a monthly
audit summary report from the IT/compliance team.

---

## 10. Board and C-suite reporting

The director presents CC performance to the board or executive committee typically monthly.

### Board-level scorecard (one page)

```
CONTACT CENTRE — MONTHLY EXECUTIVE SUMMARY
Period: [Month Year]

CUSTOMER                          PEOPLE
  SLA:        83% ✅ (target 80%)   Headcount:    312 FTE
  CSAT:       87% ✅ (target 85%)   Attrition:    2.1% (monthly)
  NPS:        +42 ✅ (target +38)   Adherence:    93% ✅
  Complaints:  1.8% ✅ (target <2%) Absence:      4.2% ✅

OPERATIONS                        FINANCIAL
  Contacts handled: 48,220         Opex vs budget: +1.2% (within tolerance)
  FCR:         74% ⚠️ (target 75%)  Cost per contact: £4.82 ✅
  Abandon:      4.1% ✅             Overtime %:   3.1% ✅
  AHT:        243s ✅

KEY ISSUES THIS MONTH
  FCR marginally below target — root cause: new product launch queries require
  callback. Action: product FAQ deployed to agents, target recovery next month.

NEXT MONTH OUTLOOK
  Forecast +12% volume (Q4 seasonal uplift). Extra 18 FTE contracted via BPO.
  Risk: BPO quality — QA calibration session scheduled w/c [date].
```

### What the board cares about most

Boards are not interested in AHT or CIQ — they want:
1. **Are we meeting our commitments to customers?** (SLA, CSAT, NPS)
2. **Are we doing it within budget?** (Cost per contact, opex variance)
3. **Is the operation sustainable?** (Attrition, absence, engagement)
4. **What are the risks?** (Volume forecast, regulatory, technology)

---

## 11. Permission model for director in the RTM shell

### Single-tenant director (one organisation, one CC)

```
Role: Administrator (or Superadmin if they need to manage tenants)

Permission Group: Director
  pg_queues:            All
  pg_skills:            All
  pg_agent_supergroups: All
  pg_business_units:    All

  menu_permissions:
    menu.dashboards:      ✅
    menu.users:           ✅ (view only — not day-to-day management)
    menu.permissionGroups:✅ (approve PG design)
    menu.audit:           ✅ (compliance requirement)
    menu.tenantSettings:  ✅ (SSO, password policy, retention)
    menu.widgetCatalog:   ✅
    menu.tenants:         ❌ (unless Superadmin)

  dashboard_permissions:
    Executive summary screen: View + Edit
    All department screens:   View only
    Audit screen:             View only
```

### Multi-tenant director (BPO or multi-entity)

```
Role: Superadmin
  → No PG restrictions
  → Can switch between tenants [ARCH-02]
  → Writes Tenant.Switched audit event on each switch
  → Sees all tenants in platform
```

---

## 12. Screens the director needs

### Screen A — Executive Operations Summary (director-configured)

Daily overview: all departments, current SLA, today's call volume, CSAT (week),
headcount online now vs scheduled. Refresh every 60 seconds.
Intended audience: director + their PA.

### Screen B — Multi-Department Comparison

Side-by-side department KPIs: SLA, abandon rate, AHT, adherence, agent count.
Used for: weekly operations review meeting with department managers.

### Screen C — Live Operations (read-only access to shift screens)

Director can view any shift screen configured by department managers.
Used for: client visits, board demonstrations, crisis monitoring.
Permission: View only — never Edit (avoids accidentally changing a live screen).

---

## 13. Glossary — director-level terms

| Term | Definition |
|---|---|
| BPO | Business Process Outsourcer — third party CC provider |
| Capex | Capital expenditure — large upfront investments (technology, fit-out) |
| COPC | Customer Operations Performance Centre — CC performance standard |
| Cost avoidance | Savings from not having to handle contacts (deflection, FCR improvement) |
| CX | Customer Experience — the totality of how customers feel about the organisation |
| Digital deflection | Moving customers from phone to cheaper digital channels |
| FTE | Full-Time Equivalent — standard headcount unit |
| IVR containment | % of calls resolved by IVR without human agent |
| NPS | Net Promoter Score — likelihood to recommend (−100 to +100) |
| Omnichannel | Seamless customer experience across all contact channels |
| Opex | Operational expenditure — ongoing running costs |
| PCI-DSS | Payment Card Industry Data Security Standard |
| P&L | Profit and Loss — financial performance statement |
| QBR | Quarterly Business Review — formal client performance meeting |
| ROI | Return on Investment — financial justification for a project |
| SAR | Subject Access Request — GDPR right to see personal data held |
| SLA contract | Service Level Agreement — contractual performance commitment to a client |
| VoC | Voice of Customer — programme to capture and act on customer feedback |
| WFM | Workforce Management — forecasting, scheduling, and intraday optimisation system |
