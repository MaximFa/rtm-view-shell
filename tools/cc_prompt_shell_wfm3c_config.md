# CC task — WFM-3c-config (shell): TenantSettings WFM UI + DTO/command plumbing — AWAITING §4
> GOAL: expose the 8 WFM Phase-1 config fields (spec §5, already on the `TenantSettings` ENTITY + migration `20260721110721_WfmTenantSettings`) end-to-end so a Superadmin/Administrator can edit them on the Tenant modal. This half is INDEPENDENT of the WFM store/transport (that is WFM-3c-widget).
> The entity fields ALREADY EXIST (src/CcDashboard.Domain/Domain/TenantSettings.cs:33-48): WfmServingStateGroups (string[]), WfmWindowMinutes (int=30), WfmSlTargetPct (double=80), WfmSlThresholdSec (int=20), WfmTrunkCapacity (int=100), WfmDefaultShrinkage (double=0.28), WfmEnableRealtime (bool=true), WfmThresholds (string? JSON).
> The DTO/Request/handler/read-projection DO NOT carry them yet (verified: TenantSettingsDto.cs + UpdateTenantSettingsCommand.cs at HEAD 515c355 have no Wfm* members). This task plumbs them + adds the UI.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat(web):`. **NO push** (§37 — push only via barrier).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # must be v3
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-21T13:08:24Z | spec: shell | directive: tools/cc_prompt_shell_wfm3c_config.md | status: open
### DIRECTIVE (spec->CC): WFM-3c-config — plumb 8 Wfm* fields DTO/Request/handler/read-projection + Tenant modal "WFM" tab (SA/Admin); WfmServingStateGroups multiselect from Agent State GROUPS. v3, feat(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web territory)
- src/CcDashboard.Contracts/DTOs/TenantSettings/TenantSettingsDto.cs                         (add 8 Wfm* to BOTH records)
- src/CcDashboard.Application/Commands/TenantSettings/UpdateTenantSettingsCommand.cs          (map + clamp + serialize)
- the GetTenantSettings query/handler that projects TenantSettings entity -> TenantSettingsDto  (LOCATE under src/CcDashboard.Application/Queries/TenantSettings/ ; add the Wfm* projection)
- src/CcDashboard.Web/Components/Admin/TenantsPage.razor                                       (new "WFM" tab in the edit modal + load + save mapping)
- IF a FluentValidation validator exists for UpdateTenantSettingsRequest: extend it (else add clamps in the handler only)

## THE WORK
### 1. DTO — TenantSettingsDto.cs
Add these members to BOTH `TenantSettingsDto` AND `UpdateTenantSettingsRequest` (append after FontSizes; keep positional-record order stable — append at END):
```
    List<string>? WfmServingStateGroups,
    int WfmWindowMinutes,
    double WfmSlTargetPct,
    int WfmSlThresholdSec,
    int WfmTrunkCapacity,
    double WfmDefaultShrinkage,
    bool WfmEnableRealtime,
    string? WfmThresholds
```
(WfmServingStateGroups as List<string>? mirrors the existing palette-list convention; entity stores string[].)

### 2. Read-projection (GetTenantSettings query/handler)
Where the entity is mapped to TenantSettingsDto, project the Wfm* fields:
- `WfmServingStateGroups = settings.WfmServingStateGroups?.ToList()`
- the scalars 1:1; `WfmThresholds = settings.WfmThresholds`.

### 3. UpdateTenantSettingsCommandHandler — map + clamp (mirror the existing clamp style)
```
settings.WfmServingStateGroups = (r.WfmServingStateGroups is { Count: > 0 }) ? r.WfmServingStateGroups.ToArray() : settings.WfmServingStateGroups;
settings.WfmWindowMinutes    = Math.Clamp(r.WfmWindowMinutes, 1, 1440);
settings.WfmSlTargetPct      = Math.Clamp(r.WfmSlTargetPct, 1, 100);
settings.WfmSlThresholdSec   = Math.Clamp(r.WfmSlThresholdSec, 1, 3600);
settings.WfmTrunkCapacity    = Math.Clamp(r.WfmTrunkCapacity, 1, 100000);
settings.WfmDefaultShrinkage = Math.Clamp(r.WfmDefaultShrinkage, 0.0, 0.95);
settings.WfmEnableRealtime   = r.WfmEnableRealtime;
settings.WfmThresholds       = NormalizeJsonOrNull(r.WfmThresholds);   // trim; if blank -> null; if non-null MUST JsonDocument.Parse-validate, on invalid throw a ValidationException / friendly error (do NOT persist invalid JSON)
```
Add the small `NormalizeJsonOrNull` helper (private static).

### 4. TenantsPage.razor — new "WFM" tab in the edit modal (SA/Admin)
- Add a tab button `WFM` next to General/Settings/Appearance/Agent States, gated the same way those admin tabs are gated (Superadmin/Administrator). Pattern: `@if (EditTab == "wfm")`.
- Bind the 8 fields to the edit-form model you already load in `LoadEditSettings` (extend that model + the `Save` builder that constructs `UpdateTenantSettingsRequest`).
- **WfmServingStateGroups = MULTISELECT of Agent State GROUP names.** Source the ACTIVE group names for the tenant from the SAME data the "Agent States" tab already loads (the State Groups list). Render as a checkbox list (or dual-pane) of group names; the selected set persists to WfmServingStateGroups. Do NOT free-text it.
- WfmWindowMinutes / WfmSlThresholdSec / WfmTrunkCapacity: number inputs (int). WfmSlTargetPct / WfmDefaultShrinkage: number inputs (double; show shrinkage as 0..0.95 or a %—your call, but persist the 0..1 fraction). WfmEnableRealtime: checkbox. WfmThresholds: an "Advanced (RAG JSON)" collapsible `<textarea>` (optional; blank = spec defaults) with a one-line hint.
- Labels/hints via `IStringLocalizer` (§I18N-03 — NO hardcoded UI strings; add keys to SharedResources .resx: en-US + ru-RU at minimum, mirror existing key style). Use CSS logical properties; respect dark mode (the modal already themes — match the Settings tab).
- Keep the existing Save flow: on save, the request now includes the Wfm* values.

### 5. Do NOT touch the entity or the migration (already landed). Do NOT touch the WFM store/loop (that is 3c-widget).

## VERIFY / DoD
- Object-store: both DTO records carry the 8 Wfm* members; handler maps+clamps all 8 (+ JSON-validates WfmThresholds); read-projection returns them; TenantsPage has a WFM tab wired load<->save; WfmServingStateGroups is a multiselect over Agent State GROUP names (not free text); new .resx keys present (en+ru).
- Soma (host-Chrome): POST /ops/build -> 0 errors; POST /ops/test?suite=unit -> failed 0. If Soma down: report build-evidence-pending (route to devops), do NOT claim build0 without evidence.
- Round-trip sanity (describe, operator/QA may live-check): open a tenant -> WFM tab -> change WfmWindowMinutes + toggle a serving group + Save -> reopen -> values persisted.

## COMMIT
- `bash tools/pre-commit-check.sh` -> commit.lock -> stage ONLY the claimed files -> `feat(web): WFM-3c-config — TenantSettings WFM fields DTO/command + Tenant modal WFM tab [shell-0609]` -> post-commit verify (§0.6) -> journal append -> release lock -> **NO push** -> §0.7 re-sync claimed files from HEAD.

## §0.6b CAPTURE -> role-shell §B
"WFM Phase-1 config: entity fields (TenantSettings.Wfm*) + EF migration landed on backend BEFORE the DTO/command/read-projection/UI carried them — plumbing the 8 fields end-to-end (DTO+Request records, handler clamp+JSON-validate, GetTenantSettings projection, Tenant modal WFM tab with a group-name multiselect for WfmServingStateGroups) is the shell half. Rule: a new tenant-setting is only user-editable once ALL FOUR carry it — entity, DTO/Request, command handler (with clamps + JSON validation for JSON fields), read-projection — plus the modal tab; a field present on the entity alone is invisible to admins." SOURCE:TenantSettings.cs:33-48 + TenantSettingsDto.cs + UpdateTenantSettingsCommand.cs @515c355.

## §0.6b BINDING POSTAMBLE — append RESULT to .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files TenantSettingsDto.cs + UpdateTenantSettingsCommand.cs + GetTenantSettings*.cs + TenantsPage.razor + SharedResources.resx . status done|failed . blockers . verified: object-store
```
