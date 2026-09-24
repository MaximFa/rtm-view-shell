/* =========================================================================
   RTM wallboard — reusable live engine
   Inline this in the page, then add the screen-specific model + renderers.
   Expects from the page:
     - RTM.model   {Q:[queues], A:[agents], KPI:{}}  set before RTM.start()
     - RTM.render  function() re-rendering every widget from the model
     - element ids: clock, lastupd, u1, u2, u3 (timestamps); ncall (flash label)
   ========================================================================= */
window.RTM = (function () {

  /* ---------- static mode: frozen frame for PNG export ---------- */
  const STATIC = location.search.indexOf('static') > -1;
  if (STATIC) document.addEventListener('DOMContentLoaded',
    () => document.body.classList.add('static'));

  /* ---------- formatting ---------- */
  const two  = n => String(n).padStart(2, '0');
  const mmss = s => two(Math.floor(s / 60)) + ':' + two(Math.round(s) % 60);
  const hms  = s => two(Math.floor(s / 3600)) + ':' +
                    two(Math.floor(s % 3600 / 60)) + ':' + two(Math.round(s) % 60);
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

  /* ---------- threshold classifiers: the whole colour system ---------- */
  const cls   = (v, ok, warn) => v <= ok ? 'ok' : (v <= warn ? 'warn' : 'bad'); // lower better
  const clsUp = (v, ok, warn) => v >= ok ? 'ok' : (v >= warn ? 'warn' : 'bad'); // higher better

  /* ---------- flash ---------- */
  function flash(el, kind) {
    if (!el) return;
    el.classList.remove('fl', 'flb', 'flo');
    void el.offsetWidth;                       // force reflow so it re-runs
    el.classList.add(kind || 'fl');
  }

  /* ---------- weighted aggregates ---------- */
  function weighted(rows, field, weight) {
    const w = rows.reduce((s, r) => s + r[weight], 0) || 1;
    return rows.reduce((s, r) => s + r[field] * r[weight], 0) / w;
  }

  /* ---------- donut ---------- */
  function donut(svgEl, slices) {           // slices: [[label, count, colour], …]
    const total = slices.reduce((s, x) => s + x[1], 0) || 1;
    svgEl.innerHTML =
      '<circle cx="21" cy="21" r="15.915" fill="none" stroke="#f1f4f8" stroke-width="5.2"></circle>';
    let off = 25;
    slices.forEach(x => {
      const pct = x[1] / total * 100;
      const c = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      c.setAttribute('cx', 21); c.setAttribute('cy', 21); c.setAttribute('r', 15.915);
      c.setAttribute('fill', 'none'); c.setAttribute('stroke', x[2]);
      c.setAttribute('stroke-width', 5.2);
      c.setAttribute('stroke-dasharray', pct.toFixed(2) + ' ' + (100 - pct).toFixed(2));
      c.setAttribute('stroke-dashoffset', off.toFixed(2));
      svgEl.appendChild(c);
      off -= pct;
    });
    return total;
  }

  /* ---------- agent state machine ---------- */
  const TRANSITIONS = {
    call:  [['acw', 0.55]],
    acw:   [['call', 0.75], ['idle', 1.0]],
    idle:  [['call', 0.70]],
    break: [['idle', 1.0]]                     // only once relief phase starts
  };

  function advanceAgent(a, i, step, k, onPickup) {
    a.ss++; a.log++;
    if      (a.s === 'call')  a.talk++;
    else if (a.s === 'acw')   a.acw++;
    else if (a.s === 'break') a.br++;
    else                      a.idle++;

    if ((step + i * 3) % 11 !== 0) return;     // staggered, so agents don't move in lockstep
    if (a.s === 'break' && k <= 8) return;     // agents return from break in the relief phase
    if (a.s === 'train' || a.s === 'na') return;

    const roll = Math.random();
    const opts = TRANSITIONS[a.s] || [];
    for (const [next, p] of opts) {
      if (roll < p) {
        a.s = next; a.ss = 0;
        if (next === 'call' && onPickup) onPickup(a);
        return;
      }
    }
  }

  /* ---------- queue dynamics ---------- */
  function advanceQueue(q, k, isStory, waitPerContact) {
    const drift    = k < 7 ? 1.0 : (k < 16 ? -1.0 : -0.25);
    const arrivals = Math.random() < (q.load * 1.5) ? 1 : 0;
    const handled  = Math.random() < (q.load * 1.3 + (k >= 7 ? 0.42 : 0)) ? 1 : 0;
    const push     = Math.random() < Math.abs(drift) / 3
                     ? Math.sign(drift) * (isStory ? 2 : 1) : 0;

    q.w   = Math.max(0, q.w + arrivals - handled + push);
    q.fw  = Math.max(0, Math.round(q.fw + (q.w * (waitPerContact || 11.5) - q.fw) * 0.28));
    q.asa = Math.max(4, Math.round(q.asa + (q.w > 4 ? 0.9 : -0.7)));
    q.sla = +clamp(q.sla + (q.w > 4 ? -0.6 : 0.55), 55, 99.6).toFixed(1);
    if (arrivals) { q.tot++; (Math.random() < 0.975 || q.w < 5) ? q.ans++ : q.aban++; }
    return arrivals;
  }

  /* ---------- rolling chart window ---------- */
  function rollChart(CH, step, stamp) {
    const last = CH.t.length - 1;
    if (step % 5 !== 0) return last;
    CH.t.push(stamp); CH.t.shift();
    ['inc', 'ans', 'abn', 'sla'].forEach(z => { CH[z].push(CH[z][CH[z].length - 1]); CH[z].shift(); });
    return last;
  }

  /* ---------- scenario clock ---------- */
  let step = 0, t = null, timer = null;

  function start(startTime, tickFn) {
    t = startTime instanceof Date ? startTime : new Date(startTime);
    stamp();
    if (STATIC) return;                        // frozen frame: render once, never tick
    timer = setInterval(() => {
      step++;
      t = new Date(t.getTime() + 1000);
      stamp();
      tickFn(step, step % 20, t);              // (step, k, now)
    }, 1000);
  }

  function stamp() {
    const s = `${two(t.getHours())}:${two(t.getMinutes())}:${two(t.getSeconds())}`;
    const c = document.getElementById('clock'); if (c) c.textContent = s;
    ['lastupd', 'u1', 'u2', 'u3'].forEach(id => {
      const el = document.getElementById(id); if (el) el.textContent = s;
    });
    return s;
  }

  /* ---------- fit the fixed 1920×1080 shell to the viewport ---------- */
  function fit() {
    const sh = document.querySelector('.shell'); if (!sh) return;
    const k = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
    sh.style.zoom = k < 1 ? k : 1;
  }
  window.addEventListener('resize', fit);
  window.addEventListener('DOMContentLoaded', fit);

  return { STATIC, two, mmss, hms, clamp, cls, clsUp, flash, weighted, donut,
           advanceAgent, advanceQueue, rollChart, start, stamp, fit,
           get step() { return step; }, get now() { return t; } };
})();
