---
name: dba-reference-toolkit
description: "General-purpose engine-aware DBA skill (skill-dba-main) — reference toolkit for RTM DBA audits, query optimization, migrations"
metadata: 
  node_type: memory
  type: reference
  originSessionId: d714da75-d40c-4dfd-b84f-f07cc83d7179
---

**`skill-dba-main`** — third-party general-purpose DBA skill (author u1pns, MIT), installed at `D:\Claude\Projects\RTM View Shell\.claude\skills\skill-dba-main\` (`SKILL.md` + `README.md` + `references/`). Use as a reference toolkit for DBA work in the RTM DBA role (audits, schema review, query optimization, migrations).

Engine-aware (MySQL / PostgreSQL / SQL Server / Oracle / SQLite). 80/20 architecture:
- **SKILL.md** = universal rules: SARGability (no functions on indexed cols in WHERE), composite-index leftmost-prefix (equality→range→order), right-sizing types, DECIMAL not FLOAT for money, no `SELECT *` (covering indexes), keyset vs deep OFFSET, EXISTS vs COUNT>0, index all JOIN cols, avoid implicit type casts. Audit-report format: **CRITICAL / WARNING / SUGGESTION / INFO** — adopt for DB-consistency review reports.
- **references/** (read on demand): `adv-performance.md` (EXPLAIN plans), `adv-diagnostics.md` (unused/redundant indexes, bloat/dead tuples), `adv-logic.md` (triggers/stored-procs, app-vs-db logic), `adv-migrations.md` (zero-downtime, shadow-table, INT→BIGINT, dialect translation).

**Precedence — PROJECT RULES OVERRIDE this generic skill where they conflict:**
- §33.8 PROCEDURE-not-FUNCTION for RTM-called writes (CALL) — project-specific, generic skill doesn't cover it.
- PK = UUIDv7 (UUIDNext) — skill warns "random UUID PK = fragmentation"; our UUIDv7 is sequential + PG heap tables soften it (skill's own PG section confirms).
- timestamptz UTC, multitenant GQF, EF-Core-only migrations (§7/MAINT-04) — project-specific.

**Useful confirmations it provides:** SQL Server gotchas (DATETIME2 over legacy DATETIME; NEWSEQUENTIALID/IDENTITY over random GUID) back the MSSQL type-mapping advice for the BI guide. Engine = PostgreSQL 18 prod for RTM.

Related: [[project_rtm_view_shell]], [[feedback_rtm_workflow]].
