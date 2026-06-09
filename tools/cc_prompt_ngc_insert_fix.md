# CC Task — DB: NGC_GetOrCreateQueue + NGC_GetOrCreateAgentGroup INSERT fix (E-004)

Session: backend-0609
Bug: E-004 baseline drift — NGC_GetOrCreateQueue and NGC_GetOrCreateAgentGroup INSERT statements
omit the "Id" column (uuid, no default) and "IsActive" column. On a fresh install this produces:
  ERROR 23502: null value in column "Id" of relation "NGC_Queues" violates not-null constraint
Fix: add "Id"=gen_random_uuid() and "IsActive"=true to the INSERT in both procedures.
File: db/functions/01_ngc_functions.sql (read from HEAD after d6b1672 — E-016 DO-loop DROPs present).

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/rtm-service-expert/rtm-service-expert.md
Only after reading all four: proceed.

## Git push (§37)
Do NOT run `git push`. Commit only.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) + fetch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)"
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  case "$f" in db/data/02_metrics.sql|db/schema.sql|docs/RTMViewShell_SecurityOverview.docx) echo "SKIP: $f"; continue;; esac
  HL=$(git show HEAD:"$f" 2>/dev/null | wc -l); WL=$(wc -l < "$f" 2>/dev/null)
  if [ "$((HL-WL))" -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync
```

## Multi-session sync (§42) — slug: backend-0609
Claims: db/functions/01_ngc_functions.sql

```bash
# S1 barrier
if grep -q "FREEZE ACTIVE" ".coord/push/request.md" 2>/dev/null; then
  echo "PUSH BARRIER ACTIVE"; exit 1; fi
# S2 claims
python3 tools/coord_check_claims.py backend-0609 db/functions/01_ngc_functions.sql
```

S3 commit.lock: phantom-aware acquire (tools/cc_prompt_sync_block.md pattern; retry 5x60s).
After commit: bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)

---

# TASK — fix INSERT in db/functions/01_ngc_functions.sql (Python+fsync, Edit BANNED §0.3)

Read the file from HEAD first to get the current state (d6b1672 may differ from working tree):
```bash
git show HEAD:db/functions/01_ngc_functions.sql > /tmp/01_ngc_functions_head.sql
diff db/functions/01_ngc_functions.sql /tmp/01_ngc_functions_head.sql | head -20
# If diff is non-empty: restore from HEAD first
git show HEAD:db/functions/01_ngc_functions.sql > db/functions/01_ngc_functions.sql
```

## Change 1 — NGC_GetOrCreateQueue INSERT (~line 91)

Current:
```sql
    INSERT INTO "NGC_Queues" ("ExternalId", "Name", "CreatedDatetime", "TenantId")
    VALUES (p_external_id, p_name, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
```

Replace with:
```sql
    INSERT INTO "NGC_Queues" ("Id", "ExternalId", "Name", "IsActive", "CreatedDatetime", "TenantId")
    VALUES (gen_random_uuid(), p_external_id, p_name, true, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
```

## Change 2 — NGC_GetOrCreateAgentGroup INSERT (~line 117)

Current:
```sql
    INSERT INTO "NGC_AgentGroups" ("ExternalId", "Name", "CreatedDatetime", "TenantId")
    VALUES (p_external_id, p_name, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
```

Replace with:
```sql
    INSERT INTO "NGC_AgentGroups" ("Id", "ExternalId", "Name", "IsActive", "CreatedDatetime", "TenantId")
    VALUES (gen_random_uuid(), p_external_id, p_name, true, NOW(), p_tenant_id)
    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;
```

## OUT OF SCOPE
Do NOT touch any other procedure bodies. Do NOT touch ON CONFLICT clauses. Do NOT touch E-016 DO-loop DROPs.

## Python write script
```python
import os
path = r"D:\Claude\Projects\RTM View Shell\db\functions\01_ngc_functions.sql"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

old1 = '    INSERT INTO "NGC_Queues" ("ExternalId", "Name", "CreatedDatetime", "TenantId")\n    VALUES (p_external_id, p_name, NOW(), p_tenant_id)\n    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;'
new1 = '    INSERT INTO "NGC_Queues" ("Id", "ExternalId", "Name", "IsActive", "CreatedDatetime", "TenantId")\n    VALUES (gen_random_uuid(), p_external_id, p_name, true, NOW(), p_tenant_id)\n    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;'

old2 = '    INSERT INTO "NGC_AgentGroups" ("ExternalId", "Name", "CreatedDatetime", "TenantId")\n    VALUES (p_external_id, p_name, NOW(), p_tenant_id)\n    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;'
new2 = '    INSERT INTO "NGC_AgentGroups" ("Id", "ExternalId", "Name", "IsActive", "CreatedDatetime", "TenantId")\n    VALUES (gen_random_uuid(), p_external_id, p_name, true, NOW(), p_tenant_id)\n    ON CONFLICT ("ExternalId", "TenantId") DO NOTHING;'

assert old1 in text, "PATTERN 1 NOT FOUND — check file"
assert old2 in text, "PATTERN 2 NOT FOUND — check file"
text = text.replace(old1, new1)
text = text.replace(old2, new2)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())
print("OK")
```

## Verify before commit
```bash
cd "D:\Claude\Projects\RTM View Shell"
sync
grep -n '"Id", "ExternalId"' db/functions/01_ngc_functions.sql   # must show 2 lines
grep -n 'gen_random_uuid' db/functions/01_ngc_functions.sql       # must show 2 lines
grep -n '"IsActive"' db/functions/01_ngc_functions.sql            # must show 2 lines
tail -3 db/functions/01_ngc_functions.sql
wc -l db/functions/01_ngc_functions.sql
bash tools/pre-commit-check.sh db/functions/01_ngc_functions.sql
# exit 0 required before proceeding
```

## Commit (under commit.lock)
One commit, prefix §39.3:
- `db: fix NGC_GetOrCreateQueue + NGC_GetOrCreateAgentGroup INSERT missing Id + IsActive (E-004)`

After commit: §0.6 post-commit verify + PD-007 re-sync of db/functions/01_ngc_functions.sql, then:
  `bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)`

## Deploy (operator — apply to prod server)
This is a SQL-only change. Apply via DBeaver or psql:
```sql
-- Run only the two changed procedures (lines ~72-125 of 01_ngc_functions.sql):
DO $drop_getorcreatequeue$ ... END $drop_getorcreatequeue$;
CREATE OR REPLACE PROCEDURE "NGC_GetOrCreateQueue"(...) ...;
DO $drop_getorcreateagentgroup$ ... END $drop_getorcreateagentgroup$;
CREATE OR REPLACE PROCEDURE "NGC_GetOrCreateAgentGroup"(...) ...;
```
No RTM Service restart required (procedures called at runtime, not compiled at startup).
Verify: RTM log should no longer show 23502 errors on queue/agentgroup creation.
