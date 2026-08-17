# CC task — DEFECT A fix: Agent Grid DEFAULT columns → correct catalog metric IDs (no phantom, no new metrics)
> §4-PASS (coordinator 2026-07-15) — 2-file ID swap, all 5 IDs verified in catalog, operator-confirmed mapping. TERRITORY: backend authors BOTH (narrow 2-file claim; shell-0609 idle). RUN-CLEARED.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Only after reading all: proceed.

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
Every M file: if HEAD line-count > working → `git show HEAD:"$f" > "$f"`. sync.

## Git push
Do NOT run `git push`. Commit only.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_defectA_agentgrid_default.md | status: open`
`### DIRECTIVE: fix AgentGrid DEFAULT columns → real catalog metric IDs (2 files, no new metrics). Claims: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor, db/data/03_rtsgrid.sql. prefix web:/db: (two commits).`

## ROOT (why)
The default Agent Grid columns reference PHANTOM metric IDs (AgentName/AgentState/AgentStateDuration/AgentOccupancy/AgentAdherence) that do NOT exist in the catalog db/data/02_metrics.sql → a fresh/default AgentGrid renders blank. The manual metric-install on 140 was a workaround. The CORRECT metrics ALREADY EXIST in the catalog and are the operator-confirmed mapping. Fix = point the default at the real IDs. NO new metrics are added (all 5 verified present in 02_metrics.sql).

CORRECT mapping (operator-confirmed, all exist in 02_metrics.sql):
| Column | OLD (phantom) | NEW (correct, exists in catalog) |
|---|---|---|
| Agent | AgentName | AgentLoginName |
| State | AgentState | MonAgentState |
| Duration | AgentStateDuration | MonAgentStateDuration |
| OCC% | AgentOccupancy | MonAgentAvailableDurationPct |
| ADH% | AgentAdherence | MonAgentAverageCallDuration |

## CLAIM (touch ONLY these)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
- db/data/03_rtsgrid.sql

## CHANGE 1 — Shell default: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
In `GetDefaultColumnDefs()` (~line 3920-3930) replace the 5 MetricId values ONLY (keep Name values):
```csharp
private List<AgentGridColumnDef> GetDefaultColumnDefs()
{
    return new List<AgentGridColumnDef>
    {
        new() { Name = "Agent", MetricId = "AgentLoginName" },
        new() { Name = "State", MetricId = "MonAgentState" },
        new() { Name = "Duration", MetricId = "MonAgentStateDuration" },
        new() { Name = "OCC%", MetricId = "MonAgentAvailableDurationPct" },
        new() { Name = "ADH%", MetricId = "MonAgentAverageCallDuration" }
    };
}
```
Do NOT change any other method. (RtmRelayService already reads MonAgentState as the primary state field — this aligns.)

## CHANGE 2 — DB seed default: db/data/03_rtsgrid.sql
In the `RTSUserGrid_Column` COPY block (~lines 51-55), change the 4th tab-column (MetricId) ONLY, keep the ColumnId/ColumnsSetId/Title/StyleId/Order:
```
1	1	Agent	AgentLoginName	\N	0
2	1	State	MonAgentState	\N	1
3	1	Duration	MonAgentStateDuration	\N	2
4	1	OCC%	MonAgentAvailableDurationPct	\N	3
5	1	ADH%	MonAgentAverageCallDuration	\N	4
```
Preserve exact TAB separators and the `\.` terminator. Do not touch RTSUserGrid_ColumnsSet / RTSUserGrid_Grid or any other block.

## CONSTRAINTS
- NO new metrics (all 5 already in 02_metrics.sql — do NOT add AgentName/AgentState/etc.). NO legacy/adapter/RTM touch. No `git push`.
- Edit via Python + os.fsync (§0.3). After each write: `sync; tail -3 <f>; wc -l <f>`.
- Two commits (territory): `web:` for ScreenEditorPage.razor, `db:` for 03_rtsgrid.sql (§39.3).

## ACCEPTANCE
- `dotnet build src/CcDashboard.Web` = 0 errors (build0) for the razor change.
- grep confirms: ScreenEditorPage GetDefaultColumnDefs has the 5 NEW MetricIds; 03_rtsgrid.sql RTSUserGrid_Column has them; ZERO occurrences of AgentName/AgentState/AgentStateDuration/AgentOccupancy/AgentAdherence remain in either file.
- Confirm all 5 NEW IDs exist in db/data/02_metrics.sql (grep).
- pre-commit-check.sh green.

## COMMIT (two commits, commit.lock each)
`bash tools/pre-commit-check.sh` → if exit 1 restore+retry.
1. `web: fix AgentGrid default columns → real catalog metric IDs (MonAgentState/... ; fixes blank default AgentGrid)`
2. `db: fix RTSUserGrid_Column default MetricIds → real catalog metrics (AgentLoginName/MonAgentState/...)`
NO push. Journal append + lock release + §0.7 re-sync of both files from HEAD.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hashes, files+line counts, build result, grep-verify (no phantom IDs remain; 5 new IDs present in catalog), verified: object-store.

## NOTE (mirrors — for DBA/coordinator, NOT this task)
Baseline mirrors also carry the phantom seed: db/baseline.sql, staging/regen234/data/03_rtsgrid.sql, devops/tools/db/data/03_rtsgrid.sql, Installations/dbdeploy/db/baseline.sql. These regenerate via Export-All; flag DBA to reconcile after this canonical fix. Operator's manual 140 phantom-metric adds become unused orphans (optional 140 cleanup).
