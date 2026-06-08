# Cross-Cowork ownership - module map + seam-file owners
# Source of truth for cross-Cowork claims. Spec: docs/Two-Cowork-Coordination.ru.md
# Updated: 2026-06-08

## Cowork -> modules
- Cowork-A "Backend"  (branch v2-backend):  RTM Server, Metrics, DBA, Devops
- Cowork-B "Frontend" (branch v2-frontend): Shell, UX-UI, Widget, QA
- Security: shared release gate (mandatory ack before prod), exercised at L2 integration
- Release captain: Cowork-A
- Integration trunk: v2

## Module -> paths (claim guidance)
- rtm     -> A : RTM/
- metrics -> A : metric migrations/functions, docs/metrics-catalog*, MetricsPage/MetricWizard data
- dba     -> A : db/ (schema, functions, migrations, baseline, tools)
- devops  -> A : deploy/, tools/ build+release, db/tools/Compare-ToBaseline
- shell   -> B : src/CcDashboard.Web (admin/auth/infra), Program.cs
- ux-ui   -> B : wwwroot css/tokens, *.razor.css, App.razor styling
- widget  -> B : Components/Widgets, widget config UI
- qa      -> B : tests/

## Seam files - single owner
| File | Owner | Rule |
|---|---|---|
| CLAUDE.md | A (captain) | append-only sections; edit of existing section -> captain only |
| src/CcDashboard.Web/Program.cs | B | non-owner requests via cross-inbox |
| db/schema.sql, db/baseline.sql | A | regen only via A Export-All |
| src/.../RtsEntities.cs | A | |
| Components/Layout/NavMenu.razor | B | |
| wwwroot/css/tokens.css, wwwroot/app.css | B | |
| db/data/02_metrics.sql | A | |

## Notes
- A whole release stays in ONE Cowork. Server-234 upgrade = wholly A.
- daytrend epic: data path (RTM/DB/widget) in A; Shell-component touches = seam -> cross-request to B.
