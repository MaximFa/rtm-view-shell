# CC Task — FIX quote-doubling corruption in rtm-metrics-expert.md (from 7af14c1)

> docs: corrective commit. Commit 7af14c1 ("metric lifecycle") landed with a SQL-escape artifact: every single
> quote in the WHOLE skill file was doubled `'` -> `''` (26 instances; e.g. `BU's`->`BU''s`, `'BREAK'`->`''BREAK''`,
> SQL examples `'%[<Id>]%'`->`''%[<Id>]%''`). Verified from the object store: 7af14c1 has 26 `''`, parent 72bd997 has 0,
> and the clean lifecycle section (95a48c4) has 0 — so ALL 26 `''` are corruption. Structure is otherwise intact
> (484 lines, 27 headings, the RTSGrid_Cell.Value lifecycle refinement IS present). Issued by metrics-3-0609. No push.

## 0. §0.6a integrity FIRST. §40 reads. §37 NO push. §0.3 Python+fsync (Edit BANNED). Touch ONLY the skill file.
## Sync slug metrics-3-0609. Claims: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
S1 marker barrier (block only on "FREEZE ACTIVE"); S2 coord_check_claims; S3 commit.lock; S4 cc_post_commit.sh.
NOTE: .claude/ is gitignored -> stage with `git add -f`.

## FIX — operate on the COMMITTED 7af14c1 content (the mount working copy may be truncated; restore from the blob first)
```bash
f=".claude/skills/rtm-metrics-expert/rtm-metrics-expert.md"
git show HEAD:"$f" > "$f"   # HEAD==7af14c1; get the authoritative 484-line content (not the truncated mount copy)
```
```python
# /tmp/metrics-3-0609_qfix.py
import os
f = ".claude/skills/rtm-metrics-expert/rtm-metrics-expert.md"
t = open(f, encoding="utf-8").read()
n = t.count("''")
assert n > 0, "no doubled quotes found — investigate, do not commit"
t = t.replace("''", "'")
assert "''" not in t, "doubled quotes still present after fix"
with open(f, "w", encoding="utf-8") as out:
    out.write(t); out.flush(); os.fsync(out.fileno())
print(f"fixed {n} doubled-quote instances")
```
```bash
python3 /tmp/metrics-3-0609_qfix.py && sync
# VERIFY (object-store-grade content):
echo "dq remaining (MUST be 0): $(grep -o \"''\" "$f" | wc -l)"
echo "headings (expect 27): $(grep -c '^#' "$f")"
echo "lifecycle refinement present (expect 1): $(grep -c 'PRIMARY metric reference in vendor-shipped' "$f")"
echo "section header present: $(grep -c 'Metric Lifecycle — vendor product-constants' "$f")"
tail -3 "$f"   # proper close (docs/metrics-hot-reload-contract.md reference)
```
Sanity spot-check that real apostrophes are back: `grep -n "BU's\|Don't\|'BREAK'" "$f" | head`.

## Commit (under commit.lock; .claude/ -> git add -f)
```bash
bash tools/pre-commit-check.sh
git add -f .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
git commit -m "docs: fix quote-doubling corruption in rtm-metrics-expert (7af14c1 SQL-escape artifact; 26 '' -> ')"
```
§0.6 verify (git diff HEAD -- the file empty after commit; committed dq==0) -> `bash tools/cc_post_commit.sh metrics-3-0609 $(git log -1 --format=%h)` -> PD-007 re-sync (`git show HEAD:"$f" > "$f"; sync`). NO push.

## Report: dq before/after, commit hash. NO push.
