# Widget catalogue

Contents: [Shared helpers](#shared-helpers) · [KPI tile row](#kpi-tile-row) ·
[Queue grid](#queue-grid) · [Agent grid](#agent-grid) · [State donut](#state-donut) ·
[Agent score](#agent-score) ·
[Thresholds panel](#thresholds-panel) · [WFM panel](#wfm-panel) ·
[Trend chart](#trend-chart) · [Info ticker](#info-ticker) · [Panel chrome](#panel-chrome)

Every widget is a `.panel` with a `.phead` header and a `.pbody`, except the KPI
row which is bare tiles. All markup below assumes `assets/wallboard.css` is
inlined in the page.

## Shared helpers

Put these once, above the render functions:

```js
const two=n=>String(n).padStart(2,'0');
const mmss=s=>two(Math.floor(s/60))+':'+two(Math.round(s)%60);
const hms=s=>two(Math.floor(s/3600))+':'+two(Math.floor(s%3600/60))+':'+two(Math.round(s)%60);
const cls  =(v,ok,warn)=>v<=ok?'ok':(v<=warn?'warn':'bad');   // lower is better
const clsUp=(v,ok,warn)=>v>=ok?'ok':(v>=warn?'warn':'bad');   // higher is better
const flash=(el,k)=>{if(!el)return;el.classList.remove('fl','flb','flo');void el.offsetWidth;el.classList.add(k||'fl');};
```

`cls` / `clsUp` are the whole colour system. If a value is being coloured by
anything other than one of these two functions, the threshold isn't explicit
enough — fix the data model, not the CSS.

## KPI tile row

7–8 tiles across the top. Grid of equal columns, fixed height ~112px. Each tile:
label (14.5px, semibold), value (32px), subtitle carrying the target.

```html
<div class="kpirow" id="kpirow"></div>
```

```js
function renderKPI(){
  const tiles=[
    // [label, value, state('' | 'ok' | 'warn' | 'bad'), subtitle html]
    ['אחוז מענה עד 120 שניות', KPI.sla.toFixed(1)+'%', clsUp(KPI.sla,90,80),
      `<span class="chip ${clsUp(KPI.sla,90,80)}">${KPI.sla>=90?'▲':'▼'} ${Math.abs(KPI.sla-90).toFixed(1)}%</span> מול יעד 90%`],
  ];
  document.getElementById('kpirow').innerHTML=tiles.map(x=>
    `<div class="kpi ${x[2]}"><div class="lbl">${x[0]}</div><div class="val num">${x[1]}</div>
     <div class="sub">${x[3]}</div></div>`).join('');
}
```

The tile state paints the 3px accent stripe and the value colour. Leave it `''`
for pure counters (volumes) that have no target — colouring everything destroys
the signal. Roughly half the tiles should be neutral.

Grid column count must match the tile count: `.kpirow{grid-template-columns:repeat(8,1fr)}`.
Labels longer than ~22 Hebrew characters wrap at 14.5px in an 8-column row —
shorten the label rather than shrinking the font.

## Queue grid

The screen's narrative engine. One row per queue or channel.

Columns: name (+ latin subtitle) · waiting now · longest wait · ASA · abandon % ·
answered within target % · total · answered · abandoned · agents. Footer row with
weighted totals.

```js
{n:'אשראי והלוואות', c:'Credit & Loans', w:11, fw:127, asa:72, sla:68.4,
 tot:164, ans:151, aban:13, ag:6, load:.16}
```

`w` waiting, `fw` longest wait in seconds, `asa` seconds, `sla` percent,
`load` is the queue's share of arrivals, used by the simulation.

Row class is derived, not hand-set: any `bad` cell makes the row `.alert` (red
wash), any `warn` cell makes it `.warnrow` (amber wash). That way the eye finds
the problem row before reading a single number, which is the entire point of a
wallboard.

Recompute the footer every tick:

```js
const wasa = Q.reduce((s,q)=>s+q.asa*q.tot,0)/tt;   // volume-weighted, not row-averaged
const wsla = Q.reduce((s,q)=>s+q.sla*q.tot,0)/tt;
```

For digital channels swap the header wording: ערוץ instead of תור, פניות instead
of שיחות.

## Agent grid

Wide, dense, the optical centre of the screen. 15–20 columns is normal and
correct — a supervisor's real tool looks like this.

Voice column set: name · state · time in state · call type · phone · avg handle ·
inbound · outbound · talk · break · ACW · wrap · idle · %talk · %break · %ACW ·
%idle · total login.

Digital column set: name · state · time in state · channel · conversation id ·
conversations · **time to first response** · **time between messages** · avg
handle · handling time · break · wrap-up · idle · %handling · %break · %wrap ·
%idle · total login.

Sort by the metric the screen is arguing about (talk time, handling time,
occupancy) so the table reads as a gradient from healthy to problematic. Say so
in the panel header: `ממוין לפי % בשיחה`.

Per-agent percentages must sum to exactly 100 — compute three and derive the
fourth:

```js
const tot=a.talk+a.br+a.acw+a.idle;
const pt=Math.round(a.talk/tot*100), pb=Math.round(a.br/tot*100),
      pa=Math.round(a.acw/tot*100), pi=100-pt-pb-pa;
```

Threshold-colour the columns a supervisor would act on. Useful bands:

| Column | ok | warn | bad |
|---|---|---|---|
| talk / handling time | ≥ 02:40:00 | ≥ 02:10:00 | below |
| % in conversation | ≥ 70% | ≥ 55% | below |
| % break | ≤ 10% | ≤ 15% | above |
| % wrap-up | ≤ 8% | ≤ 12% | above |
| % idle | ≤ 15% | ≤ 25% | above |
| time to first response | ≤ 00:30 | ≤ 01:00 | above |
| time between messages | ≤ 01:00 | ≤ 02:00 | above |

Show live identifiers (phone number, conversation id) only for agents actually in
a conversation; `—` otherwise. Nothing says "fake screenshot" like an idle agent
with an active call.

The table needs `table-layout:fixed` plus an explicit `<colgroup>` whose widths
sum to 100 — see `references/pitfalls.md` for why auto layout fails here.

## State donut

Narrow start-column panel: SVG donut from stroke-dasharray arcs, centre count,
legend with count and percentage per state.

```js
const DCOL={call:'#0f9d58',acw:'#2f6fd0',idle:'#7a869a',break:'#c77700',train:'#7b4bd1',na:'#d32f2f'};
```

Draw with one `<circle r="15.915">` per state in a `viewBox="0 0 42 42"` — the
radius makes the circumference exactly 100, so `stroke-dasharray` is
`pct 100-pct` and `stroke-dashoffset` walks backwards from 25.

Derive it from the agent array every tick, never from a static list. A donut that
doesn't move while the agent table does is an instant tell.

State vocabulary differs by screen type: voice uses בשיחה / ניירת, digital uses
בטיפול / סיכום.

## Agent score

A five-star rating rendered directly under the agent's name in the first column of
the agent grid — this is how the product itself shows it, so replicas must match.
Stars fill left-to-right in orange over a grey track, with the numeric score in
small threshold-coloured type beside them.

```css
.scorewrap{display:flex;align-items:center;gap:5px;margin-top:1px;line-height:1}
.stars{position:relative;display:inline-block;direction:ltr;font-size:10.5px;line-height:1;
  letter-spacing:.6px;color:#d7dee9;white-space:nowrap}
.stars .fill{position:absolute;left:0;top:0;overflow:hidden;white-space:nowrap;
  color:#f5a623;transition:width .5s ease}
.sc{font-size:9.5px;font-weight:700}
```

```js
function stars(v){
  return `<span class="stars">★★★★★<span class="fill" style="width:${(v/5*100).toFixed(1)}%">★★★★★</span></span>`;
}
```

The grey track and the orange overlay are the same five glyphs stacked; clipping
the overlay by percentage gives smooth fractional stars without images or icon
fonts. Force `direction:ltr` on the container so the fill starts at the first star
even inside an RTL page.

**Composition.** 60% speed, 40% discipline, mapped onto 1–5:

| Screen type | Speed half | Discipline half |
|---|---|---|
| Voice | average handle time, share of time in conversation | % on break, % idle beyond target |
| Digital | time to first response, time between messages | % on break, % idle beyond target |

```js
const clampS=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
function discScore(pb,pi){ return clampS(5-(pb-7)/2.2-Math.max(0,pi-15)/8, 1, 5); }
// digital speed half:
const speed=(clampS(5-(frt-15)/13,1,5)+clampS(5-(ibm-30)/25,1,5))/2;
const score=clampS(0.6*speed+0.4*discScore(pb,pi),1,5);
```

Put the breakdown in the cell's `title` so a live viewer can hover:
`ציון נציג 4.2 · מהירות 4.6 · משמעת 3.6`. Colour the numeric with
`clsUp(score,4,3)`.

**Sort the grid by score** and say so in the panel header. The stars then form a
visible gradient down the table, which is the entire reason a supervisor looks at
this column.

**Two things that bite.** The score line adds ~11px per row, so recompute the row
budget and re-slice the array — otherwise the last rows and the queue grid's
totals row silently disappear. And the score must actually move during the
scenario loop: drive the underlying quality metrics (first-response time, handle
time) from the load phase so the rating dips during the surge and the ranking
reshuffles. A rating that sits still while everything else moves reads as a
decorative graphic.

## Thresholds panel

The widget that makes the concept legible to someone who has never seen the
product: each metric as a green/amber/red band with a marker on the current value.

```js
{m:'זמן המתנה ממוצע (ASA)', v:'00:27', s:'ok',
 pos: 30,                      // marker position, % from the start edge
 g:'≤ 00:30', a:'00:30–01:00', r:'> 01:00',
 gp:50, ap:25}                 // band widths in %, red takes the remainder
```

Compute `pos` from the live value against the scale the bands imply, clamped to
4–96 so the marker never disappears off the edge. The marker has a CSS transition,
so it visibly slides during the scenario loop — that motion is the best
single demonstration of the whole idea.

Four rows fit comfortably; a fifth clips. Choose the four that match the screen's
argument (voice: ASA, abandon, answered-in-target, occupancy — digital: first
response, between messages, abandon, bot containment).

## WFM panel

Small four-cell grid — arrivals λ, AHT, on hand, required — plus a sentence with
the gap, the forecast and a recommendation.

Voice staffing: `required = round(λ / 8.2)` is a serviceable Erlang-C stand-in for
demo purposes and moves sensibly with load.
Digital with concurrency: `required = ceil(λ * AHT / 3600 / concurrency / 0.85)`.

Colour the required cell red when `on hand − required < 0`. The recommendation
line must change when the gap changes sign, otherwise the panel looks hard-coded.
Keep the sentence to three lines at 10px or it clips.

## Trend chart

Inline SVG, no library. Four series over eight points: volume, answered,
abandoned (left axis), SLA % (right axis, dashed). Rolling window — push a new
point and shift the oldest every 5 seconds.

**Axis direction follows the language.** In RTL, time runs right → left, so
`X(i) = L + pw - i*(pw/(n-1))` with index 0 as the oldest. In LTR, drop the
inversion. Getting this backwards makes every trend read as its own opposite.

Mark the newest point with a larger filled dot and a shaded "now" band. That, plus
the rolling shift, is what makes the chart read as streaming rather than static.

## Info ticker

Full-width strip: solid brand label on the start edge, scrolling messages after
it. Carries the narrative in plain language — one alert about the failing metric,
one supervisor instruction with a deadline, one restatement of the day's targets,
one positive note. Alert in red and bold, supervisor names and times in brand blue.

Under `body.static` the animation stops and the line renders from the start, so
the PNG shows the alert rather than a random mid-scroll fragment.

## Panel chrome

```html
<div class="panel">
  <div class="phead">
    <h3>Title</h3><span class="tag">LIVE</span><span class="upd num" id="u1">11:42:07</span>
  </div>
  <div class="pbody">…</div>
</div>
```

The `LIVE` tag and the per-panel timestamp are load-bearing: they are what tells a
viewer this is a real-time surface and not a report. Update every panel's stamp
on the same tick as the clock.
