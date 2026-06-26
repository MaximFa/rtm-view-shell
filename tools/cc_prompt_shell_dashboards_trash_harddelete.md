# CC task — HARD-DEL-01c (dashboards): hard-delete icon in the Trash tab (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Operator HARD-DEL-01: add a permanent-delete icon to the Trash table rows of dashboards (reports half is folded into the C list-parity prompt). Backend landed. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). Small, scoped edit to the existing dashboard Trash tab.

## INIT — branch v3 + role-shell §A/§C + §40 + integrity. §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push.

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Dashboard/ScreenListPage.razor (MODIFY — Trash tab only, ~L207-238: it has Restore, add Hard-delete)
- 3x Resources/SharedResources.{en-US,ru-RU,he-IL}.resx (Hard-delete strings, if not already present from C — reuse if shared keys)
- (role-shell.md via git add -f if CAPTURE)
- This is the ONLY intended edit to ScreenListPage (the Trash-row action). Do NOT touch the main list / editor / shared selectors otherwise.

## BACKEND (landed, bind exactly)
`PurgeDashboardCommand(Guid Id) : IRequest` (v3 `cad6868`) — permanent removal (widgets+permissions cascade). Throws: NotFound (not in Trash / wrong tenant), DomainException (target not IsDeleted), Forbidden (non-Superadmin lacks Delete=4). Server-enforced perm (CODE-03) — show the icon per row; server is the gate.

## THE WORK
- In the Trash tab table rows (where Restore currently is), ADD a per-row **Hard-delete** icon button `bi-trash3` (`btn btn-sm btn-icon` or match the existing Restore button's wrapper) next to Restore.
- On click → MANDATORY confirmation dialog: "Permanently delete \"{name}\"? This cannot be undone." Cancel / Delete (btn-danger). On confirm → `PurgeDashboardCommand(Id)` → on success reload the Trash list + the deleted-count badge.
- Reuse the project's confirm pattern (if an App* confirm modal is wired use it; else the inline 2-step / small modal already used elsewhere — match the existing dashboard delete-confirm style).
- @L for all new strings (en/ru/he); reuse Common_*/Screens_* where identical. Catch errors → Logger.LogError (never bare). Dark/light; a11y (button title, focus).

## OUT OF SCOPE: anything outside the Trash-tab row action.

## VERIFY / DoD (role-shell §A)
- Object-store: ScreenListPage Trash row has a Hard-delete `bi-trash3` action → PurgeDashboardCommand behind a confirm dialog; main list / editor / shared selectors UNTOUCHED (diff = Trash-tab + resx only); @L 3 locales.
- **Soma: compile via /shell/start|restart healthy + serilog [ERR]/[FTL] clean** (+ /ops/test?suite=unit — safe now).
- **VISUAL CHROME (light+dark):** /screens → Trash tab → row shows Hard-delete icon; clicking opens the confirm; (with a soft-deleted dashboard) confirm removes it. + parity: rest of /screens byte-identical.

## §0.6b CAPTURE -> role-shell §B if real lesson. Commit fix:, NO push, commit.lock. Binding RESULT -> cc/shell.md. Report: commit, files, build/serilog, screenshots, parity confirm.
