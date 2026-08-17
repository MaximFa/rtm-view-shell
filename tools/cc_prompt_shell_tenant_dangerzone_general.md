# CC task — Tenant modal: Danger Zone on GENERAL tab ONLY — §4-PASS (coordinator 2026-07-16) (Web-only, no dependency). RUN-CLEARED.
> Edit Tenant modal: the Danger Zone (Suspend/Delete tenant) renders at the modal bottom REGARDLESS of the active tab (it's after all the tab conditionals) → wrong context on Settings/Appearance/Agent States. FIX: render it ONLY when EditTab == "general".
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**. Narrow claim (1 file, 1 condition).

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
## BINDING 2026-07-16T08:18:34Z | spec: shell | directive: tools/cc_prompt_shell_tenant_dangerzone_general.md | status: open
### DIRECTIVE (spec->CC): Tenant Danger Zone renders only when EditTab=="general". v3, fix(web):, NO push. build0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Admin/TenantsPage.razor

## GROUNDING (object-store)
- TenantsPage.razor:504 — `@if (EditTenant.Status != TenantStatus.Deleted && EditTenant.Slug != "platform")` wraps the Danger Zone block (`<!-- Danger Zone -->` :503), rendered AFTER the tab conditionals (general :161 / settings :177 / appearance :274 / agentstates :370) → shows on every tab.

## THE WORK
- TenantsPage.razor:504 — add `EditTab == "general" && ` to the front of the condition:
  `@if (EditTab == "general" && EditTenant.Status != TenantStatus.Deleted && EditTenant.Slug != "platform")`
- Nothing else. (Keeps existing suspend/resume/delete-in-modal logic; only its VISIBILITY is now gated to the General tab.)

## VERIFY / DoD
- Object-store: the Danger Zone `@if` at :504 now also requires `EditTab == "general"`.
- Soma: /ops/build 0.
- ⛔ LIVE (coord 140): Danger Zone (Suspend/Delete) shows ONLY on the General tab; absent on Settings/Appearance/Agent States.

## COMMIT
- pre-commit-check → commit.lock → stage TenantsPage.razor → `fix(web): Tenant Danger Zone renders only on the General tab [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . files TenantsPage.razor . status . verified: object-store (LIVE danger-zone-general-only = coord 140)
```
