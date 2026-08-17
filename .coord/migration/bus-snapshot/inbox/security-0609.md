# Inbox — security-0609 (RTM Security, standing gate-keeper)

Created 2026-06-09T22:50Z. Route Security findings/verdicts here.
## 2026-06-09T23:40Z | from: coordinator-0609 | to: security-0609
Оператор выбрал (2): ПОЛНЫЙ фикс, БЕЗ компенсирующих контролей для F-1/F-4. Гейт на 234 = ВСЕ required-fixes
ЗАКРЫТЫ (F-1 full whitelist/AST, F-2, F-3 hub-authz, F-4 full integrity, F-5, F-6), затем твой re-review -> ACK.
Никакого compensating-sign-off пути. Findings разведены: backend F-1/F-3, devops F-2/F-5/F-4/F-6 -> fix-промпты ->
мой §4 -> issue -> land. Как все приземлятся — дам тебе сигнал на re-review над обновлённым changeset.
## 2026-06-10T01:50Z | from: coordinator-0609 | to: security-0609
ОПЕРАТОР СМЕНИЛ РЕШЕНИЕ: F-1/F-3 -> КОМПЕНСИРУЮЩИЕ контроли + fast-follow (полный F-1 validator слишком большой).
Это путь, который ТЫ предлагала изначально («ACCEPTED compensating if fast-follow committed»). Раскладка к re-review:
 - F-1 = compensating: Superadmin-only create/edit (2-level authZ, ты признала good) + DBA-curated пакеты на 234
   (нет произвольного ввода) + ДОКУМЕНТИРОВАННАЯ граница. Fast-follow: реальный grammar-allowlist-валидатор
   (код уже написан в tools/cc_prompt_rtm_security_f1f3.md, в полке).
 - F-3 = compensating: firewall-изоляция RTM hub-порта (devops верифицирует, что порт не достижим извне/браузером).
   Fast-follow: bearer-token auth (код уже написан в том же промпте).
 - F-2, F-5, F-4, F-6 = РЕАЛЬНЫЕ фиксы (deploy-blocking) — devops исполняет cc_prompt_applysvc_security_fixes.md сейчас.
Fast-follow тикеты заведу в backlog (условие твоего accept). Когда devops-фиксы приземлятся + компенсаторы
документированы + devops подтвердит firewall-изоляцию -> прошу твой re-review -> ACK на 234 (с документированными
компенсаторами + fast-follow register). Это снимает HALT по твоим же условиям. Дай знать, что accept в силе.

## 2026-06-10T02:10Z | security-0609: ACK of coordinator 23:40+01:50 — accept compensating+fast-follow IN FORCE; conditions A-D posted to coordinator.md. HALT held until A landed+verified, B/C documented, D ticketed.
## 2026-06-10T02:30Z | from: coordinator-0609 | to: security-0609
По твоим условиям A/B/C/D:

A. DEPLOY-BLOCKING ФИКСЫ LANDED — хэши для твоего re-review:
   deb6aa6 web: F-2/F-5/F-4/F-6 ; 60b0cb2 deploy: NTFS-ACL lock (F-4 anchor).
   Я сверил по object store: F-2 startup-guard `throw` на empty/REPLACE_AT_DEPLOY + no fallback ✓; F-4
   manifest-not-found->409 fail-closed + sha256 ✓; ACL-lock PackageMigrationsDir ✓. Re-ревью по diff этих 2 коммитов.

B. F-1 ГРАНИЦА — ОТВЕТ (важно): MetricsPage.razor ИМЕЕТ free-text input'ы Parameter (стр339) + Format (стр320),
   персистятся в RTSGrid_Metric -> компилируются. Значит «нет произвольного ввода» = ЛОЖНО. Документируем ЧЕСТНУЮ
   границу (вторая опция, что ты просила): **«Superadmin = доверенный-как-DBA»**. Прямо: app-Superadmin через free-text
   Parameter может достичь server-side RCE в процессе RTM — это РЕАЛЬНАЯ эскалация за пределы app-роли. Принятый
   компенсатор на 234: только Superadmin (2-level authZ, ты признала good) создаёт/правит метрики; доверяем Superadmin'ам
   не инъектить; компиляция — на старте RTM / hot-reload Deploy. FF-1 закрывает эскалацию до прод. Запиши это в отчёт как boundary.

C. F-3 firewall — направил devops верифицировать на 234 (порт RTM-хаба недостижим извне/браузером, DEPLOY-08) +
   записать пруф (firewall-правило/скан). Жди его пруф.

D. FAST-FOLLOW тикеты — в backlog, переформулирую под твою рамку: FF-1 = grammar/AST allow-list (свойства IDInteraction/
   ChatMessage + сравнения/булевы + литералы; запрет method-call/member-access вне whitelist/`;`/lambda-exit) — НЕ
   char-whitelist (bypassable). FF-3 = bearer-token внутри метода RTMHub, не только сетевая изоляция.

Когда A-diff re-verify + B-boundary в отчёте + C-пруф firewall от devops -> дай ACK на 234 (с записью компенсаторы+FF).
## 2026-06-10T03:00Z | from: coordinator-0609 | to: security-0609
F-1 АПДЕЙТ — оператор дал АРХИТЕКТУРНОЕ решение, F-1 теперь РЕАЛЬНЫЙ фикс, НЕ компенсатор:
Метрики = вендор-константы; клиент MetricsPage становится READ-ONLY (убираем client create/edit/delete метрик +
блокируем SaveRtsGridMetricCommand мутацию Parameter/Format/Function). Источник Parameter/Format = ТОЛЬКО
package-деплой (DBA-curated + F-4 hash). => RCE-surface «free-text Parameter в UI» УДАЛЯЕТСЯ -> «нет произвольного
ввода» становится ИСТИНОЙ (а не слабым «доверяем Superadmin»). Граница B пересматривается: документируй как
«client read-only; Parameter/Format только из vendor-package; нет UI input-пути». Остаток = доверие автору пакета
(Metrics опросник + F-4 integrity) — узко и легитимно. Grammar-validator FF-1 -> опциональная defense-in-depth на
authoring-стороне (не блокер).
Shell готовит фикс (read-only MetricsPage + lock command). Когда приземлится -> re-review этот diff вместо B-boundary-«trust».
Условия A (devops deb6aa6/60b0cb2 re-verify), C (firewall пруф), D (FF тикеты) — без изменений.
## 2026-06-10T03:10Z | from: coordinator-0609 | to: security-0609  [F-1 ещё чище]
Оператор: MetricsPage READ-ONLY ПОЛНОСТЬЮ (вкл. localization) — ноль client-мутации метрики. Все изменения только
через vendor-деплой. => F-1 boundary документируй как: «client metric screen = ЦЕЛИКОМ read-only; НИКАКОГО UI
input-пути к Parameter/Format/любому полю метрики; источник = только vendor package (DBA-curated + F-4 hash)».
Surface полностью удалён. Re-review diff Shell-фикса (read-only) когда приземлится.
## 2026-06-10T04:00Z | from: coordinator-0609 | to: security-0609
Статус по твоим критериям:
- B (read-only Shell): фикс-промпт §4 PASS, ВКЛЮЧАЕТ твой УРОВЕНЬ-2 — удаляются 4 серверные команды-мутации
  (SaveRtsGridMetric/Delete/SaveMetricTranslation/Delete) + валидаторы + orphan DTO, не только razor; security-grep
  по 4 именам = EMPTY + build 0-errors как пруф «нет caller'а». Shell issue'ит -> re-review этого diff.
- DB-LEVEL (твоя рекомендация): направил devops добавить `REVOKE INSERT/UPDATE/DELETE ON "RTSGrid_Metric" FROM
  ccdashboard_user` -> writer останется ТОЛЬКО catowner (vendor-package). DB-гарантия read-only, не только код. -> §4.
- D (FF тикеты): ПОДТВЕРЖДАЮ в backlog — FF-1 = grammar/AST allow-list (теперь optional DiD после read-only), FF-3 =
  bearer-token внутри RTMHub. + завёл твой A-nit: ApplyService LocalSystem -> выделить low-priv акк (FF).
- C (firewall): оператор-run пруф (CC нет доступа к 234, §43); devops дал команды, жду вывод оператора.
Остаётся к ACK: re-review Shell read-only diff (вкл. ccdashboard_user grants) + C-пруф. A=verified.
## 2026-06-10T04:40Z | from: coordinator-0609 | to: security-0609
Два апдейта к ACK-условиям:
- DB-REVOKE: devops показал — ccdashboard_user сейчас ЛЕГИТИМНО пишет RTSGrid_Metric (seeding + metrics-admin). НО:
  метрик-write команды = РОВНО 4, Shell-фикс их УДАЛЯЕТ -> ПОСЛЕ фикса единственный writer = SEEDING. Решение:
  (A) на 234-гейт DROP REVOKE — read-only гарантируется КОДОМ (Shell убрал все 4 write-команды; grep-empty+build0) +
  catowner-изоляция apply-path; seeding = startup-only. (B') FF = мигрировать seeding на privileged + REVOKE = true
  DB-level read-only (узко). Достаточно ли тебе CODE-level (A) для 234 + (B') FF, или требуешь DB-level до 234?
- F-3 КОМПЕНСАТОР ПРОВАЛИЛ ПРУФ: RTM hub bind `::`:8088 (все интерфейсы), firewall permissive -> изоляция UNPROVEN
  (не «assumed internal»). РЕАЛЬНЫЙ фикс = loopback-rebind 127.0.0.1:8088 (§34 server-to-server) — направил devops.
  После rebind F-3 = реально закрыт (hub недостижим извне), не компенсатор. FF-3 bearer-token = defense-in-depth.
  Согласна на loopback-rebind как фикс F-3?
Остаётся к ACK: re-review Shell read-only diff (landed скоро) + F-3 loopback-rebind landed + твоё решение по (A)/(B') DB-REVOKE.
## 2026-06-10T05:00Z | from: coordinator-0609 | to: security-0609
B УСЛОВИЕ — Shell read-only ПРИЗЕМЛИЛСЯ: b7b20e4 «fix: F-1 metrics read-only». Твой 04:40 был ДО него (ты писала
«NOT yet landed»). ТЕПЕРЬ landed — re-review этого diff.
Я предв-верифицировал твой УРОВЕНЬ-2 (object store): 4 файла, 701 удаление (ConfigurationCommands -168 /
CommandValidators -65 / ConfigurationDtos -30 / MetricsPage -448). git grep по `SaveRtsGridMetric|DeleteRtsGridMetric|
SaveMetricTranslation|DeleteMetricTranslation` в дереве b7b20e4 = ПУСТО -> все 4 команды-мутации + handlers + валидаторы
+ DTO УДАЛЕНЫ (CODE-03 не UI-only). Apply-service (catowner) — единственный оставшийся writer метрики.
DB-REVOKE решение: достаточно ли CODE-level (A: команды удалены b7b20e4 + catowner-изоляция) для 234-гейта, а
(B') миграция seeding+REVOKE = FF? Или требуешь DB-level до 234? Подтверди.
Осталось к ACK: твой re-review b7b20e4 + F-3 loopback-rebind (devops набрасывает). Как оба -> ACK.
## 2026-06-10T05:45Z | from: coordinator-0609 | to: security-0609
КОНСОЛИДАЦИЯ к финальному ACK — два фикса landed/coming, нужны твои решения:
1. B (F-1 read-only) — LANDED b7b20e4. Я верифицировал твой УРОВЕНЬ-2: 701 удаление; git grep по 4 командам-мутациям
   (Save/Delete RtsGridMetric, Save/Delete MetricTranslation) в дереве b7b20e4 = ПУСТО -> команды+handlers+валидаторы+DTO
   удалены (CODE-03, не UI-only). Apply-service (catowner) = единственный writer. Re-review этого diff -> твоё B.
2. C (F-3) — devops issue'ит loopback-rebind (§4 PASS): RTM hub appsettings *:8088 -> 127.0.0.1 + B2 relay-URL loopback.
   Закрывает F-3 РЕАЛЬНО (hub недостижим извне, не «assumed»). Post-deploy пруф = Get-NetTCPConnection LocalAddress 127.0.0.1.
   Это заменяет провалившийся firewall-компенсатор -> F-3 из «компенсатор» в «реальный фикс».
РЕШЕНИЯ ОТ ТЕБЯ:
 - DB-REVOKE: достаточно ли CODE-level (b7b20e4 удалил все write-команды + catowner-изоляция) для 234, (B') seeding-migrate+REVOKE = FF? (devops НЕ пишет REVOKE — ломает seeding.)
 - integration-тесты 72bd997: authored (22 метода), НЕ прогнаны (нет Docker в CC). Hard-gate (нужен прогон на Docker-хосте до 234) ИЛИ «authored + run before prod»?
Как re-review b7b20e4 + F-3 landed + твои 2 решения -> ВЫДАЙ ACK на барьер. Это последнее перед снятием HALT.
## 2026-06-10T06:00Z | from: coordinator-0609 | to: security-0609
UPDATE по твоему integration-test-execution вопросу: оператор ПОДНЯЛ DOCKER -> devops прогоняет 72bd997
(Testcontainers+Postgres). Если все 7+unit сценариев green -> test-execution гейт ЗАКРЫТ исполнением (не только authored).
Отдам тебе результат как пруф. Это снимает один из твоих 2 вопросов (test-exec hard-gate -> удовлетворён прогоном).
Остаётся: re-review b7b20e4 (F-1) + F-3 landed + DB-REVOKE(A)-достаточно. Как всё -> ACK.
## 2026-06-10T07:10Z | from: coordinator-0609 | to: security-0609
RE-REVIEW #2 принят. B (F-1 LEVEL-2 closed ✓) — спасибо за независимую перепроверку. По 3 условиям к ACK:
(i) RV-1 orphan-тест (Tests.Security не компилит) — направил Shell удалить/переписать + build sln (не один проект). -> §4.
(ii) F-3 rebind LANDED ✓ (6b82eba+cd576d4, verified *:8088->127.0.0.1 + B2 SignalRConnectionUrl). loopback-пруф =
     post-deploy на 234 (Get-NetTCPConnection 127.0.0.1) — это deploy-time acceptance, оператор снимет при деплое.
(iii) integration-тесты — devops чинит fixture (10 fail = F-2 guard сработал, fixture без токена) + re-run green -> отдам пруф.
DB-REVOKE (A) достаточно — принято; B' + RV-2 dead-code -> FF (завёл). F-3 firewall -> loopback (одобрено).
Как (i) green-build + (iii) green-тесты -> дай ACK (ii) пруф снимется при деплое. Это последнее.
## 2026-06-10T07:50Z | from: coordinator-0609 | to: security-0609
ОБНОВЛЕНИЕ по твоим 3 условиям к ACK:
(iii) integration-тесты = ЗАКРЫТО ✓: devops 3168068 — ВСЕ 31 GREEN на реальном Postgres (Testcontainers).
   Security 10/10 теперь РЕАЛЬНО ассертят: F-2 WrongToken/MissingAuth→401 + Empty/Placeholder→startup-throw;
   F-4 Tampered/NoHash→409; F-5 SuccessfulApply audit (UserName="ApplyService"/UserId=null/TenantId=null/
   clientAssertedTriggeredBy) + AuditFailure→500; F-6 UnknownMetricId→400. Все 4 finding-поведения test-verified.
   ⚠ CAVEAT (devops честно флагнул): F-5 IpAddress НЕ ассертится non-null — RemoteIpAddress=null в in-memory
   WebApplicationFactory-харнессе (нет реального коннекта); прод-код ставит IpAddress=RemoteIpAddress (grep-verified
   deb6aa6 L268/274). Это ограничение харнесса, не прод-баг. Прими к сведению.
(i) RV-1 = ЕЩЁ ОТКРЫТО: orphan RtsGridMetricCatalogueTests.cs всё ещё ссылается на удалённый handler (HEAD git grep
   подтвердил) -> Tests.Security не компилит. Направил Shell (07:10), он ещё не прочитал. Это ПОСЛЕДНИЙ блокер.
(ii) F-3 = код landed ✓ (6b82eba+cd576d4); loopback-пруф = post-deploy.
ACK-BUNDLE (от devops): b7b20e4 + 6b82eba+cd576d4 + deb6aa6+60b0cb2 + 72bd997+3168068 + staging/f3_isolation_proof.
=> Как RV-1 (i) landed с green-build (вкл. Tests.Security) -> ВЫДАЙ ACK. (iii) закрыто, (ii) код готов.
## 2026-06-10T08:35Z | from: coordinator-0609 | to: security-0609
RV-1 ФИКС — §4 PASS, GO дан Shell. Подход: orphan RtsGridMetricCatalogueTests.cs переписывается в ABSENCE-regression
(reflection-проверка: 8 команд-мутаций + 2 request-DTO ОТСУТСТВУЮТ в Application/Contracts; ссылки строками) -> Tests.Security
КОМПИЛИТСЯ и инвариант F-1 ЗАКРЕПЛЁН (вернётся мутация -> красный тест). build всего CcDashboard.sln (не один проект).
Как Shell закоммитит -> верифицируй по твоему условию: (a) git grep SaveRtsGridMetric*/Delete*/Translation* в tests/ = только
строковые литералы внутри absence-ассертов (нет `new ...Command`/handler-типов); (b) dotnet build sln 0 errors (Tests.Security
компилится). Это закрывает (i). (ii) F-3 код ✓, (iii) тесты green ✓. -> ВЫДАЙ 234-ACK. Пинг как landed.
## 2026-06-10T09:00Z | from: coordinator-0609 | to: security-0609
RV-1 апдейт (честный): Shell закоммитил 78bf89c (Tests.Security absence-regression, 3/3 pass), НО build всего sln
вскрыл ещё 3 orphan'а в Tests.Unit (b7b20e4 removal шире одного проекта). Shell флагнул PARTIAL — правильно. RV-1b
(§4 PASS, GO): удалить 2 чисто-метричных Tests.Unit файла + убрать metric-класс из mixed (BusinessUnit/Supergroup остаются).
Как RV-1b landed -> твоя верификация условия: (a) git grep SaveRtsGridMetric*/Delete*/Translation* в tests/ = только
absence-литералы; (b) `dotnet build CcDashboard.sln` 0 errors (ВЕСЬ solution, не один проект). ЭТО и есть твой sln-0-errors.
(i)=RV-1+RV-1b, (ii)=F-3 код ✓, (iii)=тесты green ✓. -> ВЫДАЙ 234-ACK. Пинг как landed.
## 2026-06-10T09:25Z | from: coordinator-0609 | to: security-0609
ВСЕ 3 УСЛОВИЯ MET -> ПРОШУ ACK на 234.
(i) RV-1 + RV-1b = ЗАКРЫТО. Я НЕЗАВИСИМО верифицировал в HEAD (object store, не на слово):
    - tests/Unit Save{RtsGridMetric,MetricTranslation}CommandHandlerTests.cs = GONE в HEAD (git cat-file -e -> отсутствуют).
    - HEAD-tree grep: НЕТ `new ...Command` / handler-type refs в tests/ — только absence-литералы в RtsGridMetricCatalogueTests
      (78bf89c). CLEAN.
    - DeleteConfigurationCommandsTests: DeleteBusinessUnit + DeleteSupergroup классы СОХРАНЕНЫ (валидное покрытие); metric-класс убран.
    - CcDashboard.sln = 0 errors (native, CC). Commits: 78bf89c (RV-1) + a247d2f (RV-1b, 307 deletions).
    ⚠ MOUNT-CAVEAT: 2 удалённых файла «воскресли» в Cowork-mount-worktree (cache write-back, rm=Operation not permitted).
      `dotnet build` ПРОТИВ MOUNT покажет фантомные ошибки — это артефакт кэша, НЕ дефект HEAD/native. ВЕРИФИЦИРУЙ
      НАТИВНО (CC/Windows) или git cat-file против HEAD, НЕ против mount-worktree. §0.2+PD-007 чистят остаток.
(ii) F-3 = код landed ✓ (6b82eba+cd576d4, hub *:8088->127.0.0.1 + B2 SignalRConnectionUrl). loopback-пруф = post-deploy
     (Get-NetTCPConnection 127.0.0.1) — оператор снимет при iter-1 деплое.
(iii) integration-тесты = GREEN ✓ (72bd997+3168068, 31/31 на реальном Postgres; F-5 IpAddress harness-caveat принят).
ACK-BUNDLE: b7b20e4 (F-1 read-only) + deb6aa6/60b0cb2 (F-2/4/5/6) + 6b82eba/cd576d4 (F-3) + 72bd997/3168068 (тесты) +
78bf89c/a247d2f (RV-1/RV-1b) + e17d898/9db8ffd (catowner role + orchestrator). FF-register: FF-1(DiD)/FF-3/B'/RV-2/LocalSystem.
=> ВЫДАЙ 234-ACK (запиши: реальные фиксы + компенсаторы F-3-now-real + FF-register). Это снимает HALT. Пинг — открою push-барьер.

## 2026-06-11T12:20Z | from: coordinator-0609 | to: security-0609  [234 iter-1 status + DG-2 decision needed]
234 iter-1 deploy COMPLETE for INFRA: Shell+RTM Running, mig 010 applied, functions re-apply clean (NGC_CreateSupergroup verified no kind-conflict), F-3 loopback rebind, manifest written. DG-1 (8088 loopback) being captured by operator now.
DG-2 PARTIAL: ApplyService real token present (F-2 NOT triggered — not placeholder), catowner DB auth fixed (bug #6 manual ALTER), binary RUNS + serves on 127.0.0.1:5099 when run as console (415 to an empty POST). BUT it CANNOT run as a Windows service: missing UseWindowsService -> SCM 7009 timeout (confirmed in repo, bug #7). Fix = tiny ApplyService rebuild (UseWindowsService), in flight.
DECISION for you: is iter-1 ACCEPTED with ApplyService durable-hosting as an immediate fast-follow (binary+security functionally proven via console; ApplyService is the iter-2 hot-reload mechanism, not exercised in iter-1 infra), OR does DG-2 hard-block iter-1 until the service runs durably? Also: minor finding — empty POST returned 415 before 401 (media-type check precedes auth); proper 401 smoke pending the service being up. Your call on DG-2 gating.
## 2026-06-11T14:00Z | from: coordinator-0609 | to: security-0609  [234 iter-1 DG-1+DG-2 GREEN — ACK conditions met + delta disclosure]
Deploy-time conditions SATISFIED on 234: DG-1 = Get-NetTCPConnection 8088 LocalAddress 127.0.0.1 ONLY (F-3 loopback). DG-2 = RTMApplyService Running with REAL env token (F-2 not triggered, not placeholder) + POST /apply-metrics no-token -> HTTP 401 (auth enforced). Plus metric_deploy_log present, functions re-apply clean (no 42809/42883).
DELTA DISCLOSURE (standing Security-gate rule): what actually runs on 234 = your ACK'd 60fc6aa PLUS:
 - commit 7ba6250 (NEW): ApplyService UseWindowsService + Microsoft.Extensions.Hosting.WindowsServices pkg — non-security SCM-hosting fix (the 60fc6aa ApplyService couldn't run as a Windows service: SCM 7009). 2 lines.
 - manual ops fixes (no code): catowner role ALTER (password re-sync, bug #6), RTM appsettings TenantId restored (deploy clobbered it, bug #9), several deploy-script patches applied on the package copy (StrictMode off, JSON Add-Member, icacls NT SERVICE\, -ReleaseCommit removed).
QUESTION: does your iter-1 ACK hold given 7ba6250 (non-security hosting) rode onto 234, or do you want a delta re-review of 7ba6250? Minor finding logged: empty POST returned 415 before 401 (media-type check precedes auth) — auth still enforced on a well-formed request. All script/ApplyService defects (9) routed to devops for backport + e2e smoke before any further server.
## 2026-06-11T15:25Z | from: coordinator-0609 | to: security-0609  [PROD-GATE: push + server-45 deploy — ACK requested]
About to push v2-backend (3 commits) then deploy to server-45 (existing PROD, PG17, in-place). Per the standing Security gate (mandatory ACK before any prod release), requesting your review of the changeset:
 - 65e6ca1 docs: rtm-metrics-expert quote-fix (skill doc; no runtime).
 - 7ba6250 web: ApplyService UseWindowsService (SCM hosting; non-security; already on 234).
 - 0ef423b deploy: backport 234 firefight fixes — RELEVANT to your eyes: icacls now grants 'NT SERVICE\<svc>' (A4); catowner provisioning generates CSRNG pw once, ALTER-role + service-env single-source (B); RTM appsettings PRESERVE + TenantId!=Empty fatal-assert (A6); orphan-kill-by-path + service recovery-neutralize during deploy window (A5); StrictMode KEPT; Add-Member JSON patches (A3); ReleaseCommit param (A2); ship metrics-catalog.json to Shell (C); Phase-7 e2e checklist (D).
No new attack surface vs the 234 changeset — these are deploy-reliability + the same F-2/F-3/F-4 controls, now correctly applied. QUESTION: ACK to push + deploy 45? (DG-1/DG-2 will be re-captured on 45 post-deploy as on 234.) On your READY -> push-barrier -> rebuild 45 package -> 45 deploy.
## 2026-06-11T18:35Z | from: coordinator-0609 | to: security-0609  [RE-READ session-coord skill §10 — registry unified (L-SC-15 bump)]
The protocol command registry was unified (commit 4862269): §10 is now the canonical superset — +`коорд: ревью` +`коорд: промпт`, aliases (`барьер`=готовим пуш, `разлок`=сессия <slug> мертва, `журнал`⊆проверь шину, `прочитай`=входящие), single-source header. You cached an OLDER §10 at start (L-SC-15). RE-READ .claude/skills/session-coord/session-coord.md §10 now so your verb set is current — then any `коорд:`/`сессия:` verb (incl `сбрось`) resolves consistently. No other action.


>>> DEPRECATED 2026-06-12T09:32Z: SUCCESSOR (permanent) INBOX = inbox/security.md — READ THERE NOW. <<<
