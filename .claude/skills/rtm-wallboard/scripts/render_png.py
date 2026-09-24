#!/usr/bin/env python3
"""Render a wallboard HTML file to a 3840x2160 PNG (1920x1080 @2x).

Loads the page with ?static=1 so the live simulation is frozen on the designed
opening frame rather than whatever tick the loop happened to reach.

    python3 render_png.py board.html board.png [--width 1920] [--height 1080] [--scale 2]
"""
import argparse, os, pathlib, sys

os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")
from playwright.sync_api import sync_playwright  # noqa: E402


def render(src, out, width, height, scale, settle_ms, live):
    src = pathlib.Path(src).resolve()
    if not src.exists():
        sys.exit(f"no such file: {src}")
    url = src.as_uri() + ("" if live else "?static=1")
    with sync_playwright() as p:
        browser = p.chromium.launch(
            args=["--force-color-profile=srgb", "--font-render-hinting=none"])
        page = browser.new_page(viewport={"width": width, "height": height},
                                device_scale_factor=scale)
        page.goto(url)
        page.wait_for_timeout(settle_ms)
        page.screenshot(path=out,
                        clip={"x": 0, "y": 0, "width": width, "height": height})
        browser.close()
    print(f"{out}  ({width*scale}x{height*scale})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("out")
    ap.add_argument("--width", type=int, default=1920)
    ap.add_argument("--height", type=int, default=1080)
    ap.add_argument("--scale", type=int, default=2)
    ap.add_argument("--settle", type=int, default=1200,
                    help="ms to wait for fonts and first render")
    ap.add_argument("--live", action="store_true",
                    help="do NOT freeze the simulation (rarely wanted)")
    a = ap.parse_args()
    render(a.src, a.out, a.width, a.height, a.scale, a.settle, a.live)
