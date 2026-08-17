---
name: rtm-backend-session-resume
description: Резюме сессии RTM backend деплой + TenantId миграция (2026-05-31)
metadata: 
  node_type: memory
  type: project
  originSessionId: ce27623f-8c43-49d1-a27d-678e69aeca25
---

## Статус на конец сессии (2026-05-31)

### Рабочая папка
`D:\Claude\Projects\RTM View Shell` — основной репозиторий.
`C:\Users\farbe\Documents\Claude\Projects\RTM View Shell` — зеркало (тот же git).

### RTM Service на сервере
- Сервис запущен, работает на PostgreSQL
- Бинарники: версия с коммита `0763574` (последний)
- `appsettings.json` на сервере: TenantId = `019e03e9-60dd-72da-bd01-648ffdb2b433`
- Лог: `C:\Logs\RTMView\RTM.log`
- Установлен в: `C:\Program Files\RTM`
- Сервис: `RTMService` (Windows Service)

### Задеплоенные SQL функции (все актуальны)
- `01_ngc_functions.sql` — NGC_Get* (FUNCTION с TenantId)
- `02_rtsdata_functions.sql` — RTSData_Set* + MidnightClear (с TenantId)
- `03_rtsgrid_read_functions.sql` — RTSGrid joins (с TenantId)
- `fix_set_interaction.sql` — RTSData_SetInteraction PROCEDURE (48 params + TenantId)
- `fix_set_userstatus.sql` — RTSData_SetUserStatus PROCEDURE (14 params + TenantId)
- `fix_function_params.sql` — RTSData_getInteractions/getUsersStatuses (text, uuid) 2 params
- `fix_ngc_signatures.sql` — NGC_CreateBusinessUnit (text, text, text, text, uuid)
- `fix_ngc_procedures.sql` — все NGC_ write функции как PROCEDURE с правильными подписями

### Коммиты этой сессии (git log)
- `0763574` fix(RTM): handle named timezone IDs in getLocalDateTime
- `0c3c902` feat(CC-003): RTM Relay Infrastructure
- `b4fe8ac` feat(RTM): add TenantId support — one instance = one tenant
- `3bccb31..46e1a91` docs(CLAUDE.md): §0.7 CC промпт правила
- `3d34413` docs(CLAUDE.md): §33 RTM multi-tenancy architecture
- `9e31d71` fix: guard empty TimeZone + SQL procedures
- `ce20686` fix(DBMng): DateTime.SpecifyKind.Utc

### Текущие ошибки в логе (на конец сессии)
- `getLocalDateTime "Israel"` — ИСПРАВЛЕНО в коммите `0763574`, нужен деплой новых бинарников
- Возможны другие NGC_ ошибки — нужно проверить после деплоя

### Pending actions
1. **Задеплоить новые бинарники** (коммит `0763574` — timezone fix):
   - Запустить `Publish-RTM.ps1` на dev-машине
   - Остановить сервис, скопировать `RTM.exe`, `RTM.dll`, `RTM.Tools.dll`
   - Запустить сервис, проверить лог
2. **Проверить лог** после деплоя на наличие новых ошибок NGC_*
3. **Push** — выполнить `tools/cc_prompt_push.md` в CC

### Пути установки на сервере
- **RTM Service:** `C:\RTMView\RTM`
- **Shell (CcDashboard):** `C:\RTMView\Shell`

### База данных на сервере
- **Имя БД: `rtmviewdb` (lowercase)** — не `RTMViewDB`
- psql путь: `C:\Program Files\PostgreSQL\16\bin\psql.exe` (или 15)
- Подключение: `& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d rtmviewdb`

### Известные архитектурные решения
- RTMAdapter вызывает `CALL` → нужны PROCEDURE для void функций
- RTMAdapter вызывает `SELECT * FROM` → нужны FUNCTION для returning функций
- TenantId берётся из `appsettings.json → AppConfig.TenantId` (статик)
- Datetime параметры: всегда `DateTime.SpecifyKind(dt, DateTimeKind.Utc)`
- TimeZone поля: могут быть как `+03:00` так и `Israel` (Windows TZ ID)

### CLAUDE.md изменения этой сессии
- §0.7 — все изменения кода только через CC промпты (reliability + plugins)
- §0.8 — названия сессий с префиксом RTM
- §33 — RTM Service multi-tenancy architecture
- §34 — RTM Relay Architecture (из предыдущих сессий)
