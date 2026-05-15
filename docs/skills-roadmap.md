# Skills Roadmap — RTM View Shell

Just-in-time activation of project skills. A skill is created or activated when its
**trigger** is reached, not preemptively.

A "skill" here is a `<skill-name>/SKILL.md` file with frontmatter and triggers, placed
under `<project>/<skill-name>/` and copied into `.claude/skills/<skill-name>/` when
ready to use (Cowork's `.claude/skills/` is write-protected — use the PowerShell
one-liner from `feedback_rtm_workflow` memory).

---

## Active skills (already created)

| Skill | Location | Active trigger met |
|---|---|---|
| program-architector | `<root>/program-architector/` | Clean Arch already in place |
| blazor-server-expert | `<root>/blazor-server-expert/` | Blazor Server is the UI framework |
| blazor-frontend-design | `<root>/blazor-frontend-design/` | Design system + RTL needed |
| ux-ui-expert | `<root>/ux-ui-expert/` | wireframes/en/ active |
| app-cyber-security-expert | `<root>/app-cyber-security-expert/` | Auth & permissions in scope |
| signalr-expert | `<root>/signalr-expert/` | SignalR circuit + force-logout |
| contact-center-expert | `<root>/contact-center-expert/` | Domain knowledge needed |
| contact-center-shift-manager | `<root>/contact-center-shift-manager/` | UX informed by manager flow |
| contact-center-manager | `<root>/contact-center-manager/` | KPI definitions |
| contact-center-director | `<root>/contact-center-director/` | Strategic context |
| contact-center-ceo | `<root>/contact-center-ceo/` | Executive context |
| technical-writer | `<root>/technical-writer/` | Doc updates |
| platform-presale | `<root>/platform-presale/` | Presale materials |

---

## Planned skills (with triggers)

| Skill | Trigger — create when ... | Reason |
|---|---|---|
| `efcore-postgres-rtm` | Before first non-trivial EF migration | xmin concurrency, soft-delete, AsNoTracking, UUIDv7, GQF patterns distilled from current code |
| `rtm-multi-tenancy-rules` | Before any new endpoint or hub that touches tenant data | Encode ARCH-01..10 as machine-checkable rules |
| `secure-coding-dotnet` | Before first PR with new auth / token handling code | Encode CODE-01..07, PWD-01..05, SEC-05 as checklist |
| `wireframe-to-blazor` | Before implementing screen 02 (User Management) | Distill pattern from screen 01 (Login) implementation |
| `audit-discipline` | Before first state-changing API endpoint outside login | Force audit-event coverage from day one |
| `widget-catalog-curator` | When CC-platform API hook becomes real (replace NoOp) | Govern widget catalogue additions/deactivations |
| `tdd-state-machine` | If test chaos appears (≥ 3 flaky tests in one sprint) | Borrow pattern from DevelopmentProcessExample |
| `release-checklist` | Before first staging deployment | Pre-merge + deployment gate |

---

## Skill creation pattern

1. Draft `<project>/<skill-name>/SKILL.md` with frontmatter:
   ```yaml
   ---
   name: <skill-name>
   invocation: user
   description: >
     <when to trigger — be specific so Claude Code auto-activates>
   ---
   ```
2. Provide PowerShell copy command to the user:
   ```powershell
   Copy-Item "<project>\<skill>" "<project>\.claude\skills\<skill>" -Recurse -Force
   ```
3. Move from "Planned" to "Active" table once user confirms the copy.

---

## Anti-pattern

Don't write skills preemptively. A skill written before its trigger is reached usually
documents abstract patterns rather than concrete project conventions — and the project's
conventions evolve, leaving the skill out of date.
