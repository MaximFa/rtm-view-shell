# CC Task: Replace RTMViewDB → rtmviewdb in appsettings (C: drive copy)

## MANDATORY RULES (CLAUDE.md §0)

§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `sync && tail -3 <path> && wc -l <path>`
§0.5 — Before commit: `bash tools/pre-commit-check.sh` (exit 0)

---

## Problem

The application reads config from the C: drive copy of the project:
  C:\Users\farbe\Documents\Claude\Projects\RTM View Shell

That copy has `Database=RTMViewDB` (old mixed case) in appsettings.
EF Core / Npgsql tries to CREATE DATABASE "RTMViewDB", which fails because
the actual database is named `rtmviewdb` (lowercase).

The D: drive (git repo) already has `rtmviewdb` — only the C: copy needs updating.

---

## Fix — update all 4 appsettings files

Run this Python script (use absolute Windows paths):

```python
import os

files = [
    r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Web\appsettings.json",
    r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Web\appsettings.Development.json",
    r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Api\appsettings.json",
    r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Api\appsettings.Development.json",
]

for path in files:
    if not os.path.exists(path):
        print(f"SKIP (not found): {path}")
        continue
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    new_text = text.replace("RTMViewDB", "rtmviewdb")
    if new_text == text:
        print(f"OK (no change): {path}")
        continue
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)
        f.flush()
        os.fsync(f.fileno())
    print(f"Updated: {path}")
```

---

## Verification

```python
import os

files = [
    r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Web\appsettings.json",
    r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\src\CcDashboard.Web\appsettings.Development.json",
]

for path in files:
    if not os.path.exists(path): continue
    with open(path) as f: text = f.read()
    count = text.count("RTMViewDB")
    print(f"{os.path.basename(path)}: RTMViewDB occurrences = {count}")
    assert count == 0, f"STILL HAS RTMViewDB: {path}"
print("All clean.")
```

No commit needed — these files are outside the D: git repo.
