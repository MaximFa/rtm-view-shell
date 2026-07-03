# RTM View Shell — Historical Reports Guide (B-07)

> Audience: Viewers, Editors, Administrators. Brand: INSIGHTENSE. Route: /reports.
> Source: Historical Reports UI Track B (verified vs ReportsPage/ReportFilterBar razor + ReportScopeResolver).

## Document revision history
| Version | Date | Summary | Product release ID | Shipped-with |
|---|---|---|---|---|
| 1.0 | 2026-06-23 | Initial | RTM-REL-2026.06 | (pending push) |

1. **What HR reports are** — historical (after-the-fact) queue & agent reporting from stored history; route /reports; permission-scoped (only permitted queues/agents).
2. **The four reports** — Queue Interval, Queue Wait Time, Agent Monthly, Agent Shift Detail (tabbed).
3. **Filtering** — From/To (inclusive of today), Workgroups, Agents (agent reports), Page size → Apply.
4. **Service level** — SL measured vs the per-tenant threshold `SlThresholdSeconds` (A-07).
5. **Reading/exporting** — paged table; export capped per request; saved reports soft-deleted (recoverable in retention).
6. **Tips** — narrow range first; use filters; dashboards (B-05) for live, reports for analysis.

Appendix A — reports quick reference. Companion: Unified Reporting Guide (real-time↔historical on one model).
