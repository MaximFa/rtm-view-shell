# CC Task: Metrics linter (D1) + Calc quarantine (D2)

> Source: RTM Metrics session (rtm-metrics-expert skill). Prevents the defect classes found in the
> 2026-06-05 audit from recurring, and hardens the engine against broken Calc metrics.
> **D3 (catalogue fields / CurLoginTimeStamp fix) is OUT OF SCOPE here** — it moved to a separate
> EF-based prompt (`tools/cc_prompt_metrics_catalog_fields.md`, TBD). Do NOT touch db/ or the
> RtsGridMetric entity in this task.

## Mandatory — read before starting
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md   (§2 engine truths, §10.2 function inventory, §12 pipeline)
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/widget-planner/widget-planner.md
Only after reading all three: proceed.

## Git push
Do NOT run `git push`. Commit only (§37).

## Claims for this session (file-mode, metrics-0605)
- tools: `tools/lint_metrics.py`
- rtm:   `RTM/RTM/Union.cs`, `RTM/RTM/UserManager.cs`

> ⚠ COORD: DayTrend (RTM) is starting in parallel and needs the RTM files. **Commit D2 (`rtm:`) FIRST
> and as early as possible**, then the session no longer needs Union.cs/UserManager.cs — the Cowork
> owner will release them from claims immediately after. Order your work: D2 → rtm: commit → D1 → tools commit.

## Step 0 — §0.6a integrity block
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l); W=$(wc -l < "$f" 2>/dev/null)
    if [ $((H-W)) -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f";
    else echo "OK $f ($W)"; fi
done
sync
# Known false-M (hash==HEAD, DO NOT touch): db/data/02_metrics.sql, db/schema.sql — verify with
#   git hash-object <f>  vs  git rev-parse HEAD:<f>  before "restoring".
```
Then the coord sync block from `tools/cc_prompt_sync_block.md` (running slug + the two claim sets above).

---

## Deliverable 2 (DO FIRST) — Calc quarantine  `RTM/RTM/Union.cs` (+ `UserManager.cs`)

A broken `Calc` metric throws inside `CompiledExpression.Eval()` **every calc cycle (~2 s) for every
Union** — silent for users, but spams `Union.getData.Calc` Error logs and burns CPU on exceptions
(confirmed with `QueuePctAnsweredCalls60secIncLast30min` before deletion).

In the `case "Calc":` block of `Union.cs` (~line 1283, catch at ~1316) and the analogous `case "Calc":`
in `UserManager.cs`, add a per-metric consecutive-failure quarantine:

- A `static readonly ConcurrentDictionary<string,int> _calcFailures` keyed by `metric.ID` (one per class).
- `const int CalcQuarantineThreshold = 5;`
- On Eval **success** → `_calcFailures[id] = 0`.
- On Eval **exception** → increment; log the FULL error ONLY on the 1st failure (count==1) and every
  100th thereafter — NOT every cycle.
- When count reaches the threshold → **skip Eval** for this metric (keep the existing/Default value) and
  log ONE `Warn: metric <id> quarantined after N consecutive Calc failures`.
- **Self-heal probe:** while quarantined, every 100th cycle attempt Eval once; success → reset to 0
  (un-quarantine) without a service restart.

Keep healthy-metric Calc semantics unchanged. Minimal, self-contained: the dictionary field + logic
inside the two switch blocks only. Write via Python+fsync (§0.3 — Edit BANNED).

**Build:** stop dotnet processes (widget-creator §28), `dotnet build RTM/RTM` — zero errors.
**Commit `rtm:` NOW** (pre-commit-check → §0.6 verify → journal → release lock → PD-007 re-sync).
After this commit, Union.cs/UserManager.cs are done for this task.

---

## Deliverable 1 — Metrics linter  `tools/lint_metrics.py`

Standalone Python validator (Python+fsync). Parses the `COPY "RTSGrid_Metric" FROM stdin` block of
`db/data/02_metrics.sql` (tab-separated, 9 cols: MetricId, Description, DataType, MetricFunction,
MetricParameter, MetricFormat, DefaultValue, ValueType, MetricType). **Exit 1 on any ERROR**, else 0.
One line per finding; final summary `N errors, M warnings`.

Checks (ERROR unless noted):
1. **Column count** == 9 per COPY row.
2. **MetricFunction exists in engine**, case-sensitive: parse `case "<Name>":` from `RTM/RTM/Union.cs`
   → `DATA_FUNCS`; from `RTM/RTM/UserManager.cs` → `AGENT_FUNCS` (exclude interaction-type values
   `Call/Chat/Email/Dialer`). Row `MetricType=Agent` → must be in AGENT_FUNCS; else DATA_FUNCS.
   (Catches the `CurLoginTimeStamp` vs `CurLoginTimestamp` class.)
3. **Calc refs** (`MetricFunction=Calc`): extract `\[(.*?)\]`; each trimmed ref must be an existing
   MetricId; ERROR if raw bracket content has leading/trailing whitespace (`[Foo ]`) — exact-match
   lookup fails in the engine (§2.3).
4. **Roslyn string-literal gotcha** (filter funcs: not Calc, not status-counter, non-empty param):
   if an IDInteraction/ChatMessage property name appears INSIDE a double-quoted literal in
   MetricParameter → ERROR (TransformQuery corrupts it, §12.2). Property names: regex
   `public <type> <Name> { get` from `RTM/RTM/IDInteraction.cs` and `RTM/RTM/ChatMessage.cs`.
5. **Duplicates** — canonical key `(MetricFunction, canonical(MetricParameter), bag)`; bag =
   `UsersInteraction` vs other for interaction funcs, IGNORED for status/login counters
   (UsersInStatus*, LogedInUsersCount). canonical(): trim, collapse ws, split top-level `&&`, strip
   redundant parens per atom, sort atoms. Two live (non-`\N`) rows, same key → ERROR.
6. **MetricId hygiene** — no dots, no dashes → ERROR.
7. **Enums** — ValueType ∈ {number,time,text}; MetricType ∈ {Data,Agent}; DataType ∈
   {Interactions Summary, UsersInteraction, UsersSummary, User} → WARNING if unknown.
8. **Description prefix** (`QM - ` / `Agent Group - ` / `Agent - `) → WARNING if missing.

CLI: `python3 tools/lint_metrics.py [--sql db/data/02_metrics.sql] [--rtm RTM/RTM]`.

**Self-test:** run against the current committed catalogue → MUST be 0 errors. If it flags the live
catalogue, fix the linter, not the catalogue. Then flip ONE MetricFunction to `CurLoginTimeStamp`
temporarily → linter MUST exit 1 with a clear message → revert.

> Do NOT wire into Export-All.ps1 here (that's db module, held elsewhere). Leave a one-line note in
> the completion report that Export-All wiring is a follow-up under the db claim.

**Commit `docs:`** (tooling) — pre-commit-check → §0.6 verify → journal → release lock → PD-007 re-sync.

---

## Commit plan (two commits, lock per §42.4)
1. `rtm: Calc quarantine in Union/UserManager (per-metric consecutive-failure guard)`  ← FIRST
2. `docs: tools/lint_metrics.py — RTSGrid_Metric catalogue linter (engine-function + Calc + dup checks)`
`.claude/` not involved. No db/ files. No push.

## Acceptance criteria
1. `dotnet build RTM/RTM` clean; a deliberately broken Calc metric is quarantined after 5 cycles with a
   single Warn line (verify in log), no per-cycle Error spam; a fixed metric self-heals within ~100 cycles.
2. `python3 tools/lint_metrics.py` exits 0 on the current catalogue.
3. Linter exits 1 (clear message) on: misspelled MetricFunction, bad/space-padded Calc ref,
   property-name-in-string-literal, duplicate, dotted/dashed MetricId.
4. Two clean commits (rtm:, docs:); working tree clean (ignore known false-M); journal line per commit;
   lock released; no push.
5. Completion report states Union.cs/UserManager.cs are no longer needed (so claims can be released for DayTrend).
