# role-skill standard + promotion gate (Specialist Protocol spine)
> Curator-owned (NORM-CUR-11). The VERTICAL axis: how ONE role keeps + grows its expertise across its own
> re-instantiations. Complements §42 (horizontal coordination). Source spec: .coord/specialist-protocol.md.
> Curator OWNS this standard + audits role-skills ASYNCHRONOUSLY (NOT a per-write gate — that would stall capture).

## Two layers (the cut)
- PERSISTENT (role): `.claude/skills/role-<role>/role-<role>.md` — SURVIVES reap. The worker's notebook.
- EPHEMERAL (incarnation): `.coord/sessions/<slug>.md` — dies at reap (claims/heartbeat/cc_task).
IRON RULE: nothing durable lives ONLY in the ephemeral layer. A lesson is written into the PERSISTENT layer BEFORE
the incarnation ends, or it is lost by design.

## role-skill anatomy
Frontmatter: `role, project, version, last_verified, owner: <role>, reviewer: curator`.
- §A CORE — invariant, HARD CAP ~40 lines, loaded EVERY init. Role rules + the caveat "reality wins — update me" +
  3-7 cardinal truths, EACH source-pinned. If §A can't be read in one breath, weed §B.
- §B LESSONS — append-only, dated, with status. One line each:
  `<date> · <what happened> · <rule> · SOURCE:<commit/journal-ts/log/file:line> · status: active|superseded-by:<id>`
- §C VERIFY — at init: spot-check §A cardinal truths against CURRENT code/artifacts; mismatch -> mark superseded, do NOT act on it.
- §D REFERENCE (optional) — deep material, NOT loaded each init.
  ⚠ Because §D is NOT loaded at init and §C only spot-checks §A, **§D is verified by nothing** — a dead
  path there survives until someone opens the reference by hand (real case: `.coord/protocols/specialist-protocol.md`
  referenced from role-curator §D, absent from `v3`, undetected for ~2 months; it survives only inside the
  FROZEN `migration/bus-snapshot/`). Cheap closure, one line per role: add to §C a check that every path
  named in §D resolves — `git cat-file -e v3:<path>` per path, expected exit 0.
  **This is a SENSOR, not a gate**: it reports into the init report and never blocks. A sensor promoted to a
  mandatory gate becomes the process-creep it exists to detect.

## 4 invariant properties (carried from the working anchor)
1. CO-OWNERSHIP with a reality-node (the role + the code/artifacts; reviewer = curator).
2. "REALITY WINS — update me" caveat is explicit in §A.
3. CORE (invariant) vs PERIPHERY (append-able) separation.
4. SOURCE-GROUNDING, not session narrative (sessions confabulate — verified repeatedly). Every fact pins a source.

## Capture discipline (anti-rot)
- CAPTURE is a MANDATORY lifecycle step (not opt-in): any task that yields a lesson -> append the dated, source-pinned
  lesson to §B BEFORE the task closes. Wired into the CC postamble next to binding-RESULT (§0.6b).
- Status active/superseded only; SILENT editing forbidden (like the journal). Reality-wins caveat. VERIFY at init.
- ROUTING (operator 2026-06-22): EVERY lesson is recorded in §B (append-only) — nothing is 'too small for §B'. A lesson is
  ELEVATED to §A as a source-pinned CARDINAL TRUTH ONLY when it is a CRITICAL AMPLIFIER: a load-bearing invariant that changes
  how the role ACTS at init / high recurrence / high blast-radius. Default = §B; §A is RESERVED for critical amplifiers and stays
  within the ~40-line cap (elevate deliberately; weed §A when it overflows). Capture EVERYTHING in §B; promote ONLY amplifiers.
- Periodically weed §B so §A stays loadable. Writes are native-CC only (mount truncates), via §4-review.

## Lifecycle (vertical, brother of the §42 horizontal lifecycle)
INIT/HANDOFF (wake ritual): (1) §0.2 integrity-check; (2) read role-<role>.md §A CORE — expert from line 1;
(3) §C VERIFY vs current code, mark stale; (4) read role charter + re-claim territory (§42.2) + read own inbox.
WORK: under coordination discipline (claims, binding .coord/cc/<role>.md, §4-review, native-CC, commit.lock).
CAPTURE: mandatory, as above. HANDOFF/REAP: ephemeral layer may die; the PERSISTENT role-skill carries forward; a
fresh incarnation reads it and is ALREADY expert.

## Scope tiers + PROMOTION GATE (PREVENT-BEFORE / fail-closed — hold the bar hardest here)
- Specialist + coordinator role-skills = PROJECT-scoped. Curator = AGNOSTIC.
- **DEFAULT-DENY** (mirrors AD AUTHZ-03): a lesson stays PROJECT-scoped BY DEFAULT. It does NOT enter the agnostic
  curator skill until the gate is AFFIRMATIVELY satisfied with PINNED evidence. No silent promotion. The agnostic tier
  is **append-ONLY-AFTER-PROOF**, never append-then-audit.
- **TWO-KEY promotion:**
  1. The proposing role marks a CANDIDATE in its project role-skill (`status: promotion-candidate`) — it STAYS
     project-scoped meanwhile.
  2. The CURATOR promotes to the agnostic tier ONLY after confirming, with evidence PINNED in the entry: (a) substrate-
     level proof (mount / git / protocol), OR (b) >=2 INDEPENDENT occurrences, each cited with a commit/journal pin FROM
     EACH project. Unproven -> stays project-scoped. A single-domain pattern is NEVER promoted (that path IS the
     cross-domain contagion vector; over-generalization = contamination).
- The async curator audit is a SECONDARY backstop (catch slips), NOT the primary gate. The gate stops the contagion
  BEFORE it crosses, not after it crossed.

## §C VERIFY — WRITE-TIME GATE (NORM-CUR-11c, peer-review Маяк)
A broken verifier is WORSE than none: a §C check that FAILS against correct code FALSELY marks a TRUE truth superseded —
defeating the anti-rot purpose (real defect: role-backend §C#1 grep `CREATE PROCEDURE`=2 vs `CREATE OR REPLACE PROCEDURE`=15).
- Every §C VERIFY check MUST be EXECUTED ONCE at AUTHORING time and confirmed to return its EXPECTED result BEFORE the role-skill
  is committed. A §C line that does not pass against the CURRENT code at write-time does NOT ship.
- §4-REVIEW REJECT item: any §C check not run-green at authoring -> verdict REVISE, not PASS. (Mirrors cold-start "from artifacts":
  do not ship a self-check you did not run, same as you do not ship a truth you did not pin.)
- When §C later FAILS at init, treat it as a SIGNAL the code drifted (or the check needs updating) — investigate; do NOT blindly
  supersede a truth on a check you never proved correct.
## §A source-pin discipline (AGNOSTIC, curator-blessed 2026-06-21)
NEVER pin a SOURCE to a § that does not literally support the claim (verify the cite exists). If the codified location is absent, mark CONVENTION/skill-provided — do not fabricate a CLAUDE § (cf. finesse-sim #6 / CODE-05 catches).

## Local-validation gate (AGNOSTIC, curator-blessed 2026-07-02)
LOCAL-VALIDATION GATE: nothing moves forward until the commit is validated by a LOCAL RUN on the REAL app — not a PoC/harness/component/object-store alone. Object-store verifies WHAT shipped; local validation verifies it WORKS (TWO floors). CODE/ship roles (backend/shell/dba/devops/qa/test) PERFORM the local validation; GATE roles (curator/coordinator/security) REQUIRE local-validation evidence BEFORE greenlight. Complements NORM-CUR-13 (object-store = truth for what's committed). · SOURCE: operator 2026-06-26; pins T1 9734252 (object-store-verified-but-broken-in-prod), Garnet INC-001d (PoC-harness-only).

## Test-gate (AGNOSTIC kernel, curator-blessed 2026-07-02)
TEST-GATE: in a MULTI-PROJECT solution, building or running ONE project does NOT run the tests — they are SEPARATE build targets. "The app builds/runs" NEVER implies "the tests pass". A green test-gate REQUIRES an ACTUAL test-run RESULT with COUNTS (failed=0), never inferred; a missing/absent test result = HARD STOP. Corollary: a change to a public contract (signature/ctor/const/public member) MUST update its tests in the SAME unit of work, else the test project silently drifts (undetected until a full test build). This is the MIDDLE verification floor: object-store (NORM-CUR-13 — WHAT shipped) → test-gate (tests PASS, counts) → local-validation-gate (app WORKS on the real run). Code/ship roles RUN+report counts; GATE roles REQUIRE+verify the numbers. · SOURCE: operator 2026-07-02, RTM 62-error test-project-drift root cause; substrate = build-graph topology (test projects not referenced by the app target).


## BODY INTEGRITY — норма 2026-08-29 (Н-6…Н-9, куратор + координатор)

Роль-скилл — единственный ПОСТОЯННЫЙ слой роли и грузится при каждом ините. До сегодня правило проверки
байтов после записи существовало только для `.coord/`; `.claude/skills/` под него не попадал никогда.
Цена: `role-coordinator.md` нёс **1913 нулевых байт** с 2026-07-03 (блоб `1b5778a`, последний чистый —
`c1b7fba`), 57 дней и три коммита поверх, включая аттестацию владельца. Содержимое дыры текстом не
существовало никогда и из стора не восстанавливается.

**Н-6. После ЛЮБОЙ записи в роль-скилл — проверка по БАЙТАМ, до коммита.**
`NUL == 0` · первые 3 байта ≠ `EF BB BF` · `CR == 0` · прирост размера сходится с дописанным.
**Счёт строк доказательством не является:** дыра в 1913 байт не меняет счёт строк вообще — потому её и
не видели 57 дней.

**Н-7 (объединена с Н-8 по поправке координатора). Сенсор целостности — при ините, ПО ОБОИМ ТЕЛАМ.**
Стора мало: дыра сначала ложится НА ДИСК и лишь потом уезжает в объект — то есть в момент, когда её
ещё можно поймать дёшево, стор ещё чист. Три строки, ожидание `0 / 0 / равны`:
```
python3 -c "d=open('<скилл>','rb').read();print(d.count(b'\x00'))"        -> 0   (диск)
git show v3:<скилл> | tr -d -c '\000' | wc -c                              -> 0   (стор)
git hash-object <скилл>  ==  git rev-parse v3:<скилл>                      -> равны
```
**Это СЕНСОР, а не гейт.** Красный не блокирует подъём — идёт в отчёт инита и оператору. Расхождение
диск↔стор объявляется вслух с причиной; молча грузиться с дрейфующего тела нельзя.

**Н-9. Новый роль-скилл не заведён, пока не прогнана Н-6 и не назван sha.** «Я добавил» — не поставка;
поставка — `DELIVERED <sha>`.

**Третий симптом, который делает это опасным вдвойне: файл с NUL классифицируется как БИНАРНЫЙ.**
Измерено на `role-coordinator.md`: `grep -c 'status: active'` даёт **54**, а `grep -n` по тому же
маркеру печатает `binary file matches` и НИ ОДНОЙ строки. То есть счётные проверки остаются зелёными, а
показывающие строку немеют — проверка выглядит пройденной и не показывает ничего. Любой `§C`,
сформулированный через показ строки, по повреждённому телу молчит вместо того, чтобы упасть.

**Формулировка нормы едина и живёт ЗДЕСЬ.** Роль, у которой уже стоит свой вариант этой проверки,
приводит его к этой формулировке: расхождение формулировок одной нормы хуже, чем чужая формулировка.

## Curator continuity (pointer)
The curator role is governed additionally by `.coord/protocols/curator-continuity-canon.md` (written+versioned):
reconstitution self-check, SUCCESSION VALIDATION of every successor, self-drift audit, and the `curator: drift check`
operator tripwire. A colony without a curator drifts unnoticed — the standing steward + this canon are the guard.