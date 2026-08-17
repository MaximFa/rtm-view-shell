# CC task — Agent States + State Groups: Activate (inactive) + Delete, context-aware icons — §4 (⚠ BLOCKED on backend commands)
> Edit Tenant → Agent States tab. Today each row (both tables) has Edit (pencil) + Deactivate (red x-circle). An INACTIVE row (IsActive=false, e.g. 'Back Office') has NO way to re-activate. Required PER-ROW action set by status:
> - **ACTIVE** row → Edit + Deactivate (existing) + **Delete** (trash).
> - **INACTIVE** row → Edit + **Activate** (new) + **Delete** (trash).
> Apply to BOTH the State Groups table (Section 1) AND the Agent States table (Section 2).
> ⚠⚠ **BLOCKED on backend:** the Activate + Delete Application commands DO NOT EXIST — AgentStateCommands.cs has only Create/Update/**Deactivate** (Group + State). This Shell prompt Mediator.Sends `ActivateAgentStateGroupCommand`, `ActivateAgentStateCommand`, `DeleteAgentStateGroupCommand`, `DeleteAgentStateCommand` — **DO NOT RUN until backend has added those 4 commands+handlers** (else the build fails on unknown types). Coordinator dispatches backend in parallel; run this AFTER they land.
> Owner: role-shell (UI wiring). Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md

## PRECONDITION — DO NOT RUN unless these exist (grep first):
`grep -rn "ActivateAgentStateCommand\|ActivateAgentStateGroupCommand\|DeleteAgentStateCommand\|DeleteAgentStateGroupCommand" src/CcDashboard.Application` → MUST return the 4 records. If ANY is missing → STOP, report "blocked: backend commands not yet present" to inbox/coordinator.md, do NOT edit.

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — .coord/cc/shell.md
```
## BINDING 2026-07-16T08:19:21Z | spec: shell | directive: tools/cc_prompt_shell_agentstates_activate_delete.md | status: open
### DIRECTIVE (spec->CC): Agent States+Groups per-row Activate(inactive)+Delete, context icons, wired to backend commands. v3, fix(web):, NO push. build0/unit0. BLOCKED until 4 backend commands exist.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Admin/TenantsPage.razor  (both Agent-States tables' row actions + confirm modals + handlers)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx  (new labels/tooltips: Activate, Delete, delete-confirm)

## GROUNDING (object-store)
- State Groups table rows (~:400 `@foreach (var g in AgentStateGroups)`): Edit `OpenEdit... (bi-pencil ~:419)` + Deactivate `OpenDeactivateGroupModal(g)` (btn-outline-danger, bi-x-circle ~:421). `AgentStateGroupDto` has `IsActive`.
- Agent States table rows (~:461 `@foreach (var s in AgentStates)`): Edit `OpenEditStateModal(s)` (bi-pencil ~:479) + Deactivate `OpenDeactivateStateModal(s)` (bi-x-circle ~:482). `AgentStateDto` has `IsActive`.
- Existing commands: DeactivateAgentStateGroupCommand, DeactivateAgentStateCommand (+ Create/Update). Activate/Delete = NEW (backend).

## THE WORK
### Per row, context-aware action set (both tables):
```razor
@* Edit — always *@ <button ... @onclick="() => OpenEdit...(x)"><i class="bi bi-pencil"></i></button>
@if (x.IsActive)
{
    @* Deactivate — existing *@ <button class="btn btn-sm btn-outline-danger" @onclick="() => OpenDeactivate...Modal(x)"><i class="bi bi-x-circle"></i></button>
}
else
{
    @* Activate — NEW: green, semantic *@ <button class="btn btn-sm btn-outline-success" @onclick="() => Activate...(x)" title="@L[\"AgentStates_Activate\"]"><i class="bi bi-check-circle"></i></button>
}
@* Delete — NEW: red trash, confirmation *@ <button class="btn btn-sm btn-outline-danger" @onclick="() => OpenDelete...Modal(x)" title="@L[\"Common_Delete\"]"><i class="bi bi-trash"></i></button>
```
### Handlers:
- `Activate...` → `await Mediator.Send(new ActivateAgentStateGroupCommand(g.Id))` / `new ActivateAgentStateCommand(s.Id)` → reload the tab (reuse the existing reload used after Deactivate). Surface errors.
- `OpenDelete...Modal` → a confirmation modal (DANGER, mirror the existing Deactivate confirm modal pattern) → on confirm `await Mediator.Send(new DeleteAgentStateGroupCommand(g.Id))` / `new DeleteAgentStateCommand(s.Id)` → reload. Surface any guard error (e.g. group with active states / state with a definition) returned by the command as a friendly message.
### resx: add `AgentStates_Activate`, `Common_Delete` (reuse if exists — grep), `AgentStates_DeleteConfirm...` labels in en/ru/he. No hard-coded strings. RTL-safe (logical props / Bootstrap).
### Keep Edit + Deactivate exactly as-is; only ADD Activate (inactive branch) + Delete (both).

## VERIFY / DoD
- Object-store: both tables render context-aware actions (active→Deactivate, inactive→Activate; Delete on both) wired to the 4 commands; confirm modal for Delete; resx 3 locales; no hard-coded strings.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140/nayax): an INACTIVE Agent State/Group shows Activate → clicking re-activates (IsActive=true, row becomes active); Delete shows a confirmation → removes the row; guard message on a blocked delete; Edit/Deactivate unchanged.

## COMMIT
- pre-commit-check → commit.lock → stage TenantsPage.razor + 3 resx → `fix(web): Agent States/Groups — Activate (inactive) + Delete with context-aware icons [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files TenantsPage.razor (+3 resx) . status done|BLOCKED(backend cmds absent) . verified: object-store (LIVE activate/delete = coord 140)
```
