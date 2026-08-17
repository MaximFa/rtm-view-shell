#!/usr/bin/env python3
"""
save_broll.py — download approved B-roll clips under user-chosen names.

Reads the candidates JSON produced by search_broll.py, downloads the picked
clips, sanitizes the chosen names to safe ASCII .mp4 filenames, avoids
overwriting, and appends a manifest row to broll_index.csv in the destination.

Usage:
    python3 save_broll.py --candidates broll_candidates.json \
        --pick 1 --name "cream_apply_hero" \
        --pick 2 --name "cream_closeup_drop" \
        --dest ./broll
"""
import argparse, csv, json, os, re, sys, unicodedata, urllib.request

UA = "DS-B-ROLLS/1.0"

# minimal Hebrew -> Latin transliteration so Hebrew names don't get dropped
HEB = {
    "א": "a", "ב": "b", "ג": "g", "ד": "d", "ה": "h", "ו": "v", "ז": "z",
    "ח": "ch", "ט": "t", "י": "y", "כ": "k", "ך": "k", "ל": "l", "מ": "m",
    "ם": "m", "נ": "n", "ן": "n", "ס": "s", "ע": "a", "פ": "p", "ף": "f",
    "צ": "tz", "ץ": "tz", "ק": "k", "ר": "r", "ש": "sh", "ת": "t",
}


def sanitize(name):
    name = name.strip()
    if name.lower().endswith(".mp4"):
        name = name[:-4]
    out = []
    for ch in name:
        if ch in HEB:
            out.append(HEB[ch])
        else:
            out.append(ch)
    name = "".join(out)
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    name = name.lower()
    name = re.sub(r"[^a-z0-9]+", "_", name).strip("_")
    return (name or "broll") + ".mp4"


def unique_path(dest, fname):
    path = os.path.join(dest, fname)
    if not os.path.exists(path):
        return path
    base, ext = os.path.splitext(fname)
    i = 2
    while os.path.exists(os.path.join(dest, f"{base}_{i}{ext}")):
        i += 1
    return os.path.join(dest, f"{base}_{i}{ext}")


def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        while True:
            chunk = r.read(65536)
            if not chunk:
                break
            f.write(chunk)
    return os.path.getsize(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--pick", action="append", type=int, required=True,
                    help="candidate index (repeatable), pair with --name")
    ap.add_argument("--name", action="append", required=True,
                    help="output name for the matching --pick (repeatable)")
    ap.add_argument("--dest", default="./broll")
    args = ap.parse_args()

    if len(args.pick) != len(args.name):
        sys.exit("Each --pick must be paired with one --name (counts differ).")

    with open(args.candidates, encoding="utf-8") as f:
        cands = json.load(f)
    by_index = {c.get("index"): c for c in cands}

    os.makedirs(args.dest, exist_ok=True)
    index_csv = os.path.join(args.dest, "broll_index.csv")
    new_file = not os.path.exists(index_csv)

    saved = []
    with open(index_csv, "a", newline="", encoding="utf-8") as cf:
        w = csv.writer(cf)
        if new_file:
            w.writerow(["filename", "description", "source", "orientation",
                        "duration_s", "resolution", "page_url", "license"])
        for idx, raw_name in zip(args.pick, args.name):
            c = by_index.get(idx)
            if not c:
                print(f"[skip] candidate {idx} not found", file=sys.stderr)
                continue
            fname = sanitize(raw_name)
            path = unique_path(args.dest, fname)
            try:
                size = download(c["download_url"], path)
            except Exception as e:
                print(f"[error] candidate {idx} ({fname}): {e}", file=sys.stderr)
                continue
            res = f"{c.get('width','?')}x{c.get('height','?')}"
            w.writerow([os.path.basename(path), c.get("description", ""),
                        c.get("source", ""), c.get("orientation", ""),
                        c.get("duration", ""), res, c.get("page", ""),
                        c.get("license", "")])
            saved.append((os.path.basename(path), size))
            print(f"saved: {os.path.basename(path)} "
                  f"({size/1_048_576:.1f} MB) <- candidate {idx} [{c.get('source')}]")

    if saved:
        print(f"\n{len(saved)} clip(s) saved to {args.dest}")
        print(f"manifest: {index_csv}")
    else:
        print("Nothing saved.")


if __name__ == "__main__":
    main()
