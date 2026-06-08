---
name: contact-center-manager
invocation: user
description: >
  Apply contact centre department manager domain expertise to the RTM View Shell project.
  Trigger this skill whenever the user mentions: department manager, CC manager, operations manager,
  head of contact centre, director of operations, manager over supervisors, managing shift managers,
  multi-shift view, cross-shift performance, weekly performance, monthly performance,
  KPI reporting to management, management dashboard, executive dashboard, operations review,
  QBR (quarterly business review), team performance comparison, shift performance comparison,
  supervisor performance, coaching supervisors, capacity planning, headcount planning,
  workforce budget, agent attrition, recruitment need, training plan, quality management,
  QA, quality assurance, call monitoring, calibration, scoring, CSAT trend, NPS trend,
  FCR trend, SLA trend over weeks/months, department-level reporting, multi-queue oversight,
  multi-team oversight, cross-BU visibility, strategic metrics, leading indicators,
  lagging indicators, performance review, disciplinary, PIP, performance improvement plan,
  employee engagement, agent satisfaction, turnover, absenteeism trend, occupancy target,
  budget variance, cost per contact, revenue per agent, wrap code analysis,
  reason code analysis, call driver analysis, customer journey, escalation rate,
  complaint rate, regulatory compliance in CC, ISO 18295, COPC, or any request about
  what a CC operations manager or department head needs to see differently from a supervisor.
  Also trigger on: "manager view", "management report", "how does a manager use this",
  "cross-shift comparison", "weekly SLA report", "who owns the SLA target", "executive summary".
  Never skip this skill when designing management-level dashboards, reporting screens,
  or permission structures for department-level roles.
---

# Contact Centre Department Manager — RTM View Shell

This skill covers the domain knowledge of a **contact centre department manager** —
the person responsible for multiple shifts, multiple teams, and overall department KPIs.
They manage shift managers (team leaders), not individual agents directly.

Their relationship to the dashboard differs fundamentally from a shift manager:
- Shift manager → acts on what is happening *right now* (minutes).
- Department manager → understands trends and patterns (hours, days, weeks, months).

The RTM shell supports both views. This skill defines what the department manager needs.

---

## 1. The department manager's world — context

### Organisational position

```
Contact Centre Director / VP
        │
Department Manager  ← THIS ROLE
        │
   ┌────┴────┐
Shift Mgr   Shift Mgr   Shift Mgr
(Morning)  (Afternoon)  (Evening)
        │
   ┌────┴────┐
Agent    Agent    Agent
```

### Core responsibilities

| Responsibility | Time horizon | Primary tool |
|---|---|---|
| SLA ownership | Daily / Weekly | Management dashboard |
| Shift manager performance | Weekly / Monthly | Team reports |
| Capacity and staffing | Weekly / Quarterly | WFM + headcount tracker |
| Quality oversight | Weekly / Monthly | QA reports |
| Budget management | Monthly | Finance reports |
| Escalation owner | As needed | Real-time + historical |
| Reporting to director | Weekly / Monthly | Executive summary |
| Process improvement | Ongoing | Call driver analysis |

### What they don't do (vs shift manager)

- Do NOT manage individual agent breaks.
- Do NOT pull agents back from break personally.
- Do NOT answer escalated calls themselves (except as last resort).
- Do NOT make intraday queue assignments — that's the shift manager's job.

They **intervene at the shift manager level** when patterns suggest a systemic problem.

---

## 2. How a department manager uses the dashboard

### Screen 05 — Dashboard Viewer — manager's perspective

A department manager viewing Screen 05 sees the same live data as the shift manager,
but uses it differently:

| Signal | Shift manager response | Department manager response |
|---|---|---|
| SLA 65% for 20 min | Recall agents from break | Ask shift manager: "What's the recovery plan?" |
| CIQ spike at 14:00 daily | Delay break wave today | "Why does this spike happen every day? Fix the forecast." |
| Agent X in ACW 15 min | Check in with agent | "Is this a training issue? Has it happened before?" |
| Abandon rate 12% today | Open overflow queue | "Which queues are affected? Is this a product issue?" |

The department manager **uses the dashboard to ask questions**, not to take immediate operational action.

### What they want in a management view (not in v1 — design for future)

- Cross-shift SLA comparison: morning vs afternoon vs evening.
- Weekly SLA trend chart (not just today).
- Agent count by state aggregated across all teams.
- Top 5 worst-performing queues this week.
- Supervisor on duty right now + their team's current SLA.

---

## 3. KPIs the department manager owns

The department manager is typically measured on these metrics:

### Primary KPIs (usually in the management scorecard)

| KPI | Target (typical) | Period | Who sets it |
|---|---|---|---|
| Service Level | 80/20 (80% in 20s) | Monthly avg | Director / client SLA |
| CSAT | ≥85% | Monthly | Director / client contract |
| FCR (First Call Resolution) | ≥75% | Monthly | Director |
| Abandon Rate | <5% | Monthly | Director |
| Occupancy | 80–85% | Monthly | WFM + Director |
| Schedule Adherence | ≥92% | Monthly | WFM |
| AHT vs target | ±10% of target | Monthly | Operations |

### Secondary KPIs (operational health)

| KPI | What it signals |
|---|---|
| Agent attrition / turnover rate | Team stability, morale, management quality |
| Absenteeism rate | Wellbeing, engagement, management quality |
| % calls escalated to supervisor | Agent capability gap or difficult call types |
| Average ACW vs target | Process efficiency, training gaps |
| Cost per contact | Efficiency / budget management |
| Coaching sessions completed | Shift manager activity |
| QA scores | Quality of interactions |

### Leading vs lagging indicators

| Lagging (outcome) | Leading (predictor) |
|---|---|
| Monthly SLA% | Daily adherence trend |
| Monthly CSAT | FCR and AHT trends |
| Agent attrition | Engagement survey, absence rate |
| Escalation rate | ACW time, agent QA scores |

**Department manager focus:** monitor leading indicators to prevent lagging ones from degrading.

---

## 4. Multi-shift oversight — what the manager needs to compare

The department manager runs **multiple shifts** under them. They need to compare:

### Shift-level performance comparison

| Metric | Morning shift | Afternoon shift | Evening shift | Target |
|---|---|---|---|---|
| SLA% | 84% | 79% | 71% | 80% |
| Abandon Rate | 3.2% | 4.8% | 8.1% | <5% |
| Adherence | 94% | 92% | 89% | ≥92% |
| AHT (s) | 238 | 241 | 267 | 240 |

**Insight from this data:**
- Evening shift is underperforming on all metrics.
- Likely causes: fewer experienced agents, lower supervisor quality, higher call complexity, fatigue.
- Manager action: schedule calibration session with evening shift manager, review staffing model.

### What to look for in cross-shift data

- SLA consistently lower on one shift → staffing model or supervisor problem.
- AHT higher on one shift → training gap or call type difference.
- Adherence lower on one shift → shift manager not enforcing schedules.
- Abandon rate spike at specific hours → forecast miss (WFM issue).

---

## 5. Quality management — the manager's role

### QA (Quality Assurance) process

1. **Call monitoring:** QA analysts listen to recorded calls and score them.
2. **Calibration:** team leaders and QA align on scoring standards monthly.
3. **Coaching:** shift managers use QA results to coach individual agents.
4. **Trend review:** department manager reviews QA trend by team and by agent cohort.

### QA scoring dimensions (typical)

| Dimension | Weight | What is assessed |
|---|---|---|
| Greeting and compliance | 15% | Opening script, legal disclosures |
| Needs identification | 20% | Did agent understand the customer's issue? |
| Resolution | 30% | Was the issue resolved correctly and completely? |
| Communication | 15% | Tone, empathy, clarity |
| Procedure adherence | 20% | Correct system usage, data entry |

**Dashboard implication:** QA scores are historical, not real-time.
They belong on a management report screen, not the wallboard.

### The calibration session

Department manager chairs monthly calibration:
- Same call, scored independently by QA + shift managers + sample agents.
- Compare scores → identify and resolve scoring disagreements.
- Output: updated scoring guide, aligned expectations.

---

## 6. Capacity planning and headcount

### The manager's staffing model

```
Required productive headcount (Erlang) per interval
  ÷ (1 - shrinkage%)
= Gross headcount required

Gross headcount required
  - Currently employed agents (active, full capacity)
= Hiring gap
```

**Shrinkage breakdown (typical 30–35%):**

| Component | % of shift |
|---|---|
| Scheduled breaks | 10% |
| Lunch | 7% |
| Training / team meetings | 5% |
| Coaching sessions | 3% |
| Absence (sick, personal) | 8–10% |
| Late arrivals / early departures | 1–2% |

### Attrition management

Contact centres typically have 20–35% annual agent attrition — one of the highest of any industry.

```
Monthly attrition rate = (Agents who left this month / Average headcount) × 100
Annual attrition = Monthly rate × 12

At 25% annual attrition with 100 agents → replace 25 agents/year = 2 per month
```

Department manager tracks:
- Attrition rate by shift (evening shifts often higher).
- Exit reasons (tracked in exit interviews).
- Time to replace (recruitment lead time).
- Ramp-up time (new agent reaches full productivity in 4–8 weeks).

---

## 7. Call driver analysis — why customers are calling

One of the most strategic tools available to the department manager.

**Call driver** = the primary reason a customer contacted the centre.

```
Top call drivers this month:
  1. Account balance enquiry      32%
  2. Payment dispute              21%
  3. Product fault report         18%
  4. Change of address            14%
  5. Complaint escalation          9%
  6. Other                         6%
```

**Manager's use:**
- High "payment dispute" → is there a billing system issue? → escalate to finance.
- High "product fault" → is there a product defect? → escalate to product team.
- High "change of address" → is the self-service option broken? → escalate to digital.

**Implication for permissions:** call drivers are captured via **wrap codes** (ACW reason codes).
The manager needs access to wrap code reports — typically in a BI tool, not the RTM shell v1.
Future widget: "Top wrap codes today" by queue.

---

## 8. Escalation management

A department manager is the **second-level escalation owner**.

### Escalation triggers from shift manager

| Situation | Shift manager escalates to department manager |
|---|---|
| SLA < 60% for >15 min with no recovery | Immediate phone call |
| System outage (ACD, CRM, telephony) | Immediate notification |
| Multiple agents calling in sick (>20% absent) | Start of shift or when it happens |
| Media complaint or VIP customer complaint | As soon as identified |
| Agent grievance or formal complaint | Before end of shift |
| Unusual call pattern (suspected fraud, crisis) | Immediate |

### Department manager escalation to director

- SLA miss >15% vs target for a full day.
- Recurring SLA misses on same shift 3 days in a row.
- A formal complaint from a major client or regulator.
- Headcount crisis (>30% absent, cannot cover shift).

---

## 9. Permission model — what the department manager needs

The department manager needs **broader visibility** than a shift manager, but still
restricted to their department's queues, teams, and BUs.

### Recommended Permission Group configuration

```
Department Manager PG:
  pg_queues:           All queues managed by their department
  pg_skills:           All skills in their department
  pg_agent_supergroups: All supergroups in their department
  pg_business_units:   Their BU(s) only

  menu_permissions:
    menu.dashboards:    ✅ (view all screens in their PG)
    menu.users:         ✅ (may need to view — not necessarily create)
    menu.audit:         ✅ (review activity in their department)
    menu.permissionGroups: ❌ (managed by Administrator)
    menu.tenants:       ❌ (Superadmin only)

  dashboard_permissions:
    Management screens: View + Edit
    Shift screens:      View only (they observe, not operate)
```

### Screens the department manager needs

1. **Screen 05 variants:** one screen per shift team (Morning Ops, Afternoon Ops).
2. **Management summary screen:** cross-shift KPI scorecard (department-level).
3. **Queue health screen:** all department queues, current status.

The management summary screen is typically configured differently from the shift wallboard:
- Fewer, bigger KPI numbers (summary, not detail).
- Trend charts (15-min intervals for the last 4 hours).
- No real-time agent state board (that's the shift manager's tool).

---

## 10. Reports the department manager produces

### Daily operations report (end of day)

Sent to director and relevant stakeholders. Contains:

```
Date: [date]   Shift periods covered: Morning / Afternoon / Evening

PERFORMANCE SUMMARY
  Service Level:    82% (target: 80%) ✅
  Calls Handled:    1,847
  Abandon Rate:     4.1% (target: <5%) ✅
  AHT:              243s (target: 240s) ✅
  CSAT:             87% (target: 85%) ✅

STAFFING
  Scheduled agents:   62
  Logged in (peak):   58 (94% of schedule)
  Absent:             4 (6.5%)

ISSUES & ACTIONS
  - 14:00–14:30: CIQ reached 12 on Sales queue. Break wave delayed 15 min.
    SLA recovered to 81% by 14:45.
  - Agent J. Smith absent (sick). Covered by overtime volunteer.

TOMORROW
  Forecast: +8% call volume (Monday effect).
  Staffed: 65 agents scheduled.
```

### Weekly performance review (for director)

- 7-day SLA trend chart by shift.
- Week-over-week KPI comparison.
- Top 3 issues + actions taken.
- Headcount: actual vs plan.
- Next week's risks and mitigations.

---

## 11. Management screens vs supervisor screens — design differences

| Aspect | Shift manager (Screen 05) | Department manager screen |
|---|---|---|
| Time horizon | Last 5 min / now | Last 4h, today, this week |
| Agent detail | Individual agent tiles | Aggregated by team |
| Metric size | Large (24px+) readable from 3m | Medium (16–18px), more metrics visible |
| Update frequency | Every 5 seconds | Every 30–60 seconds acceptable |
| Interaction | Passive monitoring | Active analysis (click to drill down) |
| Queues shown | 1–3 primary queues | All department queues |
| Focus | "What do I do right now?" | "What is the pattern? What do I change?" |
| Alert style | Full-screen colour change | Inline badge / indicator |

---

## 12. Regulatory and compliance context

Department managers in contact centres often work under regulatory constraints:

| Regulation / Standard | Relevance |
|---|---|
| ISO 18295 | Contact centre management standard (customer service requirements) |
| COPC CX Standard | Quality and performance framework used by outsourcers |
| GDPR / data protection | Call recording consent, data retention |
| FCA / financial regulation | Specific scripts, disclosures required for financial products |
| PCI-DSS | Agent cannot hear/record card numbers (pause recording) |
| TCPA (US) | Outbound calling restrictions |
| Ofcom (UK) | Silent call rules for outbound |

**Audit log relevance [AUD-*]:**
The audit log in the shell captures who accessed which screens and when.
A department manager may be asked to produce evidence of who saw certain data
(e.g. for a GDPR subject access request or an internal investigation).
Access to `menu.audit` is appropriate for this role.

---

## 13. Glossary — department manager terms

| Term | Definition |
|---|---|
| Attrition | Rate at which agents leave the organisation (voluntary + involuntary) |
| Calibration | Session where QA scores are aligned across scorers |
| Call driver | Primary reason a customer contacted the centre (captured as wrap code) |
| COPC | Customer Operations Performance Centre — CC quality standard |
| Cost per contact | Total operating cost / total contacts handled |
| FCR | First Call Resolution — customer's issue resolved without repeat contact |
| ISO 18295 | International standard for customer contact centre management |
| Lagging indicator | Outcome metric (reflects past performance, e.g. monthly SLA) |
| Leading indicator | Predictive metric (forecasts future outcomes, e.g. daily adherence) |
| PCI-DSS | Payment Card Industry Data Security Standard |
| QBR | Quarterly Business Review — formal performance presentation to client or director |
| QA | Quality Assurance — structured evaluation of call/interaction quality |
| Ramp-up time | Time for a new agent to reach full productivity (typically 4–8 weeks) |
| Shrinkage | % of scheduled time unavailable for handling contacts |
| Wrap code | Reason code selected by agent after call (captures call driver) |
| WFM | Workforce Management — system for forecasting, scheduling, and intraday management |
