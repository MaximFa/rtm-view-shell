# RTM View Shell — Incident Ledger
> Owner: role-incident. Durable, versioned. Each incident pinned to the FLOOR (specific error + stack), not a narrative.
> Processing: KNOWN-DETECTION by floor-signature FIRST; match -> confirm signature -> apply known fix; no match -> full diagnosis.

| ID | Date/time | Server | Symptoms (observed) | Root (FLOOR-pinned) | Resolution (+durable status) | Status |
|---|---|---|---|---|---|---|
| INC-2026.06.20-001 | 2026-06-20 ~14:07 +03 | 234 | dashboard VIEW does not open; EDIT opens but empty (no grid, no widgets); server log shows dashboards/widgets rendering server-side, so NOT data/code | Redis/Memurai DOWN -> SignalR Redis backplane `RedisHubLifetimeManager.OnConnectedAsync` throws on circuit connect -> WebSocket 1011 -> every interactive Blazor page blank (view AND edit). PIN: log-20260620 ~14:07 Redis errors (x7) + RedisHubLifetimeManager.OnConnectedAsync stack; aoc:1 | Immediate (DONE): restart Memurai (Redis) -> prod restored. Durable (PENDING §4): (a) shell Program.cs AbortOnConnectFail=false; (b) devops Memurai service resilience; (c) ledger detail below. Owners DISPATCHED (shell a / devops b). RCA findings A1-A5 below: outage-CHAIN root established (crash 03:55 + NO service-recovery + Shell backplane hard-dep); crash-TRIGGER cause still open (Memurai log @03:55 outstanding). H1 (Startup!=Automatic) FALSIFIED. | resolved (app) / ROOT CONFIRMED (Memurai Developer 10-day auto-shutdown, edition pinned via INFO server); durable fix (d) = Microsoft Garnet (free/MIT, no 10-day tier limit) — VALIDATED GREEN local, operator-accepted 2026-07-01; (a) 9732eab graceful-degrade CONFIRMED; residual = prod-234 rollout + cross-instance retest |

## Notes
- Same symptom ("editor empty") has had DIFFERENT roots historically (Redis-down vs stale-asset-cache vs ConfigJson-format) -> ALWAYS match by floor-signature (error+stack), never by symptom.

## INC-2026.06.20-001 — durable detail

### Why BOTH view AND edit die from ONE backplane failure
Both `/screens/{id}` (Viewer) and the Screen Editor are **InteractiveServer Blazor** pages. Each
page opens its own **SignalR circuit**. The circuit's connect path runs through the SignalR
**Redis backplane** (`AddStackExchangeRedis`, Program.cs:41-45). When Redis/Memurai is DOWN and
`AbortOnConnectFail` is at its default (`true`), `RedisHubLifetimeManager.OnConnectedAsync` throws
at connect -> the circuit fails to establish -> the browser WebSocket closes with **1011** -> the
page renders its server-side shell (so the HTML/log shows dashboards+widgets rendering) but never
becomes interactive: blank grid, no widgets. This is **transport-level and shared**, NOT per-page,
NOT data, NOT code. That is exactly why a "view vs edit" difference is a red herring — both ride the
same circuit transport. Server-side render success in the log MISLEADS toward "data/code is fine, so
it's the page" when the real fault is the circuit that never came up.

### Floor-signature (match THIS, not the symptom)
- Shell log: `RedisHubLifetimeManager.OnConnectedAsync` in the stack + Redis connect errors (here x7).
- Browser/WS: close code **1011** on the circuit socket.
- Service: Memurai (Redis on Windows, DEPLOY-11) not running / connection refused on 6379.

### How to confirm in SECONDS next time
1. Is Memurai/Redis service running? (`Get-Service Memurai*` / connect 127.0.0.1:6379).
2. Hit **`/health/ready`** — it ALREADY includes a Redis check (Program.cs:124 `.AddRedis(...)`),
   so a Redis outage reports **Unhealthy** there. Use this as the fast oracle, not the blank pages.
3. grep the Shell log for `RedisHubLifetimeManager.OnConnectedAsync` + `1011`.
Match all three -> apply known fix (restart Memurai = immediate; durable below).

### Durable fix (ownership split — routed via coordinator §4; PENDING bless)
- **(a) shell** — Program.cs:44-45, inside the `AddStackExchangeRedis(...)` options lambda set
  `opts.Configuration.AbortOnConnectFail = false;`. A Redis that is unreachable AT STARTUP then
  degrades (background retry) instead of throwing and killing the circuit.
- **(b) devops** — Memurai Windows service resilience: Startup=Automatic + service recovery
  (auto-restart on failure). NOTE: `/health/ready` Redis check is ALREADY present (Program.cs:124)
  — outage is observable on health today; verify it is monitored/alerted.
- **(c) ledger** — this durable section (DONE).
- Deploy (a)+(b) as ONE release (config + service together).

### Acceptance gate — beware FALSE-CONFIRMATION
Redis is UP again (mitigation done). A test run now passes for the WRONG reason. The durable fix is
ONLY proven by: **stop Memurai -> start Shell with Redis DOWN -> both the Viewer page AND the Editor
page still open and become interactive.** Do NOT accept a green that the mitigation makes green.
**2nd false-confirmation vector (coordinator §4 amend, 2026-06-21):** the backplane is registered ONLY
under `if (!isDev)` (Program.cs:43) -> AddStackExchangeRedis is NEVER wired in Development. A Dev-mode
test would pass for the WRONG reason (no backplane path exercised). ACCEPTANCE MUST run in a prod-like
env: `ASPNETCORE_ENVIRONMENT != Development` (on 234, or local `--no-launch-profile` Production).


### RCA — WHY Memurai died (PENDING evidence from 234)  [coordinator follow-up I, priority]
Resolution-first != root-cause-blind. (b) auto-restart treats the SYMPTOM; the dependency-failure root
is NOT yet established. INC-001 durable status stays **PENDING** until WHY is known or explicitly
accepted as a one-off. I am diagnosis-only -> EVIDENCE-REQUEST to operator for server 234, then analyse.

Evidence requested (server 234, around 2026-06-20 ~14:07 +03):
1. **Windows Event Log (Application + System)** near 14:07: Memurai service stop/crash event, exit code,
   any OOM/Resource-Exhaustion entries.
2. **Memurai's own Redis log** — last lines before death: OOM/`maxmemory` reached, RDB save (BGSAVE)
   failure, SIGTERM/clean stop vs crash.
3. **Resource floor:** memory pressure on the box; **DISK FULL** (DEPLOY-11 RDB snapshot every 5 min ->
   save fail -> crash) — free space on the Redis data drive; `maxmemory` + eviction policy.
4. **KEY hypothesis (deploy-as-trigger -> floor):** did the recent binary update / a reboot leave Memurai
   STOPPED because service **Startup != Automatic**? Confirm Memurai service start-type + start/stop
   history on 234. If yes -> that IS the WHY and ties directly to (b).
5. **One-off vs flapping:** has Memurai stopped before? Service history / Event Log frequency.

Hypotheses held (>=2, cross-layer; NOT collapsed): (H1) service Startup!=Automatic + reboot/deploy ->
left stopped [ties to b]; (H2) crash from resource floor (disk-full RDB-save fail / OOM-maxmemory);
(H3) clean SIGTERM by an external actor (manual/installer). Verify HARDEST the evidence that
CONTRADICTS the convenient "deploy left it stopped" story before concluding.

### Recommendation (II) — Post-deploy dependency smoke-step  [deploy-hardening; route to devops/coordinator LATER]
A deploy must not be 'complete' until dependencies are verified ALIVE: after binary/service deploy,
probe Redis/Memurai (PING 127.0.0.1:6379) AND PostgreSQL, and hit `/health/ready` expecting Healthy,
BEFORE declaring the deploy done. Draft only — folds into the devops/coordinator deploy-hardening stream.

### Recommendation (III) — /health/ready alerting gap  [route to devops LATER]
Verified in code: `/health/ready` is mapped (Program.cs:169) and runs the Redis + Npgsql checks
(registered Program.cs:122-124), so a Redis outage DOES report Unhealthy. GAP: it is **pull-only** —
no HealthCheckPublisher / no alert hook is wired, so nobody is PAGED; the outage surfaced only as blank
user pages. Recommendation: wire readiness to an alert (publisher -> ops channel) so Redis-down pages an
operator instead of users. Draft only — route to devops after current load.

### CAPTURE pending (NORM-CUR-11) — role-incident §B lesson (rides next CC touch of the skill)
Exact line to append to `.claude/skills/role-incident/role-incident.md` §B:
`2026-06-20 . INC-001: investigate WHY the dependency died, not just the app's reaction. Auto-restart
(b) masks the root; durable status stays PENDING until the Memurai-death RCA is established or accepted
one-off. RULE: resolution-first != root-cause-blind; a symptom-restart is mitigation, not durable fix. .
SOURCE: INC-2026.06.20-001 + coordinator follow-up 2026-06-21 . status: active`
(Skill edits go via CC per L-SC-24 / .claude is not a Cowork-write exception -> not written here.)


### RCA FINDINGS (evidence A1-A5, 2026-06-21) — CHAIN established, crash-cause OPEN
**Corrected timeline (floor-pinned):**
- `2026-06-20 03:55:17` — Memurai **terminated unexpectedly** (Event System 7034, "...1 time(s)"). NOT a clean stop. PIN: svc_state_history + memurai_history_14d.
- No SC failure/recovery action configured (`sc qfailure` empty: RESET_PERIOD 0, no actions). PIN: svc_recovery.txt -> service stayed DOWN ~10.5 h.
- `~14:07` — incident noticed (Viewer + Editor blank). RTMViewShell restarted 14:06:52->14:07:06 (A1) — did NOT help (backplane dep still dead).
- `2026-06-20 14:30:33` — Memurai started (running) = manual mitigation -> prod restored. PIN: svc_state_history 7036.

**Hypotheses resolved against evidence:**
- H1 (deploy/reboot left it STOPPED because Startup!=Automatic) — **FALSIFIED**: `StartMode: Auto` (svc_config.txt). The coordinator's KEY hypothesis did not hold; verifying-hardest-the-contradicting-evidence (§A#4) paid off.
- H2 (resource floor: disk-full / OOM / RDB-save fail) — **not supported by current state**: disk C: 37.5 GB free, used_memory 1.16M vs maxmemory 7.98G (noeviction), rdb_last_bgsave_status:ok, no Resource-Exhaustion event (A1/A3). CAVEAT: A3 is POST-restart live state, not the 03:55 moment -> cannot fully exclude a transient at 03:55 without the Memurai log.
- H3 (clean external SIGTERM) — **weakened**: 7034 = unexpected termination (crash), not a clean 7036 stop.

**Outage-CHAIN root (ESTABLISHED, durable-actionable):** a single dependency (Memurai/Redis) crash, with NO service auto-recovery, against a Shell that hard-depends on the SignalR Redis backplane at circuit-connect (AbortOnConnectFail default true) -> 10 h total blackout of ALL interactive pages. Both durable fixes are evidence-validated: (a) shell AbortOnConnectFail=false (Shell would degrade, not blackout) AND (b) devops SC recovery actions (would auto-restart Memurai after the 03:55 crash instead of 10 h down). (b) is now CONCRETE: `sc qfailure` is empty -> configure failure actions (restart after N s + reset period).

**Crash-TRIGGER cause (OPEN — durable stays PENDING):** WHY Memurai crashed at 03:55 is NOT yet pinned. The Memurai own log around 03:55 (logfile "memurai-log.txt" in C:\Program Files\Memurai) is the outstanding artifact. LEAD: both 06-10 (~03:53, clean stop/start cycle) and 06-20 (03:55, crash) cluster at ~03:5x AM -> a NIGHTLY scheduled job likely touches Memurai; on 06-20 that interaction produced a crash. Route to devops to identify the 03:5x scheduled task (backup/maintenance) once log is read. One-off so far (1 unexpected termination / 14 days) — NOT flapping.

### CAPTURE pending (NORM-CUR-11) — sharpened role-incident §B lesson (rides next CC touch of skill)
`2026-06-20 . INC-001 RCA: the coordinator's KEY hypothesis (Memurai Startup!=Automatic) was FALSIFIED by
evidence (svc_config StartMode=Auto). Real chain = unexpected crash 03:55 (7034) + EMPTY sc-qfailure
(no recovery) + Shell backplane hard-dep. RULES: (1) verify-hardest the evidence that contradicts the
prior - it overturned the convenient story; (2) separate the outage-AMPLIFIER root (no-recovery + hard-dep,
ESTABLISHED) from the crash-TRIGGER root (still open); a symptom-restart/auto-restart is mitigation, durable
stays PENDING until the trigger is pinned to a floor line; (3) live post-restart INFO describes "now", not
the death moment. . SOURCE: INC-2026.06.20-001 evidence A1-A5 2026-06-21 . status: active`
`2026-06-21 . INC-001 trigger: operator domain-knowledge (free-tier) cracked it; confirmed via vendor FAQ
(Developer Edition 10-day max-uptime auto-shutdown) + EXACT 10-day Event-Log arithmetic + INFO server
memurai_edition=Developer. RULE: add VENDOR/LICENSE-TIER limits (uptime caps, connection/RAM caps, eval
expiry) as a first-class hypothesis class for dependency crashes - NOT just resource/config/code. A 7034
"unexpected termination" with NO resource pressure + a periodic interval = suspect a built-in tier timer.
And: auto-restart MASKS a recurring tier-limit root - the durable fix is the licensed product. .
SOURCE: INC-001 INFO server + Memurai FAQ 2026-06-21 . status: active`
(Skill edits via CC per L-SC-24; not written from Cowork.)


### RCA UPDATE — crash-TRIGGER root FOUND (H4: Memurai Developer Edition 10-day uptime limit)
Operator hypothesis (free-tier built-in timer) + vendor doc + Event-Log arithmetic converge:
- **Memurai Developer Edition (free) auto-shuts-down after a MAX UPTIME of 10 days** (vendor FAQ;
  also: 10 unique-IP limit, RAM cap 50% of system). Licensed for NON-PRODUCTION only — prod use prohibited.
- Arithmetic (floor): last clean start `06-10 03:54:12` (A5) -> crash `06-20 03:55:17` (7034) = **exactly
  10 days + ~65 s**. The self-shutdown exits the process -> SCM logs 7034 "terminated unexpectedly".
- Explains the ~03:5x clustering: it is start-time + 10 days, NOT a wall-clock nightly job.
- Confidence HIGH; explicit floor-line confirmation outstanding = the Memurai log line @03:55 (will state
  the shutdown reason) + `INFO server` (memurai_edition / uptime_in_days). Pull then close.

**DURABLE FIX — REFRAMED (this changes (b)):**
- (a) shell `AbortOnConnectFail=false` — STILL valid (Shell must degrade, not blackout, on any Redis loss).
- (b) devops SC auto-restart — would only MASK a RECURRING 10-day outage, and Developer Edition in
  production is a LICENSE VIOLATION. Auto-restart is a stop-gap, not the fix.
- **(d) ROOT fix (operator decision): replace Memurai Developer with a PRODUCTION-licensed Memurai
  edition (or production-appropriate Redis) on prod servers.** Without it, the 10-day timer re-arms on
  every restart -> guaranteed recurrence ~every 10 days.
- **FLEET-WIDE flag:** every prod server running Memurai Developer Edition has the same 10-day time-bomb
  -> audit all servers (234 + others) for edition; the next shutdown is predictable (last start + 10 days).


### RCA CLOSED on root (edition pinned, 2026-06-21)
`INFO server` confirms **`memurai_edition: Memurai Developer`** (memurai_version 4.2.2, redis_version 7.4.7),
service_name Memurai, uptime_in_seconds 72193 (~20h since the 14:30 manual restart). Combined with the exact
10-day arithmetic (start 06-10 03:54:12 -> crash 06-20 03:55:17 = 10 days) this PINS the crash-trigger root:
**Memurai Developer Edition max-uptime (10 days) auto-shutdown.** Status moves from durable-PENDING(open) to
durable-PENDING(operator decision): the ROOT is known; what remains is the FIX DEPLOY (d) + (a)/(b).
Optional extra corroboration (not required): the Memurai log line @03:55 stating the shutdown reason.
DURABLE actions (priority): (d) production-licensed Redis on prod [ROOT] > (a) shell AbortOnConnectFail=false
[resilience] > (b) SC auto-restart [interim stop-gap only] ; + fleet-wide edition audit (10-day time-bomb).

### INC-001(d) Garnet durable-fix VALIDATED — real-app local, operator-accepted 2026-07-01
Chosen replacement for Memurai Developer = **Microsoft Garnet** (free/MIT, native Windows, RESP; NO 10-day/
IP/RAM tier cap). Local real-Shell validation GREEN:
- STEP0: real Shell up in NON-Development (backplane wires; the PoC Caveat-3 dev-DB-drift blocker was gone).
- STEP1/2: Garnet 1.1.10 on :6379 with auth; /health 200; 14-channel SignalR backplane ACTIVE
  (RedisHubLifetimeManager Connected).
- STEP3 (KEY): Shell SURVIVED Garnet-DOWN **gracefully** (AbortOnConnectFail=false, 9732eab) — NO WebSocket
  1011 circuit-kill (UNLIKE Memurai-down in the original incident); auto-recovered on `garnet --recover`
  (health 503->200). Real circuit UP (/screens list + dashboard viewer, not "Connecting...").
- Residual (honest): validated SINGLE-instance local circuit; cross-instance fan-out on the real Shell not
  re-tested locally (PoC harness had covered 2-instance fan-out). Accepted by operator.
- VERDICT: Garnet-down degrades better than Memurai-down (graceful vs blank/1011) => INC-001 durable-fix (d)
  VALIDATED. Durable status: (d) validated + operator-accepted; remaining = prod-234 rollout + cross-instance
  retest. (a) 9732eab, (b) da4cd7e already in v3.

