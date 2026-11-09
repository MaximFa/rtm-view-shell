# Expected git tree of a commit, computed from disk blobs without writing objects.
# Run from ~/mnt/RTM View Shell:  python3 <this> <add_paths.txt> <base-ref>
# add_paths.txt lines: "<path> <blob12>" or "<path> DELETE". TREE_CALC_REPO=v3 for the v3 tree.
import subprocess,hashlib,os,sys
import os
V=os.environ.get("TREE_CALC_REPO","v4")
if V=="v3":
    G=".git"; D=os.path.expanduser("~/mnt/RTM View Shell")
else:
    G=".git/worktrees/RTM-design"; D=os.path.expanduser("~/mnt/RTM-design")
add=[l.split()[0] for l in open(sys.argv[1]) if l.strip()]
def ls(t):
    out=subprocess.run(["git","--git-dir="+G,"ls-tree","-z",t],capture_output=True).stdout; r={}
    for e in out.split(b"\0"):
        if not e: continue
        meta,name=e.split(b"\t",1); mode,typ,h=meta.split(b" "); r[name]=[mode.lstrip(b"0"),typ,h.decode()]
    return r
def th(ents):
    key=lambda n:n+(b"/" if ents[n][1]==b"tree" else b"")
    body=b"".join(ents[n][0]+b" "+n+b"\0"+bytes.fromhex(ents[n][2]) for n in sorted(ents,key=key))
    return hashlib.sha1(b"tree %d\0"%len(body)+body).hexdigest()
def blob(p):
    if not os.path.exists(os.path.join(D,p)): return None
    return subprocess.run(["git","hash-object","--stdin"],stdin=open(os.path.join(D,p),"rb"),capture_output=True,cwd="/").stdout.decode().strip()
def build(t,ops):
    ents=ls(t) if t else {}; sub={}
    for parts,h in ops:
        if len(parts)==1:
            if h is None: ents.pop(parts[0])
            else: ents[parts[0]]=[b"100644",b"blob",h]
        else: sub.setdefault(parts[0],[]).append((parts[1:],h))
    for d,fs in sub.items(): ents[d]=[b"40000",b"tree",build(ents[d][2] if d in ents else None,fs)]
    return th(ents)
root=subprocess.run(["git","--git-dir="+G,"rev-parse",sys.argv[2]+"^{tree}"],capture_output=True).stdout.decode().strip()
print("self-check:",th(ls(root))==root); print("expected tree:",build(root,[([x.encode() for x in p.split("/")],blob(p)) for p in add]))
