# CC Task — append section 6 (Widget grid lifecycle, DB-verified) to testing/regression_checklist.md

> test (QA) authored this after running the scenario live (Queue Grid -> RTSGrid_Grid, Agent Grid -> RTSUserGrid_Grid; add/config/save/delete all DB-verified GREEN). Append the section verbatim; bump the revision-history table.

## Mandatory: read .claude/skills/session-coord/session-coord.md first.
## Git push: NONE.

## Step 0a §0.6a integrity; git fetch origin v3; HEAD ancestor/equal of origin/v3.
## Step 0b §0.6b binding: append to .coord/cc/test.md PREAMBLE (status open) + POSTAMBLE RESULT after commit.
## Sync: slug test-5-0607; claims (file): testing/regression_checklist.md ; tools/cc_prompt_regression_wgsection.md. S1 barrier check; S2 coord_check_claims; S3 commit.lock. Writes via Python+os.fsync (Edit BANNED).

## Deliverable — APPEND this section to testing/regression_checklist.md, immediately AFTER section 5 (Console/log) and BEFORE the "## Verdict" line (Python read->insert->fsync):

----BEGIN section----

## 6. Widget grid lifecycle — DB-verified (Queue Grid + Agent Grid)
*Confirms widget add/config/save/delete materialises & cleans the grid config tables. KEY: a widget must be CONFIGURED (BU + at least a row/columns) before Save — an unconfigured widget shows "Save widget config to connect" and creates NO grid row.*
- [ ] Create a dashboard -> open editor (/screens/{id}/edit) -> open the widget palette.
- [ ] **Queue Grid**: drag onto canvas -> config (Rows: add a Business Unit row; Columns: default 5 QM/Agent-Group metrics) -> widget Save -> dashboard Save. DB (Soma): `RTSGrid_Grid` +1 (and `RTSGrid_Row`/`RTSGrid_Column`/`RTSGrid_Cell` created).
- [ ] Delete Queue Grid (trash -> confirm "also delete the associated grid configuration") -> dashboard Save. DB: `RTSGrid_Grid` back to baseline (Row/Cell/dashboard_widgets = 0).
- [ ] **Agent Grid**: drag onto canvas -> config (General: select a Business Unit; Columns: default 5 agent metrics) -> widget Save -> dashboard Save. DB: `RTSUserGrid_Grid` +1 (`RTSUserGrid_Column` created). (Agent Grid -> RTSUserGrid_*, NOT RTSGrid_*.)
- [ ] View Mode (/screens/{id}): Agent Grid renders ("Connection failed/Retry" is OK in dev = no live RTM relay feed).
- [ ] Edit -> delete Agent Grid -> dashboard Save. DB: `RTSUserGrid_Grid` back to baseline.
- [ ] Clean up: delete the test dashboard.

----END section----

Also bump the revision-history table: add a row `| v2 | 2026-06-24 | Added section 6: widget grid lifecycle DB-verify (Queue->RTSGrid_Grid, Agent->RTSUserGrid_Grid; config-before-save key). |`.
Verify: `grep -c 'Widget grid lifecycle' testing/regression_checklist.md` == 1; `tail -3` ends with the v2 row.

## Commit: `test: regression checklist section 6 — widget grid lifecycle DB-verify (Queue/Agent grids)`
acquire commit.lock -> pre-commit-check.sh -> git add testing/regression_checklist.md -> commit -> §0.6 verify -> `bash tools/cc_post_commit.sh test-5-0607 $(git log -1 --format=%h)` -> sync -> PD-007 re-sync. NO push.

## Acceptance: section 6 present in testing/regression_checklist.md on v3; one test: commit; binding RESULT written; no push.
