# CC task — v3 Audit Fix-A + fresh-migrate PROOF + binding (FOCUSED remainder)

> Owner: backend. Branch **v3**. Commit: web: (follow-up on top of 187e8ca). NO push (§37).
> WHY THIS FILE: the combined EF-fix prompt (cc_prompt_v3_ef_designer_fix.md) kept short-circuiting — the CC saw 187e8ca (App Designer.cs DONE) and exited "already complete", skipping the remainder. THIS prompt is ONLY the 3 leftover steps. There is NO Designer.cs work here — do NOT touch Migrations/App/** (187e8ca is correct and KEPT).
> §4 scope = coordinator-0622 20:34:56 (Audit Fix-A folded) + 20:46:43 (complete remainder). Same approved content, repackaged so it actually runs.
> §4-CONFIRM: coordinator-0622 2026-06-22T20:53:31Z — focused remainder = PASS. Explicit binding PREAMBLE(STEP-1)+RESULT(STEP-5) present (REVISE satisfied); 1-line Audit Fix-A exact; fresh-DB migrate PROOF required (paste); claims=InfrastructureServiceExtensions.cs only; 187e8ca untouched; v3, commit.lock, NO push. No-Designer.cs body = no short-circuit. EXECUTE authorized.

## DONE ALREADY (context — do NOT redo)
- 187e8ca (v3) = TASK A: 3 App Designer.cs + AppDbContextModelSnapshot.cs, ORIGINAL [Migration] IDs. VERIFIED correct. KEEP. Do NOT regenerate or touch them.

## INIT / discipline
- §0.6a integrity FIRST; **branch v3** (`git checkout v3`; verify `git rev-parse HEAD` == 187e8ca via object-store, §0.5 — NOT mount status; .git/HEAD has shown NUL/mount drift, restore if needed).
- §0.3 Python+fsync for any `.coord/` write; after the source edit: `sync` + `tail -3` + `wc -l` + NUL-check (0).
- §42.6 sync block: slug = your backend slug; **claims** = `["src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs"]` (ONLY this file — the 1-line Audit Fix-A). commit.lock around commit. pre-commit-check.sh. §0.7 re-sync from HEAD. **NO push.**

## STEP 1 — binding PREAMBLE (write to .coord/cc/backend.md BEFORE work, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_v3_audit_fixa.md | status: open
### DIRECTIVE: Audit Fix-A 1-line (InfrastructureServiceExtensions.cs AuditDbContext reg) + fresh-DB migrate PROOF (App+Audit, no 42883/42P07). Claims: InfrastructureServiceExtensions.cs. gate: fresh-DB clean. commit-prefix web:.
```

## STEP 2 — Audit Fix-A (the 1-line durable 42P07 fix)
In `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs`, the `AddDbContext<AuditDbContext>` registration (~line 53-59) currently has, inside `UseNpgsql(...)`, ONLY:
```csharp
npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
```
ADD the history-table line immediately after it so RUNTIME matches the design-time factory (DesignTimeDbContextFactory.cs:52) + the project lowercase convention:
```csharp
npg.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName);
npg.MigrationsHistoryTable("__ef_migrations_history", "audit");
```
Touch ONLY the AuditDbContext registration block. Do NOT change the App (lines 39/49) or BackendEmulation (line 68) registrations, and do NOT touch any migration file.
WHY: AuditDbContext has `HasDefaultSchema("audit")` → without this line EF runtime uses `audit."__EFMigrationsHistory"` (capitalised) while design-time uses `audit.__ef_migrations_history` (lowercase) → runtime never finds InitialCreate → re-runs CreateTable audit_logs → persistent 42P07. This line aligns them.

## STEP 3 — build + fresh-DB migrate PROOF (the acceptance — must PASTE the output)
- `dotnet build CcDashboard.sln` → 0 errors.
- Spin a FRESH scratch Postgres (Testcontainers or a throwaway empty DB). Run `CcDashboard.Web.exe migrate` (App + Audit). CAPTURE the console output. ASSERT + show:
  - all 3 App migrations + Audit InitialCreate applied; `public.__ef_migrations_history` has the 3 App rows; **audit.__ef_migrations_history** (lowercase — proves Fix-A) has InitialCreate;
  - hist_*/arch_*/user_report + audit.audit_logs present;
  - a SECOND `migrate` run = no-op; NO 42883, NO 42P07 (even on the 2nd run).
- PASTE this migrate output into the binding RESULT (STEP 5).

## STEP 4 — commit (follow-up web: on top of 187e8ca; commit.lock; NO push)
`git add src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs` → commit `web: v3 Audit Fix-A — align runtime AuditDbContext history table to audit.__ef_migrations_history (durable 42P07 fix)`. §0.6 post-commit verify (working tree == HEAD by hash). NO push.

## STEP 5 — binding POSTAMBLE / RESULT (write to .coord/cc/backend.md at END, Python+fsync)
```
### RESULT: commits <hash> . build <0 errors> . files InfrastructureServiceExtensions.cs(+1) . status done|failed . blockers . verified: object-store
<paste the fresh-DB migrate output here: App+Audit applied, 2nd-run no-op, NO 42883/42P07>
```
Leave `> consumed <UTC>` for the coordinator. Relay a 2-line digest to inbox/coordinator.md.

## ACCEPTANCE
- InfrastructureServiceExtensions.cs AuditDbContext registration has `MigrationsHistoryTable("__ef_migrations_history","audit")` (one line added; nothing else changed).
- Fresh-DB `Web.exe migrate` (App+Audit) PROVEN clean: all applied, history in lowercase tables, 2nd-run no-op, NO 42883/NO 42P07 — output pasted in RESULT.
- One follow-up web: commit on v3, commit.lock, NO push. §0.6b binding PREAMBLE+RESULT written. 187e8ca untouched.
