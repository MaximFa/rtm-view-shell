# CC task — Max Wait fix COMPLETION (shell): (1) fix the QueueGrid CLOCK bug (C1), (2) add the AgentGrid enqueue-anchor 89feb34 MISSED — §4
> 89feb34 did the QueueGrid half but is INCOMPLETE + has a C1 CLOCK bug:
> ISSUE 1 (C1 clock — WRONG absolute value): QueueGridWidget ApplyMetricValue anchors `DateTime.SpecifyKind(enqueueLocal, DateTimeKind.Utc)` (:1313) — this LABELS the server-local enqueue as UTC WITHOUT converting; GetCellDisplay uses `DateTime.UtcNow - StartedAt` (:~1336). On a non-UTC server (140 is UTC+3 per serilog "+03:00"), `UtcNow - localLabeledUtc` = trueWait MINUS the server offset → Max Wait HOLDS at a WRONG value (likely clamped to 00:00). This is exactly the C1 failure the coordinator flagged.
> ISSUE 2 (incomplete): AgentGridWidget was NOT touched (89feb34 = 3 files, no AgentGrid) — its Duration '+'-cells still use the receipt-anchor (F5-reset bug). The prompt required AgentGrid.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**. web territory (both files under src/).

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
## BINDING 2026-07-20T06:30:45Z | spec: shell | directive: tools/cc_prompt_shell_maxwait_complete.md | status: open
### DIRECTIVE (spec->CC): Max Wait completion — fix QueueGrid clock (server-local enqueue -> UTC) + add AgentGrid enqueue-anchor (89feb34 missed). v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor   (clock fix)
- src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor   (add enqueue-anchor)
> Do NOT re-touch GridCellUpdate.cs / RtmRelayService.cs (89feb34, correct: Value2 carried + CellSnapshot stores it).

## THE WORK
### 1. QueueGridWidget — CLOCK FIX (C1)
In ApplyMetricValue (~:1313): change
`var enqueueUtc = DateTime.SpecifyKind(enqueueLocal, DateTimeKind.Utc);`
to convert the SERVER-LOCAL enqueue to a real UTC instant so it's consistent with GetCellDisplay's `DateTime.UtcNow`:
`var enqueueUtc = DateTime.SpecifyKind(enqueueLocal, DateTimeKind.Local).ToUniversalTime();`
(the widget runs on the server = same machine/clock that produced the server-local enqueue; Local->UTC yields the correct instant, so `UtcNow - enqueueUtc` = the true wait). Update the misleading comment. GetCellDisplay unchanged.
> RATIONALE: coordinator confirmed enqueue Value2 is SERVER-LOCAL. `SpecifyKind(Local).ToUniversalTime()` puts both operands on the same (UTC) clock. VERIFY on the C1 seal that the absolute value matches the wire/legacy (~22:11), not off-by-offset.

### 2. AgentGridWidget — add the SAME enqueue-anchor
AgentGrid has the identical pattern: `ApplyMetricValue(row, metricId, raw, receiptTs)` (call sites ~:528/543/549), `TimerAnchors` (:341), `GetCellDisplay` (:1238, uses UtcNow + StartedAt).
- Thread Value2 to AgentGrid's cell-apply (the agent snapshot cells must carry Value2 — verify the AgentSnapshot/cell path exposes it; if the agent path does NOT deliver Value2, NOTE it — that half may need the relay/agent-snapshot to carry Value2 too, flag coordinator). If AgentGrid duration cells come through the SAME grid updateGridData path with Value2, thread it like QueueGrid.
- In AgentGrid ApplyMetricValue: when a '+'-duration cell has a parseable Value2 enqueue datetime → anchor `(0, SpecifyKind(enqueueLocal, DateTimeKind.Local).ToUniversalTime())` (same as QueueGrid, C1-correct); tolerant `TryParseExact("dd/MM/yyyy HH:mm:ss", InvariantCulture)`; fall back to receipt-anchor when absent/unparseable (C2).
- If AgentGrid genuinely has NO '+'-duration/enqueue cells (verify — Agent Duration may be a state-duration, not enqueue-based), NOTE that in RESULT and skip — do not force an enqueue anchor where there's no enqueue.
- **CLARIFY 1 (coordinator) — do NOT half-fix AgentGrid, do NOT block the QueueGrid seal:** the operator's ACTUAL bug is the QUEUE grid Max Wait; it seals INDEPENDENTLY once QueueGrid C1(a/b/c) passes. AgentGrid Duration is backend's proactively-flagged sibling. If AgentGrid Duration comes via `updateUserGrid`/AgentSnapshot (NOT the GridCellUpdate path) and that path does NOT carry Value2 → do NOT half-anchor it → DOCUMENT the gap in RESULT + flag coordinator (AgentGrid becomes a SEPARATE follow-up that may need relay/AgentSnapshot to carry Value2 = another Domain/Infra edit). If AgentGrid "Duration" is a STATE duration (state-change instant, not enqueue) → note it, do NOT force an enqueue anchor. QueueGrid must NOT wait on AgentGrid — commit the QueueGrid clock fix regardless.

## VERIFY / DoD
- Object-store: QueueGrid enqueue anchor now uses `SpecifyKind(Local).ToUniversalTime()` (not Utc); AgentGrid duration '+'-cells anchor the same way (or a documented skip-note if no enqueue cells); GridCellUpdate/RtmRelayService UNCHANGED; tolerant TryParseExact + receipt fallback intact.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0. **CLARIFY 2 (coordinator): Soma was DOWN this session.** If Soma is still unresponsive at run time, get build/unit evidence another way — `dotnet build CcDashboard.sln` + `dotnet test tests/CcDashboard.Tests.Unit` directly — and report the real numbers; do NOT claim build0/unit0 without evidence (a no-evidence build is not a gate).
- ⛔ LIVE SEAL (coord/operator on 140, diag ad73870 until sealed) — C1 ALL THREE: (a) Max Wait ABSOLUTE value matches wire/legacy (~22:11) — the clock fix must make it RIGHT, not off-by-3h; (b) F5 HOLDS; (c) climbs 1s/s. C2: F5 actually HOLDS (enqueue-anchor taken, not fallback) — if it resets or shows a wrong absolute -> escalate, do NOT seal. Same for Max Wait Callbacks + AgentGrid Duration (if it has enqueue cells).

## COMMIT
- pre-commit-check → commit.lock → stage QueueGridWidget.razor + AgentGridWidget.razor → `fix(web): Max Wait completion — server-local enqueue clock fix (C1) + AgentGrid enqueue-anchor [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync.

## §0.6b CAPTURE -> role-shell §B: "Enqueue-anchor clock: the enqueue datetime is SERVER-LOCAL; anchoring via SpecifyKind(..,Utc) (label-not-convert) while GetCellDisplay uses UtcNow yields trueWait - serverOffset (HOLDS but WRONG absolute). Correct = SpecifyKind(..,Local).ToUniversalTime() so both operands share the UTC clock. Also: a multi-widget fix (QueueGrid+AgentGrid) must land BOTH; 89feb34 shipped QueueGrid-only." SOURCE:QueueGridWidget:1313 + serilog +03:00 + 89feb34 stat. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files QueueGridWidget.razor + AgentGridWidget.razor . skipped: <AgentGrid if no enqueue cells + why> . status . verified: object-store (LIVE C1 absolute+F5-holds = coord 140 seal)
```
