---
name: storydream-sprint
description: >
  StoryDream end-of-sprint workflow — automatically generates a sprint report,
  updates the Excel sprint tracker, and flags which project docs need syncing.
  ALWAYS trigger this skill when the user says anything like: "sprint done",
  "end of sprint", "sprint N finished", "generate sprint report", "sprint
  report", "закончили спринт", "отчёт по спринту", "обнови трекер спринта",
  "синхронизируй доки после спринта", or any phrase about wrapping up a
  StoryDream sprint. Also trigger if the user mentions updating the
  StoryDream sprint tracker or syncing docs after building something.
---

# storydream-sprint

End-of-sprint workflow for the **StoryDream** project. Three outputs every time:

1. **Sprint report** — Markdown file (+ Word if requested)
2. **Sprint Tracker** — Excel file updated with new sprint data and velocity chart
3. **Doc sync check** — table of project docs that may need updating

The goal is fast, low-friction sprint closure. Collect the minimum info upfront, produce polished outputs automatically, and let the documents speak for themselves.

---

## Project context

Key file locations (always read these before generating output):

| File | Purpose |
|---|---|
| `F:\EAIP\PLAN_StoryDream.md` | Sprint plan: all 8 sprints, tasks, SP, owners |
| `F:\EAIP\ТЗ_StoryDream.md` | Technical spec — check after API/data model changes |
| `F:\EAIP\sprint-reports\` | Output directory for sprint reports |
| `F:\EAIP\StoryDream_SprintTracker.xlsx` | Sprint tracker (create if missing) |

Read `PLAN_StoryDream.md` at the start to get planned tasks and SP for the sprint the user mentions. This avoids asking the user to repeat what's already documented.

---

## Step 1 — Collect sprint data

Ask the user for this information in **one message** (not multiple back-and-forth):

- Which sprint number just ended?
- Which tasks are done? (they can say "all" or list exceptions)
- Anything not completed — and why? (carried over, blocked, descoped)
- Any blockers, incidents, or notable events?
- Dates (or confirm the 2-week schedule from the plan is correct)
- Safety status: was SAFETY_BLOCK modified? Any ModerationIncidents this sprint?

If the user is terse (e.g., "sprint 2 done"), use the plan as the baseline and ask only for the delta: what was skipped and why. Don't make them repeat what's already in the plan.

---

## Step 2 — Generate the sprint report

Create `F:\EAIP\sprint-reports\Sprint{N}_Report.md` using the template in `references/sprint_report_template.md`.

Fill in all sections from the data collected. Calculate:
- **Velocity %** = completed SP / planned SP × 100
- **Cumulative SP** = sum of all completed SP across sprints 1–N
- **Remaining SP** = 354 − cumulative SP (354 is total from the plan)
- **Projected completion** = remaining SP / (cumulative SP / N) sprints from now

**Safety Pipeline Status** is mandatory every sprint — it reflects the project's highest priority. Even if no safety work happened, confirm that:
- `SAFETY_BLOCK` constant in `constants.ts` was not modified
- No `ModerationIncident` records were generated this sprint
- Fallback stories count is still ≥ 20

If the user wants a Word document too, read the docx SKILL.md and generate `Sprint{N}_Report.docx` in the same directory.

---

## Step 3 — Update the Sprint Tracker (Excel)

Check if `F:\EAIP\StoryDream_SprintTracker.xlsx` exists:
- **Doesn't exist** → create it from scratch with all three sheets below
- **Exists** → update the Overview sheet and add/update the sprint detail sheet

Read the xlsx SKILL.md before writing the file.

### Sheet: "Overview"

Columns: Sprint | Dates | Goal | Planned SP | Completed SP | Velocity % | Cumulative SP | Status

One row per sprint. Keep a **Totals** row at the bottom.
- Freeze the header row
- Conditional formatting on Velocity %: green ≥ 90%, yellow 70–89%, red < 70%
- Auto-fit column widths

### Sheet: "Sprint N Detail"

Name the sheet `Sprint {N}`. Columns:
Task | Owner | Planned SP | Done (Y/N) | Actual SP | Notes

Pull planned tasks from `PLAN_StoryDream.md`. Fill in Done/Actual from user input. Include a summary block at the top (planned SP, completed SP, velocity %).

### Sheet: "Velocity"

A bar chart — **Planned SP** vs **Completed SP** per sprint, side by side.
- X-axis: Sprint numbers
- Y-axis: Story Points
- Add data labels on bars
- Update this sheet every sprint with the new data point

---

## Step 4 — Doc sync check

Based on what was built this sprint, flag which project documents likely need updating. Not a full audit — just obvious ones.

Map sprint tasks to documents:

| If this was built | This doc likely needs updating |
|---|---|
| API routes, data model, Prisma schema | ТЗ §7 Data model, §8 Integrations |
| Safety pipeline changes | ТЗ §5 — verify SAFETY_BLOCK description matches code |
| Scope changes, task carryover | PLAN_StoryDream.md — update sprint table |
| New UI screens or components | ТЗ §9 UI Specification |
| Auth, sessions, magic link | ТЗ §4.5 |
| Stripe integration | ТЗ §4.6 |
| Audio or image pipeline | ТЗ §4.3–4.4 |

Output a table:

| Document | Section | Reason | Priority |
|---|---|---|---|

If nothing touches documented areas, say so: "No doc updates needed this sprint."

If git is accessible (`git -C F:\EAIP log --since={sprint_start} --oneline` returns results), use the actual commit list to make the mapping more precise.

---

## Step 5 — Closing summary

End with a brief message (3–5 lines):
- Where sprint report was saved
- Sprint tracker updated
- Velocity this sprint and cumulative project velocity
- Projected finish date (sprints remaining × average sprint duration)
- Docs to action (if any)

---

## Edge cases

**Sprint 1 (first):** Create the `sprint-reports/` directory and the tracker from scratch. No cumulative history yet — just this sprint's data.

**Carryover tasks:** Note them in the carryover section. Also note the carryover in `PLAN_StoryDream.md` (add a note to the next sprint's task list — don't silently move it).

**Safety incident:** If any `ModerationIncident` occurred, add a dedicated subsection: layer triggered, count, review status, pattern observed. Flag ТЗ §5 for review at High priority.

**Scope change:** If tasks were added or removed vs. original plan, note the delta in SP and update the total (354 SP base) in the report.

**Sprint > 8:** Beyond the original roadmap — ask if this is an extension sprint and adjust projected completion accordingly.
