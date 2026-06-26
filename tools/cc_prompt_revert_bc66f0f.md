# CC task — REVERT bc66f0f (T-FN apply-order change was not an improvement)
> §4-DRAFTED by coordinator-0612 2026-06-15T06:29Z. Owner: dba-0610. Executor: native CC, Windows. **NO push.**
> Reason: bc66f0f flipped Regen apply order + regenerated schema.sql, but verification showed it merely TRADED one set of
> missing functions for another (old: missing RTSData_GetInteractions; new: missing NGC_CreateBusinessUnit/Delete/Modify/GetSiteTable).
> Neither matches the real (45 GREEN) function set. Revert to the pushed-and-proven 7ae098a; re-diagnose T-FN properly (separate task).

## Mandatory read (§40) + integrity
- Read: session-coord skill (§0.2, §0.4).
- §0.2: `git status --short`; this revert drops a LOCAL UNPUSHED commit only.

## STEP 0 — preconditions (ABORT if any fail)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD            # MUST be v2-backend
git rev-parse --short HEAD                 # MUST be bc66f0f (the commit to drop)
git rev-list --count origin/v2-backend..HEAD   # MUST be 1 (bc66f0f is the only unpushed commit)
git rev-parse --short HEAD~1               # MUST be 7ae098a (== origin/v2-backend)
git rev-parse --short origin/v2-backend    # MUST be 7ae098a
```
If HEAD != bc66f0f, or count != 1, or HEAD~1 != 7ae098a != origin -> STOP, report. Do NOT reset.

## STEP 1 — revert (drop the unpushed commit, restore tree to 7ae098a)
```bash
git reset --hard HEAD~1
git rev-parse --short HEAD                  # MUST now be 7ae098a
git rev-list --count origin/v2-backend..HEAD   # MUST be 0 (in sync with origin)
```

## STEP 2 — verify tree == pushed 7ae098a
```bash
git rev-parse HEAD ; git rev-parse origin/v2-backend     # MUST be equal
# schema.sql + Regen-Schema.ps1 back to 7ae098a content:
git show HEAD:db/schema.sql | grep -c 'CREATE FUNCTION public."NGC_CreateBusinessUnit"'   # expect >=1 (NGC fns restored)
wc -l db/schema.sql
git status --short | head
```

## STEP 3 — journal (Python+fsync) + report. NO push, NO commit (reset already moved HEAD).
```bash
python3 - <<'PY'
import os,datetime
now=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ')
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write("\n"+now+" | dba-0610 (via CC) | REVERTED bc66f0f via reset --hard HEAD~1 -> HEAD=7ae098a==origin (ahead=0). bc66f0f T-FN apply-order change traded missing-fn sets, not an improvement; reopened for proper diagnosis. NO push.\n")
fd=os.open(".coord/journal.md",os.O_RDONLY); os.fsync(fd); os.close(fd)
print("journaled revert")
PY
sync
```

## Report (chat) — NO push
HEAD now 7ae098a == origin/v2-backend; ahead=0; NGC_CreateBusinessUnit restored in schema.sql; bc66f0f dropped. NO push.
