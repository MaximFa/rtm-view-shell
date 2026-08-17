# CC task — H: per-tenant username unique index — AMENDED per dba ruling, AWAITING §4
> Owner: backend (slug **backend-0626**). Branch **v3**. Commit `fix:` (EF migration under AppDbContext). **NO push** (§37). ⛔ЧП B item 2.
> SCHEMA CHANGE → routed to **dba** for review (§26.2) BEFORE coordinator §4. No run until dba-OK + §4-bless.
> §4-REVIEW: PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for dba-review then coordinator §4.

## ROOT (object-store @ v3 HEAD a261840)
`identity.users` still carries Identity's DEFAULT GLOBAL unique index `UserNameIndex` (unique `NormalizedUserName`, cross-tenant) — snapshot `AppDbContextModelSnapshot.cs:1356` `HasDatabaseName("UserNameIndex")`. §6.2 requires PER-TENANT uniqueness. On a 2nd tenant whose admin normalizes to the same `NormalizedUserName` ("ADMIN") → **23505 unique violation** → Shell seed crash (the 140 restart crash, item 2).
- The EMAIL side is ALREADY per-tenant: `AppDbContext.cs:86` `e.HasIndex(x => new { x.NormalizedEmail, x.TenantId }).IsUnique().HasFilter("\"IsActive\" = true");`. Only the USERNAME side is missing its composite + still has the global unique.
- ApplicationUser config block = `AppDbContext.cs:84-91`.

## THE WORK
**A. `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs`** — in the `ApplicationUser` config block (:84-91), (1) neutralize the global unique `UserNameIndex`, (2) add the per-tenant username unique:
```csharp
mb.Entity<ApplicationUser>(e =>
{
    e.HasIndex(x => new { x.NormalizedEmail, x.TenantId }).IsUnique().HasFilter("\"IsActive\" = true"); // existing — unchanged
    // [H] per-tenant username uniqueness (§6.2) — replaces the global UserNameIndex unique
    e.HasIndex(x => x.NormalizedUserName).HasDatabaseName("UserNameIndex").IsUnique(false);  // drop the cross-tenant unique (keep for lookup)
    e.HasIndex(x => new { x.NormalizedUserName, x.TenantId }).IsUnique().HasFilter("\"IsActive\" = true"); // NEW composite unique (mirrors email)
    e.Property(x => x.FirstName).HasMaxLength(100);
    e.Property(x => x.LastName).HasMaxLength(100);
    e.Property(x => x.PreferredLocale).HasMaxLength(10).HasDefaultValue("en-US");
    e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
});
```
✅ dba RULED (2026-07-13) — apply EXACTLY:
1. **KEEP** the global `UserNameIndex` as NON-UNIQUE (`IsUnique(false)`) — do NOT drop it (mirrors Identity's default non-unique EmailIndex). Neutralize ONLY its uniqueness.
2. Composite `(NormalizedUserName, TenantId)` UNIQUE **WITH `HasFilter("\"IsActive\" = true")`** — byte-mirror of the email composite (AppDbContext:86); partial-unique on active rows.
Final index set (symmetric): EmailIndex(non-unique) + (NormalizedEmail,TenantId) unique WHERE IsActive ; UserNameIndex(non-unique) + (NormalizedUserName,TenantId) unique WHERE IsActive.

**B. Generate the EF migration (AppDbContext):**
```
dotnet ef migrations add PerTenantUserNameIndex --context AppDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web
```
Expected DDL (dba-ruled): recreate `UserNameIndex` as NON-UNIQUE (DROP + CREATE non-unique) + `CREATE UNIQUE INDEX "IX_users_NormalizedUserName_TenantId" ON "identity"."users" ("NormalizedUserName","TenantId") WHERE "IsActive" = true`. No email-index change (@86 already applied).

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`; `.claude/skills/role-backend/role-backend.md` §A (⛔ЧП) + §C.
- Object-store grounding: AppDbContext.cs (:84-91 ApplicationUser config, :86 email composite pattern); AppDbContextModelSnapshot.cs (:1352 EmailIndex, :1356 UserNameIndex); §6.2 data-model; MAINT-04 (EF migrations only). ⚠ NO §38a/db_patch_history line — this is an EF APP migration (auto-records in __ef_migrations_history); §38a is for the db/migrations/*.sql module ONLY (dba correction).

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git rev-parse --abbrev-ref HEAD` == **v3**; `git status --short`; hash-verify claimed files vs HEAD (§0.5); restore PD-007 truncation from HEAD first.
- §0.3 Python+fsync; Edit BANNED for hand-writes. The migration files are EF-GENERATED (do not hand-author the Designer). After edits: `sync`+`tail -3`+`wc -l`+NUL(0). Preserve LF/no-BOM.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP on OPEN FREEZE. Slug = **backend-0626**. **Claim (file-mode)** = `["src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs", "src/CcDashboard.Infrastructure/Migrations/App/**"]` (the new migration + Designer + snapshot update). NARROW-ADD (L-SC-09): `git add` ONLY these; post-commit `git show --stat` = only AppDbContext.cs + the new migration/Designer + AppDbContextModelSnapshot.cs, zero unrelated files/deletions, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync. **NO push.**

## STEP 1 — binding PREAMBLE (.coord/cc/backend.md, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_pertenant_username_index.md | status: open
### DIRECTIVE: H — per-tenant username unique index. AppDbContext ApplicationUser: drop/neutralize global UserNameIndex unique + add (NormalizedUserName,TenantId) unique; EF migration PerTenantUserNameIndex (no §38a — EF app migration). dba-ruled. Claim: AppDbContext.cs + Migrations/App. gate: build 0 + unit failed 0. fix:.
```

## STEP 2 — apply config (A per dba ruling), STEP 3 — generate migration (B). NO §38a line.

## STEP 4 — VERIFY (GREEN gate — PASTE)
- `dotnet build CcDashboard.sln` → 0 errors.
- `dotnet test tests/CcDashboard.Tests.Unit` → failed=0 (counts). (Soma /ops/build + /ops/test?suite=unit.)
- `dotnet ef migrations script --idempotent --context AppDbContext ...` → PASTE the generated Up() DDL (recreates UserNameIndex non-unique + creates the composite unique WHERE IsActive; NO db_patch_history insert).
- Object-store: only AppDbContext.cs + the new migration + Designer + snapshot; zero unrelated deletions.
- ⚠ ACCEPTANCE (runtime, owned by devops/QA/coord on 140): migration applies clean (140 safe — single admin under 019f58ea, crashed seed inserted NO 2nd admin, spurious 019f5978 empty); after apply a 2nd tenant can seed an "admin" without 23505.

## STEP 5 — commit (fix:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add` the claimed files ONLY → `git status --short` (zero unrelated D) → commit `fix(db): per-tenant username unique index (drop global UserNameIndex) - §6.2 [backend]` → §0.6 post-commit → `bash tools/cc_post_commit.sh backend-0626 <hash>` → §0.7 re-sync → sync. **NO push.**

## STEP 6 — binding POSTAMBLE / RESULT (.coord/cc/backend.md, Python+fsync)
```
### RESULT: commit <hash> . files AppDbContext.cs + <migration>.cs/.Designer.cs + AppDbContextModelSnapshot.cs . build 0 . unit passed/failed <N>/<N> . migration Up() DDL <pasted> . dba-decisions applied . only-claimed/zero-deletion . status done|failed . verified: object-store . 140-apply seal -> devops/QA/coord
<paste build + unit + migration script>
```
Relay a 2-line digest to inbox/coordinator.md (commit + the DDL + which dba decisions were taken).

## ACCEPTANCE (GREEN gate)
- Global `UserNameIndex` unique dropped/neutralized; `(NormalizedUserName, TenantId)` unique added (per §6.2, mirroring the email composite). Email index @86 unchanged.
- EF migration PerTenantUserNameIndex generated (App+Designer+snapshot). NO §38a/db_patch_history line.
- build 0 + unit failed 0; only claimed files; zero unrelated deletions; fix: on v3; commit.lock; NO push. Binding PRE+POST. dba decisions (1 drop-vs-nonunique, 2 filter) recorded.
