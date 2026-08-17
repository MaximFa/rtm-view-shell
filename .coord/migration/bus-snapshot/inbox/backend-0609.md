# inbox: backend-0609 (RTM Backend specialist, role #1 RTM Server)
>>> INBOX RULE: читай ЭТОТ файл (.coord/inbox/backend-0609.md) ЦЕЛИКОМ. Пиши в .coord/inbox/coordinator.md. Команды
>>> из session-coord skill §10 (не угадывать). Полный comms-протокол: .coord/protocols/comms-backend-0609.md.
>>> История инбокса (всё handled/superseded) заархивирована в inbox/archive/backend-0609-pre-reinit-20260610.md.

## 2026-06-10T05:40Z | from: coordinator-0609 | to: backend-0609  [CURRENT STATE / HANDOFF — действуй ТОЛЬКО по этому]
Всё, что было выше до архивации — ИСТОРИЯ, обработано/устарело. Твоя АКТУАЛЬНАЯ картина:

ТВОЯ СДЕЛАННАЯ РАБОТА (закоммичена, unpushed на 24122c2, поедет в push-барьер после Security ACK):
- 9cc8a66 rtm: hot-reload compile (Engine.HotReloadMetrics + RTMHub.compileMetrics, incremental, ConcurrentDict). DONE.
- 160259a db: NGC_GetOrCreate INSERT fix (Id/IsActive, E-004) + Engine guards. DONE.

F-1 / F-3 — БОЛЬШЕ НЕ ТВОЯ активная работа:
- F-1 (RCE) ЗАКРЫТ АРХИТЕКТУРНО: оператор решил «метрики = вендор-константы, клиент read-only». Shell сделал b7b20e4
  (MetricsPage read-only + удалены 4 команды-мутации). Твой cc_prompt_rtm_security_f1f3.md (char-whitelist) = В ПОЛКЕ как
  fast-follow (он всё равно обходился string-concat). НЕ коммить его.
- F-3 (hub authz): фикс = loopback-rebind RTM hub -> 127.0.0.1:8088 (§34). Если bind в RTM appsettings (Kestrel:Urls) ->
  это devops. Если HARDCODE в RTM Program.cs -> координатор отдаст тебе. Сейчас devops проверяет где bind. Жди.

ТЕКУЩИЙ СТАТУС: IDLE / standby. Активного CC-таска за тобой НЕТ.
ВОЗМОЖНО ВПЕРЕДИ: (a) F-3 loopback-rebind, ЕСЛИ bind в RTM Program.cs (по сигналу координатора); (b) fast-follow (ПОТОМ,
не сейчас): FF-1 = настоящий grammar/AST-валидатор выражения метрики (теперь optional DiD); FF-3 = bearer-token внутри RTMHub.

ШИНА: origin/v2-backend=24122c2, unpushed=8 (вкл. твои 9cc8a66/160259a). 234 hot-reload deploy = HALT (Security gate, близко
к ACK). FREEZE НЕТ (request.md = tombstone). commit.lock нет.

ДЕЙСТВИЕ: подтверди приём — флашни в coordinator.md, что прочитал и понял статус (idle, ждёшь сигнал по F-3). Не переспрашивай
закрытое (option-2/компенсаторы/read-only — всё решено выше по истории, не возвращайся к ним).

> handled 2026-06-10T05:45Z by backend-0609 — acked, idle/standby, awaiting F-3 contingency signal
## 2026-06-10T06:55Z | from: coordinator-0609 | to: backend-0609
RE-INIT ACK ПРИНЯТ — чисто. Прочитал comms-протокол + §10 + свой инбокс целиком, флашнул в coordinator.md (не чат),
idle/standby, F-1/F-3 «закрыто, не реоткрываю». Именно так. Загадка решена. Standby подтверждён — сигналов пока нет
(F-3 = devops appsettings, не Program.cs -> тебя не трогает; FF-1/FF-3 = future). Жди, на гейт ты не блокируешь.

## 2026-06-11T18:35Z | from: coordinator-0609 | to: backend-0609  [RE-READ session-coord skill §10 — registry unified (L-SC-15 bump)]
The protocol command registry was unified (commit 4862269): §10 is now the canonical superset — +`коорд: ревью` +`коорд: промпт`, aliases (`барьер`=готовим пуш, `разлок`=сессия <slug> мертва, `журнал`⊆проверь шину, `прочитай`=входящие), single-source header. You cached an OLDER §10 at start (L-SC-15). RE-READ .claude/skills/session-coord/session-coord.md §10 now so your verb set is current — then any `коорд:`/`сессия:` verb (incl `сбрось`) resolves consistently. No other action.


>>> DEPRECATED 2026-06-12T09:32Z: SUCCESSOR (permanent) INBOX = inbox/backend.md — READ THERE NOW. <<<

## 2026-06-18T13:00:18Z | from: coordinator-0612 | to: backend-0609  [QUICK — confirm NGC_DeleteBUQueueClassificationMapping caller=CALL (234 B=1)]
234 Compare B=1: NGC_DeleteBUQueueClassificationMapping missing a FUNCTION overload (self-heals on db/functions re-apply). Confirm by object-store: the caller (RTM/Engine or Shell) invokes it via CALL (CommandType.StoredProcedure) -> then it MUST be a PROCEDURE (RTM-SEC-002), and the missing FUNCTION overload is benign / correctly dropped by _012. Report verdict -> coordinator inbox. Object-store only, no deploy.
