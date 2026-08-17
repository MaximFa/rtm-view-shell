# CC task — DIAG LOG-ONLY (our RTM only): discriminate AgentGrid membership fork
> §4-PASS (coordinator 2026-07-15) — log-only, RTM-only claim, zero-risk, legacy/adapter untouched. RUN-CLEARED.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Only after reading all files: proceed.

## Step 0 — INTEGRITY (mandatory)
cd "D:\Claude\Projects\RTM View Shell"; git status --short
For every M file: compare HEAD line count; if truncated -> `git show HEAD:"$f" > "$f"`. sync.

## Git push
Do NOT run `git push`. Commit only.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_rtm_diaglog.md | status: open`
`### DIRECTIVE: log-only diag on OUR RTM to fork membership-arrives(A) vs not(B). Claims: RTM/RTM/RTMAdapter.cs, RTM/RTM/UserManager.cs, RTM/RTM/Engine.cs. prefix chore(rtm).`

## GOAL
LOG-ONLY. Add diagnostic AsyncLogger.Info lines to OUR RTM Service so the operator can, after a restart on 140, tell whether agent->workgroup membership (setWorkgroups / userWorkgroupActivation) ARRIVES at our RTM and whether the union intersection matches. **NO logic change of any kind** — only add/uncomment log statements. Do NOT touch the adapter, legacy, DB, or Shell. Files limited to RTM/RTM/*.

## CLAIM (touch ONLY these)
- RTM/RTM/RTMAdapter.cs
- RTM/RTM/UserManager.cs
- RTM/RTM/Engine.cs

## EXACT LOG INSERTIONS (log-only; use existing AsyncLogger; §0.3 Python writes)

### A. RTM/RTM/RTMAdapter.cs
1. In `Server_MessageReceived` there is a commented line (~:182) `//AsyncLogger.Info("method = " + method ...)`. ENABLE it as:
   `AsyncLogger.Info($"SERVER <= method={method}");`
2. In `userWorkgroupActivation(Dictionary<string,object> dic, string jsnonString)` (~:269): at the START of the method body (after existing parse of workgroup/active/deactive lists), add:
   `AsyncLogger.Info($"RECV userWorkgroupActivation workgroup={workgroup} active=[{string.Join(",", activeUsersList)}] deactive=[{string.Join(",", deactiveUsersList)}]");`
   (use whatever local variable names the method already parses into; if it does not parse them until later, place the log immediately after those locals are assigned — do NOT reorder logic.)
3. In `setWorkgroups(Dictionary<string,object> dic, string jsnonString)` (~:482): after the workgroups list local is parsed, add:
   `AsyncLogger.Info($"RECV setWorkgroups count={workgroups.Count} names=[{string.Join(",", workgroups)}]");`

### B. RTM/RTM/UserManager.cs
4. In the method that mutates `_workgroups` on activation (the `workgroupActivation`/activation handler around :621-:672 where `refreshUnions()` is called): immediately AFTER `_workgroups` is mutated and BEFORE `refreshUnions()`, add:
   `AsyncLogger.Info($"_workgroups[{userId}] now=[{string.Join(",", _workgroups)}]");`
5. In `refreshUnions()` (:564-:608): inside `foreach (List<string> wgArr in union.UserGroups.Values)`, when `ContainsAllItems(_workgroups, wgArr)` is FALSE **and** `wgArr != null && wgArr.Count > 0`, add a one-line MISS log (add an `else` to the existing `if`):
   `else if (wgArr != null && wgArr.Count > 0) { AsyncLogger.Info($"refreshUnions MISS user={this.userId} union={union.UnionId} need=[{string.Join(",", wgArr)}] have=[{string.Join(",", _workgroups)}]"); }`
   This is the DECISIVE line: it shows the SG's required AG token set vs the agent's actual membership token set (branch A token/partial mismatch) — or is absent entirely if membership never arrives (branch B).

### C. RTM/RTM/Engine.cs
6. In `LoadData` where `union.UserGroups[<SupergroupId>]` is populated with the AG list (the union agent-group structure load): add, right after the assignment, per SG:
   `AsyncLogger.Info($"LoadData union={union.UnionId} sg={<sgId var>} needGroups=[{string.Join(",", <agListVar>)}]");`
   (match the actual variable names in that block; log-only, do not change the assembly.)

## CONSTRAINTS
- LOG-ONLY. Zero control-flow / data changes. No new methods except inline log statements. No `git push`.
- Edit via Python + os.fsync (§0.3). After each write: `sync; tail -3 <f>; wc -l <f>`.
- Do NOT touch adapter (RTM.Twilio / RTM.Adapter.Common), legacy (RTM.ININ), db/, src/.

## ACCEPTANCE
- `dotnet build RTM/RTM` = 0 errors (build0).
- grep the changed files to confirm the 6 log lines exist and compile.
- pre-commit-check.sh green.

## COMMIT
`bash tools/pre-commit-check.sh` -> if exit 1 restore+retry.
Commit (commit.lock per §42.4) prefix: `chore(rtm): diag log-only — membership arrival + refreshUnions MISS token-diff (AgentGrid fork)`.
NO push. Journal append + lock release + §0.7 re-sync of the 3 files from HEAD.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hash, files+line counts, build result, verified: object-store.
