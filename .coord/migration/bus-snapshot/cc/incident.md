# cc-binding channel: incident <-> CC (NORM-CUR-07). Append-only.

## BINDING 2026-06-21T06:20Z | spec: incident | directive: tools/cc_prompt_incident_ledger_commit.md | status: open
### DIRECTIVE: commit docs/incidents/incidents.md as `docs:` (INC-001 RCA). claim: docs/incidents/**. gate: commit.lock, no push.

### RESULT: commit 707f759 . files docs/incidents/incidents.md (164 lines) . build/test n/a (docs) . status done . blockers none . verified: object-store (git show HEAD == WT)
## BINDING 2026-06-21T06:22Z | spec: incident | directive: tools/cc_prompt_incident_ledger_commit.md | status: done

## BINDING 2026-07-02T04:30:18Z | spec: incident | directive: tools/cc_prompt_incident_ledger_garnet.md | status: open
### DIRECTIVE: INC-001(d) Garnet VALIDATED ledger update + $B capture. claim: docs/incidents/** + .claude/skills/role-incident/**. gate: commit.lock, no push, branch v3.

### RESULT: commit 463fba6 . files 2 (ledger + role-incident $B) . build/test n/a . status done . blockers none . verified: object-store . branch v3
## BINDING 2026-07-02T04:34:11Z | spec: incident | directive: tools/cc_prompt_incident_ledger_garnet.md | status: done
