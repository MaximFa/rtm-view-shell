# CC Task: Integrity restore → commit valid changes → push to origin v2

## MANDATORY RULES (CLAUDE.md §0)
§0.3 — Edit tool BANNED. Python atomic writes only. After every write: `tail -3 <path> && wc -l <path>`.
§0.5 — `bash tools/pre-commit-check.sh` before every commit.

---

## ANALYSIS (Cowork pre-checked — do NOT re-investigate)

### Files to RESTORE from HEAD (truncated in working tree):
```
tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs     WT=197  HEAD=313  TRUNCATED
tools/SignalRSimulator/Services/DbMetricService.cs  WT=216  HEAD=229  TRUNCATED (ends: "await usi")
tools/SignalRSimulator/Program.cs                   WT=63   HEAD=76   TRUNCATED
tools/SignalRSimulator/Models/GridModels.cs          WT=59   HEAD=63   TRUNCATED
src/.../Dashboard/ScreenEditorPage.razor            WT=5396 HEAD=5408 TRUNCATED (ends: "Width = 280")
src/.../Widgets/AgentGridWidget.razor               WT=1446 HEAD=1459 TRUNCATED (ends: "if (_hub != null) {")
```
HEAD already contains the full committed fixes (56a11cb, 745c69c, 0e00674, becf2c8).

### Files with valid uncommitted changes (commit these):
```
docs/user-documentation/DOC-REGISTRY.md                              updated dates + doc status
src/CcDashboard.Application/Queries/InfoSlots/InfoSlotQueries.cs     new GetInfoSlotWidgetDataQuery
src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor              Superadmin tenant column + badge fix
src/CcDashboard.Web/Components/Admin/PermissionGroupsPage.razor       InfoSlot PG binding fix
src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor           InfoSlotWidget case routing
src/CcDashboard.Web/Program.cs                                        MapHub<InfoSlotHub>
tools/SignalRSimulator/appsettings.json                               Kestrel endpoint + CorsOrigins
tools/SignalRSimulator/Generators/MetricDataGenerator.cs              trailing newline (CRLF→LF)
src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor           CRLF→LF only
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor          CRLF→LF only
```

---

## Step 1 — Restore truncated files from HEAD

```bash
cd "$(git rev-parse --show-toplevel)"

for f in \
  "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs" \
  "tools/SignalRSimulator/Services/DbMetricService.cs" \
  "tools/SignalRSimulator/Program.cs" \
  "tools/SignalRSimulator/Models/GridModels.cs" \
  "src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor" \
  "src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor"; do
    git show HEAD:"$f" > "$f"
    echo "Restored: $f ($(wc -l < "$f") lines)"
    tail -2 "$f"
    echo "---"
done
```

Verify these now show proper closing tokens (`}`) and correct line counts.
After restoration these files will no longer be `M` (they match HEAD).

---

## Step 2 — Pre-commit check on files to be committed

```bash
bash tools/pre-commit-check.sh \
    docs/user-documentation/DOC-REGISTRY.md \
    src/CcDashboard.Application/Queries/InfoSlots/InfoSlotQueries.cs \
    src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor \
    src/CcDashboard.Web/Components/Admin/PermissionGroupsPage.razor \
    src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor \
    src/CcDashboard.Web/Program.cs \
    tools/SignalRSimulator/appsettings.json \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
```

**If exit code 1 — DO NOT COMMIT.**

---

## Step 3 — Commit (excl. RTM/)

Only after pre-commit check exits 0:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    docs/user-documentation/DOC-REGISTRY.md \
    src/CcDashboard.Application/Queries/InfoSlots/InfoSlotQueries.cs \
    src/CcDashboard.Web/Components/Admin/InfoSlotAdmin.razor \
    src/CcDashboard.Web/Components/Admin/PermissionGroupsPage.razor \
    src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor \
    src/CcDashboard.Web/Program.cs \
    tools/SignalRSimulator/appsettings.json \
    tools/SignalRSimulator/Generators/MetricDataGenerator.cs \
    src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
    src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: InfoSlot widget routing, PG binding, DOC-REGISTRY; simulator appsettings + CRLF normalize"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

If HEAD.lock blocks — use commit-tree workaround (CLAUDE.md §0.4):
```bash
TREE=$(GIT_INDEX_FILE=/tmp/cc-idx git write-tree)
COMMIT=$(git commit-tree "$TREE" -p HEAD -m "feat: InfoSlot widget routing, PG binding, DOC-REGISTRY; simulator appsettings + CRLF normalize")
python3 -c "
import os, subprocess
git_dir = subprocess.check_output(['git','rev-parse','--git-dir']).decode().strip()
head = open(os.path.join(git_dir,'HEAD')).read().strip()
ref = head[5:] if head.startswith('ref: ') else None
if ref:
    open(os.path.join(git_dir, ref), 'w').write('$COMMIT\n')
    print('HEAD updated to', '$COMMIT')
"
cp /tmp/cc-idx .git/index
```

---

## Step 4 — Post-commit integrity (CLAUDE.md §0.6)

```bash
git status --short
# Expected: only RTM/ files remain M or ??; committed files gone

git diff HEAD -- \
    src/CcDashboard.Web/Program.cs \
    tools/SignalRSimulator/appsettings.json \
    src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor
# Expected: empty
```

---

## Step 5 — Push

```bash
git push origin v2
git log --oneline -3
```
