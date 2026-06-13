#!/usr/bin/env python3
"""Inbox auto-archival v2 (NORM-CUR-06). Keep header + last N blocks + any block within last D hours.
Archive everything older to inbox/archive/<role>.md (append-only). Never deletes content (archive is durable)."""
import os, sys, re, datetime
NOW = datetime.datetime.now(datetime.timezone.utc)

def block_ts(seg):
    m = re.match(r'## (\d{4}-\d{2}-\d{2}T\d{2}:\d{2})', seg)
    if not m: return None
    try: return datetime.datetime.fromisoformat(m.group(1)).replace(tzinfo=datetime.timezone.utc)
    except: return None

def archive(inbox_path, keep_last=25, keep_hours=24, dry=False):
    text = open(inbox_path, encoding="utf-8").read()
    idx = [m.start() for m in re.finditer(r'(?m)^## ', text)]
    if not idx: return (0,0,0)
    header = text[:idx[0]]
    blocks = [text[idx[i]:(idx[i+1] if i+1<len(idx) else len(text))] for i in range(len(idx))]
    n = len(blocks); keep_tail = set(range(max(0,n-keep_last), n))
    cutoff = NOW - datetime.timedelta(hours=keep_hours)
    keep, arch = [], []
    for i,b in enumerate(blocks):
        ts = block_ts(b)
        recent = ts is not None and ts >= cutoff
        if i in keep_tail or recent: keep.append(b)
        else: arch.append(b)
    if not arch: return (n, len(keep), 0)
    role = os.path.splitext(os.path.basename(inbox_path))[0]
    adir = os.path.join(os.path.dirname(inbox_path), "archive"); os.makedirs(adir, exist_ok=True)
    apath = os.path.join(adir, role + ".md")
    if dry: return (n, len(keep), len(arch))
    with open(apath,"a",encoding="utf-8") as f:
        if os.path.getsize(apath)==0: f.write(f"# archive: {role} (auto-archived, NORM-CUR-06). Append-only.\n\n")
        f.write("".join(arch)); f.flush(); os.fsync(f.fileno())
    with open(inbox_path,"w",encoding="utf-8") as f:
        f.write(header+"".join(keep)); f.flush(); os.fsync(f.fileno())
    return (n, len(keep), len(arch))

if __name__=="__main__":
    path=sys.argv[1]; keep=int(sys.argv[2]) if len(sys.argv)>2 else 25
    hrs=int(sys.argv[3]) if len(sys.argv)>3 else 24
    n,k,a=archive(path,keep,hrs,"--dry" in sys.argv)
    print(f"{os.path.basename(path)}: blocks={n} kept={k} archived={a}")
