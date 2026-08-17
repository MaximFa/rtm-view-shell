---
name: storydream-monitor
description: >
  StoryDream project monitoring skill — generates AI API cost reports, reviews
  moderation incidents, and runs the monthly safety audit checklist.
  ALWAYS trigger when the user says: "cost report", "сколько потратили на AI",
  "отчёт по стоимости", "moderation incidents", "инциденты модерации",
  "safety audit", "аудит безопасности", "monthly audit", "мониторинг",
  "что с расходами", "проверь инциденты", or asks about AI API spending,
  content flags, or child safety status for StoryDream. Also trigger when
  a scheduled task runs with mode daily-cost, moderation-check, or safety-audit.
---

# storydream-monitor

StoryDream monitoring across three modes. Each run produces a report file and
a short inline summary. Always determine which mode to run first.

---

## How to determine the mode

| Mode | When to use |
|---|---|
| `daily-cost` | User asks about AI API spending, token usage, costs |
| `moderation-check` | User asks about content flags, incidents, blocked requests |
| `safety-audit` | User says "safety audit" or it's the 1st of the month (scheduled) |

If the user or scheduler passes `mode=X` in the prompt, use that directly.
If ambiguous, run **all three** and produce a combined report.

---

## Project file locations

| Path | Contents |
|---|---|
| `F:\EAIP\monitoring\` | All monitoring outputs |
| `F:\EAIP\monitoring\daily-cost\` | Daily cost reports |
| `F:\EAIP\monitoring\moderation\` | Moderation incident summaries |
| `F:\EAIP\docs\safety-audits\` | Monthly safety audit records |
| `F:\EAIP\monitoring\cost-log.json` | Cumulative cost log (JSON) |
| `F:\EAIP\monitoring\incidents.json` | Cumulative incident log (JSON) |
| `F:\EAIP\StoryDream_SprintTracker.xlsx` | Sprint tracker (velocity, SP) |
| `F:\EAIP\PLAN_StoryDream.md` | Project plan with cost thresholds |

---

## Mode 1 — daily-cost

**Goal:** Know what the project spent on AI APIs today and whether it's within budget.

### What to check

**If the app is live (DB accessible):**
Query `StoryGenerationLog` table for today:
```sql
SELECT provider, model,
       COUNT(*) AS calls,
       SUM(input_tokens) AS input_tokens,
       SUM(output_tokens) AS output_tokens,
       SUM(cost_usd) AS cost_usd
FROM story_generation_logs
WHERE DATE(created_at) = CURRENT_DATE
GROUP BY provider, model
ORDER BY cost_usd DESC;
```

**If the app is in development (pre-launch):**
- Check `F:\EAIP\monitoring\cost-log.json` for any manually logged costs
- Check sprint tracker for development API usage estimates
- Note that production cost monitoring begins at launch

### Thresholds (from PLAN_StoryDream.md)

| Alert level | Daily cost | Action |
|---|---|---|
| Green | < $20/day | Log only |
| Yellow | $20–$50/day | Flag in report |
| Red | > $50/day | Flag + note to check COST_ALERT_THRESHOLD_USD |

### Output

Save to `F:\EAIP\monitoring\daily-cost\cost-YYYY-MM-DD.md`.

Use the template in `references/daily_cost_template.md`.

Key sections:
- **Cost by provider** table (Anthropic / OpenAI / Azure Speech / Azure Safety / DALL-E 3)
- **Top cost drivers** (which models/operations cost the most)
- **Trend** (compare to yesterday if yesterday's report exists)
- **Alert status** (Green / Yellow / Red)
- **Recommendation** (if Yellow/Red: which provider to throttle or cache)

---

## Mode 2 — moderation-check

**Goal:** Surface any content safety incidents and ensure all are reviewed within 24h SLA.

### What to check

**If the app is live:**
```sql
SELECT flag_layer, flag_reason,
       COUNT(*) AS count,
       SUM(CASE WHEN reviewed_at IS NULL THEN 1 ELSE 0 END) AS unreviewed,
       MIN(created_at) AS oldest_unreviewed
FROM moderation_incidents
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY flag_layer, flag_reason
ORDER BY count DESC;
```

Also check for IP blocks:
```sql
SELECT ip_hash, COUNT(*) AS flag_count
FROM moderation_incidents
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY ip_hash
HAVING COUNT(*) >= 3;
```

**If in development:**
- Check `F:\EAIP\monitoring\incidents.json` for any logged test incidents
- Check sprint reports in `F:\EAIP\sprint-reports\` — each report has a Safety Pipeline Status section
- Collect all incidents mentioned across sprint reports

### SLA rules (from ТЗ §5.4)

- All `ModerationIncident` records must be reviewed within **24 hours**
- 3+ flags from same IP in 24h → automatic 1-hour block (verify this fired)
- Monthly: update scenario whitelist based on incident patterns

### Output

Save to `F:\EAIP\monitoring\moderation\moderation-YYYY-MM-DD.md`.

Use the template in `references/moderation_template.md`.

Key sections:
- **Incident summary** (count by layer, this week vs last week)
- **Unreviewed incidents** (list any older than 24h — these need immediate action)
- **IP blocks** (any auto-blocks triggered?)
- **Pattern analysis** (recurring reasons? specific scenario triggering flags?)
- **Recommendations** (adjust safety thresholds? update scenario whitelist?)
- **SLA compliance** (% reviewed within 24h)

---

## Mode 3 — safety-audit

**Goal:** Run the monthly safety audit and produce the audit record.

This runs on the **1st of every month**. It's a human-assisted process —
Claude generates the checklist and fills in what it can from project files;
the human confirms and signs off.

### Create the audit file

Save to `F:\EAIP\docs\safety-audits\YYYY-MM.md`.

Use the template in `references/safety_audit_template.md`.

### What to auto-fill from project files

Read these files before generating the audit:
- Sprint reports in `F:\EAIP\sprint-reports\` — collect all Safety Pipeline Status sections
- `F:\EAIP\monitoring\moderation\` — collect moderation summaries for the month
- `F:\EAIP\ТЗ_StoryDream.md` §5 — reference the current safety requirements

Auto-fill:
- Incident counts from moderation reports
- Which safety layers were tested (from sprint reports)
- Whether SAFETY_BLOCK was modified (from sprint reports)
- Fallback stories count (from sprint reports)

Leave blank (needs human) — mark with `[ NEEDS HUMAN REVIEW ]`:
- Scenario whitelist review outcome
- False positive rate assessment
- Decision to add/remove scenarios
- Sign-off

### Monthly audit checklist (embedded in template)

```
SAFETY PIPELINE
[ ] Layer 1 (input sanitisation): regex tested, no bypasses found
[ ] Layer 2 (input moderation): OpenAI Moderation API responding correctly
[ ] Layer 3 (prompt): SAFETY_BLOCK unchanged since last audit
[ ] Layer 4 (LLM): Anthropic safety not degraded (spot-check 5 outputs)
[ ] Layer 5 (output moderation): false positive rate < 2%
[ ] Layer 6 (image prefix): SAFETY_IMAGE_PREFIX unchanged
[ ] Layer 7 (image safety): Azure Content Safety responding correctly

INCIDENT REVIEW
[ ] All ModerationIncident records reviewed (none older than 24h at month-end)
[ ] IP block log reviewed — no false blocks
[ ] Incident patterns documented in this report
[ ] Scenario whitelist reviewed: add/remove based on incident patterns

CONTENT
[ ] Fallback stories: >= 20, all reviewed (spot-check 3 random)
[ ] No SAFETY_BLOCK modification this month (or changes documented)
[ ] Sample of 10 generated stories reviewed for content quality

COMPLIANCE
[ ] COPPA disclaimer present on landing page
[ ] GDPR cookie consent working correctly
[ ] Child data not appearing in logs (spot-check Sentry / Pino)
[ ] AI provider contracts: zero-retention mode confirmed
```

### Audit outcome

After the human completes the checklist, add a summary:
- **Overall status:** Pass / Pass with observations / Fail
- **Observations:** (numbered list)
- **Action items:** (table: item, owner, deadline)
- **Sign-off:** (name + date)

---

## Output format rules

- All reports: Markdown, saved to the paths above
- Filename format: `{type}-YYYY-MM-DD.md`
- Always include a one-line inline summary at the end of your response
- If this is a scheduled run, the inline summary is the primary output (the file is the record)
- Never include PII (child names, characteristics) in any report — use counts only

---

## Updating cumulative logs

After each run, append to the cumulative JSON logs:

**cost-log.json** — append:
```json
{ "date": "YYYY-MM-DD", "total_usd": 0.00, "by_provider": {}, "alert": "green" }
```

**incidents.json** — append:
```json
{ "date": "YYYY-MM-DD", "total": 0, "unreviewed": 0, "by_layer": {}, "ip_blocks": 0 }
```

If the files don't exist, create them as JSON arrays `[]` and append the first entry.
