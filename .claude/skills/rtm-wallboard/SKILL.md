---
name: rtm-wallboard
description: Design and render real-time contact-center wallboard screens and individual dashboard widgets in the RTM house style - KPI tiles with threshold indicators, queue grids, agent grids, state donuts, threshold-band panels, WFM/Erlang panels, trend charts and tickers. Produces a self-contained live HTML page with a scripted 20-second demo loop for screen recording, plus a 4K PNG frame for slides. Use this skill whenever someone asks for a wallboard, real-time monitoring screen, contact-center dashboard, demo screen with synthetic data, a replica of an existing monitoring screen, or any single widget from that family (queue, agents, SLA tile, thresholds, trend). Also use it for "make the same screen", "draw a widget", "I need a dashboard image for the deck", "demo data for the presentation", or to add or modify a widget on a screen built with this skill. Prefer it over generic charting or HTML work whenever the output is an operations monitoring surface, even if the word wallboard is never said.
---

# RTM Wallboard

Build monitoring screens that look like a real product, not a mockup: dense, calm,
numerically consistent, and alive. Every screen produced with this skill has to
survive two hostile audiences — a contact-center manager who will spot a metric
that can't exist, and a prospect who will pause the video and read the numbers.

## Workflow

1. **Establish the brief.** Four things decide everything downstream, so pin them
   before writing code. If the user hasn't said, ask in one short round (buttons,
   not prose):
   - **Language and direction** — Hebrew RTL is the default house style; English
     LTR and Russian are supported. Direction changes chart axis order (below).
   - **Vertical** — drives queue names, agent names, channel names. Banking,
     telecom, retail, insurance, utilities.
   - **Screen type** — voice operations, digital channels + bots, supervisor view,
     executive summary, or a replica of a screen the user will show you.
   - **Output** — live HTML, PNG frame, or both (usually both).
2. **If replicating an existing screen**, read it first with whatever tool you
   have (browser, screenshot, pasted text). Inventory the widgets, the column
   list of every table, and the KPI labels *before* designing. Then state
   explicitly which differences from the original are deliberate. A replica that
   silently drops a column is a bug; a replica that improves a dead widget and
   says so is the deliverable.
3. **Design the dataset before the layout.** See `references/data-rules.md`. This
   is the step people skip and it is the one that makes the screen credible.
4. **Assemble the page** from `assets/shell.html` + `assets/wallboard.css` +
   `scripts/engine.js`, adding the per-widget render functions from
   `references/widgets.md`. The page must be one self-contained HTML file.
5. **Render the PNG** with `scripts/render_png.py` (it loads `?static=1`, which
   freezes the simulation on the designed opening frame).
6. **Look at the PNG.** Always. Then fix what you see — the pitfalls in
   `references/pitfalls.md` are all things that render "fine" in code review and
   obviously broken on screen.
7. **Deliver**: publish the HTML as a live artifact, present the PNG file, and
   summarize in a table what's in the screen and which numbers are deliberately
   in breach.

## The visual system

Light theme, near-white background, white cards with a 1px cool-grey border and
7px radius. Information density is the aesthetic: a real wallboard is full. Empty
space reads as "the product has no data", which is exactly the impression to avoid.

**Colour is semantic, never decorative.**

| Token | Hex | Meaning |
|---|---|---|
| `--ok` | `#0f9d58` | within target |
| `--warn` | `#c77700` | in the warning band |
| `--bad` | `#d32f2f` | breaching target |
| `--brand` | `#1b3a6b` | chrome: top bar, ticker label |
| `--brand2` | `#2f6fd0` | neutral data series, links, accents |
| `--muted` / `--faint` | `#7a869a` / `#9aa5b5` | labels, secondary text |

Never colour a number green just because it's good news in the abstract — colour
it because it sits inside a stated threshold band. Every coloured value must have
its target visible somewhere on the screen (in the tile subtitle, the column
header, or the thresholds panel).

**Typography.** One sans stack with real Hebrew fallbacks:
`'Heebo','Assistant','Arial Hebrew','Noto Sans Hebrew','DejaVu Sans',Arial`.
All numerals get `class="num"` for tabular figures and LTR isolation — a number
inside RTL text reverses without it.

**Canvas.** Fixed `1920×1080` shell, rendered at `device_scale_factor=2` for a
3840×2160 PNG. The page scales itself to the viewport with a `zoom` fit function
so the same file works on a laptop, a projector and a real wallboard TV.

**Height budget.** The shell is unforgiving; work it out before writing markup:

```
1080 = 52 (topbar) + 10 (pad) + KPI row + 10 + row2 + 10 + row3 + 10 + 38 (ticker) + 10 + 22 (footer)
```
So `KPI row + row2 + row3 = 918`. A typical split is `112 / 450 / 356`. Table rows
are ~28px at 12.6px font and ~33px at 13.8px — divide the panel's inner height
(panel height − 30 header − ~40 thead) by that to get how many rows actually fit,
then show exactly that many and label the table "showing N of M". Guessing here is
what produces a clipped totals row.

## Widgets

Full specs, data shapes and render functions: `references/widgets.md`.

| Widget | Use it for |
|---|---|
| KPI tile row | 7–8 headline metrics with `vs target` deltas. The screen's headline. |
| Queue grid | Per-queue or per-channel live state; the row that goes red is the story. |
| Agent grid | Per-agent detail; wide, dense, sortable by the metric that matters. |
| State donut | Where the workforce is right now. Small, left/start column. |
| Thresholds panel | The explicit green/amber/red bands with a marker on the current value. |
| WFM panel | Erlang-style staffing: arrivals, AHT, on hand, required, gap, recommendation. |
| Trend chart | Intraday volume vs SLA, inline SVG, rolling window. |
| Info ticker | Supervisor messages and alerts; carries the narrative in one line. |

Compose a screen as: KPI row across the top; then donut / wide grid / side stack;
then queue grid / trend chart; then ticker; then footer. Deviate when the brief
demands, but keep the wide dense grid as the optical centre.

## Making it alive

A static dashboard screenshot sells nothing. Everything built with this skill runs
a **scripted 20-second loop** so a single screen recording captures a complete
story: surge → response → recovery. Details and the reusable tick engine:
`references/engine.md` and `scripts/engine.js`.

The three-act shape, keyed off `step % 20`:

| Seconds | Act |
|---|---|
| 0–6 | Load rises. One queue swells, its row flashes red, max-wait climbs, SLA slips. |
| 7–15 | Response. Agents come off break, the queue drains, threshold markers slide back. |
| 16–19 | Recovery. Values return inside target, pills flip green, ready to loop. |

Under that arc, run continuous motion: the clock and the three "last updated"
stamps, per-agent state timers, agents changing state and picking up new
calls/conversations with new identifiers, cumulative counters, the donut
redrawing, the trend chart rolling left every 5 seconds, WFM recomputing, and the
ticker scrolling. Movement everywhere means any 20-second clip is usable.

`?static=1` freezes everything on frame zero — use it for the PNG so the still
shows the designed "problem" moment rather than a random tick.

## Numbers that hold up

Detail in `references/data-rules.md`. The short version:

- Totals reconcile. Queue volumes sum to the headline. Bot containment plus
  escalations equals bot intake. Per-agent state percentages sum to 100.
- Weighted averages are actually weighted by volume, not averaged across rows.
- Mix the verdicts. A screen where everything is green is a screensaver; a screen
  where everything is red is a fire drill. Aim for roughly: most green, one or two
  amber, exactly one red — and make that red the narrative.
- Let the interesting failure be a *distribution* failure: averages inside target
  while the tail breaches. That is precisely the argument for real-time monitoring
  over daily reports, and it makes the screen self-selling.
- Invented names are plausible and local to the vertical and language. Phone
  numbers, conversation IDs and ticket references follow the real format of the
  market.
- State it plainly in the footer when data is synthetic.

## Bundled files

| Path | Read it when |
|---|---|
| `assets/wallboard.css` | Always — inline it into the page. The whole visual system lives here. |
| `assets/shell.html` | Starting a new screen; it is the 1920×1080 skeleton with every panel slot. |
| `scripts/engine.js` | Always — inline it, then add the screen's model and renderers. |
| `scripts/render_png.py` | Exporting the PNG frame. |
| `scripts/check_motion.py` | Before delivering, to confirm the loop actually moves. |
| `references/widgets.md` | Building or modifying any widget — data shapes, render functions, threshold bands. |
| `references/data-rules.md` | Designing the dataset, which is step 3 and the one that decides credibility. |
| `references/engine.md` | Tuning the scenario arc or the agent/queue dynamics. |
| `references/pitfalls.md` | Before the first render, and again if something looks wrong on screen. |
| `examples/` | Two finished screens for the same fictional bank — concrete implementations of every widget. |

## Before delivering

Work through `references/pitfalls.md` — it is a list of failures actually
observed building these screens, each of which passed code review and failed on
screen. Then check:

- [ ] Rendered the PNG and *looked* at it
- [ ] No clipped row, footer, header label or wrapped panel note
- [ ] Every coloured value has a visible target
- [ ] Totals reconcile; weighted means recomputed
- [ ] Chart time axis runs in the reading direction of the language
- [ ] `?static=1` gives a clean still; the live page changes visibly within 20s
- [ ] Synthetic-data disclaimer present
