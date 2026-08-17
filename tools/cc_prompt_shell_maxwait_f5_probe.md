# CC task — Queue Grid Max Wait F5-reset PROBE (shell): log the wire value on re-subscribe to pin shell-vs-RTM — §4 (temp instrumentation)
> Symptom (corrected, operator): after F5/re-subscribe, Max Wait resets from the TRUE accumulated wait (e.g. 16:50) to ~00:42 and climbs from there. Read-only established the WIDGET IS FAITHFUL: `ApplyMetricValue` (QueueGridWidget.razor:1300) always anchors `base = ParseTimeToSeconds(serverValue)` from the pushed cell — there is NO 'subscribe-moment zero' in the widget. So the base after F5 = whatever RTM pushes on init/refreshCells. This PROBE captures that exact wire value to pin the owner: 16:50 pushed → widget bug; 00:42 pushed → RTM bug. INSTRUMENTATION ONLY (temp log), NOT the fix.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `chore(web):` (temp probe). **NO push**.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — .coord/cc/shell.md
```
## BINDING 2026-07-16T23:06:50Z | spec: shell | directive: tools/cc_prompt_shell_maxwait_f5_probe.md | status: open
### DIRECTIVE (spec->CC): PROBE — temp-log the Max Wait cell wire value on each updateGridData push (esp. first after F5/re-subscribe) to pin shell-vs-RTM. v3, chore:, NO push.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor  (TEMP log only, in _gridHandler + on subscribe)

## THE WORK — temp instrumentation, marked `// PROBE MAXWAIT-F5`
1. In `_gridHandler` (~:475, the `foreach (var cell in updates)` loop): for cells whose value starts with '+' (duration) OR whose metricId contains "wait"/"maxwait" (case-insensitive), `Logger.LogWarning("[PROBE MAXWAIT-F5] push cellId={CellId} metricId={MetricId} rawValue={Val} parsedBase={Base}s", cell.CellId, metricId, cell.Value, cell.Value is not null && cell.Value.StartsWith('+') ? ParseTimeToSeconds(cell.Value[1..]) : -1);` (make ParseTimeToSeconds accessible or inline the parse). This logs the RAW server value + parsed base on every push.
2. Right after subscribe succeeds (~:490 after SubscribeGridAsync) log `Logger.LogWarning("[PROBE MAXWAIT-F5] (re)subscribed to GridId {GridId} at {Ts:HH:mm:ss.fff}", _rtsGridId, DateTime.UtcNow);` — so the FIRST push after this line = the re-subscribe/F5 value.
3. No behavioural change; keep all logging behind `// PROBE MAXWAIT-F5`.

## RUN + CAPTURE (the deliverable)
- Build + bring up on nayax/140. Open a Queue Grid where Max Wait is large (e.g. US-Support ~16:50). Note the displayed value. Then **F5** the page. Read the Shell serilog (Soma /logs/tail?source=serilog): find the `(re)subscribed` line, then the FIRST `[PROBE MAXWAIT-F5] push ... metricId=<maxwait>` after it.
- The rawValue on that first post-F5 push is the answer:
  · `+16:50` (base ~1010s) → **RTM pushes the TRUE wait; the WIDGET resets it** → shell fix (find where the widget drops/rebases it — but per read-only the widget uses the pushed base, so re-examine the row-rebuild/anchor-carryover path).
  · `+00:42` (base ~42s) → **RTM pushes the reset value** → RTM/backend fix (RTM must push `now - enqueue`, not a re-subscribe-relative value) → flag coordinator to route backend.
- REPORT the captured rawValue + the verdict to inbox/coordinator.md + cc/shell.md.

## VERIFY / DoD
- Object-store: temp `// PROBE MAXWAIT-F5` logging in the 2 spots; no behavioural change; v3.
- Soma: /ops/build 0 + serilog readable. The VALUE = the captured wire value + the shell-vs-RTM verdict (diagnostic, not a user gate).
- Follow-up: after the verdict, the probe is REMOVED (a later prompt) and the real fix authored per the pinned owner.

## COMMIT
- pre-commit-check → commit.lock → stage QueueGridWidget.razor → `chore(web): PROBE Max Wait F5-reset — log wire value on re-subscribe [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commit <hash> . build 0 . PROBE FINDING: first-post-F5 Max Wait rawValue=<+16:50 | +00:42> => owner=<widget | RTM> . status done . verified: live-log
```
