#!/usr/bin/env python3
"""
search_broll.py — search free stock-video sources for ad B-roll.

Queries the Pexels and Pixabay video APIs (free, commercial-use licensed) and
returns a normalized, numbered list of candidate clips. Designed for vertical
9:16 ad footage by default.

API keys are read from the environment:
    PEXELS_API_KEY   (https://www.pexels.com/api/)
    PIXABAY_API_KEY  (https://pixabay.com/api/docs/)
If a key is missing, that source is skipped (a note is printed to stderr).

Usage:
    python3 search_broll.py --query "woman applying face cream" \
        --query "skincare closeup" --orientation portrait \
        --per-source 6 --out broll_candidates.json
"""
import argparse, json, os, sys, urllib.parse, urllib.request

UA = "DS-B-ROLLS/1.0"


def _get(url, headers=None, timeout=30):
    req = urllib.request.Request(url, headers=headers or {})
    req.add_header("User-Agent", UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def orient(w, h):
    if h > w:
        return "portrait"
    if w > h:
        return "landscape"
    return "square"


def search_pexels(query, orientation, per_source):
    key = os.environ.get("PEXELS_API_KEY")
    if not key:
        print("[skip] PEXELS_API_KEY not set", file=sys.stderr)
        return []
    params = {"query": query, "per_page": per_source, "size": "medium"}
    if orientation in ("portrait", "landscape", "square"):
        params["orientation"] = orientation
    url = "https://api.pexels.com/videos/search?" + urllib.parse.urlencode(params)
    try:
        data = _get(url, headers={"Authorization": key})
    except Exception as e:
        print(f"[pexels error] {e}", file=sys.stderr)
        return []
    out = []
    for v in data.get("videos", []):
        files = sorted(
            [f for f in v.get("video_files", []) if f.get("link")],
            key=lambda f: (f.get("height") or 0),
        )
        # pick the best file <= 1920 tall, else the smallest available
        pick = None
        for f in files:
            if (f.get("height") or 0) <= 1920:
                pick = f
        pick = pick or (files[-1] if files else None)
        if not pick:
            continue
        pics = v.get("video_pictures") or []
        thumb = v.get("image") or (pics[0].get("picture") if pics else "")
        w, h = pick.get("width") or v.get("width"), pick.get("height") or v.get("height")
        out.append({
            "source": "Pexels",
            "description": (v.get("user", {}) or {}).get("name", "") and
                           f"by {v['user']['name']}" or "Pexels clip",
            "tags": query,
            "duration": v.get("duration"),
            "width": w, "height": h,
            "orientation": orient(w or 0, h or 0),
            "preview": thumb,
            "page": v.get("url", ""),
            "download_url": pick["link"],
            "license": "Pexels License — free for commercial use, no attribution required",
        })
    return out


def search_pixabay(query, orientation, per_source):
    key = os.environ.get("PIXABAY_API_KEY")
    if not key:
        print("[skip] PIXABAY_API_KEY not set", file=sys.stderr)
        return []
    params = {"key": key, "q": query, "per_page": max(3, per_source),
              "safesearch": "true", "video_type": "all"}
    url = "https://pixabay.com/api/videos/?" + urllib.parse.urlencode(params)
    try:
        data = _get(url)
    except Exception as e:
        print(f"[pixabay error] {e}", file=sys.stderr)
        return []
    out = []
    for v in data.get("hits", []):
        vids = v.get("videos", {})
        # prefer large, then medium, small, tiny
        pick = None
        for q in ("large", "medium", "small", "tiny"):
            f = vids.get(q)
            if f and f.get("url"):
                pick = f
                break
        if not pick:
            continue
        w, h = pick.get("width"), pick.get("height")
        thumb = pick.get("thumbnail") or ""
        out.append({
            "source": "Pixabay",
            "description": (v.get("tags") or query),
            "tags": v.get("tags") or query,
            "duration": v.get("duration"),
            "width": w, "height": h,
            "orientation": orient(w or 0, h or 0),
            "preview": thumb,
            "page": v.get("pageURL", ""),
            "download_url": pick["url"],
            "license": "Pixabay Content License — free for commercial use, no attribution required",
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", action="append", required=True,
                    help="search phrase (repeatable)")
    ap.add_argument("--orientation", default="portrait",
                    choices=["portrait", "landscape", "square", "any"])
    ap.add_argument("--per-source", type=int, default=6)
    ap.add_argument("--min-duration", type=int, default=0)
    ap.add_argument("--max-duration", type=int, default=0)
    ap.add_argument("--out", default="broll_candidates.json")
    args = ap.parse_args()

    o = None if args.orientation == "any" else args.orientation
    results = []
    seen = set()
    for q in args.query:
        for fn in (search_pexels, search_pixabay):
            for item in fn(q, o, args.per_source):
                key = item["download_url"]
                if key in seen:
                    continue
                if o and item["orientation"] != o:
                    continue
                d = item.get("duration") or 0
                if args.min_duration and d and d < args.min_duration:
                    continue
                if args.max_duration and d and d > args.max_duration:
                    continue
                item["query"] = q
                seen.add(key)
                results.append(item)

    for i, item in enumerate(results, 1):
        item["index"] = i

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    # human-readable summary to stdout
    if not results:
        print("No clips found. Check API keys (PEXELS_API_KEY / PIXABAY_API_KEY) "
              "or try different / broader queries.")
        return
    print(f"Found {len(results)} candidate clip(s) -> {args.out}\n")
    for item in results:
        dur = f"{item['duration']}s" if item.get("duration") else "?s"
        res = f"{item.get('width','?')}x{item.get('height','?')}"
        print(f"{item['index']}. [{item['source']}] {item['description']} "
              f"· {item['orientation']} · {dur} · {res}")
        print(f"   query: {item['query']}")
        print(f"   preview: {item.get('preview','')}")
        print(f"   page:    {item.get('page','')}\n")


if __name__ == "__main__":
    main()
