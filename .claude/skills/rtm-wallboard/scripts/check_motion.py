#!/usr/bin/env python3
"""Sample a live wallboard at 0/7/14/20s and print the values that should move.

A scenario loop that looks right in source and flatlines in practice is a common
failure — usually a drift constant too small next to the random term. This is the
cheap way to catch it.

    python3 check_motion.py board.html
    python3 check_motion.py board.html --probe "waiting=#tq" --probe "sla=#kpirow .val:nth-child(6)"
"""
import argparse, os, pathlib, json

os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")
from playwright.sync_api import sync_playwright  # noqa: E402

DEFAULT_PROBES = {
    "clock":   "#clock",
    "waiting": "#tq",
    "agent_1_state": "#agents tr:first-child td:nth-child(2)",
    "queue_1_wait":  "#queues tr:first-child td:nth-child(2)",
    "donut_total":   "#dtotal",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--probe", action="append", default=[],
                    help="name=cssSelector (repeatable); replaces the defaults")
    ap.add_argument("--at", default="0,7,14,20",
                    help="seconds at which to sample")
    a = ap.parse_args()

    probes = dict(p.split("=", 1) for p in a.probe) if a.probe else DEFAULT_PROBES
    js = ("() => { const o={}; " +
          " ".join(f'{{const e=document.querySelector({json.dumps(sel)});'
                   f'o[{json.dumps(name)}]=e?e.innerText.trim():null;}}'
                   for name, sel in probes.items()) +
          " return o; }")

    marks = [int(x) for x in a.at.split(",")]
    url = pathlib.Path(a.src).resolve().as_uri()
    prev, moved = None, set()
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={"width": 1920, "height": 1080})
        pg.goto(url); pg.wait_for_timeout(600)
        last = 0
        for m in marks:
            pg.wait_for_timeout(max(0, (m - last)) * 1000); last = m
            vals = pg.evaluate(js)
            print(f"t={m:>2}s  " + "  ".join(f"{k}={v}" for k, v in vals.items()))
            if prev:
                moved |= {k for k in vals if vals[k] != prev[k]}
            prev = vals
        b.close()

    still = [k for k in probes if k not in moved]
    print("\nmoved: " + (", ".join(sorted(moved)) or "nothing"))
    if still:
        print("NEVER CHANGED: " + ", ".join(still) +
              "  <- intended only if it is a genuine constant (headcount, targets);\n"
              "     otherwise the drift constant is too small next to the random term")


if __name__ == "__main__":
    main()
