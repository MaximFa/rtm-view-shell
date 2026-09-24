# The live engine

`scripts/engine.js` holds the reusable pieces: time formatting, threshold
classifiers, the flash helper, the agent state machine, the queue dynamics and the
scenario clock. Inline it in the page and add the screen-specific model and render
functions on top.

## Why scripted rather than random

Random jitter reads as noise — numbers wobble and nothing means anything. A
scripted arc means any 20-second capture contains a beginning, a middle and an
end, and the person watching can narrate over it without waiting for something to
happen. The loop repeats cleanly, so the recording can start anywhere.

```
k = step % 20

k 0–6    load rises        drift +1.0, one queue gets a ×2 multiplier
k 7–15   response          drift −1.0, extra handling probability +0.42
k 16–19  recovery          drift −0.25, values settle inside target
```

## Tick structure

One `setInterval(tick, 1000)`. Each tick, in order:

1. Advance the clock; write it to the header and every panel's timestamp.
2. Advance each agent: increment time-in-state and the counter for the current
   state; run the state machine; drift the per-agent quality metrics.
3. Advance each queue: arrivals, handled, scenario drift; recompute longest wait,
   ASA and SLA; increment cumulative counters.
4. Recompute derived KPIs (arrival rate, occupancy, required staffing).
5. Re-render every widget.
6. Update the chart's newest point; roll the window every 5 ticks.
7. Fire the flashes.

Re-rendering whole panels each second is fine at this scale and keeps the render
functions pure — one source of truth, no incremental-update drift.

## Agent state machine

Stagger transitions so agents don't move in lockstep:

```js
if ((step + i*3) % 11 === 0) { /* agent i may transition */ }
```

Transitions: `call → acw` (55%), `acw → call` (70–75%, else `idle`), `idle → call`
(70%), and `break → idle` once the relief phase starts. On entering a call,
increment the conversation counter and assign a fresh phone number or conversation
id — visible identifiers changing is a strong live signal for a viewer.

Agents on training or unavailable stay put; a board where literally everyone moves
looks as synthetic as one where nobody does.

## Queue dynamics

```js
const arrivals = Math.random() < (q.load * 1.5) ? 1 : 0;
const handled  = Math.random() < (q.load * 1.3 + (k >= 7 ? 0.42 : 0)) ? 1 : 0;
const push     = Math.random() < Math.abs(drift)/3 ? Math.sign(drift) * (isStoryQueue ? 2 : 1) : 0;
q.w  = Math.max(0, q.w + arrivals - handled + push);
q.fw = Math.max(0, Math.round(q.fw + (q.w * 11.5 - q.fw) * 0.28));   // longest wait tracks depth
q.asa = Math.max(4, Math.round(q.asa + (q.w > 4 ? 0.9 : -0.7)));
q.sla = clamp(q.sla + (q.w > 4 ? -0.6 : 0.55), 55, 99.6);
if (arrivals) { q.tot++; (Math.random() < 0.975 || q.w < 5) ? q.ans++ : q.aban++; }
```

Give the story queue a larger drift multiplier so the eye has one thing to follow.
The `11.5` in the longest-wait line is seconds of wait per waiting contact —
adjust it to land the peak just past the target you want breached.

## Flashes

```css
@keyframes flash    {0%{background:#fff6cc}100%{background:transparent}}
@keyframes flashbad {0%{background:#ffd9d9}100%{background:transparent}}
@keyframes flashok  {0%{background:#d5f5e3}100%{background:transparent}}
```

Flash the story row amber during the surge, green during the recovery, neutral
when calm. Re-trigger with the `void el.offsetWidth` reflow so the animation
restarts on an element that already has the class. Also pop a small
"new contact arrived" label above the queue panel every third second.

Keep flashes to one or two elements. A board where everything blinks is unreadable
and looks cheap.

## Verifying the loop

Don't trust the code — sample it. Load the page headless and read the key values
at 0, 7, 14 and 20 seconds; confirm the arc actually happens and the numbers stay
reconciled. `scripts/check_motion.py` does exactly this. A loop that looks right in
source and flatlines in practice is common, usually because a drift constant is
too small relative to the random term.

## Recording guidance for the user

Open the page full screen, let it run two or three seconds to warm up, then
capture 20–22 seconds from any point — the loop is seamless. Add `?static=1` for
a still frame.
