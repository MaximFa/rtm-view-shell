# .coord/coordinator-commands.md — operator→coordinator command registry
> Verbs the operator (Max) issues to the coordinator session. Coordinator reads this at session start
> (alongside backlog.md + session-coord skill). Prefix all with `коорд:`.

> **⚠ ИСТОЧНИК ПРАВДЫ = session-coord skill §10 (полный набор команд, ~18, для ВСЕХ сессий).** Этот реестр —
> лишь КРАТКАЯ выжимка частых коорд-команд и НЕ полон. **НИКОГДА не угадывай неизвестный `коорд:`/`сессия:` глагол** —
> если команды здесь нет, прочитай session-coord §10 и выполни её точную семантику; если и там нет — скажи «команда
> неизвестна» и спроси оператора. Рабочие сессии: семантику команд берите из СКИЛЛА §10, не из этого coordinator-реестра.
> (Урок 2026-06-10: backend читал этот реестр (5 команд), не знал `коорд: сбрось`/`статус` из §10 -> угадал -> прочитал не тот файл.)

| Command | What the coordinator does |
|---|---|
| `коорд: входящие` | Process coordinator inbox (inbox/coordinator.md + own slug inbox). Read-back-verify each, act, mark handled, journal. |
| `коорд: разбери` | Full bus triage: verify git/bus truth via object store, reconcile journal↔git (L-SC-04), surface blockers, do the in-purview housekeeping, present decisions. |
| `коорд: проверь шину` | Integrity sweep: journal↔git reconcile, stale sessions/locks, push/freeze state, truncation checks. |
| `коорд: дай ack` / push-barrier verbs | Push-barrier flow per §42.7 (request, collect READY acks, quorum, gate the push prompt). |
| `коорд: handoff` | **Produce a verified coordinator handoff** → see spec below. End-of-shift / context-refresh / takeover. |
| `коорд: статус` | (NORM на возврате оператора) Полная ресинхронизация: перечитать ВСЁ состояние шины из object store, игнорируя память чата; coordinator -> полный аудит (сессии+heartbeats, locks, queue, journal↔git, unpushed). |
| `коорд: сбрось` | Флаш текущего статуса/вопроса/handoff на шину: обновить свой session-файл + дописать блок в `.coord/inbox/<recipient>.md` (recipient = coordinator для решений, или peer-slug). |
| `коорд: ревью` | Review a CC prompt or returned result: check mandatory blocks (§0.6a integrity, §40 skill-loads, sync block), claim correctness, acceptance criteria, fact-consistency vs code/object-store. Verdict PASS / REVISE-with-notes -> requester inbox. |
| `коорд: промпт <role> <task>` | Draft a FULL self-contained directive (mandatory reads + integrity block + specialist claim + task + acceptance criteria + commit.lock/journal/no-push), write to `.coord/inbox/<role-slug>.md`, hand operator trigger-list. Coordinator does NOT execute. |
| прочие (`ты координатор`/`регистрируйся`/`готовим пуш`/`пуш`/`очередь`/`файл твой`/`передай координацию`/`завершаю сессию`/`кросс-статус`/`кросс-ack`) | См. session-coord §10 — точная семантика ТАМ (реестр их не дублирует). |

---

## `коорд: handoff` — specification

**Purpose:** Produce a verified resume-checkpoint so the NEXT coordinator session (new session, context-refresh,
or takeover) picks up cold WITHOUT re-deriving state from chat. Truth = the bus + git object store, never chat memory
(§0.1 verification discipline). Output overwrites `.coord/coordinator_handoff.md` (latest-only) + journal line + memory pointer.

**Steps (run in order, all writes Python+fsync §0.3):**
1. **Git/bus truth** (object store, mount index is unreliable — §feedback_git_mount_distrust):
   local branch tip + `origin/<branch>`, unpushed count + list; push/freeze state (`push/request.md` tombstone vs FREEZE);
   `locks/commit.lock` (owner/age). Reconcile journal↔git (L-SC-04): every recent commit has a journal line.
2. **Roster snapshot:** every session in `sessions/*.md` — slug, role, status, heartbeat (flag stale >3h), cc_task, claims.
3. **In-flight work:** per session — drafting / issuable / blocked, with §4 status.
4. **§4 queue:** prompts awaiting coordinator §4; prompts PASSED §4 awaiting operator issue (issuable).
5. **Operator-action items:** only-Max moves (pushes, issues, GOs, envelopes), each with what it unblocks.
6. **Untracked → next-barrier git-home (E-023):** list design docs / prompts not yet committed.
7. **Open seams / decisions / known gaps / lessons** from the shift (candidate hardening items).
8. **Write** `.coord/coordinator_handoff.md` (overwrite) + append journal `... | HANDOFF written ...` + update the
   memory checkpoint pointer (MEMORY.md ▶ Latest checkpoint).

**Output to operator:** one concise screen — tip/unpushed, roster one-liners, issuable-now, operator-to-dos. Plus the file.

**Do NOT** raise a push barrier or issue any CC prompt as part of handoff — it is a read+snapshot command only.

---
## See also
- `.coord/session-commands.md` — working-session lifecycle commands (`сессия: handoff` / `takeover`) incl. the
  MANDATORY inbox-migration step (L-SC-21, metrics-2→metrics-3 lesson).
- On takeover, coordinator's reciprocal duty: ensure successor inbox exists + route there (re-deliver post-takeover directives).
