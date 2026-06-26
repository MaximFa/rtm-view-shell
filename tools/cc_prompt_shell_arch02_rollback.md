# CC task — ARCH-02 ROLLBACK (shell): git revert the global tenant-switch (unbreak admin pages) — AWAITING §4-BLESS — URGENT
> Operator: the ARCH-02 global Superadmin TopBar tenant-switch was an OVER-BUILD. It (1) didn't actually select, and (2) BROKE Business Units / Sites / Super Groups (and other admin pages) with `NpgsqlOperationInProgressException: A command is already in progress` — the MainLayout switcher's `GetTenantsQuery` runs concurrently on the scoped DbContext. ROLL IT BACK. The real need (a per-page tenant selector on the Reports page) is a SEPARATE follow-up task; this prompt is ONLY the rollback.
> Owner: role-shell. Executor: native CC. Branch: **v3**. **NO push** (§37).
> Revert EXACTLY two commits; keep everything else (FIX-E d47753d, bi scope_buonly 2a52c16, dba loads, phase5). No file conflict expected (ARCH-02 touched Identity/auth/middleware/MainLayout; the keepers touch reports files).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync if any manual file write needed; **Edit tool BANNED**. Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_arch02_rollback.md | status: open
### DIRECTIVE (spec->CC): ROLLBACK ARCH-02 — git revert 47a610c + 1f4d6dc only; keep FIX-E/scope_buonly/dba/phase5. Verify admin pages clean. NO push, §4-mechanics.
```

## §42.6 CLAIM
- whole-repo (revert touches ARCH-02 files only: CurrentUserAccessor.cs, TenantResolutionMiddleware.cs, TenantCircuitHandler.cs, Program.cs, MainLayout.razor, CustomClaimsPrincipalFactory.cs, SwitchTenantCommand.cs, resx). Coordinate via commit.lock.

## THE WORK
1. Confirm the two target commits and that nothing depends on them after:
```bash
git log --oneline -8   # confirm 47a610c (shell ARCH-02 web) + 1f4d6dc (backend ARCH-02 server) are present; note current tip
```
2. Revert BOTH, newest first (so the reverts apply cleanly):
```bash
git revert --no-edit 47a610c    # shell ARCH-02 Web half
git revert --no-edit 1f4d6dc    # backend ARCH-02 server half
```
   - If a revert reports conflicts (unexpected): STOP, `git revert --abort`, and report to the spec — do NOT force. (The keepers shouldn't conflict.)
   - Use the §0.4 index.lock / HEAD.lock plumbing workarounds if the mount blocks the revert commits.
3. Do NOT touch any reports file, FIX-E, scope_buonly, dba, or phase5 work — only the two reverts.

## VERIFY / DoD (role-shell §A — ЧП: LIVE, not object-store)
- **Object-store:** after the two reverts —
  - `git show HEAD~1:src/CcDashboard.Web/Components/Layout/MainLayout.razor` / current MainLayout has NO tenant switcher ("Switch tenant"/active_tenant_id UI GONE).
  - CurrentUserAccessor.cs / TenantResolutionMiddleware.cs / TenantCircuitHandler.cs back to pre-ARCH-02 (no active_tenant_id override; CurrentUserAccessor.TenantId reads tenant_id only).
  - CustomClaimsPrincipalFactory.cs no longer adds `active_tenant_id`; SwitchTenantCommand.cs removed/reverted.
  - FIX-E (ReportWidgetConfigModal/ReportWidgetConfig BU-only), scope_buonly, dba loads, phase5 all STILL PRESENT (unaffected).
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator):** Business Units / Sites / Super Groups + all admin pages LOAD CLEAN (no `NpgsqlOperationInProgressException`); the TopBar "Switch tenant…" control is GONE. App back to working.

## COMMIT (commit.lock + journal + no-push)
- The reverts ARE the commits. `bash tools/pre-commit-check.sh` (post-revert, vs HEAD) → exit 0.
- commit.lock around the reverts. Journal both revert hashes.
- `bash tools/cc_post_commit.sh shell-0609 <hash>` (or journal each). §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync the reverted files from HEAD.

## §0.6b CAPTURE -> role-shell §B (MANDATORY — process lesson): "'No X on the Reports page' meant ADD the existing per-page X to Reports, NOT build a new global feature. A global MainLayout query (GetTenantsQuery in the switcher) runs concurrently on the scoped DbContext → NpgsqlOperationInProgressException breaking sibling pages. Confirm the actual UX/scope (reuse existing per-page control) before building a feature epic; a global control sharing the scoped DbContext is a concurrency hazard." SOURCE: operator reversal 2026-06-26 + revert <hashes>. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <revert1> <revert2> . build <0 err>/unit <n/0> . files ARCH-02 set reverted . status done|failed . blockers . verified: object-store (LIVE admin-pages-clean = operator gate, pending)
```
