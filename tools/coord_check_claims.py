#!/usr/bin/env python3
"""coord_check_claims.py — claim conflict detector (CLAUDE.md §42.3, skill §9).

Usage:  python3 tools/coord_check_claims.py <my-slug> <path> [<path>...]
Exit 0: no conflicts. Exit 1: at least one path is claimed by another ACTIVE session
(details printed). Run this BEFORE writing a CC prompt (Cowork) and in sync block S2 (CC).
"""
import sys, re, glob

MODULE_PATHS = {
    "rtm":  ["RTM/"],
    "web":  ["src/", "tests/", "wireframes/"],
    "db":   ["db/"],
    "docs": ["docs/", "tools/", "testing/", ".claude/", "CLAUDE.md"],
}

def parse(fp):
    txt = open(fp, encoding="utf-8").read()
    m = re.search(r"^---\s*$(.*?)^---\s*$", txt, re.S | re.M)
    fm = m.group(1) if m else txt
    def field(name):
        mm = re.search(r"^" + name + r":\s*(.*)$", fm, re.M)
        return mm.group(1).strip() if mm else ""
    slug, status = field("slug"), field("status")
    modules = [w for w in re.findall(r"[\w-]+", field("modules")) if w in MODULE_PATHS]
    fi = field("files")
    if fi.startswith("["):
        files = [x.strip() for x in fi.strip("[]").split(",") if x.strip()]
    else:
        m2 = re.search(r"^files:\s*$\n((?:\s*-\s*.+\n?)*)", fm, re.M)
        files = re.findall(r"^\s*-\s*(.+?)\s*$", m2.group(1), re.M) if m2 else []
    return slug, status, modules, files

def covered(path, modules, files):
    p = path.strip().lstrip("./")
    for f in files:
        f = f.strip().lstrip("./")
        if p == f or p.startswith(f.rstrip("/") + "/"):
            return "file-claim: " + f
    for mod in modules:
        for prefix in MODULE_PATHS[mod]:
            if p == prefix.rstrip("/") or (prefix.endswith("/") and p.startswith(prefix)):
                return "module-claim: " + mod
    return None

def main():
    if len(sys.argv) < 3:
        print(__doc__); return 2
    me, paths = sys.argv[1], sys.argv[2:]
    conflicts = 0
    for fp in sorted(glob.glob(".coord/sessions/*.md")):
        slug, status, modules, files = parse(fp)
        if slug == me or status != "active":
            continue
        for p in paths:
            hit = covered(p, modules, files)
            if hit:
                print("CONFLICT: %s is held by %s (%s)" % (p, slug, hit))
                conflicts += 1
    if conflicts:
        print("=> %d conflict(s). Do NOT proceed - add a REQUEST line to .coord/queue.md (skill section 9)." % conflicts)
        return 1
    print("OK: no claim conflicts for %s (%d path(s) checked)" % (me, len(paths)))
    return 0

if __name__ == "__main__":
    sys.exit(main())
