body.push(H1("1. What Historical Reports are"));
body.push(P("Where the dashboards show you what is happening now, Historical Reports show you what happened over a chosen period — by queue and by agent. They read from RTM View Shell’s stored history, so you can review a shift, a day, a month, or a custom range after the fact."));
body.push(P([{t:"Where: ",b:true},"open Reports from the navigation menu, or go to /reports."]));
body.push(callout("note","You see only what you are allowed to",[
 "Reports are permission-scoped: you see data only for the queues (workgroups) and agents your permission group permits — exactly as on the dashboards. If a queue or agent you expect is missing, it is a permissions matter for your administrator."]));
body.push(H1("2. The four reports"));
body.push(P("The Reports page has four tabs; select one, set the filters (section 3), and choose Apply:"));
body.push(tbl(["Report","What it shows"],[
 ["Queue Interval","Queue activity broken into time intervals across the range — volumes and service measures per interval."],
 ["Queue Wait Time","How long callers waited in a queue, against the service-level target (see section 4)."],
 ["Agent Monthly","Per-agent totals rolled up by month — a month-over-month view of each agent."],
 ["Agent Shift Detail","A detailed, per-shift breakdown for an agent — the finest-grained agent view."]
],[2700,6660],{zebra:true}));
body.push(H1("3. Filtering a report"));
body.push(P("The filter bar at the top of each report controls what is included:"));
body.push(...bullets([
 [{t:"From / To",b:true}," — the date range. The range is inclusive of today, so you can run a report up to and including the current day."],
 [{t:"Workgroups",b:true}," — limit the report to specific queues; leave it open to include all the queues you are permitted to see."],
 [{t:"Agents",b:true}," — on the agent reports, limit to specific agents."],
 [{t:"Page size",b:true}," — how many rows to show per page."]
]));
body.push(P("Set the filters and select Apply to run the report. Change any filter and Apply again to refresh."));
body.push(H1("4. Service level and the SL threshold"));
body.push(P("Queue reports measure service level against a target answer time — the service-level threshold. This threshold is set per organisation (the SlThresholdSeconds tenant setting) and expressed in seconds: a call answered within the threshold counts as within service level. If your service-level figures look unexpected, confirm the configured threshold with your administrator (see the Multi-Tenant Management Guide, A-07)."));
body.push(H1("5. Reading and exporting results"));
body.push(P("Results appear as a paged table; use the page controls to move through large result sets. Reports can be exported for use outside the application; exports are capped at a maximum size per request to keep them responsive — narrow the date range or filters if an export is too large. Saved reports you no longer need are removed by a soft-delete, so they can be recovered within the retention window if removed by mistake."));
body.push(H1("6. Tips"));
body.push(...bullets([
 "Start with a narrow date range and widen it once you have the right view — large ranges return more data and slower exports.",
 "Use the Workgroups and Agents filters to focus on exactly what you are investigating.",
 "For live, second-by-second monitoring use the dashboards (Dashboard Viewer Guide, B-05); use these reports for after-the-fact analysis."
]));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Reports quick reference"));
body.push(tbl(["You want to…","Do this"],[
 ["Open reports","Navigation → Reports (/reports)"],
 ["Pick a report","Select a tab: Queue Interval · Queue Wait Time · Agent Monthly · Agent Shift Detail"],
 ["Set the period","From / To dates (inclusive of today) → Apply"],
 ["Focus on queues / agents","Use the Workgroups / Agents filters"],
 ["Understand service level","SL is measured vs the per-tenant threshold (SlThresholdSeconds) — confirm with your admin"],
 ["Get the data out","Export (capped per request; narrow filters if too large)"]
],[3300,6060],{zebra:true}));
body.push(P([{t:"Conceptual companion: ",b:true,i:true},{t:"the Unified Reporting Guide explains how real-time and historical metrics relate on one data model.",i:true}]));
