# CC task — TAG the physically server-verified product version (rollback anchor)

> Owner: devops (slug devops-0619). §4-PASS coordinator-0612 2026-06-21T18:23:13Z. Operator-confirmed anchor: b58e2c2.
> This is a DEDICATED TAG-PUSH prompt (the ONLY push it performs is the annotated TAG ref — NOT branch commits, §37).
> Purpose: pin the version PHYSICALLY DEPLOYED + SMOKE-VERIFIED on servers 234 AND 45 (2026-06-19) as the precise
> FE/BE/DB rollback anchor before the v3 reports work. (Journal 530: "BOTH SERVERS (234+45) DEPLOY COMPLETE — technical
> Compare B=0 + functional UI/widgets".)

## Why b58e2c2 (not 5206633/HEAD)
- b58e2c2 (2026-06-17, T6) = the Shell+RTM code shipped in package 234_b58e2c2_19062026_Full, deployed to 234 AND 45,
  smoke-confirmed by operator. The db/ module at b58e2c2 is the PRE-carve schema = exactly what the servers ran.
- Everything after (3516a68, 5206633 #2-barrier, today's incident/R0/reports up to HEAD) was CODED but NEVER server-tested.
- b58e2c2 is an ANCESTOR of origin/v2-backend (5206633) -> pushing the tag publishes ONLY the tag ref, NO new commits.

## INIT / discipline
- §0.2 integrity (read-only here — no working-tree writes). §0.5 object-store. NO branch commits. NO branch push.
- This prompt does NOT touch the index/working tree; it only creates + pushes a tag ref.

## THE WORK
1. Create the annotated tag on b58e2c2 (native git, Windows):
```
git tag -a v2-server-verified-20260619 b58e2c2 -m "Physically server-verified product (FE src/ + BE RTM/ + DB db/). Deployed + smoke-confirmed on servers 234 AND 45 on 2026-06-19 (Compare B=0; UI/widgets functional). Rollback anchor before v3 reports work. Live-data snapshots: 234 C:\RTMView\Backup\19062026_1134, 45 C:\RTMView\Backup\19062026_1214."
```
2. Push the TAG ONLY:
```
git push origin v2-server-verified-20260619
```
3. VERIFY (object-store):
```
git show -s --format="%H" v2-server-verified-20260619^{commit}   # must == b58e2c2 full hash
git ls-remote --tags origin | grep v2-server-verified-20260619    # tag present on origin
```

## ACCEPTANCE
- Annotated tag v2-server-verified-20260619 points at b58e2c2; present on origin (git ls-remote shows it).
- NO branch commits pushed (git log origin/v2-backend unchanged at 5206633; unpushed branch work untouched).

## ROLLBACK RUNBOOK (document in deploy/ROLLBACK.md, devops claim)
To roll the product back to this verified version:
1. Code: `git checkout v2-server-verified-20260619` (FE src/ + BE RTM/ + DB module db/ all at this point).
2. DB schema/functions/seed: rebuild from this commit's db/ (per db/REBUILD_RUNBOOK at that commit — PRE-carve).
3. Live data: restore from the deploy-time pg_dump (234: C:\RTMView\Backup\19062026_1134; 45: ...19062026_1214),
   or a fresher pg_dump if taken later.
4. Redeploy the b58e2c2 binaries (package 234_b58e2c2_19062026_Full) per deploy/Install or Update scripts.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md (tag hash, origin presence, ROLLBACK.md committed). 
## NOTE: ROLLBACK.md is a normal docs/deploy commit (db:/deploy: prefix) under commit.lock — that part follows §37 (NO branch push); only the TAG is pushed by this prompt.
