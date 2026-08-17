# CC task — create orphan branch `adapters` + commit adapter solution (REDACTED secrets) — §4 PRE-BLESSED, plan-verified

> Tight execution of a coordinator-verified plan (subagent-designed). Create orphan branch `adapters` (same repo, decoupled from v3), commit RTM.Twilio + RTM.Adapter.Common + WIRE test AS BASELINE, with Twilio secrets REDACTED (operator decision). Owner: backend. **Native CC on Windows** (git worktree + dotnet). Branch `adapters`. **NO push** (§37 — push is a later barrier step). §0.3/§0.4/§0.5 discipline.

## Mandatory reads
Read: CLAUDE.md §0.3 (Python+fsync), §0.4 (index/HEAD.lock workarounds — verbatim), §0.5 (verify via object store), §37 (no push), §48 (WIRE contract carried on this branch). session-coord.

## PRE: verify base state (object store, native)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD          # MUST be v3
git branch --list adapters               # MUST be empty (no adapters branch yet)
git --version                            # need >= 2.42 for `worktree add --orphan`
```

## STEP 1 — orphan worktree OUTSIDE the repo (leaves v3 tree untouched)
```bash
WT="D:\Claude\Projects\RTMView-adapters-wt"
git worktree add --orphan adapters "$WT"
# git <2.42 fallback: git worktree add --detach "$WT" HEAD ; cd "$WT" ; git checkout --orphan adapters ; git rm -rf . ; git clean -fdx
```

## STEP 2 — copy the 3 kept projects to worktree ROOT (drop 10072026/ prefix)
```bash
SRC="D:\Claude\Projects\RTM View Shell\10072026"
cp -r "$SRC/RTM.Twilio"               "$WT/RTM.Twilio"
cp -r "$SRC/RTM.Adapter.Common"       "$WT/RTM.Adapter.Common"
cp -r "$SRC/RTM.Adapter.Common.Tests" "$WT/RTM.Adapter.Common.Tests"
cd "$WT"
find . -type d \( -name bin -o -name obj -o -name .vs \) -prune -exec rm -rf {} +
find . -name '*.user' -delete
```

## STEP 3 — REDACT Twilio secrets in RTM.Twilio/appsettings.json (Python+fsync, §0.3)
In `$WT/RTM.Twilio/appsettings.json`: replace ONLY the Twilio secret VALUES with placeholders, keep everything else (Kestrel 9201, RTM:Targets structure, StatusGroups/StatusNames/WorkgroupAttName — those are config, not secrets):
- `AccountSid` value → `"REDACTED_SET_ON_DEPLOY"`
- `AuthToken`  value → `"REDACTED_SET_ON_DEPLOY"`
- `WorkspaceSid` value → `"REDACTED_SET_ON_DEPLOY"`
(Real values live ONLY on the deploy box — runbook STEP 5 copies them from RTM.Test verbatim. NEVER commit real secrets.)
Also create `$WT/RTM.Twilio/appsettings.Sample.json` = a copy of the redacted appsettings.json (reference template).
After write: `sync ; python3 -c "import json;json.load(open('RTM.Twilio/appsettings.json'));json.load(open('RTM.Twilio/appsettings.Sample.json'));print('json valid')"` — must print `json valid`.
VERIFY no secret leaked: `grep -riE "AC79a7|79aa2e|WS2c8548" $WT` → MUST be empty (no real Twilio values anywhere in the worktree).

## STEP 4 — .gitignore at worktree root (Python+fsync)
Content:
```
bin/
obj/
publish/
.vs/
.idea/
*.user
*.suo
Thumbs.db
.DS_Store
```
After write: `sync ; tail -3 .gitignore ; wc -l .gitignore`.

## STEP 5 — solution (generated, never hand-write GUIDs)
```bash
cd "$WT"
dotnet new sln -n RTM.Adapters
dotnet sln RTM.Adapters.sln add RTM.Adapter.Common/RTM.Adapter.Common.csproj RTM.Twilio/RTM.Twilio.csproj RTM.Adapter.Common.Tests/RTM.Adapter.Common.Tests.csproj
```

## STEP 6 — stage + commit (baseline root commit)
```bash
cd "$WT"
git add .gitignore RTM.Adapters.sln RTM.Twilio RTM.Adapter.Common RTM.Adapter.Common.Tests
git commit -m "adapters: RTM.Twilio multi-target + RTM.Adapter.Common (minimal RTM-independent wire lib) + WIRE contract test [baseline, secrets redacted]"
```
If lock errors → CLAUDE.md §0.4 (index.lock cp-workaround; HEAD.lock → `commit-tree` with **NO -p** (orphan root), write `refs/heads/adapters`). Prefer plain commit.

## STEP 7 — object-store verification (§0.5, NOT status/line-count)
```bash
for f in RTM.Twilio/RTM.Twilio.csproj RTM.Adapter.Common/RTM.Adapter.Common.csproj RTM.Adapter.Common.Tests/RTM.Adapter.Common.Tests.csproj RTM.Adapters.sln .gitignore RTM.Twilio/appsettings.json; do git cat-file -e adapters:"$f" && echo "OK $f"; done
# NO v3 leak + NO secret + NO cruft:
git cat-file -e adapters:src 2>/dev/null && echo "LEAK src" || echo "clean no src"
git cat-file -e adapters:CLAUDE.md 2>/dev/null && echo "LEAK CLAUDE" || echo "clean no CLAUDE"
git ls-tree -r adapters --name-only | grep -E "/(bin|obj)/|\.vs/|\.user$" || echo "clean no cruft"
git show adapters:RTM.Twilio/appsettings.json | grep -iE "AC79a7|79aa2e|WS2c8548|AuthToken" | grep -v REDACTED || echo "clean: no real secret in committed appsettings"
git ls-tree -r adapters --name-only | wc -l          # expect ~33
git rev-list --count adapters                        # expect 1
git log --format='%P' -1 adapters                    # expect EMPTY (orphan root)
```

## STEP 8 — return to v3 (main tree was never touched); DO NOT push
```bash
cd "D:\Claude\Projects\RTM View Shell"
git worktree remove "D:\Claude\Projects\RTMView-adapters-wt"   # --force if artifacts remain
git rev-parse --abbrev-ref HEAD    # still v3
git branch --list adapters         # branch persists
```

## Report → inbox/coordinator.md: adapters commit hash, `git ls-tree -r adapters --name-only | wc -l`, secret-leak grep = clean, v3-leak checks clean, orphan-root confirmed (no parent). NO push (barrier follows). This baseline is the input to the quorum + push origin/adapters step.
