body.push(H1("1. About this workshop"));
body.push(P("This is a facilitated, hands-on workshop for administrators learning to design permission groups in RTM View Shell. It pairs a short model recap with scenarios and lab exercises you complete in a test tenant. Allow about 60–90 minutes. Each exercise has an expected outcome; an answer key is in Appendix A."));
body.push(P([{t:"You will need: ",b:true},"a test tenant, an administrator account, and a few sample dashboards and queues to assign. The reference for every control is the Permission Groups Configuration Guide (A-03)."]));
body.push(H1("2. The role × feature matrix"));
body.push(P("Roles set the outer boundary; permission groups refine access within it:"));
body.push(tbl(["Feature","Superadmin","Administrator","Editor","Viewer"],[
 ["Tenant management","Yes","—","—","—"],["Switch tenants","Yes","—","—","—"],
 ["User management","Yes","Yes","—","—"],["Permission groups","Yes","Yes","—","—"],
 ["Tenant settings / SSO","Yes","Yes","—","—"],
 ["Create / edit / delete dashboard","Yes","Yes","Yes (PG)","—"],
 ["View dashboard","Yes","Yes","Yes (PG)","Yes (PG)"],
 ["View widget catalogue","Yes","Yes","Yes","—"],["View audit log","Yes","Yes","—","—"]
],[3360,1500,1500,1500,1500],{zebra:true}));
body.push(P([{t:"(PG) ",b:true,i:true},{t:"= further restricted by the user’s permission group.",i:true}]));
body.push(H1("3. The model in three rules"));
body.push(...nums([
 [{t:"One group per user. ",b:true},"Every non-Superadmin user belongs to exactly one permission group; change the group to change access."],
 [{t:"Most-permissive wins. ",b:true},"Effective access is the union of the group’s grants — adding a grant never reduces access."],
 [{t:"Empty list denies; backend enforces. ",b:true},"An empty resource list (queues, skills, BU/SG) denies all of that type; every limit is enforced in the application, not just the UI."]
]));
body.push(H1("4. Scenario walk-throughs"));
body.push(H2("Scenario A — read-only sales supervisors"));
body.push(P("Goal: supervisors view (not edit) the sales dashboards and see only sales queues. Design: a group with the Dashboards menu visible; View only on the sales dashboards; the sales queues added on the Queues tab (nothing else); the Sales business unit on BU/SG. Result: read-only sales visibility, backend-enforced."));
body.push(H2("Scenario B — regional editors"));
body.push(P("Goal: a regional team builds and edits its own dashboards but must not see other regions’ data. Design: Editor-role users in a group with Edit on the region’s dashboards (creators get Full automatically), and only that region’s queues and business unit assigned."));
body.push(H2("Scenario C — the empty-list trap"));
body.push(P("Symptom: a brand-new group’s users see no queue data at all. Cause: the Queues tab is empty — which denies all, not allows all. Fix: add the specific queues the group should see."));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("5. Lab exercises"));
body.push(H2("Exercise 1 — build the sales supervisors group"));
body.push(...nums(["Create a group “Sales Supervisors”, active.","Screens tab: tick View only on two sales dashboards.","Queues tab: add two sales queues; add nothing else.","Assign a test Viewer user and sign in as them."]));
body.push(P([{t:"Expected: ",b:true,c:"1F6F3C"},"the user sees only the two sales dashboards (read-only) and only the two sales queues."]));
body.push(H2("Exercise 2 — prove the empty-list rule"));
body.push(...nums(["Create a group “Empty Test” with the Dashboards menu visible but no queues added.","Assign a test user and sign in.","Observe the queue data; then add one queue and refresh."]));
body.push(P([{t:"Expected: ",b:true,c:"1F6F3C"},"with an empty Queues tab the user sees no queues; after adding one, only that queue appears."]));
body.push(H2("Exercise 3 — deletion guardrail"));
body.push(...nums(["Try to delete a group that still has a user assigned.","Note the result; then move the user to another group and retry."]));
body.push(P([{t:"Expected: ",b:true,c:"1F6F3C"},"deletion is blocked while a user is assigned; it succeeds only after the last user is moved."]));
body.push(H2("Exercise 4 — concurrency"));
body.push(...nums(["Open the same group in two browser sessions.","Save a change in the first; then save a different change in the second."]));
body.push(P([{t:"Expected: ",b:true,c:"1F6F3C"},"the second save is rejected with “Record modified by another user”; reload and reapply."]));
body.push(H1("6. Common pitfalls"));
body.push(...bullets(["Assuming an empty resource list means “all” — it means “none”.","Designing users before groups — create the groups first, then assign.","Relying on a hidden menu for security — the backend check is what protects data.","Forgetting that a dashboard’s creator group gets Full automatically."]));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Answer key & facilitator notes"));
body.push(tbl(["Exercise","Expected outcome"],[
 ["1 — Sales Supervisors","Sees only the 2 sales dashboards (read-only) and 2 sales queues"],
 ["2 — Empty-list rule","No queues with empty tab; only the added queue appears after"],
 ["3 — Deletion guardrail","Blocked while a user is assigned; succeeds after reassignment"],
 ["4 — Concurrency","Second save rejected — “Record modified by another user”"]
],[3200,6160],{zebra:true}));
body.push(P([{t:"Facilitator tip: ",b:true,i:true},{t:"run Exercise 2 first if time is short — the empty-list rule is the single most common misconfiguration.",i:true}]));
