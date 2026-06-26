# CC task — CUT v3 branch (reports expansion line) from the proven v2-backend tip

> Owner: native CC (operator/devops-run; branch create + push needs native git, L-SC-20). §37: this prompt IS authorized
> to push the NEW v3 branch ref (a dedicated branch-cut push, like the tag prompt). NO other pushes.
> Base = origin/v2-backend 8bbee78 (proven tip just pushed in barrier #3: reports Track A + R0b-e + incident fix).
> Two-Cowork model (§44) is DORMANT (all work on v2-backend; v2 trunk + v2-frontend stale) -> single v3 line.

## STEP 0 — preflight (object-store)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git rev-parse origin/v2-backend     # expect 8bbee78...
git ls-remote --heads origin v3     # expect EMPTY (v3 must not exist yet)
```
If v3 already exists on origin -> STOP, report.

## STEP 1 — create v3 from the proven tip + fold the 2 additive v2-frontend commits
```bash
git branch v3 origin/v2-backend          # v3 base = 8bbee78
git checkout v3
# Fold the 2 v2-frontend additive commits (skills + docs; NO code overlap -> clean):
#   7fc4463 docs: cc-historical-reports + wfm-expert skills (.claude/skills/)   <- directly relevant to v3
#   77bfa0d docs: local DB install guide + terminology memory
git cherry-pick 7fc4463 77bfa0d
```
EXPECTED: clean cherry-pick (both touch only NEW files in .claude/ + docs/ — additive, no conflict).
If a conflict appears (unexpected): `git cherry-pick --abort`, report — do NOT force.

## STEP 2 — verify (object-store)
```bash
git log --oneline -4 v3                                  # tip = cherry-picked 77bfa0d-equiv, then 7fc4463-equiv, then 8bbee78
git cat-file -e v3:.claude/skills/cc-historical-reports/SKILL.md && echo "cc-historical-reports skill present on v3"
git diff --stat origin/v2-backend v3                     # only the 949-insert additive .claude/docs files
```

## STEP 3 — push the new v3 branch ref
```bash
git push -u origin v3
git ls-remote --heads origin v3     # confirm v3 on origin
```

## STEP 4 — return to working branch + journal
```bash
git checkout v2-backend     # leave the tree on v2-backend; v3 is cut + on origin
printf '%s | coordinator-0612 | CUT v3 from origin/v2-backend 8bbee78 (proven tip) + folded v2-frontend 7fc4463 (cc-historical-reports+wfm-expert skills) + 77bfa0d (DB-install/terminology). Single v3 line (two-Cowork dormant). v3 pushed to origin. Reports expansion base ready.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .coord/journal.md
sync
```

## REPORT -> inbox/coordinator.md: v3 tip hash, cc-historical-reports skill present, v3 on origin, diff vs v2-backend = additive-only.
## NOTE: after v3 is live -> v3 planning (dba data-arch + bi reports TZ, SF-BI-001 hard gate) can begin on operator go. v2-backend remains the v2 line; rollback anchor stays v2-server-verified-20260619 (b58e2c2).
