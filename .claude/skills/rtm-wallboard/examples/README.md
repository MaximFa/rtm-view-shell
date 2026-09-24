# Worked examples

Four finished screens for the same fictional bank contact center, frozen at the
same moment (17.11.2026, 11:42) so their numbers reconcile with each other.
Open either with `?static=1` for the still frame.

| File | Screen | The problem it dramatises |
|---|---|---|
| `digital-channels-bots.html` | Bot KPI row, digital channel queues, 11-agent digital grid with first-response and between-messages columns | The email channel misses the 120-second response SLA (79.5%) while staffing has slack |
| `voice-operations.html` | Operational KPI row with vs-target deltas, voice queues, 18-column agent grid | Averages are inside target but max wait breaches, and Erlang requires 47 agents against 41 on hand |
| `executive-sla-thresholds.html` | Four threshold panels in a 2×2 — three departments plus a derived roll-up | Technical support breaches four of six thresholds; the total panel is computed from the three, so it cannot contradict them |

Read these when you need a concrete implementation of a widget rather than the
spec — particularly the per-widget render functions, the colgroup width tables and
the scenario `tick()`. Copy structure, not content: names, verticals and figures
should be redesigned for each new brief.

| `ai-insights.html` | Ranked insight feed, forecast with confidence band and predicted breach, NLU topic clusters, anomalies vs baseline, sentiment and automation opportunities | The predicted breach in 23 minutes, which the scenario then averts once the recommendation is applied |

Both agent grids carry the five-star agent score under the name, with the rating
driven live from each agent's own speed and discipline metrics.
