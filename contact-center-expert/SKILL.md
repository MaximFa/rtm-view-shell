---
name: contact-center-expert
invocation: user
description: >
  Apply contact centre domain expertise to the RTM View Shell project.
  Trigger this skill whenever the user mentions: contact centre, call centre, CC, queue,
  skill, agent, supervisor, supergroup, business unit, BU, agent group, agent supergroup,
  ACD, IVR, PBX, Avaya, Genesys, NICE CXone, Cisco UCCE, Aspect, Five9, Amazon Connect,
  real-time monitoring, RTM, dashboard, wallboard, SLA, service level, ASA, AHT,
  average handle time, talk time, hold time, ACW, after call work, wrap time,
  occupancy, utilisation, adherence, shrinkage, FCR, first call resolution,
  abandon rate, abandoned calls, CSAT, NPS, calls in queue, longest wait, agents available,
  agents on call, agents on break, agents in ACW, ready state, not-ready state,
  interval report, real-time report, historical data, threshold alert, KPI, metric,
  widget type, queue summary, agent status board, SLA bar, trend chart, ticker,
  permission to queue, skill-based routing, overflow, priority, VIP queue,
  wallboard layout, supervisor view, monitor call, whisper, barge-in,
  or any reference to WidgetCatalogItem categories (Queues, Agents, General metrics).
  Also trigger on: "what does X mean in a call centre", "how do supervisors use this",
  "what metrics matter", "how to show queue load", "agent states explained",
  "what is occupancy", "what is SLA in CC context", "difference between skill and queue".
  Never skip this skill when designing widgets, naming metrics, or building data models
  related to contact centre operations.
---

# Contact Centre Expert — RTM View Shell

This skill provides contact centre domain knowledge for the **CC Dashboard Shell** project.
Read it when designing widgets, naming metrics, building permission models around queues/skills,
or deciding what data a supervisor needs to see on a real-time dashboard.

The RTM View Shell does **not** render real-time data itself — it manages the container
(users, permissions, screen layout, widget catalogue). But every design decision must make
sense in the context of how contact centres operate.

---

## 1. What is a contact centre — operational context

A **contact centre** handles customer interactions (calls, chats, emails) through:

```
Customer → IVR / ACD → Queue → Agent
                    ↑
               Skill-based routing
```

- **IVR (Interactive Voice Response):** automated menu before reaching a human.
- **ACD (Automatic Call Distributor):** the routing engine that distributes calls to agents.
- **Queue:** a waiting room for interactions. Calls wait here until an agent is free.
- **Skill:** a capability tag on an agent (e.g. "Spanish", "Technical Support", "Sales").
  Routing sends calls to agents with the matching skill.
- **Agent group / Agentgroup:** a named set of agents, typically a team.
- **Supergroup (Agent Supergroup):** a grouping of agent groups — used for aggregated reporting
  across multiple teams (e.g. "All Sales Teams").
- **Business Unit (BU):** the highest-level grouping — a department or site (e.g. "EMEA Support",
  "Americas Sales"). Used to restrict data visibility to relevant supervisors.

---

## 2. Agent states — the core of real-time monitoring

Every agent is always in exactly one state. Supervisors watch these in real time.

| State | Code | Meaning | Counted as |
|---|---|---|---|
| **Available / Ready** | READY | Logged in, waiting for a call | Available |
| **On Call / Talking** | TALKING | Active customer interaction | Busy |
| **On Hold** | HOLD | Customer on hold, agent doing something | Busy |
| **ACW / Wrap** | ACW | After Call Work — completing notes after a call | Busy |
| **Not Ready** | NOT_READY | Agent unavailable (lunch, training, etc.) | Unavailable |
| **Busy (outbound)** | OUTBOUND | Agent making an outbound call | Busy |
| **Logged Out** | LOGGED_OUT | Not logged into the ACD | Offline |

**Why this matters for the dashboard:**
- Supervisors need to see at a glance: how many agents are available vs busy.
- "Available = 0" with "Calls in Queue = 15" is an emergency signal.
- Excessive ACW time is a coaching opportunity.
- Not Ready reasons (lunch, training, break) are separately tracked by most platforms.

---

## 3. Queue metrics — definitions

These are the metrics shown in queue-related widgets.

### Real-time (snapshot) metrics

| Metric | Abbreviation | Definition | Typical threshold |
|---|---|---|---|
| Calls in Queue | CIQ | Interactions currently waiting for an agent | Alert: >5 |
| Longest Wait | LWT | Time the oldest waiting call has been in queue | Alert: >2 min |
| Agents Available | AVL | Agents in READY state for this queue | Alert: <2 |
| Agents on Call | OCC | Agents currently talking (for this queue) | — |
| Agents in ACW | ACW | Agents in wrap-up (for this queue) | Alert: avg >90s |
| Agents Not Ready | NR | Agents unavailable (for this queue) | — |

### Interval / period metrics (today so far, last hour, last 30 min)

| Metric | Abbreviation | Definition | Goal |
|---|---|---|---|
| Service Level | SL / SLA | % of calls answered within X seconds (e.g. 80% in 20s) | ≥80% |
| Average Speed of Answer | ASA | Mean time from call entering queue to agent pickup | <20s |
| Average Handle Time | AHT | Talk time + hold time + ACW per call | Varies |
| Average Talk Time | ATT | Pure conversation time | — |
| Average Hold Time | AHT_HOLD | Time customer spent on hold per call | <60s |
| Average ACW | AACW | Mean after-call wrap time | <90s |
| Calls Offered | OFFERED | Total calls that entered the queue | — |
| Calls Handled | HANDLED | Calls answered by an agent | — |
| Calls Abandoned | ABANDONED | Calls that left the queue before answer | — |
| Abandon Rate | ABN% | Abandoned / Offered × 100 | <5% |
| Occupancy | OCC% | Time agents were busy / total logged-in time | 80–85% |

### SLA formula

```
SLA = (Calls answered within threshold) / (Calls offered - Calls abandoned < threshold) × 100

Standard: 80/20 = 80% of calls answered within 20 seconds
```

---

## 4. Agent metrics

| Metric | Definition |
|---|---|
| Occupancy | % of time agent was handling interactions vs available |
| Utilisation | % of logged-in time spent in productive states |
| Adherence | % of time agent followed their scheduled activity |
| CSAT | Customer Satisfaction score linked to this agent's calls |
| FCR | First Call Resolution rate — did the caller not call back? |
| AHT | Average Handle Time for this agent |

**Occupancy vs Utilisation:**
- Occupancy excludes time logged out — busy / (busy + available).
- Utilisation includes logged-out time — busy / total shift.
- Target occupancy: 80–85%. Above 90% → agent burnout, SLA risk.

---

## 5. Widget catalogue — categories and types

Defined in `WidgetCatalogItem` (cross-tenant entity). These are what supervisors add to screens.

### Category: Queues

| Widget Name | What it shows |
|---|---|
| Queue Summary | Real-time snapshot: CIQ, LWT, AVL agents, SLA |
| Queue Trend | Line chart: CIQ or ASA over time (last 30/60/120 min) |
| Abandoned Calls | Current period abandon count + rate |
| SLA Bar | Gauge or bar showing current SLA% vs target |

### Category: Agents

| Widget Name | What it shows |
|---|---|
| Agent Status | Grid of agent tiles with colour-coded state (READY=green, TALKING=blue, NOT_READY=grey) |
| Agent List | Tabular view: name, state, duration in state, queue, current call |
| Occupancy Gauge | Dial or bar showing current team occupancy% |

### Category: General metrics

| Widget Name | What it shows |
|---|---|
| KPI Scorecard | 4–6 large-number KPI tiles (CIQ, SLA, ASA, Handled, Abandoned) |
| Calls Per Hour | Bar chart: call volume by hour (current day) |
| AHT Chart | Trend of Average Handle Time |
| Real-time Ticker | Scrolling feed of live events: call answered, call abandoned, agent state change |

---

## 6. Permission model — CC resources

The shell manages which **queues, skills, supergroups, and BUs** each Permission Group can see.

### Why resource permissions matter

A supervisor for the **Sales team** should only see Sales queues and Sales agents.
Showing them Support queue data is a distraction — or a data governance issue in some organisations.

### How it maps to the data model

```
permission_groups
    ├── pg_queues          → which queues this group can monitor
    ├── pg_skills          → which skill views this group can access
    ├── pg_agent_supergroups → which supergroups (team aggregates) this group sees
    └── pg_business_units  → which BUs restrict the data visibility
```

**Empty list = access denied [PG-03]:**
- If `pg_queues` is empty for a group → that group cannot see any queue data.
- This is counter-intuitive but correct — it prevents accidental over-access.
- The UI must warn about empty resource lists (see ux-ui-expert skill §11).

### Typical role→resource matrix

| Role | Typical queue access | Typical BU access |
|---|---|---|
| Viewer (supervisor) | Own team's queues only | Own BU only |
| Editor (team lead) | Own team + overflow queues | Own BU only |
| Administrator | All queues in tenant | All BUs |
| Superadmin | All queues, all tenants | All BUs, all tenants |

---

## 7. Real-time monitoring — how supervisors work

Understanding supervisor workflows helps design the right screens.

### Morning start-up (08:00)
1. Open wallboard (Screen 05 — Dashboard Viewer).
2. Scan KPI scorecard: is SLA green? Any calls in queue already?
3. Check agent status board: who's logged in, who's not ready?

### During the day (reactive monitoring)
- Watch for CIQ > threshold → reassign agents or open overflow queue.
- Watch for LWT spike → call agents back from break.
- Notice an agent stuck in ACW >5 min → coaching flag.
- SLA dropping below 80% → escalate to manager.

### Queue filter tabs (Screen 05)
Supervisors typically manage 3–8 queues. The tab bar lets them focus on one queue at a time
without losing the "All queues" overview. Tabs come from the user's `pg_queues` list.

### Pause/Resume (Screen 05)
Used when taking a screenshot for a report, or comparing a metric at a specific moment.
The live feed pauses; data freezes. Resume resumes the 5-second update cycle.

---

## 8. Naming conventions — CC terminology in the UI

Use these exact terms in UI labels, widget names, and resource strings. Never invent synonyms.

| Concept | ✅ Use | ❌ Avoid |
|---|---|---|
| Interaction waiting | "Calls in Queue" | "Waiting items", "Queue depth" |
| Agent not available | "Not Ready" | "Offline", "Away", "Idle" |
| Agent available | "Available" or "Ready" | "Online", "Free" |
| After-call work | "ACW" or "Wrap" | "Post-call", "Notes", "Admin" |
| Service Level | "SLA" or "Service Level" | "Success rate", "Answer rate" |
| Average Handle Time | "AHT" | "Call duration", "Average call time" |
| Abandon | "Abandoned" | "Dropped", "Lost", "Missed" |
| Queue | "Queue" | "Channel", "Group", "Pool" |
| Agent Supergroup | "Supergroup" | "Team group", "Meta-team" |
| Business Unit | "Business Unit" or "BU" | "Department", "Division", "Site" |
| Occupancy | "Occupancy" | "Utilisation" (different metric — see §4) |

---

## 9. Thresholds and alert colours

Contact centres use consistent colour conventions. Use these in widgets and status indicators.

| Status | Meaning | Colour |
|---|---|---|
| Green | Healthy — within target | `--clr-success` / `--clr-success-subtle` |
| Amber / Orange | Warning — approaching threshold | `--clr-warning` / `--clr-warning-subtle` |
| Red | Critical — threshold breached | `--clr-danger` / `--clr-danger-subtle` |
| Grey | No data / offline | `--clr-overlay` / `--clr-text-muted` |

### Typical widget threshold examples

| Metric | Green | Amber | Red |
|---|---|---|---|
| SLA% | ≥80% | 70–79% | <70% |
| Calls in Queue | 0–4 | 5–9 | ≥10 |
| Longest Wait | <60s | 60–120s | >120s |
| Occupancy% | 75–85% | 85–92% | >92% or <60% |
| Abandon Rate | <3% | 3–7% | >7% |
| Agents Available | ≥3 | 1–2 | 0 |

Thresholds are configurable per tenant/queue in mature CC platforms.
In the shell v1: use hardcoded defaults; expose configuration in a future version.

---

## 10. CC platform integration context

The RTM View Shell is a **display container** — it does not connect to the CC platform directly.
Widget rendering (the actual data feed) is out of scope for v1.

However, the data model must align with how CC platforms expose data:

### Reference data (queues, skills, supergroups, BUs)
CC platforms (Avaya CMS, Genesys, Cisco UCCE, NICE) expose configuration via:
- REST API (modern platforms)
- Database views (legacy Avaya CMS)
- SOAP/XML (older Genesys)

The shell stores reference copies in `queues`, `skills`, `agent_supergroups`, `business_units` tables
with `ExternalId` (the platform's internal ID) for future synchronisation.

### Widget data flow (future v2)
```
CC Platform (ACD/PBX)
    → Real-time data adapter (separate service)
    → SignalR push to DashboardHub
    → Widget component renders the metric
```

In v1: widgets are stubs. The `PositionJson` / `ConfigJson` fields in `dashboard_widgets`
are reserved for the widget library to use.

### ExternalId field
All reference tables (`queues`, `skills`, etc.) have `ExternalId varchar(100)`.
This maps to the platform's internal queue/skill ID (e.g. Avaya CMS `split`, Genesys `queueId`).
It is populated when the CC adapter syncs reference data.

---

## 11. CC-specific data model rules

When working with CC resource tables (`queues`, `skills`, `agent_supergroups`, `business_units`):

- All are **multi-tenant** — every row has `TenantId`.
- `IsActive` flag: inactive queues/skills are hidden from selection in permission group UI,
  but existing PG assignments are preserved.
- `Name` is the display name shown to supervisors — must match what operators recognise
  from their CC platform (don't rename "Sales" to "SAL001" just because that's the ExternalId).
- `ExternalId` is internal — never shown in the supervisor UI.

### Permission assignment UX logic

When an Administrator assigns queues to a Permission Group:
1. Show only `IsActive = true` queues (inactive ones are hidden).
2. Search by name (not ExternalId).
3. Show how many groups already have access to this queue (informational).
4. Warn if the resulting list is empty (PG-03 risk).

---

## 12. Wallboard design principles

A **wallboard** (Screen 05 — Dashboard Viewer) is typically displayed on large TVs visible to
the entire contact centre floor. Design rules differ from regular admin screens:

| Regular UI | Wallboard |
|---|---|
| 13px base font size | 16–24px minimum — readable from 3m |
| Compact data density | Spacious — fewer, bigger numbers |
| Many table columns | Maximum 4–6 columns |
| Small colour badges | Large colour-filled cells or tiles |
| Hover for details | No hover — passive display |
| Click to interact | Minimal interaction |
| 1280px minimum | 1920×1080 or 3840×2160 (4K TV) |

In the shell v1, Screen 05 is viewed in a browser window (not a dedicated TV kiosk mode).
The stub widget placeholders should still respect wallboard-friendly proportions.

**Live indicator** (Screen 05): the blinking dot + "Live · 5s" is essential — operators must
know the data is current, not frozen. A frozen wallboard gives false confidence.

---

## 13. Glossary — reference

| Term | Full form | Definition |
|---|---|---|
| ACD | Automatic Call Distributor | Routing engine that assigns calls to agents |
| ACW | After Call Work | Work done after a call ends (notes, wrap-up) |
| AHT | Average Handle Time | Talk + hold + ACW per call |
| ASA | Average Speed of Answer | Mean queue wait time before agent pickup |
| BU | Business Unit | Highest-level organisational grouping |
| CIQ | Calls in Queue | Interactions currently waiting |
| CSAT | Customer Satisfaction | Post-call satisfaction score |
| FCR | First Call Resolution | Call resolved without repeat contact |
| IVR | Interactive Voice Response | Automated voice menu before agent |
| KPI | Key Performance Indicator | A tracked metric with a target |
| LWT | Longest Wait Time | Time oldest call has been waiting |
| NPS | Net Promoter Score | Likelihood to recommend (survey metric) |
| OCC% | Occupancy | Busy time / (busy + available) time |
| RTM | Real-Time Monitoring | Live operations dashboard |
| SL / SLA | Service Level | % calls answered within X seconds |
| Skill | — | Agent capability tag used for routing |
| Supergroup | Agent Supergroup | Grouping of agent groups for aggregated reporting |
| Wallboard | — | Large-screen display showing live CC metrics |
| Wrap | — | Synonym for ACW |
