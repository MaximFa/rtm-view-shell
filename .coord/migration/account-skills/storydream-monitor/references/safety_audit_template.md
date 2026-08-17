# StoryDream — Monthly Safety Audit

**Period:** {YYYY-MM}
**Audit date:** {date}
**Auditor:** {name}
**Status:** [ PENDING SIGN-OFF ]

---

## Context

| Metric | Value |
|---|---|
| Stories generated this month | — |
| Total ModerationIncidents | — |
| Incidents reviewed on time | —% |
| SAFETY_BLOCK modified | No / Yes (see notes) |
| Fallback stories in pool | — / ≥ 20 |

---

## Safety pipeline checklist

### Layer controls

- [ ] **Layer 1** — Input sanitisation: regex tested, no bypasses found
- [ ] **Layer 2** — Input moderation: OpenAI Moderation API responding correctly
- [ ] **Layer 3** — Prompt: `SAFETY_BLOCK` unchanged since last audit
- [ ] **Layer 4** — LLM: Anthropic safety not degraded (spot-check 5 outputs)
- [ ] **Layer 5** — Output moderation: false positive rate < 2%
- [ ] **Layer 6** — Image prefix: `SAFETY_IMAGE_PREFIX` unchanged
- [ ] **Layer 7** — Image safety: Azure Content Safety responding correctly

### Incident review

- [ ] All `ModerationIncident` records reviewed (none unreviewed at month-end)
- [ ] IP block log reviewed — no false blocks
- [ ] Incident patterns documented below
- [ ] Scenario whitelist reviewed: decisions documented below

### Content quality

- [ ] Fallback stories: ≥ 20, all reviewed (spot-check 3 random stories)
- [ ] No `SAFETY_BLOCK` modification this month (or changes documented)
- [ ] Sample of 10 generated stories reviewed for content quality

### Compliance

- [ ] COPPA disclaimer present and visible on landing page
- [ ] GDPR cookie consent working correctly
- [ ] Child data not appearing in application logs (spot-check Pino / Sentry)
- [ ] AI provider zero-retention contracts in force (Anthropic, OpenAI, Azure)

---

## Incident pattern analysis

{Summary of recurring patterns from this month's moderation incidents.
What triggered flags most often? Any emerging patterns?}

---

## Scenario whitelist decisions

| Decision | Scenario | Reason |
|---|---|---|
| Keep / Add / Remove | {scenario} | {reason} |

---

## Observations

{Numbered list of any non-critical observations.}

---

## Action items

| Action | Owner | Deadline |
|---|---|---|
| | | |

---

## Sign-off

**Overall status:** Pass / Pass with observations / Fail

**Auditor:** ____________________
**Date:** ____________________

---

*Next audit due: 1st of {next_month} | StoryDream safety programme*
