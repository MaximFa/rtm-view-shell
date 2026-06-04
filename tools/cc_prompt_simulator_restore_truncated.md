# CC Task: Restore truncated simulator files from HEAD + rebuild prompt

## CONTEXT

Simulator files in the working tree are TRUNCATED — the reader loop in
`GetCellsForGridAsync` is missing, so Queue/DataSlot always return 0 cells.
AgentGrid works because it uses a different code path (`GenerateAgentDataAsync`).

HEAD already contains the correct complete versions from prior commits (becf2c8, 56a11cb).
We just need to restore WT from HEAD and commit.

## DO NOT touch RTM/ folder.

---

## STEP 1 — Restore all 4 truncated simulator files from HEAD

```bash
cd "$(git rev-parse --show-toplevel)"

for f in \
  "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs" \
  "tools/SignalRSimulator/Services/DbMetricService.cs" \
  "tools/SignalRSimulator/Program.cs" \
  "tools/SignalRSimulator/Models/GridModels.cs"; do
    git show HEAD:"$f" > "$f"
    echo "Restored: $f → $(wc -l < "$f") lines, last: $(tail -1 "$f")"
done
```

Expected output — each file must end with `}`:
```
Restored: tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs → 313 lines, last: }
Restored: tools/SignalRSimulator/Services/DbMetricService.cs → 229 lines, last: }
Restored: tools/SignalRSimulator/Program.cs → 76 lines, last: }
Restored: tools/SignalRSimulator/Models/GridModels.cs → 63 lines, last: }
```

If any file doesn't end with `}` or has wrong line count — **STOP**. Do not commit.

---

## STEP 2 — Verify the critical method is present

```bash
grep -n "await cmd.ExecuteReaderAsync\|return cells;" \
    tools/SignalRSimulator/Services/DbMetricService.cs
```

Expected: both lines found (the reader loop is the key fix).
If NOT found — the restore failed; check HEAD integrity with:
```bash
git show HEAD:tools/SignalRSimulator/Services/DbMetricService.cs | tail -15
```

---

## STEP 3 — Pre-commit check (§0.5)

```bash
bash tools/pre-commit-check.sh \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Program.cs \
    tools/SignalRSimulator/Models/GridModels.cs
```

Exit code must be 0.

---

## STEP 4 — Commit

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs \
    tools/SignalRSimulator/Services/DbMetricService.cs \
    tools/SignalRSimulator/Program.cs \
    tools/SignalRSimulator/Models/GridModels.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix(simulator): restore truncated files from HEAD — GetCellsForGridAsync reader loop was missing"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

If HEAD.lock blocks — use commit-tree workaround (CLAUDE.md §0.4).

---

## STEP 5 — Post-commit integrity (§0.6)

```bash
git status --short
# Only RTM/ and other non-simulator files should remain M

git diff HEAD -- tools/SignalRSimulator/Services/DbMetricService.cs
# Expected: empty

git show HEAD:tools/SignalRSimulator/Services/DbMetricService.cs | tail -5
# Expected: return cells; } }
```

---

## STEP 6 — Instruct user to rebuild simulator

After committing, output this message for the user:

```
Simulator files restored. Please rebuild and restart the simulator:

  cd tools/SignalRSimulator
  dotnet build
  dotnet run

Then reload the dashboard page to reconnect widgets.
```
