# Shell role — migration handoff & resume anchor

**Author:** shell-0609 · **Date:** 2026-08-31 · **Branch:** v3 · **For:** the incoming Shell on the NEW account
**Read alongside:** `.claude/skills/role-shell/role-shell.md` (§A CORE every boot + §B LESSONS + §C VERIFY) ·
`CLAUDE.md` (§0 discipline, §21 screens, §34 relay, §41 localStorage, §42/§26 coordination) ·
`.coord/protocols/account-migration-runbook.md` (§4/§5 reconstitution + gate) ·
`.coord/inbox/shell.md` (your mailbox — the step-by-step resume is appended there).

---

## 1. Who you are
- **Role:** Shell — the Blazor Server UI/UX specialist for RTM View Shell (CcDashboard). Old-account slug was
  `shell-0609`; pick a fresh MMDD slug on boot (e.g. `shell-0901`) and write `.coord/sessions/<slug>.md`.
- **Territory (`web` claim):** `src/CcDashboard.Web/**` + the Contracts/Application/Infrastructure DTO/command/query
  surface you touch for a UI feature (use file-mode claims where you overlap backend). You render/configure widgets
  and admin screens. You do NOT own the RTM engine, DB functions, or deploy.
- **You NEVER edit code directly.** Every code change is authored as a CC prompt in `tools/<name>.md`, self-§4-reviewed,
  submitted to the coordinator for §4-bless, then run by native CC / the operator. You (Cowork) analyse, author,
  review, verify, reconcile, and flush to the bus.

## 2. Iron rules (load-bearing — each was learned from a real loss or false alarm)
- **§0.3 WRITES:** the Edit tool is BANNED on this mount. All writes via **Python + `os.fsync`**, then verify `tail`+`wc`.
  `tools/*.md` and `.coord/**` are Cowork-allowed direct writes (still Python+fsync). **NEVER a PowerShell pipe** for
  `.coord` files (PS 5.1 injects a UTF-8 BOM / mojibakes — § → — runbook §7).
- **§0.5 VERIFY BY OBJECT STORE, not the mount.** `git status` / line-counts LIE here (false `M`). Prove state with
  `git hash-object` vs `git rev-parse HEAD:<f>`, `git cat-file -e`, `git show`. Do NOT escalate "corruption" from a mount read.
- **PD-007:** after any commit the Cowork cache can re-truncate committed files. Hash-verify claimed files `==HEAD`;
  restore with `git show HEAD:<f> > <f>`.
- **L-SC-04:** the mount drops journal/binding lines. If a CC RESULT is missing but the commit exists, RECONCILE from
  the object store and write the reconciled RESULT to `.coord/cc/shell.md` yourself.
- **§0.6 / §37 — NO PUSH, EVER, by you.** Push runs only via the dedicated push prompt after a full push-barrier
  quorum, operator-executed. From the mount you cannot push reliably anyway (L-SC-20).
- **§26.8 §4-GATE:** self-§4-review every prompt, then submit to the coordinator for §4-bless. Do NOT run before bless.
  Fold any §4 condition INTO the prompt before it runs (pin facts by reading code — never defer to "verify later").
- **§22 CC-only:** no inline code; the canonical run form is exactly `Выполни задачу из файла tools/<name>.md`.

## 3. Operator working style (from memory)
- `.` = process your inbox (`.coord/inbox/shell.md`) + act on coordinator directives now.
- `..` (or `.` / `,`) = VERIFY the last CC result NOW by object store, reconcile, report — NOT "I am waiting".
- Give the operator/devops steps as **complete copy-paste commands** (full paths, real service names), never prose.
  140/prod layout: InstallRoot `C:\RTMView`; Shell dir `C:\RTMView\Shell`; appsettings `C:\RTMView\Shell\appsettings.json`;
  Windows service `RTMViewShell`; Serilog `C:\RTMView\Shell\logs\log-<date>.txt`; Kestrel orphan-exe (not IIS); server UTC+3.
  Per §43 CC has no external-server access → the OPERATOR runs them.
- Ask clarifying questions as **TEXT ONLY** (the AskUserQuestion tool hangs). Concise answers; dialog RU, docs/code EN.
- Build/unit via **Soma** (§47) over host-Chrome (mount sandbox can't reach host loopback); token from
  `tools/Soma/appsettings.json` (never print/commit). No `build0` claim without evidence; if Soma down, route to devops.

## 4. CURRENT RESUME POINT (verified vs the object store, 2026-08-31)
- **HEAD = 26ecfcb, branch v3. origin/v3 = f6d5c58. 24 commits unpushed — NONE are shell/web** (they are DB / docs /
  curator / coordinator work). Do not touch or push them.
- **THE SHELL ROLE IS IDLE.** No open CC task, no open ack, no push obligation.
- **Last shell delivery = WFM Phase 1 UI — PUSHED + CLOSED** (barrier cd0e39a..d1982de, 9 commits, quorum 6/6,
  2026-07-22T18:05Z; C2 live gate PASSED on 140 with real data: State OK, λ 40/hr, AHT 4:57, N 14, A 3.30 Erl,
  SL 100%, Occ 23.6% — percents NOT double-scaled). Commits: `e84e654` (3c-config: 8 Wfm* fields end-to-end + Tenant
  modal WFM tab) + `30225d6` (3c-widget: WfmWidget reads Singleton `IWfmSnapshotStore` on a 5s PeriodicTimer per
  §34.7 — no hub, no localStorage; renders the §4 contract). Both in origin.
  - **Percentage-scaling pin (permanent):** WfmWidget `FormatPct` renders `*Pct` AS-IS (already 0..100 from the loop);
    `FormatPWait` ×100 the 0..1 `PWaitC`. Never double-scale (the 80%→8000% bug).
  - **Sub-BU "No Data" in WFM = customer CONFIG gap** (BUs without SuperGroups), NOT a shell defect — do not chase.
- The stale `.coord/push/request.md` on disk is the CLOSED WFM barrier (acks left in place — the mount forbids delete).
  Not an open obligation.

## 5. HELD / BACKLOG register (shell) — resume ONLY when the coordinator/operator re-prioritises
1. **TZ Edit-Site IANA UI** — operator BACKLOGGED (stand-down 2026-07-20T16:12Z). Draft preserved; design in
   `docs/design/RTM-Timezone-Coherence-Design.md` + decisions in `.coord/features.md` ITEM A. Do NOT resume unless re-opened.
2. **Agent States Activate/Delete UI** (`tools/cc_prompt_shell_agentstates_activate_delete.md`) — HELD: needs backend to
   add 4 commands (Activate/Delete for State + Group) first.
3. **AgentGrid Duration F5-reset** — separate follow-up: AgentGrid duration comes via the AgentSnapshot path (no
   Value2/enqueue instant); relay/AgentSnapshot must carry the enqueue instant before the QueueGrid-style anchor fix applies.
4. **EDIT-500 InfoSlot concurrent-context co-review** — bi-led; pending.
5. **T3 AUDIT matrix** — enumerate every UI config-change action vs RTM live-pickup (does a saved config change reflect
   live without a restart). In progress / interleaved.

## 6. Boot sequence on the new account (in order — mirrors runbook §4/§5)
1. Read THIS file + `.claude/skills/role-shell/role-shell.md` (§A every boot; run §C VERIFY against current code/CLAUDE.md
   by object store — the artifact wins on mismatch).
2. Mechanical self-check (object store only):
   `git rev-parse --abbrev-ref HEAD` (expect `v3`) ·
   `git merge-base --is-ancestor 30225d6 origin/v3 && echo WFM-in-origin` (expect it) ·
   `git rev-list --count origin/v3..v3` (note the number; none are yours).
3. Write `.coord/sessions/<your-slug>.md` (status active, cc_task none, claims [] — you are idle).
4. Read `.coord/inbox/shell.md` fully; there is NO open shell task as of this handoff.
5. Report a one-line bus summary to the operator and GO IDLE. Wait for a `.` poke. Never start work off memory.

## 7. Anchors
- role-skill: `.claude/skills/role-shell/role-shell.md`
- widget conventions: `.claude/skills/widget-creator/` + `widget-planner/`
- coordination: `.claude/skills/session-coord/` (§10 command registry), `CLAUDE.md` §42/§26
- your mailbox: `.coord/inbox/shell.md` · your CC binding channel: `.coord/cc/shell.md`
- migration: `.coord/protocols/account-migration-runbook.md`
