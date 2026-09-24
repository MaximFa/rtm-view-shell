# Pitfalls

Every item here is a failure that actually happened while building these screens.
All of them looked fine in the code and wrong on the rendered image. Reading this
file costs less than the render cycle it saves.

## `display:inline-block` on a table cell destroys the row

The worst one, and it hides well. A numeric helper class written as

```css
.num{font-variant-numeric:tabular-nums;direction:ltr;unicode-bidi:embed;display:inline-block}
```

applied directly to `<td class="num">` takes the cell out of the table formatting
context. Rows silently become three lines tall and cells scatter across them. The
markup is valid, no error appears, and the diagnosis is not obvious from the
screenshot.

Scope the display change to inline elements only:

```css
.num{font-variant-numeric:tabular-nums;font-feature-settings:"tnum";direction:ltr;unicode-bidi:isolate}
span.num,b.num{display:inline-block}
```

Symptom to watch for: `document.querySelector('tbody tr').offsetHeight` far larger
than the font size implies.

## Auto table layout dumps surplus width into the last column

With `table-layout:auto` and RTL cells, extra width lands in one column and the
table appears to end a third of the way across the panel, leaving a large blank
area. Use `table-layout:fixed` with an explicit `<colgroup>` whose widths sum to
100, and centre-align everything except the first column or two.

But then: fixed layout plus narrow columns makes content overflow, and headers
truncate to `משך ממ...`. Fix by shortening header words (`נכנסות` → `נכנ׳`,
`Wrap Up` → `Wrap`), allowing a two-line header with `<br>`, and setting the
header font 1–2px below the body font.

## Fonts up means rows out

Raising table font from 11.5px to 13.8px raises row height ~28px → ~33px. A panel
that fitted 15 rows now fits 11, and the extras vanish without any visual cue
that they were dropped. After any font change, recompute the row budget, re-slice
the array, and update the "showing N of M" label.

The same change pushes the queue grid's `<tfoot>` below the panel edge — the
totals row disappears entirely, and a totals row that silently isn't there is
worse than no totals row. Grow the row's flex basis to compensate.

## Live ticking before the screenshot

If the simulation is running when the PNG is taken, the frozen frame shows
whatever random state the tick loop reached — usually inconsistent with the
carefully designed opening figures. Implement `?static=1`, have the renderer load
it, and keep frame zero as the designed moment.

```js
const STATIC = location.search.indexOf('static') > -1;
if (STATIC) document.body.classList.add('static');
if (!STATIC) setInterval(tick,1000);
```

`body.static` also stops the ticker scroll and the pulsing LIVE dot.

## RTL charts read backwards

In an RTL screen, time must run right → left. Compute `X(i)` with the inversion
and keep index 0 as the oldest sample. Then when you add a rolling window, push
new samples at the **end** of the array and `shift()` the front — unshifting puts
"now" at the oldest position and the chart animates backwards in time.

## Derived values that stop being derived

Two versions of the same failure:

- A "connected agents" figure computed as `sum(queue agents) + 14` where the 14
  was a leftover constant — the tile read 55 while the donut read 41.
- SLA displayed as `answered / total` when SLA actually means *answered within
  120 seconds*. Every row turned green and the failing queue looked healthy.

Keep each metric as its own field with its own drift rule, and derive the footer
from the rows. If a tile and a table disagree, a viewer stops trusting the screen.

## Panel notes that clip

The WFM recommendation is the usual victim: it renders as three lines in a fixed
panel, and a slightly longer sentence spills invisibly below the border. Either
cap the panel generously or keep the sentence short — and check it in the PNG,
not in the markup.

## Narrow columns squeeze the donut

Shrinking a side column to give the wide grid more room pushes the donut panel
title onto two lines and crowds the legend. Shorten the title
(`התפלגות מצבי נציגים` → `מצבי נציגים`) and reduce the SVG size rather than
letting the header wrap.

## A scenario that drains to zero

Tuning the relief phase too aggressively empties every queue by second 14, and
the recording ends on a board with nothing on it — less impressive than a busy
board that is healthy. Tune so the recovery lands at "busy and within target",
not "empty".

Related: max-wait must be a function of queue depth, not a counter that only
increments. `fw += (w * 11.5 - fw) * 0.28` tracks the queue and recovers with it;
an incrementing counter climbs forever and never tells the recovery half of the
story.

## Publishing environment

A published artifact page can load scripts only from a short allowlist and cannot
call the Claude API or use the artifact storage helpers. These wallboards need
none of that — keep every widget hand-rolled SVG and inline CSS/JS in one file,
and the same file works as a local file, a published artifact, and a render
target for the PNG script.
