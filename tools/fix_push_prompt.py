#!/usr/bin/env python3
"""Update cc_prompt_push.md to add Step 3b for DB changes."""
import os

path = r"D:\Claude\Projects\RTM View Shell\tools\cc_prompt_push.md"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add Step 3b after Step 3
old_block = '''Adjust the commit message to reflect what actually changed in src/.

---

## Step 4 — Post-commit verification (§0.6)'''

new_block = '''Adjust the commit message to reflect what actually changed in src/.

---

## Step 3b — Commit DB changes (if any db/ files modified)

Stage and commit db/:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add db/
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "db: <describe DB changes>"
cp /tmp/cc-idx .git/index
```

Skip this step if no db/ files were modified.

---

## Step 4 — Post-commit verification (§0.6)'''

if old_block not in text:
    print("ERROR: Step 3 -> Step 4 block not found")
    exit(1)

text = text.replace(old_block, new_block)

# Update Notes section to include db/
old_notes = '''## Notes
- RTM files: everything under `RTM/`
- Shell files: `src/`, `tests/`, CLAUDE.md, PROJECT_STATUS.md, `tools/`, `.claude/`, `docs/`, `deploy/`, `wireframes/`
- `staging/*.sql` → RTM commit
- `tools/cc_prompt_*.md` → Shell commit
- Never mix RTM and Shell in the same commit'''

new_notes = '''## Notes
- RTM files: everything under `RTM/`
- Shell files: `src/`, `tests/`, CLAUDE.md, PROJECT_STATUS.md, `tools/`, `.claude/`, `docs/`, `deploy/`, `wireframes/`
- DB files: `db/` (functions, migrations, tools, baseline.sql)
- `staging/*.sql` → RTM commit
- `tools/cc_prompt_*.md` → Shell commit
- Never mix RTM, Shell, and DB in the same commit'''

if old_notes not in text:
    print("ERROR: Notes section not found")
    exit(1)

text = text.replace(old_notes, new_notes)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Updated cc_prompt_push.md ({len(text.splitlines())} lines)")
