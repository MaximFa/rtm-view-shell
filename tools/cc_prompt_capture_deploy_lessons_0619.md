# CC task — CAPTURE today's deploy lessons into role-skills §B + CLAUDE.md (Phase 2)
> §4-PASS coordinator-0612 2026-06-19T09:23:30Z. Source of truth = .coord/lessons_today_0619.md (staged, source-pinned). Commit `docs:`. NO push.
> Two prod deploys today (234 + 45, 2026-06-19) surfaced reusable lessons. Capture them durably per §45 (Specialist Protocol) / §0.6b CAPTURE.

## INIT + discipline
- §0.2 integrity; branch v2-backend; §0.5 object-store. §0.3 Python+fsync for ALL writes (these are tracked .md — write via Python, verify tail/wc). Edit tool BANNED.
- Binding PREAMBLE -> .coord/cc/coordinator.md. commit.lock around the commit. NO push (§37).
- READ FIRST: .coord/lessons_today_0619.md — it has the exact lesson text + SOURCE pins per role. Use it verbatim (adapt to each skill's §B line format).

## THE WORK — append to each role-skill §B (append-only, dated, source-pinned, status: active)
Format per §45.2: `<2026-06-19> · <what happened> · <rule> · SOURCE:<commit/journal/file> · status: active`

1. `.claude/skills/role-devops/role-devops.md` §B — add (from lessons doc role-devops block):
   - StrictMode scalar.Count -> wrap @() (SOURCE: de5e835)
   - §35 BOM re-encode must be BINARY write b"\xef\xbb\xbf"+CRLF (SOURCE: d62e704->024feef)
   - deploy must PRESERVE operator config incl appsettings.json (SOURCE: 234 28P01; e46e849)
   - pg_dump completeness = run as object owner/postgres (SOURCE: 234 STEP-4 flag)
   - staged pkg-copy PD-007 -> re-materialize from HEAD + byte-verify before swap
   Also add to role-devops §A (cardinal, if not present): "MANDATORY Compare-ToBaseline before ANY deploy; never reuse another server's migration list or rely on memory (SOURCE: 234 FULL-10 vs 45's different 10-list, 2026-06-19)."

2. `.claude/skills/role-dba/role-dba.md` §B — add (from role-dba block):
   - apply-user for DDL migration set = postgres/owner, read-only Compare gate stays app-user (SOURCE: dba-0610 2026-06-19)
   - idempotent-migration NOTICEs on populated server are EXPECTED not errors (SOURCE: 234/45 STEP-4b logs)
   - pre-ledger migrations (pre-_002) cannot self-record -> permanent D-drift noise; optional ledger-backfill (SOURCE: 234 Compare 114916 + 45 Compare 122035, both D=4)

3. `.claude/skills/role-coordinator/role-coordinator.md` (or session-coord if no role-coordinator) §B — add:
   - Anti-saga deploy discipline: stepwise via inbox; mandatory Compare gate BEFORE apply; pg_dump FIRST; ANY tool error -> STOP + rollback from backup, never improvise; config clobber -> restore from deploy binary-backup; verify EVERY binding RESULT natively by object-store before greenlight (SOURCE: 234+45 deploys 2026-06-19, zero data loss across 4 caught defects)
   §A cardinal (if role-coordinator skill exists): the MANDATORY Compare-before-deploy headline (same as devops §A).
   NOTE: if `.claude/skills/role-coordinator/` does not exist, put the coordinator lessons in `.claude/skills/session-coord/session-coord.md` (a new dated subsection under lessons/L-SC) instead — verify which exists first (ls).

4. `CLAUDE.md` — add a short deploy-discipline note in the deploy area (§24 or a new §-pointer): the MANDATORY Compare-before-deploy rule + "deploy preserves operator config + pg_dump as owner + StrictMode @()". Keep it tight (a few lines), point to the role-skills for detail.

## VERIFY (object-store)
- Each target file: the new §B line(s) present (grep the SOURCE pins / dates); file not truncated (tail shows proper end); §A headline present where added.
- `ls .claude/skills/role-coordinator/` first to decide target #3.

## COMMIT (docs:, NO push) under commit.lock
`docs: capture 2026-06-19 deploy lessons into role-skills §B (devops/dba/coordinator) + CLAUDE.md — mandatory Compare-before-deploy, StrictMode @(), BOM, preserve-config, pg_dump-owner, apply-user=postgres, pre-ledger noise`
then §0.6 post-commit + §0.7 re-sync + sync.

## REPORT -> binding cc/coordinator.md RESULT + inbox/coordinator.md: commit hash; which files got which lessons; §A headline added where; CLAUDE.md note location. NO push.
