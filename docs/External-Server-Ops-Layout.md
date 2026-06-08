# External-Server Ops Directory Layout (deploy staging)

> AUTHORITATIVE — agreed with operator (Max), 2026-06-07. Every external (deployed) server has this
> ops/deploy working area. CC produces scripts into the repo; the operator (or a deploy channel) places
> them on the server per this layout. CC has NO direct access to external servers.

## Root: `C:\RTMView-Ops\`
(Separate from the app install `C:\Program Files\CcDashboard` — user-writable, no admin needed.)

```
C:\RTMView-Ops\
├── SERVER.md          identity of THIS server: name (e.g. "Server 45"), PG version (17 | 18),
│                      TenantId, hostname, SignalR URL, notes.
├── incoming\          CC-produced scripts staged to APPLY (migrations / align / deploy).
│                      Naming: <NNN>_<desc>.sql  (e.g. 20260606_009_ngc_useragentgroup_procedures.sql)
├── applied\           archive of successfully applied scripts: <YYYYMMDD-HHMM>_<origname>.sql (+ .log)
│   └── _ledger.txt    append-only trace, one line per apply:  <UTC> | <script> | <result>
│                      => "what has been run on THIS server" (lightweight, complements Compare-ToBaseline)
├── output\            run results: Compare-ToBaseline delta reports, generated align scripts, psql logs
├── backup\            pre-change pg_dump (custom format): <db>_<stamp>.backup  (rollback / PITR)
└── tmp\               throwaway (BOM-less temp SQL, etc.)
```

## PostgreSQL version per server (operator input 2026-06-07)
- **Server 45 → PostgreSQL 17**  (`C:\Program Files\PostgreSQL\17\bin\psql.exe`)
- **All other / future servers → PostgreSQL 18**  (`C:\Program Files\PostgreSQL\18\bin\psql.exe`)
- The version is recorded in `SERVER.md`. Deploy scripts/instructions are issued in TWO variants,
  clearly tagged: `=== Server 45 (PG17) ===` and `=== All other Servers (PG18) ===` — accounting for the
  psql path and any version-specific SQL.

## Flow (CC → repo → server)
1. CC produces the script into the **repo**: `db/migrations/` (canonical, committed) or `staging/`
   (server-ready deploy script). This is the protocolled source of truth.
2. Operator (or deploy channel) copies it to `C:\RTMView-Ops\incoming\` on the target server.
3. Apply: run with psql for that server's PG version. Capture the log to `output\`.
4. On success: move the script to `applied\` (timestamped) + append a line to `applied\_ledger.txt`;
   take a `backup\` pg_dump before destructive changes.
5. The run result returns to coordination via the CC-RESULT report block.

## HARD RULE — Cowork sessions MUST state the exact target path
When a Cowork session produces a deploy artefact and instructs the operator to place it on a server, it
MUST name the EXACT folder/subfolder explicitly — never "put it on the server". Examples:
- "Copy `staging/align_rtmviewdb_<stamp>.sql` to `C:\RTMView-Ops\incoming\` on Server 45 (PG17), then
  apply: `C:\Program Files\PostgreSQL\17\bin\psql.exe -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f C:\RTMView-Ops\incoming\align_rtmviewdb_<stamp>.sql`"
- "Output (delta report) will land in `C:\RTMView-Ops\output\`."
Symmetrically — when an OUTPUT file is needed back (e.g. CC must ingest a Compare delta report, an
exported dump, or a psql log), the Cowork session MUST state the EXACT source path to fetch FROM and where
to bring it. Examples:
- "Fetch `C:\RTMView-Ops\output\baseline_delta_rtmviewdb_<stamp>.txt` from Server 45 and paste it
  back / drop it into `staging/` so I can ingest the drift."
- "The pg_dump will be at `C:\RTMView-Ops\backup\rtmviewdb_<stamp>.backup` — bring it to <path> for the package build."
No ambiguity about where files go, where outputs come FROM, or which PG version applies.

## SERVER.md template (place on each server, fill once)
```
Server: Server 45
PG version: 17
TenantId: <uuid from CcDashboard admin>
Hostname: <host>
SignalR URL: <TenantSettings.SignalRConnectionUrl>
Notes: <test server | prod | ...>
```
