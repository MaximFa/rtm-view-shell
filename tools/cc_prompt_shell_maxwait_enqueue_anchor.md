# CC task — Max Wait F5-reset FIX (shell): carry Value2 (enqueue datetime) through relay -> anchor display = now - enqueue (F5-proof) — AWAITING §4
> ROOT (backend code-pinned, shell-CONFIRMED at HEAD): the duration cells are CLIENT-ticked with a RECEIPT anchor, and the relay DISCARDS the enqueue datetime:
> - RtmRelayService.HandleGridUpdateAsync (:682-688) reads item["CellId"]+item["Value"] ONLY -> DISCARDS item["Value2"] (the raw enqueue datetime "+dd/MM/yyyy HH:mm:ss").
> - GridCellUpdate (Domain/Rtm/GridCellUpdate.cs:4) = record(int CellId, string Value) — no Value2.
> - QueueGridWidget.ApplyMetricValue (:1300-1313): on '+' value, `TimerAnchors[metric]=(ParseTimeToSeconds(elapsed), DateTime.UtcNow)` — anchors StartedAt=RECEIPT; GetCellDisplay (:1317) = BaseSecs + (now - StartedAt); PeriodicTimer(1s) local-ticks. => the widget local-accumulates from the received elapsed; on F5 it re-subscribes, LOSES the local accumulation, re-anchors to the received elapsed -> RESET. (AgentGridWidget has the identical pattern — ApplyMetricValue with a receipt timestamp :528/543/549, TimerAnchors :341, GetCellDisplay :1238.)
> Value2 IS in the wire (RTM emits it — RTM/RTM/CellData.cs:17 Value2; Engine.cs:1396-1397 refresh serves the datetime; RTMAdapter.cs:516 sends the full CellData collection) -> NO RTM change needed; just stop discarding it.
> FIX = carry Value2 (enqueue datetime) relay->widget; when present for a '+'-duration cell, anchor `StartedAt = enqueueInstant, BaseSecs = 0` so display = now - enqueue -> recomputes the TRUE wait every render, F5-proof + cadence-independent. Fall back to the current receipt-anchor when Value2 absent.
> ⚠ CROSS-LAYER: touches Domain (GridCellUpdate) + Infrastructure (RtmRelayService) + Web (2 widgets). Coordinator: confirm shell commits the Domain/Infra half (or backend co-authors) — flagged in §4 submission.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**.

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
## BINDING 2026-07-20T05:48:22Z | spec: shell | directive: tools/cc_prompt_shell_maxwait_enqueue_anchor.md | status: open
### DIRECTIVE (spec->CC): Max Wait F5-fix — carry Value2 (enqueue dt) relay->widget; anchor display=now-enqueue (F5-proof) in QueueGrid+AgentGrid. v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode)
- src/CcDashboard.Domain/Domain/Rtm/GridCellUpdate.cs                         (+ Value2)
- src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs                  (read+carry Value2; snapshot stores it)
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor                (enqueue anchor)
- src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor                (enqueue anchor — same pattern)

## THE WORK
### 1. GridCellUpdate (Domain): `public sealed record GridCellUpdate(int CellId, string Value, string? Value2 = null);`
### 2. RtmRelayService.HandleGridUpdateAsync (:681-688):
- read `var value2 = item["Value2"]?.Value<string>();` and `updates.Add(new GridCellUpdate(cellId, value, value2));`.
- `CellSnapshot` currently stores only `value`; change it to store BOTH (e.g. `Dictionary<int,(string Value,string? Value2)>`) so the F5/refresh snapshot replay carries the enqueue dt. Update the two `CellSnapshot[cellId]=` write + any snapshot read/replay accordingly. (Do NOT change the DiagPushLogging line semantics; may extend the log to include Value2.)
### 3. QueueGridWidget.ApplyMetricValue (:1300) + its caller `_gridHandler` (:475):
- Pass `cell.Value2` into ApplyMetricValue.
- In ApplyMetricValue: if the cell is a '+'-duration AND `value2` parses as a datetime (format `+dd/MM/yyyy HH:mm:ss`, strip the leading '+'; `DateTime.TryParseExact(s, "dd/MM/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out var enq)` — TOLERANT (C2: on parse-fail, fall back but see C2 in DoD)), set the anchor to `(0, enqueueInstant)` so `GetCellDisplay` = `0 + (now - enqueueInstant)` = the TRUE wait. **CLOCK:** enqueue is SERVER-local; compute the wait against the SAME clock the widget uses — reuse the relay's existing `ServerTimeOffset` if exposed to the widget, else compute `now - enqueue` with both as the server clock (verify on the live seal that the value matches the wire ~22:11, and that a fresh F5 recomputes the true wait, not 0). If Value2 is absent/unparseable -> current behavior (elapsed + receipt anchor).
- GetCellDisplay: unchanged (BaseSecs + (now - StartedAt)); with BaseSecs=0 + StartedAt=enqueue it yields now-enqueue.
### 4. AgentGridWidget: apply the SAME enqueue-anchor in its ApplyMetricValue (:528/543/549 call sites pass a receipt ts today) + carry Value2 to it. Same '+'-duration TimerAnchors path.
### 5. No RTM change (Value2 already emitted). Keep non-duration cells + non-'+' values unchanged.

## VERIFY / DoD
- Object-store: GridCellUpdate has Value2; relay reads+carries it + snapshot stores it; both widgets anchor `(0, enqueueInstant)` when Value2 present (else fall back); no RTM edit.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- **⛔ LIVE SEAL (coord/operator on 140/nayax, diag ad73870 stays until sealed) — C1: ALL THREE required:** (a) Max Wait shows the TRUE ABSOLUTE wait matching the wire/legacy (~22:11), NOT just a stable number; (b) F5 -> it HOLDS (no reset to ~8s); (c) climbs 1s/s. Same for Max Wait Callbacks + AgentGrid Duration.
- **C1 CLOCK CORRECTNESS:** enqueue Value2 is SERVER-LOCAL (`+dd/MM/yyyy HH:mm:ss`). Compute `now - enqueue` with BOTH on the SAME server clock — a UTC-vs-server-local mismatch would HOLD at a constant WRONG value and falsely pass a "holds"-only check. PROVE the absolute value is right on 140, not just its stability.
- **C2 NO SILENT FALLBACK MASKING:** parse Value2 with tolerant `DateTime.TryParseExact("dd/MM/yyyy HH:mm:ss", InvariantCulture, DateTimeStyles.None)` (guard culture). On the seal CONFIRM the enqueue-anchor path is ACTUALLY taken — i.e. F5 HOLDS. If F5 STILL resets at seal => parse fell back to the buggy receipt-anchor => ESCALATE, do NOT seal.
- **CellSnapshot shape change** (string -> (Value,Value2)) touches all snapshot read/replay + the DiagPushLogging read; build0 must be clean; KEEP DiagPushLogging semantics.

## COMMIT
- pre-commit-check → commit.lock → stage the 4 files → `fix(web): Max Wait F5-proof — carry Value2 enqueue datetime + anchor display=now-enqueue (QueueGrid+AgentGrid) [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync.

## §0.6b CAPTURE -> role-shell §B: "Live duration cells (Max Wait) were client-ticked from the RECEIVED ELAPSED with StartedAt=RECEIPT wall-clock; the relay DISCARDED item['Value2'] (the raw enqueue datetime). So the displayed wait was widget-local accumulation that F5 reset (re-anchor to the received elapsed). FIX: carry Value2 through GridCellUpdate/relay/snapshot and anchor StartedAt=enqueue instant (BaseSecs=0) so display=now-enqueue — F5-proof + push-cadence-independent. Rule: an elapsing duration must anchor to the SOURCE start instant (enqueue), never to receipt/subscribe time." SOURCE:RtmRelayService:682 + GridCellUpdate + QueueGridWidget ApplyMetricValue + RTM CellData.Value2 (Engine.cs:1396). Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files GridCellUpdate.cs + RtmRelayService.cs + QueueGridWidget.razor + AgentGridWidget.razor . status . verified: object-store (LIVE F5-holds Max Wait = coord 140 seal)
```
