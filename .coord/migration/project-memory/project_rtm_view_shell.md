---
name: RTM View Shell — состояние проекта
description: Текущее состояние кодовой базы, документации, активных областей разработки и интеграционных точек RTM View Shell (CC Dashboard Shell)
type: project
originSessionId: e7fc5936-9b58-407e-b6f6-f191c0570f6e
---
## Платформа развёртывания

- ОС: Windows Server 2019+ / 2022+
- Хостинг: IIS (in-process, ASP.NET Core Module v2) — два пула: CcDashboard.Web + CcDashboard.Api
- Топология: all-in-one (Web + Api + PostgreSQL + Redis на одной машине)
- СУБД: PostgreSQL 15+ (рекомендуется 16+) — нативная установка для Windows
- Cache/state: Redis 7+ для Windows (Memurai либо Redis в WSL2)
- Стек: .NET 8 LTS, Blazor Server (cookie-аутентификация), REST API (JWT Bearer, опционально)

**Why:** Заказчик явно указал «без Docker, локальная установка на сервере».

**How to apply:** Не предлагать docker-compose, Kubernetes, Linux systemd, unix-socket auth.

---

## Тест-программа T1–T6 (завершена 2026-05-26)

| Sprint | Коммит | Тесты (новые) | Итого | Ключевые находки |
|---|---|---|---|---|
| T1 Security & tenant isolation | — | 79 | 79 | 4 SF + 2 PD |
| T2 Licensing enforcement | — | 20 | 166 | SF-006, SF-007 |
| T3 Multi-tenancy integration | `7b85269` | 36 | 204 | OQ-1 resolved |
| T4 PG authorization semantics | `cb7af32` | 46 | 313 (после T5) | SF-005 Critical |
| T5 Widget framework | `fbf89fd` | 28 | 313 | OQ-16 verified |
| T6 User Management + Audit Trail | `22b087a`+`119b5a9` | 79 | **392** | GAP-T6-01..04 fixed |
| Backlog #15 NGC/RTS separation | `bf8a79e` | −10 (NgcIsolation removed) | **382** | seeding fix, IF NOT EXISTS |

**Текущие счётчики (2026-05-26, после #15):** Unit: 72, Integration: 1, Architecture: 8, Security: 301 → **Total: 382, 0 failures**.
HEAD: `81ef2d1` (docs: close #15).

**T6 production fixes (GAP-T6-01..04)** в `UserManagementService.cs`:
- GAP-T6-01: эмитит `User.RoleChanged` / `User.PermissionGroupChanged` при изменении роли/PG
- GAP-T6-02: cross-tenant mutation guard на Update/Delete/SetActive/ForceLogout
- GAP-T6-03: Admin не может изменить собственную роль (USR-08)
- GAP-T6-04: только Superadmin может создавать Superadmin-пользователей (USR-05)

**Production additions в T6 Phase B:**
- `Program.cs`: ForwardedHeaders middleware для X-Forwarded-For (AUD-04)
- `IAuditLogRepository` + `AuditLogRepository`: добавлен `CountAsync` для CSV export boundary (AUD-08)

**Backlog #16 (2026-05-26):** Очистка каталога виджетов — удалены 3 mock-компонента (KpiWidget, AgentStatusWidget, QueueSummaryWidget) + 11 stub-записей из БД. Остались только 3 SignalR-backed виджета: AgentGrid, QueueGrid, DataSlot. Stub .razor файлы обнулены до однострочного комментария (0 ошибок сборки). Коммиты: `9cc4d9b`, `3f83602`, `c32a701`.

**Следующий шаг — 4 новых виджета с RT vs History анализом:**
Источник RT: SignalR (как AgentGrid/QueueGrid). Исторический период: настраивается пользователем.
Таблицы бэкенда: `RTSData_Interaction`, `RTSData_UserStatus`, `RTSData_UserStatusLog`.
Структуры таблиц и примеры данных ещё не предоставлены — ожидаем от пользователя.
4 типа виджетов: (1) RT vs history по агентам, (2) RT vs history по очередям, (3) комбинированный, (4) аналитический scorecard.
**Точка останова:** пользователь пошёл задавать вопрос по существующим виджетам, вернётся к новым виджетам после.

---

## Кодовая база (актуальное состояние)

Решение `CcDashboard.sln`, 2026-05-26. Структура совпадает с CLAUDE.md §3:

```
src/
  CcDashboard.Domain/          — entities, enums, exceptions, interfaces
  CcDashboard.Contracts/       — DTOs (Auth, Users, PermissionGroups, Dashboards,
                                  Tenants, TenantSettings, Widgets, Audit, Configuration)
  CcDashboard.Application/     — Commands, Queries, Behaviors, Validators, Interfaces, Extensions
  CcDashboard.Infrastructure/  — Persistence, Identity, Caching, Audit, Email,
                                  Security, Seeding, Services, Migrations (App + Audit)
  CcDashboard.Web/             — Blazor Server: Components (Admin, Auth, Dashboard,
                                  Layout, Pages, Shared, Widgets), Middleware, Services,
                                  Resources (.resx), wwwroot
  CcDashboard.Api/             — ASP.NET Core Web API, Middleware

tests/
  CcDashboard.Tests.Unit/      (с подпапками Commands/, Queries/)
  CcDashboard.Tests.Integration/
  CcDashboard.Tests.Architecture/
  CcDashboard.Tests.Security/
    UserManagement/  ← T6 Phase A (35 тестов)
    Audit/           ← T6 Phase B (44 теста)
```

---

## Активные области работы

Текущий фокус после T6 — разработка новых real-time виджетов:

- **Agent Grid (AG) / Queue Grid (QG)** — основные виджеты сетки, синхронизация с dashboard RTS
- **Dashboard editing** — Editor Modal, Clone Dash, Data Slot
- **Widget Templates (WG Templates)** — шаблоны конфигурации виджетов
- **Dark Mode** — реализована тёмная тема
- **Widget Creator skill** — внутри проекта `docs/skills/widget-creator.md` (~862 строк)

**How to apply:** При работе с виджетами/сетками/RTS — горячая зона, читать свежий код перед предложениями.

---

## Pending интеграция с CC-платформой

В коде 7 TODO/FIXME-меток в Application-слое, все про одну и ту же интеграцию:

- `AuthorizationBehavior` — заглушка lookup в permission service
- `AG/QG RTS` и `DeleteQueueGrid` команды — `TODO: replace NoOp with real REST/SignalR calls`
- PermissionGroup commands ждут CC-platform API hooks
- Сейчас используется `NoOpConfigurationApiHook` (см. CLAUDE.md §29.6) — заглушка

**Why:** Внешний CC-API ещё не готов; вся обвязка на стороне Shell уже написана.

**How to apply:** Если пользователь спрашивает «когда подключим к реальному CC» — это про замену `NoOpConfigurationApiHook` на HTTP-имплементацию и про устранение этих 7 TODO. Не предлагать сейчас удалять заглушки — они by design.

---

## Документация в проекте

| Файл | Назначение |
|---|---|
| `CLAUDE.md` | Главный файл инструкций для Claude Code (TZ v1.3, §1-29) — single source of truth. Bumped 2026-05-25. |
| `docs/CC_Dashboard_Shell_TZ_v1.3_EN.docx` | **Текущая** ТЗ на английском (v1.3, commit b16d2e5) |
| `CHANGELOG.md` | История изменений v1.1→v1.2→v1.3 (T1-T6, 7 SF, PD-001..005). |
| `decisions/ADR-001..ADR-008` | 8 Architecture Decision Records. |
| `docs/architecture/widget-framework.md` | Техническая архитектура widget framework (T5). |
| `docs/RTM-View-Shell-Stakeholder-Summary-v1.3.md` | Нетехническое резюме для стейкхолдеров v1.3. |
| `docs/sprints/T{1..6}-*.md` | Sprint briefs + gap analyses. |
| `docs/traceability-matrix.md` | Матрица трассировки требований (обновлена в T6). |
| `INSTALL.md` (452 lines) | Windows Server / IIS / PostgreSQL / Redis установка |
| `USER_GUIDE.md` (208 lines) | Пользовательские воркфлоу |
| `SETUP.md` (127 lines) | Локальная dev-настройка |
| `docs/diagrams/architecture.md` | C4 Context + Container диаграммы (Mermaid) |
| `docs/skills/widget-creator.md` | Гайд по созданию виджетов (внутри проекта) |

**Note:** Документация ведётся на английском (по project instructions), диалог с пользователем — на русском.

---

## Wireframes

Английская версия (`wireframes/en/`) — основная, на неё ссылается CLAUDE.md §21:

```
wireframes/en/
  index.html
  01_login_2fa.html
  02_user_management.html
  03_permission_groups.html
  04_screen_management.html
  05_dashboard_viewer.html
```

---

## Конфигурация

- `src/CcDashboard.Web/appsettings.json` + `.Development.json`
- `src/CcDashboard.Api/appsettings.json` + `.Development.json`
- `appsettings.template.json` в корне — шаблон
- `global.json` — pin .NET SDK версии

---

## CSS/Assets

- `wwwroot/css/tokens.css` — threshold colour tokens (thr-ok/warn/crit/null) + utility classes
- `app.css` начинается с `@import url('tokens.css');`
- В `src/CcDashboard.Web/wwwroot/` есть bootstrap/ (вкл. bootstrap.rtl.min.css), bootstrap-icons/, css/, js/

---

## Библиотека скиллов (вне CLAUDE.md, в корне проекта)

Скиллы в формате `<имя>/SKILL.md`. Активируются копированием в `.claude/skills/`:
```powershell
Copy-Item "<проект>\<скилл>" "<проект>\.claude\skills\<скилл>" -Recurse -Force
```

Подтверждённый список (≈14): `program-architector`, `blazor-server-expert`, `blazor-frontend-design`, `ux-ui-expert`, `app-cyber-security-expert`, `signalr-expert`, `contact-center-expert`, `contact-center-shift-manager`, `contact-center-manager`, `contact-center-director`, `contact-center-ceo`, `technical-writer`, `platform-presale`, `frontend-design` (legacy).

**How to apply:** Перед работой над областью читать соответствующий SKILL.md. Скилл `widget-creator` живёт **внутри проекта** в `docs/skills/`.
