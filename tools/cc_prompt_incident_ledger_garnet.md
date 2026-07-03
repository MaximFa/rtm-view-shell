# CC TASK — INC-001(d) Garnet VALIDATED ledger update + role-incident §B CAPTURE (v3, docs:, NO push)

Issued by: incident-0620 (Cowork). Authorised: coordinator (2026-07-01 — fold Garnet validation into INC-001 ledger).
BRANCH = **v3** (post-consolidation SINGLE line — v2-backend was merged into v3 @9bf7c11; the old incident=v2-backend map is SUPERSEDED). NO push (§37). Two files, both incident-owned:
`docs/incidents/incidents.md` + `.claude/skills/role-incident/role-incident.md`.

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-incident/role-incident.md   (§A + §C — you are editing its §B)

## Step 0 — INTEGRITY + BRANCH (§0.6a + branch-map rule)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git checkout v3
git rev-parse --abbrev-ref HEAD           # MUST print v3 (abort otherwise)
git rev-parse --short HEAD           # MUST equal 9bf7c11 (v3 tip, post-consolidation) — abort otherwise
git status --short
# object-store hash-verify the two targets vs HEAD (mount false-M; do NOT restore unless truncated):
for f in docs/incidents/incidents.md .claude/skills/role-incident/role-incident.md; do
  echo "$f WT=$(git hash-object "$f")  HEAD=$(git rev-parse HEAD:"$f")"
done
```
Expect WT==HEAD for both (ledger 99ea84e, role-incident 50c23f4). If a file is truncated vs HEAD, restore `git show HEAD:<f> > <f>` before editing.

## Step 0.6b — BINDING PREAMBLE (Python+fsync -> .coord/cc/incident.md)
```
## BINDING <UTC> | spec: incident | directive: tools/cc_prompt_incident_ledger_garnet.md | status: open
### DIRECTIVE: INC-001(d) Garnet VALIDATED ledger update + §B capture. claim: docs/incidents/** + .claude/skills/role-incident/**. gate: commit.lock, no push, branch v3.
```

## Claims
Slug incident-0620. Claim: docs/incidents/** + .claude/skills/role-incident/**. Touch ONLY those two files.
Barrier: if `.coord/push/request.md` is present+non-empty -> STOP (barrier active), report. Else proceed.

## Step 1 — commit.lock (atomic, retry 5x60s)
```bash
python3 - <<'PY'
import os,time,datetime
lock=".coord/locks/commit.lock"; os.makedirs(os.path.dirname(lock),exist_ok=True)
for i in range(5):
    try:
        fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
        os.write(fd,f"incident-0620 {datetime.datetime.utcnow().isoformat()}Z".encode()); os.fsync(fd); os.close(fd)
        print("LOCK ACQUIRED"); break
    except FileExistsError:
        try: print("busy:",open(lock).read())
        except: print("busy (phantom? content-check)")
        time.sleep(60)
else:
    raise SystemExit("commit.lock busy 5x60s — ABORT, report owner")
PY
```

## Step 2 — apply edits (Python + os.fsync; exact anchors)
```bash
python3 - <<'PY'
import os
# ---- A) ledger ----
lp="docs/incidents/incidents.md"
t=open(lp,encoding="utf-8").read()
old_cell="durable fix (d) = production-licensed Redis + (a) shell degrade, PENDING operator decision/deploy |"
new_cell=("durable fix (d) = Microsoft Garnet (free/MIT, no 10-day tier limit) — VALIDATED GREEN local, "
          "operator-accepted 2026-07-01; (a) 9732eab graceful-degrade CONFIRMED; residual = prod-234 rollout "
          "+ cross-instance retest |")
assert old_cell in t, "ledger status-cell anchor missing"
t=t.replace(old_cell,new_cell)
tail_anchor=("[resilience] > (b) SC auto-restart [interim stop-gap only] ; + fleet-wide edition audit (10-day time-bomb).")
assert tail_anchor in t, "ledger tail anchor missing"
section="""

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
"""
t=t.replace(tail_anchor, tail_anchor+section, 1)
open(lp,"w",encoding="utf-8").write(t)
import os as _o
with open(lp,"a",encoding="utf-8") as f: f.flush(); _o.fsync(f.fileno())

# ---- B) role-incident §B capture (discharge NORM-CUR-11 debt) ----
rp=".claude/skills/role-incident/role-incident.md"
r=open(rp,encoding="utf-8").read()
before="\n\n## §C VERIFY"
assert before in r, "§C anchor missing"
lessons=(
"- 2026-06-21 . INC-001 RCA: coordinator's KEY hypothesis (Memurai Startup!=Automatic) was FALSIFIED by "
"evidence (svc_config StartMode=Auto). Real chain = crash 03:55 (7034) + EMPTY sc-qfailure (no recovery) + "
"Shell backplane hard-dep. RULES: verify-hardest the prior-contradicting evidence; separate the outage-"
"AMPLIFIER root (no-recovery+hard-dep, established) from the crash-TRIGGER root; live post-restart INFO "
"describes 'now', not the death moment. . SOURCE: INC-001 evidence A1-A5 2026-06-21 . status: active\n"
"- 2026-06-21 . INC-001 trigger = VENDOR/LICENSE-TIER limit: Memurai Developer 10-day max-uptime auto-"
"shutdown (vendor FAQ + exact 10-day Event-Log arithmetic + INFO server memurai_edition=Developer). RULE: "
"add tier limits (uptime/IP/RAM caps, eval expiry) as a FIRST-CLASS hypothesis class for dependency crashes "
"— a 7034 with NO resource pressure + a periodic interval => suspect a built-in tier timer; auto-restart only "
"MASKS it, durable fix = the licensed/limitless product. . SOURCE: INC-001 INFO server + Memurai FAQ . status: active\n"
"- 2026-07-01 . INC-001(d) durable-fix validation: proof exercised the ACTUAL failure mode (dependency DOWN "
"at start, NON-Dev so the backplane path is real) — Garnet-down degraded gracefully (no 1011) where Memurai-"
"down blacked out. RULE: validate a resilience fix by REPRODUCING the fault in a prod-like env, never against "
"the mitigated/healthy state (anti false-confirmation, §A#6). . SOURCE: coordinator 2026-07-01 Garnet GREEN . status: active\n"
)
r=r.replace(before, "\n"+lessons+before, 1)
open(rp,"w",encoding="utf-8").write(r)
with open(rp,"a",encoding="utf-8") as f: f.flush(); _o.fsync(f.fileno())
print("edits applied")
PY
sync
tail -3 docs/incidents/incidents.md
wc -l docs/incidents/incidents.md .claude/skills/role-incident/role-incident.md
```

## Step 3 — pre-commit + commit (narrow; .claude needs -f)
```bash
bash tools/pre-commit-check.sh docs/incidents/incidents.md .claude/skills/role-incident/role-incident.md
cp .git/index /tmp/inc-idx
GIT_INDEX_FILE=/tmp/inc-idx git add docs/incidents/incidents.md
GIT_INDEX_FILE=/tmp/inc-idx git add -f .claude/skills/role-incident/role-incident.md
TREE=$(GIT_INDEX_FILE=/tmp/inc-idx git write-tree)
COMMIT=$(GIT_INDEX_FILE=/tmp/inc-idx git commit-tree "$TREE" -p HEAD -m "docs: INC-001(d) Garnet durable-fix VALIDATED + role-incident §B capture (NORM-CUR-11)")
python3 - <<PY
import os,subprocess
gd=subprocess.check_output(['git','rev-parse','--git-dir']).decode().strip()
head=open(os.path.join(gd,'HEAD')).read().strip(); ref=head[5:] if head.startswith('ref: ') else None
assert ref,"detached"; open(os.path.join(gd,ref),'w').write("$COMMIT\n"); print("HEAD ->","$COMMIT")
PY
cp /tmp/inc-idx .git/index
```

## Step 4 — verify (§0.6) + journal/lock-release + re-sync (§0.7)
```bash
git log --oneline -1
git status --short -- docs/incidents/incidents.md .claude/skills/role-incident/role-incident.md   # must be clean
git show HEAD:docs/incidents/incidents.md | wc -l ; wc -l docs/incidents/incidents.md               # match
bash tools/cc_post_commit.sh incident-0620 <HASH>     # journal + flush + lock-release
git show HEAD:docs/incidents/incidents.md > docs/incidents/incidents.md
git show HEAD:.claude/skills/role-incident/role-incident.md > .claude/skills/role-incident/role-incident.md
sync
```

## Step 0.6b — BINDING POSTAMBLE (-> .coord/cc/incident.md)
```
### RESULT: commit <hash> . files 2 (ledger + role-incident §B) . build/test n/a . status done . blockers none . verified: object-store . branch v3
```

## DO NOT push (§37). Report the hash to incident-0620 / coordinator.
