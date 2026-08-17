# CC TASK — reconcile devops/tools/db/data/03_rtsgrid.sql AgentGrid default MetricIds (match 46a1ce7)  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. Scope NARROWED (coordinator 10:15) to the ONE file dba-verified to carry the 5 phantom rows: **devops/tools/db/data/03_rtsgrid.sql**. (db/baseline.sql + Installations/dbdeploy = no RTSUserGrid_Column block = separate Q1 track; staging/regen234 = SKIP.) Apply the SAME phantom->real swap as 46a1ce7 in the RTSUserGrid_Column set-1 rows. NOT an Export-All. Preserve TABs + COPY terminator (§35/§39). NO push.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE + §C VERIFY.
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §35, §39, §26.2.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # v3 object-store; M hash-verify vs HEAD
sync
```
S1: if `.coord/push/request.md` active → STOP (barrier is FROZEN — coordinator directs this commit JOINS it; confirm with coordinator before commit).

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_reconcile_agentgrid_mirror_devops.md | status: open
### DIRECTIVE (spec->CC): swap 5 phantom->real AgentGrid MetricIds in devops/tools/db/data/03_rtsgrid.sql RTSUserGrid_Column set-1 (match 46a1ce7). claim: devops/tools/db/data/03_rtsgrid.sql ONLY. gate: 0 phantom + 5 real + tabs intact. NO push.
```

## 3. CLAIM
- `devops/tools/db/data/03_rtsgrid.sql` ONLY. No other file (NOT db/baseline.sql, NOT staging/regen234, NOT the canonical db/data/03_rtsgrid.sql).

## 4. TASK — §0.3 Python write (TAB-exact). In the RTSUserGrid_Column COPY block, replace the 5 phantom MetricIds (column-4, TAB-delimited) with the 46a1ce7 real IDs. Match on `\t<Header>\t<Phantom>\t` (Header disambiguates; the trailing TAB prevents substring bleed of AgentState into AgentStateDuration):
```python
import os
p = "devops/tools/db/data/03_rtsgrid.sql"
with open(p, "r", encoding="utf-8") as f: t = f.read()
subs = [
    ("\tAgent\tAgentName\t",            "\tAgent\tAgentLoginName\t"),
    ("\tState\tAgentState\t",           "\tState\tMonAgentState\t"),
    ("\tDuration\tAgentStateDuration\t","\tDuration\tMonAgentStateDuration\t"),
    ("\tOCC%\tAgentOccupancy\t",        "\tOCC%\tMonAgentAvailableDurationPct\t"),
    ("\tADH%\tAgentAdherence\t",        "\tADH%\tMonAgentAverageCallDuration\t"),
]
for old, new in subs:
    assert t.count(old) == 1, ("expected exactly 1 of "+repr(old)+" got "+str(t.count(old)))
    t = t.replace(old, new)
with open(p, "w", encoding="utf-8") as f:
    f.write(t); f.flush(); os.fsync(f.fileno())
```
Then `sync` + verify (below). Do NOT touch RTSGrid_Metric catalog rows, RTSUserGrid_ColumnsSet, or any other block. Preserve the COPY `\.` terminator and CRLF/LF exactly as the file already uses.

## 5. Verify (report in RESULT)
```bash
# 0 phantom standalone MetricIds remain in the RTSUserGrid_Column defaults:
grep -cE $'\tAgent\tAgentName\t|\tState\tAgentState\t|\tDuration\tAgentStateDuration\t|\tOCC%\tAgentOccupancy\t|\tADH%\tAgentAdherence\t' devops/tools/db/data/03_rtsgrid.sql   # expect 0
# 5 real present:
for m in AgentLoginName MonAgentState MonAgentStateDuration MonAgentAvailableDurationPct MonAgentAverageCallDuration; do grep -c "$m" devops/tools/db/data/03_rtsgrid.sql; done   # each >=1
# all 5 real exist in this file's catalog OR db/data/02_metrics.sql (they do — dba-verified)
```
Object-store: `git show <hash>:devops/tools/db/data/03_rtsgrid.sql` diff = exactly the 5 col-4 changes, byte-mirroring 46a1ce7 (no other lines changed; tabs intact).

## 6. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-07-15 · Mirror-seed reconcile: apply the phantom->real fix by DIRECT tab-exact swap in each mirror (match the canonical commit), NEVER Export-All from a live server that still carries the phantom (would re-capture it). VERIFY per-file which actually carries the defect before authoring (only devops/tools/db/data/03_rtsgrid.sql did; db/baseline.sql had NO RTSUserGrid_Column block at all). · SOURCE: 46a1ce7 + mirror verify 2026-07-15 · status: active
```

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5x60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add devops/tools/db/data/03_rtsgrid.sql` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`.
- Prefix `db:` — `db: reconcile devops-mirror AgentGrid default MetricIds to real catalog IDs (match 46a1ce7) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync); §0.7 re-sync. NO push (joins coordinator's barrier).

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . devops/tools/db/data/03_rtsgrid.sql (5 col-4 swaps) + role-dba §B . 0 phantom / 5 real / tabs intact . status done . verified: object-store
```
