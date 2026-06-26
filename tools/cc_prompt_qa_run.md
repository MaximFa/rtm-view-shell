# CC task — QA: верификация задачи из инбокса (Soma + Shell-control + Chrome)

> Для роли QA (RTM). Координатор уже положил задачу в твой `inbox/qa.md`. Этот промпт — про КАК верифицировать
> САМОСТОЯТЕЛЬНО, тремя инструментами, без операторского релея. Нативный CC.

## Git push
НЕ пушить.

## STEP 0 — INTEGRITY + входящие
- §0.2 integrity. Для git-истины — object-store (`git show HEAD:<f>`, `git log`), НЕ mount/line-count (§0.5).
- `коорд: входящие` — забери задачу из `inbox/qa.md`. ЧТО верифицировать — оттуда.
- Прочитай `CLAUDE.md §47 (Soma)` + `tools/Soma/USAGE.md` — твой каталог инструментов.

## ТВОЙ ТУЛКИТ (используй сам)
**1. Soma — read-глаза на БД/логи + ops** (база `http://127.0.0.1:5199`):
- Токен: прочитай из `tools/Soma/appsettings.json` (`Soma:Token`), шли как `Authorization: Bearer <token>`. НЕ хардкодь.
- ПРЕДУСЛОВИЕ: сначала `GET /health`. Connection-refused = Soma не поднята -> ФЛАГНУТЬ ОПЕРАТОРУ (сам не запускай демон).
- **БД:** `POST /db/query` (свободный SELECT; тело JSON `{"sql":"..."}` ИЛИ сырой SQL; для `identity.users` — view `users_safe`),
  `GET /db/report?name=<hist_queue_intervals|hist_agent_intervals>&tenant=&from=&to=` (проверить отчёты),
  `GET /db/agent-states|queues|dashboards?tenant=<guid>`.
- **Логи:** `GET /logs/serilog?tail=<N>&contains=ERR` (ловить исключения после прогона); `/logs/tail?source=<serilog|soma-shell|soma-audit>`.

**2. Shell-control через Soma — для чистого прогона:**
- `GET /shell/status` — поднят ли Shell. Нет -> `POST /shell/start`. Нужен чистый старт -> `POST /shell/restart`.
- `GET /ops/health` — пинг `/health`+`/health/ready` Shell. Дождись healthy ПЕРЕД фронт-проверкой.
- Помни: один Shell на порт; Soma управляет своим процессом (ручной Shell оператора не трогает).

**3. Chrome — фронт:**
- Навигируй на UI Shell (порт из `Soma:Shell:HealthUrl`, напр. `http://localhost:7196`), читай страницы, проверяй рендер/раскладку/виджеты.
- **Сверь «UI = БД» (§24 SYNC):** что на экране == что отдаёт Soma `/db/agent-states`/`/db/dashboards`. Расхождение = баг.

## РАБОЧИЙ ЦИКЛ
1. Забрать задачу (inbox). 2. Поднять/проверить Shell (Soma `/shell/*` + `/ops/health` -> healthy).
3. Бэкенд/данные — Soma (`/db/*`, `/logs`). 4. Фронт — Chrome (рендер + сверка с БД). 5. Собрать находки с floor-пинами.

## ГРАНИЦА QA (важно — by design)
Ты **видишь всё** (БД, логи, фронт), но **руки только в своей полосе**: верифицируешь и РАПОРТУЕШЬ, НЕ чинишь чужое.
Находки -> владельцу фикса через координатора §4 (что / где / ожидание vs факт + floor-пин). «to help not to claim».
Только именованные Soma-операции — произвольных команд нет (Soma иное и не пустит).

## РЕЗУЛЬТАТ
Вердикт по задаче (PASS/FAIL + пины) в `inbox/coordinator.md`; находки роутнуты владельцам. NO push.
