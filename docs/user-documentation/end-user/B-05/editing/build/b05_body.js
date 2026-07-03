body.push(H1("1. Opening a dashboard"));
body.push(P("Sign in and you arrive at Screens — the dashboards you are permitted to see. Select a card to open the dashboard in the viewer. You see a dashboard if your permission group has View access to it, or if it is marked public. If a colleague can see one and you cannot, that is a permissions matter for your administrator."));
body.push(H1("2. The top bar"));
body.push(P("Across the top of the viewer you will find:"));
body.push(...bullets([
 "the dashboard name on the left;",
 "a live indicator — “Live · update 5s” with a blinking dot — telling you the data is refreshing automatically;",
 "a warning count badge that flags how many items need attention;",
 "a Pause / Resume control for the live updates (section 4);",
 "your user info — your name and permission group — on the right."
]));
body.push(H1("3. Queue filter tabs"));
body.push(P("Just beneath the top bar, a row of tabs focuses the dashboard on a particular queue. The first tab, All queues, shows everything; the rest are the individual queues your permission group is allowed to see. Selecting a queue narrows every widget to that queue; All queues restores the full view."));
body.push(H1("4. Live updates — pause and resume"));
body.push(P("By default the dashboard refreshes every few seconds. To study a moment without it changing — to read a spike, screenshot, or discuss a figure — select Pause; the data holds, nothing is lost. Select Resume to catch back up. Pausing affects only your own view. If your connection drops briefly, the viewer reconnects on its own and resumes without you signing in again."));
body.push(H1("5. Reading the widget area"));
body.push(P("The body of the dashboard is a layout of widgets — the individual data displays. A typical operations dashboard combines:"));
body.push(...bullets([
 [{t:"KPI tiles",b:true}," — headline numbers such as calls in queue, average wait, available agents, calls handled."],
 [{t:"Queue load and service-level gauges",b:true}," — at-a-glance health of each queue against target."],
 [{t:"An agent-status table",b:true}," — who is available, on a call, on a break."],
 [{t:"An event ticker",b:true}," — a running list of notable events."],
 [{t:"Trend charts",b:true}," — how handle time, abandon rate and occupancy move through the day."]
]));
body.push(P("The exact widgets and layout are chosen by whoever built the dashboard. The catalogue of widget types is in the Widget Catalogue Reference (B-06); the reports for after-the-fact analysis are in the Historical Reports Guide (B-07)."));
body.push(H1("6. The status bar"));
body.push(P("A thin status bar along the bottom confirms the dashboard is healthy: the real-time connection is established, the current update latency (a few milliseconds is normal), and your session identity. If it reports the connection lost and it does not recover within a few seconds, refresh the page; if it persists, contact your administrator."));
body.push(H1("7. Good habits"));
body.push(...bullets([
 "Keep the dashboard on All queues for the overall picture; switch to one queue only when investigating it.",
 "Pause before discussing or capturing a figure so it does not move.",
 "Trust the warning badge in the top bar as your cue for where to look first."
]));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Viewer quick reference"));
body.push(tbl(["You want to…","Do this"],[
 ["Open a dashboard","Screens → select the dashboard card"],
 ["Focus on one queue","Select that queue’s tab; All queues to restore"],
 ["Freeze the numbers","Pause; Resume to return to live"],
 ["See what needs attention","Read the warning-count badge in the top bar"],
 ["Check the connection","Look at the status bar (connection + latency) at the bottom"],
 ["Learn what a widget shows","See the Widget Catalogue Reference (B-06)"]
],[3900,5460],{zebra:true}));
