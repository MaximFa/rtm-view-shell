# CC task — GIT RECONCILE: relocate Garnet from v3 to v2-backend (coordinator-owned, NATIVE CC)

> Owner: coordinator-0622. NATIVE Windows CC ONLY (Cowork mount cannot do git surgery). **NO push (§37).**
> WHY: branch-map says Garnet (INC-001 d) = **v2-backend** stream, but 8392e56 (Garnet PoC config) was committed on **v3** (reports line) + the filled PoC artifacts are uncommitted on the v3 WT. This relocates them so (a) v3 is Garnet-free for its push barrier, (b) Garnet work sits on v2-backend for Phase 2.
> HOLD: all new v3 commits are held by the coordinator during this op (shell Track B, bi SF-BI-002). Do this FIRST.

## PRE-FLIGHT — STOP on ANY mismatch, report to inbox/coordinator.md
0. Phantom lock: if `.git\index.lock` exists -> `del ".git\index.lock"` (native Windows CAN unlink; the mount cannot). Confirm `git status` runs.
1. §0.2/§0.5 object-store integrity. VERIFY these EXACT facts (STOP if any differ):
   - `git rev-parse v3`            == 63045d8...
   - `git rev-parse v2-backend`    == 5e9e22d...
   - `git rev-parse origin/v3`     == 0996a91...
   - `git rev-parse 8392e56^`      == 62a8759...   (8392e56 parent)
   - `git log --oneline 0996a91..v3` == exactly: 63045d8, 0cc1d0d, 8392e56, 62a8759, 53aa308
2. Identify the Garnet WT delta to move (and ONLY these):
   - `docs/incidents/INC-001_garnet_poc_results.md`  (M — filled GREEN version)
   - `infra/garnet-poc/Verify-GarnetPoC.ps1`         (M — BOM/REDISCLI_AUTH/TTL fixes)
   - `infra/garnet-poc/BackplaneTest/`               (?? untracked — 2-instance harness)
   `git status --short` WILL also show UNRELATED M files (spine: role-coordinator.md / role-skill-standard.md / etc.; .coord/* is gitignored). DO NOT touch or commit those — they belong to a separate v2-backend spine commit. ONLY the 3 Garnet paths above move here.

## SEQUENCE (verify after each step; STOP+report on any conflict)
A. Stash ONLY the Garnet WT delta (incl. untracked), leave everything else:
   `git stash push -u -m "garnet-wt-reloc" -- docs/incidents/INC-001_garnet_poc_results.md infra/garnet-poc/Verify-GarnetPoC.ps1 infra/garnet-poc/BackplaneTest/`
   VERIFY: `git status --short` no longer lists those 3; other M files still present.
B. Move the committed Garnet config (8392e56) onto v2-backend:
   `git checkout v2-backend`  (if checkout refuses due to WT conflict -> STOP, report)
   acquire commit.lock (.coord/locks/commit.lock, §0.4 temp-index if index.lock re-appears)
   `git cherry-pick 8392e56`  (infra files are new on v2-backend -> expect clean; conflict -> STOP)
   VERIFY: `git show --stat HEAD` lists the 4 8392e56 files; `git ls-tree -r v2-backend --name-only | findstr garnet-poc` present.
C. Apply + commit the filled PoC artifacts on v2-backend:
   `git stash pop`  (clean apply expected — same 8392e56 base; conflict -> STOP, report)
   `git add docs/incidents/INC-001_garnet_poc_results.md infra/garnet-poc/Verify-GarnetPoC.ps1 infra/garnet-poc/BackplaneTest/`
   commit -m "docs: INC-001(d) Garnet PoC GREEN results + Verify fixes + BackplaneTest harness [devops]"
   VERIFY: WT clean of the 3 Garnet paths; `git log --oneline -2 v2-backend` = [artifacts commit][cherry-picked 8392e56].
   release commit.lock.
D. Drop 8392e56 from v3 (rewrite the unpushed v3 tail — onto its parent's parent):
   `git checkout v3`
   `git rebase --onto 62a8759 8392e56 v3`  (replays 0cc1d0d + 63045d8 onto 62a8759, dropping 8392e56)
   if conflict -> `git rebase --abort`, STOP, report (coordinator will pick a revert fallback).
E. VERIFY (object-store) — ALL must hold or STOP+report:
   - `git log --oneline 0996a91..v3` == exactly: <63045d8'>, <0cc1d0d'>, 62a8759, 53aa308  (NO 8392e56; last 2 are NEW hashes)
   - `git ls-tree -r v3 --name-only | findstr garnet-poc`  -> EMPTY (Garnet gone from v3)
   - ChatMessage carve SURVIVED the rebase: `git ls-tree -r v3 --name-only | findstr ArchRtsDataChatMessage` -> EMPTY; `git grep -il arch_rtsdata_chatmessage v3 -- src` -> none.
   - dba step-0 content intact on v3 (spot: ArchiverService.cs present, contour-index sql present).
   - `git ls-tree -r v2-backend --name-only | findstr garnet-poc` -> README + Verify + garnet-args + BackplaneTest present; results doc present.
   - both tips resolve; `git status --short` shows ONLY the unrelated spine/WT files (unchanged), nothing Garnet.
F. NO push. REPORT to inbox/coordinator.md: new v3 tip hash, new v2-backend tip hash, the 2 rewritten v3 hashes (old->new), confirmation v3 is Garnet-free + carve intact + v2-backend has Garnet.

## CROSS-SESSION (coordinator handles after)
The v3 rebase rewrites 0cc1d0d->0cc1d0d' and 63045d8->63045d8'. Coordinator re-broadcasts the new v3 tip; dba/shell/bi must re-verify v3 by CONTENT (git show v3:<file>), never by old hash.
