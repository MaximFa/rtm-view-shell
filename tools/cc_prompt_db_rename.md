# CC Task: Rename database RTMViewDB → rtmviewdb (lowercase) in docs and scripts

## MANDATORY RULES (CLAUDE.md §0)

§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `sync && tail -3 <path> && wc -l <path>`
§0.5 — Before commit: `bash tools/pre-commit-check.sh` (exit 0)

---

## §0 — SESSION-RESUME (run first)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git log --oneline -1
git status --short
```
Restore any truncated M files before starting.

---

## Context

PostgreSQL stores unquoted database names in lowercase.
`CREATE DATABASE "RTMViewDB"` creates a database accessible as `rtmviewdb`.
All appsettings.json and PowerShell scripts already use `rtmviewdb` correctly.
Remaining occurrences of `RTMViewDB` are in documentation and deployment scripts only.

**Source files already correct (no changes needed):**
- `src/CcDashboard.Web/appsettings*.json` ✅
- `tools/SignalRSimulator/appsettings.json` ✅
- `RTM/RTM/appsettings.json` ✅
- `deploy/*.ps1`, `tools/*.ps1` ✅

---

## Files to update (24 occurrences total)

For each file below, use Python read→replace→write. Replace ALL occurrences of
`RTMViewDB` with `rtmviewdb` (case-sensitive exact match).

```python
import os

files = [
    r"INSTALL.md",
    r"INSTALL-SIMULATOR.md",
    r"docs\BACKUP_RESTORE.md",
    r"decisions\ADR-007-database-boundary.md",
    r"docs\architecture\widget-framework.md",
]

for path in files:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    new_text = text.replace("RTMViewDB", "rtmviewdb")
    if new_text != text:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_text)
            f.flush()
            os.fsync(f.fileno())
        print(f"Updated: {path}")
    else:
        print(f"No changes: {path}")
```

Run, then verify each changed file:
```bash
sync
for f in INSTALL.md INSTALL-SIMULATOR.md docs/BACKUP_RESTORE.md \
          decisions/ADR-007-database-boundary.md docs/architecture/widget-framework.md; do
  count=$(grep -c "RTMViewDB" "$f" 2>/dev/null || echo 0)
  echo "$f: RTMViewDB occurrences = $count"
done
# Expected: all 0
```

---

## Verification

```bash
# No RTMViewDB left in any source/doc file (excluding git history and memory)
grep -rn "RTMViewDB" \
  --include="*.md" --include="*.json" --include="*.cs" \
  --include="*.sql" --include="*.ps1" \
  . 2>/dev/null | grep -v ".git/\|bin/\|obj/\|memory/"
# Expected: no output
```

---

## Commit

```
docs: rename database RTMViewDB → rtmviewdb (lowercase) in docs and deployment scripts

PostgreSQL stores unquoted identifiers in lowercase — rtmviewdb is the actual name.
Updated: INSTALL.md, INSTALL-SIMULATOR.md, docs/BACKUP_RESTORE.md,
         decisions/ADR-007, docs/architecture/widget-framework.md
```
