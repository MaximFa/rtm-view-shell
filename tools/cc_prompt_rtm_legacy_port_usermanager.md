# CC task — LEGACY→v3 port (rtm): UserManager.cs — 2 bug-fixes + restore wait-for-call state machine — §4 PRE-BLESSED (coordinator)

> PORT-2026-07-10-A (legacy port line, .coord/legacy_port_line.md). Operator: legacy runs at clients; port ONLY real changes to existing logic, **DELETE NOTHING**, no loss of v3 functionality.
> Scope: `RTM/RTM/UserManager.cs` ONLY. Engine.cs = NO edits (legacy had none real). Call.cs = identical. Source-of-truth spec below (verified 2-way against files; legacy source = `10072026/RTM_new_cs_files/UserManager.cs`).
> Owner: rtm/backend. Executor: native CC. Branch **v3 ONLY**. Commit `fix(rtm):`. **NO push** (§37). Report-scoped.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-backend/role-backend.md (if present; §A CORE + §C VERIFY)
Read: .claude/skills/rtm-service-expert/rtm-service-expert.md (if present)
Read: CLAUDE.md §0.2/§0.3/§0.5/§0.6, §33 (RTM), §36 (RTM data flow)
Only after reading: proceed.

## INIT — §0.6a integrity + branch (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3
git fetch origin && git rev-parse origin/v3   # local >= origin/v3 (12480b2)
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
  [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- §0.3 Python+fsync; Edit BANNED. Preserve v3 file LF/no-BOM. Hebrew literals must stay UTF-8.

## §0.6b BINDING PREAMBLE → .coord/cc/backend.md (Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_rtm_legacy_port_usermanager.md | status: open
### DIRECTIVE (spec->CC): PORT-2026-07-10-A UserManager.cs — 2 fixes (st→st1, TotalStatusGroupPercent hardening keep fmt2) + restore wait-for-call machine (4 edits). DELETE NOTHING; preserve calc-quarantine/getLocalDateTime/fmt1/fmt2/ForceRefreshMetrics. v3, fix(rtm):, NO push, §4. Report build=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, rtm)
- RTM/RTM/UserManager.cs — MODIFY (5 edits below). NO other file.

## PRESERVE (v3 features — line numbers approx; DO NOT remove/revert any):
- Calc-quarantine fields (~L15-19) + `case "Calc"` try/catch (~L1406-1463).
- Robust `getLocalDateTime()` offset+IANA/Windows fallback (~L183-214).
- Default-format `fmt1` (~L1226-1227) and `fmt2` (~L1238-1239).
- `ForceRefreshMetrics()` (~L586-603).
Line numbers are anchors — VERIFY by the verbatim OLD snippets below before editing (§0.5, do not trust line numbers blindly).

## THE WORK — 5 edits (each: find the verbatim OLD, replace with NEW)

### EDIT 1 — st→st1 (case "TotalStatusGroupDuration", ~L1208-1212)
OLD:
```
                        if (metric.Parameter == UserStatusGroup)
                        {
                            st = TimeInStatus;
                            val = "+" + st1.Subtract(statusGrpDur).ToString("dd/MM/yyyy HH:mm:ss");
                        }
```
NEW: change ONLY `st = TimeInStatus;` → `st1 = TimeInStatus;` (leave the other two lines identical).
⚠ Do NOT touch the earlier `st = TimeInStatus;` in `TotalStatusDuration` (it uses `st.Subtract`, correct).

### EDIT 2 — TotalStatusGroupPercent hardening, KEEP fmt2 (~L1231-1241) — full case-block replace
OLD:
```
                    case "TotalStatusGroupPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur2 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur2 = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc2 = (double)statusGrpDur2 / (double)loginDur2;
                            var fmt2 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;
                            val = dCalc2.ToString(fmt2); // "#0.##%"
                        }
                        break;
```
NEW:
```
                    case "TotalStatusGroupPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur2 = _TotalStatuses.Values
                                .Where(x => x.StatusId != "SIGNOFF")
                                .Sum(r => r.Dur.Ticks);

                            if (loginDur2 > 0)
                            {
                                long statusGrpDur2 = _TotalStatuses.Values
                                    .Where(x => x.StatusId != "SIGNOFF" && x.StatusGroup == metric.Parameter)
                                    .Sum(r => r.Dur.Ticks);

                                double dCalc2 = (double)statusGrpDur2 / (double)loginDur2;

                                if (!double.IsNaN(dCalc2) && !double.IsInfinity(dCalc2))
                                {
                                    if (dCalc2 < 0)
                                        dCalc2 = 0;

                                    if (dCalc2 > 1)
                                        dCalc2 = 1;

                                    var fmt2 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;
                                    val = dCalc2.ToString(fmt2); // "#0.##%"
                                }
                            }
                        }
                        break;
```
⚠ Do NOT touch adjacent `case "TotalStatusPercent":` (keep its `fmt1`).

### EDIT 3A — constructor SIGNOFF init (~L162-164)
OLD:
```
                _userWorkgroupSumList = new UserWorkgroupSumList();
                _userStatusStart = DateTime.MinValue;
                _userStatusGroupStart = DateTime.Now;
```
NEW:
```
                _userWorkgroupSumList = new UserWorkgroupSumList();

                _userStatus = "SIGNOFF";
                _statusName = "SIGNOFF";
                _userStatusGroup = "SIGNOFF";

                _userStatusStart = DateTime.Now; //.MinValue;
                _userStatusGroupStart = DateTime.Now;
```

### EDIT 3B — new wait-for-call fields (~L295, after `//public bool isLastNoPhone = false;`)
OLD:
```
        //public bool isLastNoPhone = false;

       
        // Set Status
```
NEW:
```
        //public bool isLastNoPhone = false;
        private bool _isWaitForCall = false;
        private string statusBeforeWait = string.Empty;
        private string statusNameBeforeWait = string.Empty;
        private string statusGroupBeforeWait = string.Empty;

       
        // Set Status
```

### EDIT 3C — wait-for-call transition (replace the `if (!isCalcStatus) {…}` block, ~L365-377)
OLD:
```
                    if (!isCalcStatus) // Status from CallCenter
                    {
                        LastNoPhoneStatusId = newStatus;
                        LastNoPhoneStatusName = statusName;
                        LastNoPhoneStatusGroup = statusGroup;
                        AsyncLogger.Info($"LastNoPhoneStatusId = {newStatus}");

                        if (OnPhone)
                        {
                            AsyncLogger.Error("(OnPhone && !isCalcStatus");
                            return;
                        }
                    }
```
NEW (Hebrew literals MUST stay exact UTF-8 — בשיחה = on-call, ממתין לשיחה = wait-for-call):
```
                    if (!isCalcStatus) // Status from CallCenter
                    {
                        if (newStatus != "בשיחה" && newStatus != "ממתין לשיחה")
                        {
                            LastNoPhoneStatusId = newStatus;
                            LastNoPhoneStatusName = statusName;
                            LastNoPhoneStatusGroup = statusGroup;
                            AsyncLogger.Info($"LastNoPhoneStatusId = {newStatus}");
                        }

                        if (OnPhone)
                        {
                            if (newStatus == "ממתין לשיחה")
                            {
                                _isWaitForCall = true;
                                statusBeforeWait = _userStatus;
                                statusNameBeforeWait = _statusName;
                                statusGroupBeforeWait = _userStatusGroup;
                            }
                            else if (newStatus == "בשיחה")
                            {
                                if (_isWaitForCall)
                                {
                                    _isWaitForCall = false;
                                    newStatus = statusBeforeWait;
                                    statusGroup = statusGroupBeforeWait;
                                    statusName = statusNameBeforeWait;
                                }
                                else
                                {
                                    AsyncLogger.Error("newStatus == \"בשיחה\" && !_isWaitForCall");
                                    return;
                                }
                            }
                            else
                            {
                                _isWaitForCall = false;
                                AsyncLogger.Error("(OnPhone && !isCalcStatus");
                                return;
                            }
                        }
                        else
                        {
                            _isWaitForCall = false;
                            if (newStatus == "בשיחה")
                            {
                                AsyncLogger.Error("newStatus == \"בשיחה\" && !OnPhone");
                                return;
                            }
                        }
                    }
```
⚠ Do NOT add any `AsyncLogger.Info($"StatusChanged …")` line that appears in legacy nearby — it is debug noise, NOT part of this port. Downstream v3 logic (`if (onPhone != OnPhone)`, `if (_userStatus != newStatus)`) stays unchanged.

### EDIT 3D — TryAdd variant (else-branch of `_TotalStatuses.ContainsKey(_userStatus)`, ~L466-469)
OLD:
```
                        else
                        {
                            _TotalStatuses.TryAdd(_userStatus, new UserStatusData(this, _userStatus, statusName, statusGroup, ts, _dbMng, userId, false, DisplayName));
                        }
```
NEW (swap args 3/4: params → fields, pairing the outgoing `_userStatus` with its own name/group):
```
                        else
                        {
                            _TotalStatuses.TryAdd(_userStatus, new UserStatusData(this, _userStatus, _statusName, _userStatusGroup, ts, _dbMng, userId, false, DisplayName));
                        }
```
⚠ Do NOT change the OTHER TryAdd (~L493, uses `_userStatus, statusName, statusGroup` for the NEW status — correct as-is).

## DO NOT PORT (leave as v3): StatusChanged debug log; refreshUnions TimeZone= log strings; any getLocalDateTime change; Calc-case (keep quarantine); fmt1 in TotalStatusPercent.

## VERIFY / DoD
- **Object-store:** all 5 edits applied; `grep -c` on `RTM/RTM/UserManager.cs`: `HotReloadMetrics`? (N/A, that's Engine) — confirm PRESERVED tokens still present: `_calcFailures`, `CalcQuarantineThreshold`, `FindSystemTimeZoneById`, `ForceRefreshMetrics`, both `fmt1` and `fmt2` (unchanged counts). New tokens present: `_isWaitForCall` (≥5), `statusBeforeWait`, `בשיחה`, `ממתין לשיחה`. File still LF/no-BOM (`grep -c $'\\r' = 0`).
- **Build — REPORT NUMBERS:** `dotnet build RTM/RTM/RTM.csproj -c Release` (or the RTM solution) = **0 errors** (report warnings). Hebrew literals compile (UTF-8). If build fails → report verbatim, do NOT commit.
- **No feature loss:** diff review — every preserved-feature block still present (calc-quarantine, getLocalDateTime robust, fmt1/fmt2, ForceRefreshMetrics).
- (No unit-test coverage expected for UserManager; if a seam exists you MAY add one, not required.)

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY RTM/RTM/UserManager.cs (+ role-backend.md via `git add -f` if CAPTURE). Commit `fix(rtm): UserManager legacy port — TimeInStatus st→st1 + TotalStatusGroupPercent /0 guard + restore wait-for-call status machine [backend]`.
- `bash tools/cc_post_commit.sh backend <hash>` (or Python+fsync journal). §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE → role-backend §B: "Legacy→v3 forward-port: legacy files sit on an OLD base, so whole-file replace REGRESSES v3. Isolate the operator's real edits by diffing legacy vs its OWN base commit (not vs v3), classify fix/stale/divergent, port only genuine fixes + operator-approved divergent restores, enumerate v3 features to preserve. UserManager: st→st1 (dead-var elapsed), TotalStatusGroupPercent /0-NaN guard (keep fmt2), wait-for-call machine restore (Hebrew status literals; hooks the !isCalcStatus branch, preserves incoming status across wait→talk). SOURCE: PORT-2026-07-10-A, legacy_port_line.md." Binding RESULT → cc/backend.md.

## §0.6b BINDING POSTAMBLE → .coord/cc/backend.md
```
### RESULT (CC->spec): commit <hash> . build <0 err/W n> . files RTM/RTM/UserManager.cs . 5 edits applied . preserved: calc-quarantine/getLocalDateTime/fmt1/fmt2/ForceRefreshMetrics (verified present) . new: wait-for-call (_isWaitForCall + Hebrew literals) . status done|failed . blockers . verified: object-store + build
```
