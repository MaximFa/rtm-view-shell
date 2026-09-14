# MOVE OUR ENGINE OFF THE SHARED PORT: 8088 -> 8089

> Author: devops-0912, 2026-09-14. Runs on SERVER 234. **This procedure WRITES**: one config value, a
> service restart, and one UPDATE in the production database. Awaiting coordinator §4 on the text; the
> word to hand out comes separately.
> Operator's word, 2026-09-14: both edits now, including the database.

## 0. WHY — measured, not argued

```
tenant_settings."SignalRConnectionUrl" = http://127.0.0.1:8088
8088 listeners : ::        pid 3576  C:\IceDash\RTM\RTM.exe   svc RTM         (LEGACY, wildcard)
                 127.0.0.1 pid 1816  C:\RTMView\RTM\RTM.exe   svc RTMService  (OURS)
Shell's five live sockets 50321..50325, created 2026-09-13 23:59:46, are held at the server end by
pid 3576 - the LEGACY engine. Matched by socket NUMBERS, both ends, not by any rule about bindings.
Our engine has a listener on 8088 and ZERO established connections on it.
```
So our Shell has been talking to the legacy engine, and our engine was never asked anything: hence the
zero `OnConnected`, `init GridId=`, `Groups.Add` and `<<getUsers` in our log while the Shell logged a
successful handshake. The address is ambiguous BY CONSTRUCTION, and the fix removes the ambiguity
instead of checking for it.

**The adapter is already correct** and is NOT touched: `RTM:Targets[1].Url = http://127.0.0.1:8089`,
`Pipe = rtmpipe_v3`. It is the ENGINE that diverged. `8089` currently has NO listener [measured].

## 0.6b BINDING PREAMBLE — do this FIRST, before any edit

```
binding: .coord/cc/devops.md
binding: tools/cc_prompt_port8089_move.md   status open -> done|failed
```

Append to `.coord/cc/devops.md`:

```
## BINDING <UTC timestamp> | spec: devops | directive: tools/cc_prompt_port8089_move.md | status: open
### DIRECTIVE: move OUR engine off the shared port 8088 to 8089 (D1 config + D2 restart), then point
### tenant_settings."SignalRConnectionUrl" at the new port (D3). Adapter untouched - already on 8089.
### Legacy C:\IceDash\* untouched. Acceptance is socket-level, see section 4.
```
Serialisation: if `commit.lock` is held by another role, wait - do not edit under a held lock. The
conventions for that live in `tools/cc_prompt_sync_block.md`. Nothing here commits tracked files, so
the lock matters only if someone else is mid-commit on this clone.
A `RESULT` line is written back to the same binding **on every outcome, including a stop**
(`status: failed` plus the blocker) - a binding that stays silent is indistinguishable from a binding
that succeeded.

## 1. ENTRY PREDICATES — a mismatch is a STOP, never a guess

Re-measure ALL of these immediately before touching anything; they were taken an hour earlier and an
hour is enough for any of them to change:

```
a) 8089 has NO listener                         (if someone took it, STOP - pick another port with the coordinator)
b) engine config Kestrel:Endpoints:Http:Url  == http://127.0.0.1:8088
c) tenant_settings."SignalRConnectionUrl"    == http://127.0.0.1:8088   (SELECT, one row for the tenant)
d) services: RTMService and RTMTwilio_1 Running; note RTMViewShell's start time and DO NOT touch it
```

## 2. D1 — the config edit, one value

File: `C:\RTMView\RTM\appsettings.json`.

1. **Back it up first** - `appsettings.json.devops_<stamp>.bak` beside it. This is the only rollback.
2. Record sha256 and byte size BEFORE.
3. Replace the single value `http://127.0.0.1:8088` with `http://127.0.0.1:8089`.
   **A targeted replacement of ONE value**: do not re-serialise the JSON, do not reformat, do not touch
   neighbouring keys. A round-trip through `ConvertTo-Json` rewrites the whole file and has burned us
   before (two spaces after the colon in production files, literals from the repo not matching).
4. Verify by BYTES, not by eye: the file still starts with the same first three bytes (BOM state
   unchanged), size delta is exactly 0 (8088 and 8089 are the same length), `NUL` count 0, and the file
   still parses as JSON.
5. Print the ONE value after the edit. Do not print the rest of the file - it carries machine secrets.
   Guard: if the replacement matched 0 places, STOP and restore - a no-op edit that reports success is
   how a service quietly keeps its old configuration.

## 3. D2 — restart, in the order the invariant requires

```
Restart-Service RTMService      -> wait, confirm Running
Restart-Service RTMTwilio_1     -> wait, confirm Running      (engine restart ALWAYS carries the adapter:
                                                               this adapter revision has no reconnect)
RTMViewShell : NOT TOUCHED. Print its start time before and after to prove it.
```
Print each service's pid and start time. If the engine fails to start, restore the `.bak`, restart, and
report - do not iterate on a live server.

## 4. D3 — the database, and it is the only write outside our own folder

```sql
SELECT "SignalRConnectionUrl" FROM tenant_settings
 WHERE "TenantId" = '019e03e9-60dd-72da-bd01-648ffdb2b433';        -- BEFORE, printed

UPDATE tenant_settings SET "SignalRConnectionUrl" = 'http://127.0.0.1:8089'
 WHERE "TenantId" = '019e03e9-60dd-72da-bd01-648ffdb2b433';        -- WHERE is mandatory and is shown

SELECT "SignalRConnectionUrl" FROM tenant_settings
 WHERE "TenantId" = '019e03e9-60dd-72da-bd01-648ffdb2b433';        -- AFTER, printed
```
- Port **5433** explicitly. 5432 is the old PostgreSQL 15 and must never be written.
- Password only via `Read-Host -AsSecureString`; the value never reaches the output, the report or the chat.
- **Rows affected must be exactly 1.** Anything else - 0, or more than 1 - is a STOP: restore the
  previous value with the same WHERE and report. `UPDATE` without a proven row count is not a measurement.
- The column and table names come from the schema as measured (`tenant_settings`, `"TenantId"`,
  `"SignalRConnectionUrl"`, discovered in `information_schema`), not from EF naming conventions.

## 5. ACCEPTANCE — socket-level, and independent of traffic

```
1) 8089 has EXACTLY ONE listener and it is our RTMService pid
2) our pid is NO LONGER on 8088   (legacy stays there - it is not ours to move)
3) the database value reads http://127.0.0.1:8089 , one row
4) THE REAL GATE: Get-NetTCPConnection -RemotePort 8089 -State Established
   -> the client end is the Shell pid, and the SERVER end of those same socket numbers is OUR engine pid.
   Matched by socket numbers, both ends - the same predicate that exposed the substitution tonight.
```
**Negative half, stated in advance:** if the Shell is still attached to 8088/legacy after the change,
that is NOT a failed edit - the Shell has simply not re-dialled yet. Report it as a STATE, name the
sockets and their creation times, and ASK before restarting the Shell. Restarting it is a decision about
the acceptance window, not a tidy-up.
Positive control for the connection query: run it once against a port known to be alive (8444) so that
an empty result cannot be confused with a broken query.

## 6. WHAT THIS PROCEDURE MUST NOT DO

No touching `C:\IceDash\*` - not even reading its configuration; the subject is OUR address, not their
service. No `C:\Program Files\CcDashboard\*`. No writes to PostgreSQL 15 on 5432. No `-FreshDb`. No
Shell restart without asking. No push. No commit of tracked files unless the coordinator asks, and if
one is ever needed: `git commit -m "..." -- "<path>"` with the pathspec LAST.

## 7. RESULT — written back to the binding

Entry predicates as measured; config sha before/after and the single value; each service pid and start
time with the Shell's proven unchanged; rows affected by the UPDATE; the four acceptance numbers; and
anything that stopped the run. On a stop: `status: failed` with the blocker named, and the state the
server was left in.
