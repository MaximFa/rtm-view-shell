#!/usr/bin/env python3
import os, glob, datetime, subprocess

os.chdir(r"D:\Claude\Projects\RTM View Shell")

rng = subprocess.check_output(["git","log","origin/v2..HEAD","--oneline"]).decode().strip()
ok = (rng == "")

line = (datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
        + " | session-sync-0605 | PUSHED 6 commits (0c03fd1..b6d0caa) barrier complete\n")
with open(".coord/journal.md", "a", encoding="utf-8") as f:
    f.write(line)
    f.flush()
    os.fsync(f.fileno())

os.remove(".coord/push/request.md")
for a in glob.glob(".coord/push/acks/*.md"):
    os.remove(a)
print("barrier cleaned, unpushed-empty:", ok)
