---
name: contact-center-shift-manager
invocation: user
description: >
  Apply contact centre shift management domain expertise to the RTM View Shell project.
  Trigger this skill whenever the user mentions: shift, schedule, scheduling, workforce management,
  WFM, Erlang C, staffing, headcount, forecast, intraday, intraday management, adherence,
  schedule adherence, shrinkage, rostering, rotation, break schedule, lunch rotation,
  agent assignment during shift, queue assignment, skill assignment, multi-skill,
  blended agent, hot seat, seat occupancy, shift handover, shift notes, team briefing,
  interval (15-min, 30-min, half-hour), occupancy target, service level target by interval,
  peak hour, off-peak, understaffed, overstaffed, absenteeism, absence, late arrival,
  early departure, overtime, agent utilisation during shift, supervisor actions during shift,
  real-time adherence, RTA, intraday reforecast, intraday adjustment,
  shrinkage factor, Erlang, traffic intensity, call arrival rate, Poisson,
  shift pattern (morning/afternoon/evening/night), split shift, staggered start,
  agent skill level, senior agent, trainee, nesting, buddy system,
  daily ops report, shift handover report, SLA recovery, rescue plan,
  or anything about how a shift supervisor manages their team on a live day.
  Also trigger on: "how many agents do I need", "understaffed right now", "agents on break",
  "SLA falling", "what should supervisor do when", "intraday what to do if",
  "shift management report", "break rotation logic".
  Never skip this skill when designing features related to intraday operations,
  shift dashboards, adherence views, or supervisor action flows.
---

# Contact Centre Shift Manager — RTM View Shell

This skill provides shift management domain knowledge for the **CC Dashboard Shell** project.
It covers what a shift supervisor needs to see, decide, and do during a live operational shift —
and how that translates into dashboard features, widget data, permission structures, and UX flows.

---

## 1. The shift manager's world — context

A **shift manager** (also: team leader, intraday supervisor) is responsible for:
- Ensuring their team meets SLA targets throughout their shift (typically 8h).
- Monitoring agent states and intervening when something goes wrong.
- Managing breaks, lunches, and unplanned absences in real time.
- Communicating with the WFM team when forecasts are wrong.
- Handing over to the next shift with a clear status picture.

**Key difference from a WFM planner:** the shift manager acts on what is happening *right now*,
not on what was planned. Their primary tool is the real-time dashboard (Screen 05).

**Their biggest fears:**
1. SLA drops below target with no agents available to pull back from break.
2. A queue floods unexpectedly (campaign, system outage downstream).
3. Several agents call in sick — understaffed from the start of the shift.
4. An agent gets stuck on a very long call — blocking capacity.

---

## 2. Shift structure — terminology

### Shift patterns (common in CC)

| Pattern | Hours | Notes |
|---|---|---|
| Morning | 07:00–15:00 | Peak arrival, most traffic |
| Afternoon | 14:00–22:00 | Overlap with morning at 14–15h |
| Evening | 17:00–01:00 | Reduced headcount, often cross-trained |
| Night | 22:00–07:00 | Skeleton crew, usually multi-skill |
| Split shift | e.g. 08:00–12:00 + 16:00–20:00 | Covers peaks, unpopular with agents |
| Staggered start | 08:00 / 08:30 / 09:00 / 09:30 | Smooths arrival curve |

### Shift timeline events

```
Shift start
  └─ Pre-shift briefing (5–10 min)        ← team leader briefs agents on targets, updates
  └─ Staggered logins (30 min window)     ← agents log into ACD at scheduled intervals
  └─ Peak period                          ← highest call volume
  └─ Break rotation begins                ← first break wave (see §3)
  └─ Lunch rotation                       ← major capacity reduction
  └─ Afternoon ramp-down
  └─ End-of-shift wrap                    ← ACW completion, stat check
  └─ Shift handover                       ← notes passed to next team leader
Shift end
```

---

## 3. Break and lunch rotation management

### The core challenge

Breaks remove agents from the queue. A break rotation must:
1. Maintain enough agents available to hold SLA.
2. Ensure every agent gets their legally required break.
3. Flex in real time when call volumes are higher than forecast.

### Erlang C — minimum staffing

The minimum number of agents needed to maintain SLA is calculated via Erlang C:

```
Input:
  λ  = call arrival rate (calls per second)
  μ  = average handle time (seconds) = AHT
  T  = SLA target time (seconds, e.g. 20s)
  SL = service level target (e.g. 0.80 = 80%)

Traffic intensity: A = λ / μ  (Erlangs)
Erlang C gives: minimum N agents such that P(wait > T) ≤ 1 - SL
```

In practice, shift managers use a WFM system (Verint, NICE IEX, Aspect) that pre-calculates
required headcount per 30-minute interval. The dashboard shows actual vs required.

### Break rotation rules (common practice)

- **Window:** Never send more than 20–25% of team on break simultaneously.
- **Sequence:** Rotate alphabetically or by seniority (first break, first lunch).
- **Flex rule:** If CIQ > 5, delay the next break wave by 10 min and reassess.
- **Hard limit:** Legally, agents cannot be denied breaks. Maximum delay: 30 min.

### Supervisor decision tree during breaks

```
CIQ rises while agent is on break?
  ├─ CIQ 1–4 and SLA ≥ target  →  No action. Monitor.
  ├─ CIQ 5–9 or SLA 70–79%    →  Call next break wave back 10 min early.
  │                                Contact WFM for intraday reforecast.
  └─ CIQ ≥ 10 or SLA < 70%    →  Interrupt current breaks. Send alert to manager.
                                   Open overflow queue if available.
                                   Consider mandatory overtime (last resort).
```

---

## 4. Intraday management — the supervisor's decision cycle

Every 15–30 minutes, a shift manager runs through this mental checklist:

```
1. SLA — is it on target?
   └─ Yes → continue
   └─ No  → how many agents do I have? → go to step 3

2. Queue depth — calls in queue trend
   └─ Stable / falling → OK
   └─ Rising          → anticipate peak, defer next break

3. Agent state audit
   └─ Any agent in ACW > 5 min? → coaching flag
   └─ Any agent in NOT_READY unexpectedly? → check reason
   └─ Agents on OUTBOUND when CIQ is high? → reassign

4. Absenteeism check
   └─ Any scheduled agent not logged in 10 min after shift start? → call them
   └─ Late start impacts: recalculate available capacity

5. Escalations pending?
   └─ Any long-running calls needing supervisor pickup?
   └─ Any complaint calls flagged?
```

---

## 5. Adherence monitoring

**Schedule adherence** = % of time an agent was in the scheduled activity.

```
Adherence% = (Time in scheduled activity) / (Total scheduled time) × 100
Target: ≥ 92–95%
```

**Real-Time Adherence (RTA):** the live view of whether agents are doing what was scheduled.

| Agent state (actual) | Scheduled state | RTA status |
|---|---|---|
| READY | READY | ✅ Adherent |
| TALKING | READY | ✅ Adherent (productive) |
| ACW | ACW | ✅ Adherent |
| NOT_READY | READY | ⚠️ Non-adherent |
| LOGGED_OUT | READY | ❌ Non-adherent |
| READY | NOT_READY (break) | ℹ️ Early return (positive) |

**Shrinkage:** planned reduction in capacity due to breaks, training, meetings, absenteeism.

```
Gross headcount needed = Net headcount (Erlang) / (1 - shrinkage%)
Typical shrinkage: 30–40% (breaks 10%, training 5%, coaching 5%, absence 10–15%, etc.)
```

---

## 6. Multi-skill agents — blending

Modern contact centres use **blended agents** — agents who can handle multiple queue types.

```
Agent A: Skills = [Sales, Retention]
Agent B: Skills = [Technical Support, Sales]

Queue: Sales    → both A and B can take calls
Queue: Tech     → only B can take calls
Queue: Retention → only A can take calls
```

**Supervisor actions for blending:**
- Temporarily reassign Agent B from Technical to Sales when Sales CIQ is high.
- Pull all Sales-skilled agents off outbound when inbound SLA is at risk.

**Impact on permission model:**
- `pg_skills` in the permission group controls which skill views the supervisor sees.
- A supervisor only sees agents with skills their PG has access to.
- This means a Sales supervisor won't see Technical agents — by design.

---

## 7. Shift handover

A shift handover is a critical operational moment. The outgoing supervisor briefs the incoming one.

### Handover information (what to communicate)

```
1. Current SLA status  — is it on/off target? Trend for the last hour?
2. Headcount           — how many agents are logged in vs scheduled?
3. Open issues         — any escalations, complaints, or system problems?
4. Queue anomalies     — any queue behaving unusually?
5. Agent issues        — any agent on a performance plan, late, sick?
6. WFM notes           — any intraday adjustments made this shift?
7. Action items        — what does the incoming supervisor need to do first?
```

### Dashboard support for handover

Screen 05 (Dashboard Viewer) should support handover by:
- Showing "today so far" metrics alongside real-time snapshot.
- Exporting a shift summary (future feature — not in v1 scope).
- Allowing the incoming supervisor to see the same view without requiring handover notes.

---

## 8. SLA recovery scenarios

When SLA drops below target during a shift, supervisors follow a recovery playbook:

### Level 1 — Delay next break (SLA 70–79%)

1. Announce: "Break wave 2 delayed 15 minutes."
2. Monitor CIQ every 2 minutes.
3. Inform WFM of delay.
4. If SLA recovers to ≥80% within 15 min → resume normal rotation.

### Level 2 — Recall agents from break (SLA 60–69%)

1. Call agents back from break.
2. Redirect any agents on outbound to inbound.
3. Contact next-shift team leader: can they start 30 min early?
4. Notify WFM for intraday reforecast.

### Level 3 — Emergency escalation (SLA < 60% or CIQ > 20)

1. Notify operations manager immediately.
2. Open all available overflow queues.
3. Consider mandatory overtime for agents at shift end.
4. Check for system outage (is call volume spike abnormal?).
5. Communicate SLA breach to stakeholders.

---

## 9. Key metrics for shift managers — dashboard priority

Ranked by importance to the shift manager's moment-to-moment decisions:

| Priority | Metric | Why it matters |
|---|---|---|
| 1 | SLA% (current interval) | Primary KPI — the target they are measured on |
| 2 | Calls in Queue | Immediate pressure on the team |
| 3 | Agents Available | Capacity to handle CIQ |
| 4 | Longest Wait Time | How bad is the wait for the oldest caller? |
| 5 | Agents in Not Ready | Capacity being consumed unproductively |
| 6 | Agents in ACW | Capacity temporarily locked in wrap-up |
| 7 | Abandon Rate % | Proxy for customer experience |
| 8 | ASA (trend) | Is the queue getting faster or slower? |
| 9 | Occupancy% | Team health — too high = burnout risk |
| 10 | Adherence% | Are agents following their schedule? |

**Display rule:** metrics 1–4 should be the largest, most visible elements on the wallboard.
Metrics 5–10 are supporting context — smaller, in a secondary section.

---

## 10. Interval reporting — 15 min vs 30 min vs hourly

Contact centres measure performance in intervals, not just daily totals.

| Interval | Usage |
|---|---|
| 15 minutes | Real-time dashboards, intraday adjustments |
| 30 minutes | WFM scheduling unit, Erlang C input |
| 60 minutes | Supervisor hourly check-in with manager |
| Daily | End-of-day operations report |
| Monthly | Performance review, trend analysis |

**For the wallboard (Screen 05):**
- Show "current interval" metrics (last 15 or 30 min) alongside live snapshot.
- Allow the supervisor to switch between "last 15 min", "last 30 min", "today" views.
- Trend arrows (↑ ↓ →) next to metrics tell the story faster than numbers alone.

---

## 11. Agent behaviour patterns — what supervisors watch for

### Red flags in real time

| Pattern | Possible cause | Supervisor action |
|---|---|---|
| Agent in ACW > 5 min | Struggling with after-call tasks | Check in, offer help |
| Agent toggles NOT_READY frequently | Avoiding calls, burnout | Coaching conversation |
| Agent in READY but no calls assigned | Routing issue | Check ACD assignment |
| Agent login delayed > 15 min | Late arrival, tech issue | Call agent |
| Agent in TALKING > 20 min | Complex call, escalation needed | Monitor call |
| Multiple agents in NOT_READY simultaneously | Informal break ("toilet break convoy") | Stagger NOT_READY |

### Positive patterns

| Pattern | Meaning |
|---|---|
| Quick ACW (< 60s consistently) | Efficient agent — good candidate for more complex calls |
| High CSAT + low AHT | Star performer — buddy them with trainees |
| Early return from break during peak | Self-motivated, team-focused agent |

---

## 12. Staffing calculations for feature design

When building features that reference headcount or staffing:

### Required agents formula (simplified Erlang C)

```
For a given 30-minute interval:
  calls_offered × AHT_seconds / 1800 = traffic_intensity (Erlangs)
  Required agents = f(traffic_intensity, SLA_target, SLA_seconds)

Rough rule of thumb (for design purposes only):
  If traffic_intensity = A Erlangs, you need at least ceil(A) + 2..4 agents
  to achieve 80/20 SLA. The exact number depends on AHT variance.
```

### Capacity available during break rotation

```
If team_size = 20 agents, break_window = 15 min, break_wave_size = 4 agents:
  Capacity reduction during break wave = 4/20 = 20%
  Available agents during break = 16

If AHT = 240s and call_rate = 0.05 calls/sec:
  Traffic intensity = 0.05 × 240 = 12 Erlangs
  16 agents handle 12 Erlangs at ~80% occupancy → borderline safe
  → max break wave = 4 agents
```

This logic informs why `pg_queues` empty list = denied — supervisors must know exactly
which queues their capacity covers.

---

## 13. Shift manager UX patterns — design guidance

### Screen 05 (Dashboard Viewer) — shift manager specific

**Queue filter tabs:** order by priority (highest-risk queue first, not alphabetical).
Supervisors spend 80% of their time on 1–2 critical queues.

**Trend indicators:** every KPI metric should show direction arrow:
- ↑ Red = getting worse (CIQ rising, SLA falling).
- ↓ Green = improving (CIQ falling, SLA rising).
- Context matters: ↑ green for "Agents Available", ↑ red for "Abandon Rate".

**Time selector:** "Now" / "Last 15 min" / "Last 30 min" / "Today" toggle in the top bar.
Shift managers need the interval view, not just the snapshot.

**Agent status board priorities:**
- Group agents by state: Available → On Call → ACW → Not Ready → Logged Out.
- Sort within each group: longest duration first (longest wait in that state = most urgent).
- Flag agents exceeding thresholds with colour — e.g. ACW cell turns amber at 3 min, red at 5 min.

**Pause/Resume button:** critical for shift managers doing a screenshot for handover notes.

### Screen 03 (Permission Groups) — queue assignment for shift managers

When configuring `pg_queues` for a Permission Group:
- Show queues grouped by shift relevance (morning queues, evening queues, 24/7 queues).
- Show queue traffic profile (peak hours) as a tooltip — helps admin assign correctly.
- Alert when a PG has no queues assigned (shift manager would see nothing on their dashboard).

---

## 14. Glossary — shift management terms

| Term | Definition |
|---|---|
| Adherence | % of time agent followed their scheduled activity |
| Blended agent | Agent who handles multiple interaction types or queues |
| Erlang C | Formula for calculating required agents given call rate and AHT |
| Headcount | Number of agents scheduled or logged in |
| Intraday | Within the current day; real-time adjustments to the plan |
| Interval | The reporting period (15 min, 30 min) used for scheduling |
| Nesting | Trainee agent paired with a senior agent for coaching |
| Occupancy | % of time agent is busy vs available (excludes logged-out time) |
| Reforecast | Updated call volume prediction made during the shift |
| RTA | Real-Time Adherence — live view of actual vs scheduled state |
| Shrinkage | % of scheduled time unavailable for calls (breaks, training, etc.) |
| Staggered start | Agents starting at different times to smooth login spike |
| Traffic intensity | Call volume × AHT, measured in Erlangs |
| Utilisation | % of total logged-in time spent on calls (includes available time) |
| WFM | Workforce Management — planning, scheduling, and intraday management system |
