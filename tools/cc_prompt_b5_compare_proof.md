# CC task — B-5 PROOF: quick Compare-ToBaseline run, confirm Dimension [A] collapsed (READ-ONLY)
> §4-DRAFTED by coordinator-0612 2026-06-14T07:49Z. Owner: dba-0610. Executor: native CC, Windows, PG18. READ-ONLY: Compare never writes the DB or repo.
> NO edits, NO commit, NO push, NO binding. Pure verification of B-5 (01d4db6 regen schema.sql).

## Why
B-5 regenerated db/schema.sql (dropped 9 phantom tables). Structural gates verified by object-store, but the empirical Compare
[A] number was not recorded. Confirm: comparing a real EF-built DB against the NEW schema.sql now yields [A] ~0 (was ~237-454
when the old schema.sql carried phantoms). This closes the B-5 caveat and baselines E2.

## Steps
1. §0.2 light: `git status --short`; confirm branch v2-backend, HEAD == 01d4db6 (or later). No file edits in this task.
2. Pick a real EF-built target DB (in priority order, use the first that exists & is reachable):
   (a) the local dev DB `rtmviewdb` (default) — EF-built, no phantoms; OR
   (b) the kept regen scratch `rtmviewdb_regen` (if Regen-Schema was run with -KeepScratch); OR
   (c) the live 45 server DB (operator-supplied -DBHost/-Password) — the most meaningful (real prod vs new baseline).
   State which target you used.
3. Run (read-only):
```
powershell -ExecutionPolicy Bypass -File db\tools\Compare-ToBaseline.ps1 -Database <target> -Password "<pw>"
```
   (add -DBHost for 45 if used). It writes a baseline_delta_<db>_<ts>.txt report — that's an OutDir artifact, not a repo change.
4. Open the produced baseline_delta_*.txt and report the SUMMARY line + each DIMENSION:
   - DIMENSION A (SCHEMA): missing/extra line counts — EXPECT ~0 (a few cosmetic max). This is the proof.
   - DIMENSION B (routine kind): expect the known [B]=1 NGC_CreateSupergroup false-positive (multi-overload) — note it (E2 will clear it).
   - DIMENSION C (data), D (migration ledger): report as-is.

## Report (chat) — NO commit/push
- Target DB used.
- Full A/B/C/D SUMMARY (paste the SUMMARY line + Dimension A missing/extra counts).
- Verdict: did [A] collapse vs the historical ~237-454? If [A] is still large, paste the top extra/missing objects so we can drill (B-5 may need a fix).
