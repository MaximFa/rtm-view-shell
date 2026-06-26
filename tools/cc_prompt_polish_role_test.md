# CC task — polish + commit role-test.md (§A ROLE broaden + §C run-green) — coordinator-authored (§45 generate)
> Coordinator polish per operator directive 2026-06-23 ("проверь и отшлифуй"). Executor: native CC. Branch **v3**. Commit `docs:`. **NO push** (§37).
> WHY: role-test.md is WORKING-TREE ONLY (untracked) — PD-007 loss risk. Commit it (durability) WITH two polish edits. RE-AUTHORED against the CURRENT v1.1 (test added a CYCLE START §A cardinal + a 5th §B lesson + bumped version to 1.1 since v1.0). Targeted edits ONLY — PRESERVE test's CYCLE START cardinal + ALL 5 §B lessons verbatim. Curator audits ASYNC (role-skill-standard: not a per-write gate).

## INIT — branch v3 + integrity
- `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 (object-store, not mount status §0.5).
- §0.2: confirm `.claude/skills/role-test/role-test.md` exists in WT (~39 lines, version: 1.1, proper EOF, 0 NUL) BEFORE editing. If missing/truncated -> STOP, flag coordinator (HEAD has no copy; cannot restore).
- Read: .claude/skills/session-coord/session-coord.md ; .coord/protocols/role-skill-standard.md.

## §42.6 sync — slug coordinator-0623 (file-mode)
- S1: `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (current = CLOSED tombstone -> proceed).
- S2 claims (file-mode): `.claude/skills/role-test/role-test.md` ONLY.
- S3 commit.lock (owner coordinator-0623) around add/commit. §0.3 Python read/modify/write + os.fsync; after write: sync + tail -3 + wc -l + NUL-check (0).
- §0.6b binding PRE/POST -> .coord/cc/coordinator.md. NO push.

## EDIT 1 — §A ROLE line: broaden from "v3 Historical-Reports" to the general functional gate
Python read the file. Replace EXACTLY this line (it is unchanged from v1.0 — anchor valid):
```
- ROLE: QA owner of the v3 Historical-Reports functional gate; a MANDATORY push-quorum ack (peer of security + techwriter), NOT "stake-clear". v3 does not push without my GREEN. SOURCE: CLAUDE.md §42.7 + coordinator-0623 2026-06-23.
```
with:
```
- ROLE: QA owner of the FUNCTIONAL GATE — (a) IMMEDIATE per-change verification right after any fix/feature lands; (b) the PRE-PUSH REGRESSION pass (UI + DB over Dashboards + Historical Reports, testing/regression_checklist.md). A MANDATORY push-quorum ack (peer of security + techwriter), NOT "stake-clear"; no push without my GREEN. SOURCE: CLAUDE.md §42.7 + operator norm 2026-06-23.
```

## EDIT 2 — replace the ENTIRE §C section with run-green checks (NORM-CUR-11c)
Replace everything from the line `## §C VERIFY (at init)` to END-OF-FILE with EXACTLY:
```
## §C VERIFY (at init — run EACH; expected result pinned; a mismatch = INVESTIGATE, do NOT blindly supersede a truth on a check you did not prove — NORM-CUR-11c)
- C1 Soma reachable+auth: `tools/Soma/USAGE.md` present AND a `Soma:Token` key in tools/Soma/appsettings.json (gitignored; template appsettings.example.json) — expect both present; at runtime `GET /health` -> 200. (run-green 2026-06-23)
- C2 Shell port: `grep -o localhost:5239 src/CcDashboard.Web/Properties/launchSettings.json` -> a hit (app serves https://localhost:5239). (run-green 2026-06-23)
- C3 Standing checklist: `git cat-file -e v3:testing/regression_checklist.md` (tracked) AND `git show v3:testing/regression_checklist.md | grep -c 'F-QA-'` >= 3 (F-QA-1/5/6 regression guards). (run-green: 7, 2026-06-23)
- C4 QA-gate norm intact: `grep -c 'Functional/QA gate (mandatory' CLAUDE.md` = 1 (§42.7 — the basis of my mandatory ack). (run-green: 1, 2026-06-23)
```
(NOTE: §C is the LAST section in the file, so this replace-to-EOF affects ONLY §C; §A (incl test's CYCLE START cardinal) and §B (all 5 lessons) are BEFORE §C and are untouched.)

## DO NOT TOUCH (verify preserved)
- frontmatter: version stays `1.1`, last_verified `2026-06-24`, owner test / reviewer curator — UNCHANGED (do NOT bump).
- §A other cardinals: VERIFICATION METHOD 1-3, CYCLE START (preflight, test-added 2026-06-24), QA REPORTS, IDENTITY — UNCHANGED.
- §B LESSONS: ALL 5 dated lessons VERBATIM (do not rewrite/reorder/drop the F-QA-7 stop-releases-port one).

## VERIFY (before commit)
- `git diff --name-only` (after add) = `.claude/skills/role-test/role-test.md` ONLY.
- New §A ROLE line present (`grep -c "QA owner of the FUNCTIONAL GATE" role-test.md` = 1); old line gone (`grep -c "v3 Historical-Reports functional gate"` = 0).
- §C has C1..C4 (`grep -c "^- C[1-4] " role-test.md` = 4); CYCLE START cardinal still present (`grep -c "CYCLE START (preflight" role-test.md` = 1); §B still 5 lessons (`grep -c "^- 2026-" role-test.md` >= 5); version: 1.1.
- proper EOF, 0 NUL.

## Commit (docs:, commit.lock, NO push)
`git add -f .claude/skills/role-test/role-test.md` (`.claude/` gitignored — MUST -f) -> commit -m "docs: commit + polish role-test.md v1.1 (§A ROLE broaden to general functional gate; §C run-green NORM-CUR-11c; preserve test CYCLE START + §B) [coordinator-0623]" -> §0.6 post-commit (`git show v3:.claude/skills/role-test/role-test.md | grep -c "QA owner of the FUNCTIONAL GATE"` = 1) -> `bash tools/cc_post_commit.sh coordinator-0623 <hash>` -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/coordinator.md (done): commit <hash>; role-test.md v1.1 committed+tracked v3; §A ROLE broadened; §C = C1..C4 run-green; test CYCLE START + 5 §B lessons preserved; 1 file; NO push. verified: object-store. NOTE: curator async §45 audit pending.

## Report (chat): commit hash; confirm 1 file, §A/§C edits applied + CYCLE START/§B preserved; NO push.
