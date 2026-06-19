# ТЗ: Модуль исторических отчётов
## RTM View Shell — v1.0 | Дата: 2026-06-17

---

## Содержание

1. [Цель и область применения](#1-цель-и-область-применения)
2. [Архитектура](#2-архитектура)
3. [Модель данных](#3-модель-данных)
4. [Фоновый сервис агрегации](#4-фоновый-сервис-агрегации)
5. [Слой данных — репозитории и CQRS](#5-слой-данных--репозитории-и-cqrs)
6. [Системные отчёты](#6-системные-отчёты-17-штук)
7. [Конструктор пользовательских отчётов](#7-конструктор-пользовательских-отчётов)
8. [UI-компоненты и маршруты](#8-ui-компоненты-и-маршруты)
9. [Экспорт данных](#9-экспорт-данных)
10. [Локализация](#10-локализация)
11. [Права доступа](#11-права-доступа)
12. [Планы поставки](#12-планы-поставки-фазы)
13. [Тестирование](#13-тестирование)
14. [Приложение: метрики системы](#14-приложение-метрики-системы)

---

## 1. Цель и область применения

### 1.1 Цель

Добавить в RTM View Shell модуль исторических отчётов, позволяющий руководителям
контакт-центра и аналитикам анализировать накопленные данные по очередям и агентам
за произвольный период времени.

### 1.2 Что входит в модуль

- Фоновый сервис предварительной агрегации данных (30-минутные интервалы)
- Набор из 17 системных отчётов (только чтение, не удаляются)
- Конструктор пользовательских отчётов (создание, сохранение, публикация)
- Экспорт в CSV (v1), Excel/PDF (v2)
- Планировщик доставки отчётов по email (v2)

### 1.3 Что НЕ входит

- Виджеты реального времени (это RTM Service / RtmRelayService)
- Отчёты по WFM (расписания, прогнозирование — отдельный модуль)
- OLAP-кубы и произвольные JOIN между очередями и агентами в одном отчёте (v3)

### 1.4 Источники данных

| Таблица | Описание | Движок записи |
|---------|----------|---------------|
| `RTSData_Interaction` | Каждый звонок/чат | RTM Service |
| `RTSData_UserStatus` | Текущий статус агентов | RTM Service |
| `RTSData_UserStatusLog` | Лог смен статусов агентов | RTM Service (если ведётся) |

Агрегационный сервис читает эти таблицы и записывает предагрегаты в:
- `hist_queue_intervals` — данные по очередям
- `hist_agent_intervals` — данные по агентам

---

## 2. Архитектура

```
[RTM Service]
      │  пишет каждый звонок/статус
      ▼
[RTSData_Interaction]  [RTSData_UserStatusLog]
      │
      │  читает каждые 30 минут
      ▼
[HistoricalAggregationService]   ← BackgroundService (IHostedService)
      │  пишет агрегаты
      ▼
[hist_queue_intervals]  [hist_agent_intervals]
      │
      │  читает по запросу
      ▼
[HistoricalReportRepository]  ←  IHistoricalReportRepository
      │
      ▼
[MediatR: GetQueueIntervalReportQuery ...]
      │
      ▼
[Blazor: ReportPage → ReportTable → ReportFilterBar]
      │
      ▼
[Браузер пользователя]
```

### 2.1 Принципы

- **Pre-aggregation only**: отчёты читают только агрегатные таблицы, никогда не делают
  GROUP BY по `RTSData_Interaction` напрямую (слишком медленно при 100k+ строк/день)
- **Idempotent upsert**: агрегация за интервал можно запустить повторно — результат
  одинаковый (DELETE window + INSERT)
- **Multi-tenant**: все агрегатные таблицы имеют `TenantId`; Global Query Filter активен
- **Чистая архитектура**: слой Application не знает про EF, Infrastructure не знает про Blazor

### 2.2 Новые проекты/файлы

Все новые файлы размещаются в уже существующих проектах решения:

```
src/CcDashboard.Domain/
  └── Domain/Historical/
        ├── HistQueueInterval.cs
        ├── HistAgentInterval.cs
        └── UserReport.cs

src/CcDashboard.Application/
  ├── Interfaces/IHistoricalReportRepository.cs
  ├── Interfaces/IUserReportRepository.cs
  └── HistoricalReports/
        ├── Queries/GetQueueIntervalReportQuery.cs
        ├── Queries/GetQueueDailyReportQuery.cs
        ├── Queries/GetQueueWaitTimeReportQuery.cs
        ├── Queries/GetAgentDailyReportQuery.cs
        ├── Queries/GetAgentMonthlyReportQuery.cs
        ├── Queries/GetAgentShiftDetailReportQuery.cs
        ├── Queries/GetUserReportsQuery.cs
        ├── Commands/SaveUserReportCommand.cs
        ├── Commands/DeleteUserReportCommand.cs
        └── DTOs/  (все DTO-записи)

src/CcDashboard.Infrastructure/
  ├── Persistence/
  │     └── Configurations/
  │           ├── HistQueueIntervalConfiguration.cs
  │           ├── HistAgentIntervalConfiguration.cs
  │           └── UserReportConfiguration.cs
  ├── Repositories/HistoricalReportRepository.cs
  ├── Repositories/UserReportRepository.cs
  └── BackgroundServices/HistoricalAggregationService.cs

src/CcDashboard.Web/
  ├── Components/Reports/
  │     ├── ReportFilterBar.razor
  │     ├── ReportTable.razor
  │     ├── ReportSummaryTiles.razor
  │     ├── ReportBuilder.razor        ← конструктор (визард)
  │     └── UserReportsList.razor
  └── Pages/Reports/
        ├── ReportsIndex.razor         /reports
        ├── QueueIntervalPage.razor    /reports/queue-interval
        ├── QueueDailyPage.razor       /reports/queue-daily
        ├── QueueWaitTimePage.razor    /reports/queue-wait-time
        ├── AgentDailyPage.razor       /reports/agent-daily
        ├── AgentMonthlyPage.razor     /reports/agent-monthly
        ├── AgentShiftDetailPage.razor /reports/agent-shift-detail
        └── CustomReportPage.razor     /reports/custom/{id}
```

---

## 3. Модель данных

### 3.1 Таблица `hist_queue_intervals`

Хранит предагрегированные данные по каждой очереди за каждый временной интервал.

```sql
CREATE TABLE hist_queue_intervals (
    "Id"               uuid         NOT NULL DEFAULT gen_random_uuid(),
    "TenantId"         uuid         NOT NULL,
    "QueueId"          uuid         NOT NULL,   -- FK на NGC_Queue
    "QueueExternalId"  varchar(100) NOT NULL,   -- ID из CC-платформы (денормализован)
    "QueueName"        varchar(200) NOT NULL,   -- Имя очереди (денормализовано)
    "IntervalStart"    timestamptz  NOT NULL,   -- Начало интервала (UTC, округлено до 30 мин)
    "IntervalMinutes"  integer      NOT NULL DEFAULT 30,

    -- Нагрузка
    "CallsOffered"     integer      NOT NULL DEFAULT 0,  -- Поступило
    "CallsAnswered"    integer      NOT NULL DEFAULT 0,  -- Принято
    "CallsAbandoned"   integer      NOT NULL DEFAULT 0,  -- Потеряно (> AbandonThresholdSec)

    -- Время ожидания
    "SumWaitAnsweredSec"  bigint    NOT NULL DEFAULT 0,  -- Σ времени ожидания принятых
    "MaxWaitTimeSec"      integer   NOT NULL DEFAULT 0,  -- Макс. время ожидания
    "SumTimeToAbandonSec" bigint    NOT NULL DEFAULT 0,  -- Σ времени до потери

    -- Обработка
    "SumHandleTimeSec" bigint       NOT NULL DEFAULT 0,  -- Σ Handle Time (Talk+Hold+ACW)
    "SumTalkTimeSec"   bigint       NOT NULL DEFAULT 0,
    "SumAcwTimeSec"    bigint       NOT NULL DEFAULT 0,

    -- SLA
    "CallsInSl"        integer      NOT NULL DEFAULT 0,  -- Принято в рамках SLA
    "SlThresholdSec"   integer      NOT NULL DEFAULT 20, -- Порог SLA (из TenantSettings)

    -- Агенты
    "AgentsStaffed"    integer      NOT NULL DEFAULT 0,  -- Агентов на линии (avg за интервал)
    "SumReadySec"      bigint       NOT NULL DEFAULT 0,  -- Σ Ready time агентов
    "SumBusySec"       bigint       NOT NULL DEFAULT 0,  -- Σ Busy time агентов

    -- Технические
    "AbandonThresholdSec" integer   NOT NULL DEFAULT 5,  -- IVR-bounce фильтр
    "ComputedAt"       timestamptz  NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_hist_queue_intervals PRIMARY KEY ("Id")
);

-- Уникальный ключ для upsert (один интервал = одна строка на очередь)
CREATE UNIQUE INDEX uq_hist_queue_intervals
    ON hist_queue_intervals ("TenantId", "QueueId", "IntervalStart", "IntervalMinutes");

-- Индексы для запросов
CREATE INDEX ix_hist_queue_intervals_tenant_start
    ON hist_queue_intervals ("TenantId", "IntervalStart" DESC);
CREATE INDEX ix_hist_queue_intervals_queue_start
    ON hist_queue_intervals ("TenantId", "QueueId", "IntervalStart" DESC);
```

**Вычисляемые поля (НЕ хранятся, считаются в запросе):**

| Поле | Формула |
|------|---------|
| `AbandonPct` | `CallsAbandoned * 100.0 / NULLIF(CallsOffered, 0)` |
| `SlPct` | `CallsInSl * 100.0 / NULLIF(CallsAnswered, 0)` |
| `ASA` (Avg Speed of Answer) | `SumWaitAnsweredSec / NULLIF(CallsAnswered, 0)` |
| `AvgWaitTime` | `SumWaitAnsweredSec / NULLIF(CallsAnswered, 0)` |
| `AvgTimeToAbandon` | `SumTimeToAbandonSec / NULLIF(CallsAbandoned, 0)` |
| `AHT` | `SumHandleTimeSec / NULLIF(CallsAnswered, 0)` |
| `AvgTalkTime` | `SumTalkTimeSec / NULLIF(CallsAnswered, 0)` |
| `OccupancyPct` | `SumBusySec * 100.0 / NULLIF(SumReadySec + SumBusySec, 0)` |

---

### 3.2 Таблица `hist_agent_intervals`

```sql
CREATE TABLE hist_agent_intervals (
    "Id"               uuid         NOT NULL DEFAULT gen_random_uuid(),
    "TenantId"         uuid         NOT NULL,
    "AgentId"          uuid         NOT NULL,   -- FK на ApplicationUser
    "QueueId"          uuid,                    -- NULL = агент без привязки к очереди
    "AgentLoginName"   varchar(256) NOT NULL,   -- Денормализовано
    "AgentDisplayName" varchar(200),

    "IntervalStart"    timestamptz  NOT NULL,
    "IntervalMinutes"  integer      NOT NULL DEFAULT 30,

    -- Звонки
    "CallsHandled"     integer      NOT NULL DEFAULT 0,
    "CallsMissed"      integer      NOT NULL DEFAULT 0,

    -- Времена (секунды)
    "SumTalkSec"       bigint       NOT NULL DEFAULT 0,
    "SumHoldSec"       bigint       NOT NULL DEFAULT 0,
    "SumAcwSec"        bigint       NOT NULL DEFAULT 0,
    "SumReadySec"      bigint       NOT NULL DEFAULT 0,
    "SumNotReadySec"   bigint       NOT NULL DEFAULT 0,
    "SumBreakSec"      bigint       NOT NULL DEFAULT 0,
    "SumPaperworkSec"  bigint       NOT NULL DEFAULT 0,

    -- Смена
    "LoginAt"          timestamptz,
    "LogoutAt"         timestamptz,

    "ComputedAt"       timestamptz  NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_hist_agent_intervals PRIMARY KEY ("Id")
);

CREATE UNIQUE INDEX uq_hist_agent_intervals
    ON hist_agent_intervals ("TenantId", "AgentId", "IntervalStart", "IntervalMinutes");

CREATE INDEX ix_hist_agent_intervals_tenant_start
    ON hist_agent_intervals ("TenantId", "IntervalStart" DESC);
CREATE INDEX ix_hist_agent_intervals_agent_start
    ON hist_agent_intervals ("TenantId", "AgentId", "IntervalStart" DESC);
```

**Вычисляемые поля:**

| Поле | Формула |
|------|---------|
| `ShiftDurationSec` | `LogoutAt - LoginAt` (в секундах) |
| `OccupancyPct` | `(SumTalkSec+SumHoldSec+SumAcwSec) * 100.0 / NULLIF(SumReadySec, 0)` |
| `ShrinkagePct` | `(SumBreakSec+SumNotReadySec+SumPaperworkSec) * 100.0 / NULLIF(ShiftDuration, 0)` |
| `CPH` (Calls Per Hour) | `CallsHandled * 3600.0 / NULLIF(ShiftDurationSec, 0)` |
| `AHT` | `(SumTalkSec+SumHoldSec+SumAcwSec) / NULLIF(CallsHandled, 0)` |

---

### 3.3 Таблица `user_reports` (пользовательские отчёты)

```sql
CREATE TABLE user_reports (
    "Id"               uuid         NOT NULL DEFAULT gen_random_uuid(),
    "TenantId"         uuid         NOT NULL,
    "Name"             varchar(200) NOT NULL,
    "Description"      text,
    "DataSource"       varchar(20)  NOT NULL,  -- 'queues' | 'agents' | 'agentgroups'
    "Config"           jsonb        NOT NULL,  -- конфигурация (см. §7.2)
    "IsPublic"         boolean      NOT NULL DEFAULT false,
    "IsSystem"         boolean      NOT NULL DEFAULT false,  -- системные Q1-S4
    "CreatedByUserId"  uuid,
    "CreatedAt"        timestamptz  NOT NULL DEFAULT NOW(),
    "UpdatedAt"        timestamptz  NOT NULL DEFAULT NOW(),
    "UpdatedByUserId"  uuid,
    "IsDeleted"        boolean      NOT NULL DEFAULT false,
    "DeletedAt"        timestamptz,

    CONSTRAINT pk_user_reports PRIMARY KEY ("Id")
);

CREATE INDEX ix_user_reports_tenant
    ON user_reports ("TenantId", "IsDeleted", "IsPublic");
CREATE INDEX ix_user_reports_creator
    ON user_reports ("TenantId", "CreatedByUserId", "IsDeleted");
```

**Global Query Filter:** `TenantId == currentTenantId && !IsDeleted`

**Структура `Config` jsonb:**

```json
{
  "timeGranularity": "interval",
  "intervalMinutes": 30,
  "dateRangeType": "today",
  "dateFrom": null,
  "dateTo": null,
  "metrics": [
    "CallsOffered",
    "CallsAnswered",
    "AbandonPct",
    "SlPct20sec",
    "ASA",
    "AvgWaitTime",
    "MaxWaitTime",
    "AHT"
  ],
  "queueIds": [],
  "agentIds": [],
  "sort": {
    "field": "CallsOffered",
    "desc": true
  },
  "pageSize": 25,
  "slThresholdSec": 20,
  "abandonThresholdSec": 5
}
```

**Допустимые значения `timeGranularity`:** `interval` | `daily` | `weekly` | `monthly`

**Допустимые значения `dateRangeType`:**
`today` | `yesterday` | `last7days` | `thisWeek` | `lastWeek` | `thisMonth` | `lastMonth` | `custom`

---

### 3.4 C# сущности

```csharp
// Domain/Historical/HistQueueInterval.cs
public class HistQueueInterval
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid QueueId { get; set; }
    public string QueueExternalId { get; set; } = "";
    public string QueueName { get; set; } = "";
    public DateTime IntervalStart { get; set; }
    public int IntervalMinutes { get; set; }
    public int CallsOffered { get; set; }
    public int CallsAnswered { get; set; }
    public int CallsAbandoned { get; set; }
    public long SumWaitAnsweredSec { get; set; }
    public int MaxWaitTimeSec { get; set; }
    public long SumTimeToAbandonSec { get; set; }
    public long SumHandleTimeSec { get; set; }
    public long SumTalkTimeSec { get; set; }
    public long SumAcwTimeSec { get; set; }
    public int CallsInSl { get; set; }
    public int SlThresholdSec { get; set; }
    public int AgentsStaffed { get; set; }
    public long SumReadySec { get; set; }
    public long SumBusySec { get; set; }
    public int AbandonThresholdSec { get; set; }
    public DateTime ComputedAt { get; set; }
}

// Domain/Historical/HistAgentInterval.cs
public class HistAgentInterval
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid AgentId { get; set; }
    public Guid? QueueId { get; set; }
    public string AgentLoginName { get; set; } = "";
    public string? AgentDisplayName { get; set; }
    public DateTime IntervalStart { get; set; }
    public int IntervalMinutes { get; set; }
    public int CallsHandled { get; set; }
    public int CallsMissed { get; set; }
    public long SumTalkSec { get; set; }
    public long SumHoldSec { get; set; }
    public long SumAcwSec { get; set; }
    public long SumReadySec { get; set; }
    public long SumNotReadySec { get; set; }
    public long SumBreakSec { get; set; }
    public long SumPaperworkSec { get; set; }
    public DateTime? LoginAt { get; set; }
    public DateTime? LogoutAt { get; set; }
    public DateTime ComputedAt { get; set; }
}

// Domain/Historical/UserReport.cs
public class UserReport
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public string DataSource { get; set; } = "";  // "queues" | "agents"
    public string Config { get; set; } = "{}";    // JSON
    public bool IsPublic { get; set; }
    public bool IsSystem { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid? UpdatedByUserId { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
}
```

---

## 4. Фоновый сервис агрегации

### 4.1 Класс `HistoricalAggregationService`

```
Infrastructure/BackgroundServices/HistoricalAggregationService.cs
```

Наследует `BackgroundService`. Запускается при старте приложения.

### 4.2 Логика работы

```
Старт приложения:
  → Lookback 24 часа назад
  → Агрегировать все интервалы от (NOW - 24h) до NOW
  → [пропустить интервалы, которые ещё не закончились]

Каждые 30 минут (PeriodicTimer):
  → Lookback 2 часа назад
  → Агрегировать интервалы от (NOW - 2h) до NOW
  → Upsert результатов
```

### 4.3 Алгоритм агрегации очереди (один интервал)

```sql
-- Шаг 1: Определить границы интервала
-- intervalStart = '2026-06-17 10:00:00 UTC'
-- intervalEnd   = '2026-06-17 10:30:00 UTC'
-- abandonThreshold = 5 секунд
-- slThreshold = 20 секунд

-- Шаг 2: DELETE + INSERT (upsert)
DELETE FROM hist_queue_intervals
WHERE "TenantId" = @tenantId
  AND "QueueId"  = @queueId
  AND "IntervalStart" = @intervalStart
  AND "IntervalMinutes" = 30;

INSERT INTO hist_queue_intervals (...)
SELECT
    gen_random_uuid()     AS "Id",
    @tenantId             AS "TenantId",
    @queueId              AS "QueueId",
    q."ExternalId"        AS "QueueExternalId",
    q."Name"              AS "QueueName",
    @intervalStart        AS "IntervalStart",
    30                    AS "IntervalMinutes",

    COUNT(*)                                              AS "CallsOffered",
    COUNT(*) FILTER (WHERE i."Direction" = 'Incoming'
                       AND i."CallType" = 'External'
                       AND i."WaitTimeSec" IS NOT NULL)   AS "CallsAnswered",
    COUNT(*) FILTER (WHERE i."IsAbandoned" = true
                       AND i."WaitTimeSec" > @abandonThreshold) AS "CallsAbandoned",

    COALESCE(SUM(i."WaitTimeSec") FILTER (WHERE i."WaitTimeSec" IS NOT NULL), 0)
                                                          AS "SumWaitAnsweredSec",
    COALESCE(MAX(i."WaitTimeSec"), 0)                    AS "MaxWaitTimeSec",
    COALESCE(SUM(i."WaitTimeSec") FILTER (WHERE i."IsAbandoned" = true), 0)
                                                          AS "SumTimeToAbandonSec",
    COALESCE(SUM(i."HandleTimeSec"), 0)                  AS "SumHandleTimeSec",
    COALESCE(SUM(i."TalkTimeSec"), 0)                    AS "SumTalkTimeSec",
    COALESCE(SUM(i."AcwTimeSec"), 0)                     AS "SumAcwTimeSec",
    COUNT(*) FILTER (WHERE i."WaitTimeSec" <= @slThreshold
                       AND i."IsAbandoned" = false)       AS "CallsInSl",
    @slThreshold          AS "SlThresholdSec",
    0                     AS "AgentsStaffed",  -- TODO: из RTSData_UserStatus
    0                     AS "SumReadySec",
    0                     AS "SumBusySec",
    @abandonThreshold     AS "AbandonThresholdSec",
    NOW()                 AS "ComputedAt"

FROM "RTSData_Interaction" i
JOIN "NGC_Queue" q ON q."ExternalId" = i."QueueId"
                   AND q."TenantId" = @tenantId
WHERE i."TenantId"     = @tenantId
  AND i."InteractionType" = 'Call'
  AND i."CallType"        = 'External'
  AND i."Direction"       = 'Incoming'
  AND i."StartTime" >= @intervalStart
  AND i."StartTime"  < @intervalEnd
GROUP BY q."Id", q."ExternalId", q."Name";
```

**Примечание:** Поля `WaitTimeSec`, `HandleTimeSec`, `TalkTimeSec`, `AcwTimeSec`,
`IsAbandoned` берутся из `RTSData_Interaction`. Проверить реальные имена колонок перед
реализацией (`\d "RTSData_Interaction"` в psql).

### 4.4 Алгоритм агрегации агента (один интервал)

Аналогично — читаем `RTSData_UserStatusLog` за интервал, суммируем длительности
статусов. Если таблица лога не заполняется RTM Service, использовать `RTSData_UserStatus`
как снапшот (менее точно).

### 4.5 Конфигурация сервиса

Добавить в `appsettings.json`:

```json
"HistoricalAggregation": {
  "IntervalMinutes": 30,
  "StartupLookbackHours": 24,
  "PeriodicLookbackHours": 2,
  "AbandonThresholdSec": 5,
  "SlThresholdSec": 20
}
```

### 4.6 Регистрация

```csharp
// Program.cs
builder.Services.AddHostedService<HistoricalAggregationService>();
```

---

## 5. Слой данных — репозитории и CQRS

### 5.1 Интерфейс репозитория

```csharp
// Application/Interfaces/IHistoricalReportRepository.cs
public interface IHistoricalReportRepository
{
    // Данные очередей
    Task<IReadOnlyList<HistQueueInterval>> GetQueueIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        int intervalMinutes,
        IReadOnlyList<Guid>? queueIds,
        CancellationToken ct);

    Task<IReadOnlyList<HistQueueInterval>> GetQueueDailyAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        IReadOnlyList<Guid>? queueIds,
        CancellationToken ct);

    // Данные агентов
    Task<IReadOnlyList<HistAgentInterval>> GetAgentIntervalsAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        int intervalMinutes,
        IReadOnlyList<Guid>? agentIds,
        CancellationToken ct);

    Task<IReadOnlyList<HistAgentInterval>> GetAgentDailyAsync(
        Guid tenantId,
        DateTime from,
        DateTime to,
        IReadOnlyList<Guid>? agentIds,
        CancellationToken ct);

    // Агрегация (для сервиса)
    Task UpsertQueueIntervalsAsync(
        IReadOnlyList<HistQueueInterval> intervals,
        CancellationToken ct);

    Task UpsertAgentIntervalsAsync(
        IReadOnlyList<HistAgentInterval> intervals,
        CancellationToken ct);
}
```

### 5.2 MediatR запросы и DTO

#### Q1 — Queue Interval Report

```csharp
public record GetQueueIntervalReportQuery(
    Guid TenantId,
    DateTime From,
    DateTime To,
    int IntervalMinutes,        // 30 или 60
    IReadOnlyList<Guid>? QueueIds,
    int Page,
    int PageSize
) : IRequest<PagedResult<QueueIntervalRowDto>>;

public record QueueIntervalRowDto(
    DateTime IntervalStart,
    string QueueName,
    int CallsOffered,
    int CallsAnswered,
    int CallsAbandoned,
    decimal AbandonPct,
    decimal SlPct,
    int SlThresholdSec,
    int ASA,                    // секунды
    int AvgWaitTime,            // секунды
    int MaxWaitTime,            // секунды
    int AvgTimeToAbandon,       // секунды
    int AHT,                    // секунды
    decimal OccupancyPct,
    int AgentsStaffed
);
```

#### Q5 — Queue Wait Time Report

```csharp
public record GetQueueWaitTimeReportQuery(
    Guid TenantId,
    DateTime From,
    DateTime To,
    IReadOnlyList<Guid>? QueueIds
) : IRequest<IReadOnlyList<QueueWaitTimeRowDto>>;

public record QueueWaitTimeRowDto(
    DateTime IntervalStart,
    string QueueName,
    int AvgWaitTimeSec,
    int MaxWaitTimeSec,
    int AvgTimeToAbandonSec,
    int CallsAnswered,
    int CallsAbandoned
);
```

#### A4 — Agent Monthly Summary

```csharp
public record GetAgentMonthlySummaryQuery(
    Guid TenantId,
    int Year,
    int Month,
    IReadOnlyList<Guid>? AgentIds
) : IRequest<IReadOnlyList<AgentMonthlySummaryDto>>;

public record AgentMonthlySummaryDto(
    string AgentLoginName,
    string AgentDisplayName,
    int ShiftCount,             // количество смен (рабочих дней)
    long TotalLoginSec,         // суммарное время на линии
    int CallsHandled,
    int CallsMissed,
    int AvgAHT,
    decimal OccupancyPct,
    decimal ShrinkagePct,
    decimal CPH
);
```

#### A5 — Agent Shift Detail

```csharp
public record GetAgentShiftDetailQuery(
    Guid TenantId,
    Guid AgentId,
    DateTime From,
    DateTime To
) : IRequest<IReadOnlyList<AgentShiftDetailDto>>;

public record AgentShiftDetailDto(
    DateTime Date,
    DateTime? LoginAt,
    DateTime? LogoutAt,
    int ShiftDurationSec,
    int CallsHandled,
    int AvgAHT,
    long BreakSec,
    long TalkSec
);
```

---

## 6. Системные отчёты (17 штук)

Системные отчёты сидят в `user_reports` с `IsSystem = true`. Они заполняются seed-данными
при первом запуске (`DatabaseInitializer`) и недоступны для удаления.

### Группа Q — Queue Reports

| ID | Slug | Название | Маршрут |
|----|------|----------|---------|
| Q1 | `q-interval` | Queue Interval Report | `/reports/queue-interval` |
| Q2 | `q-daily` | Queue Daily Summary | `/reports/queue-daily` |
| Q3 | `q-sla-trend` | Queue SLA Trend | `/reports/queue-sla-trend` |
| Q4 | `q-abandoned` | Abandoned Calls Analysis | `/reports/queue-abandoned` |
| Q5 | `q-wait-time` | Queue Wait Time Report | `/reports/queue-wait-time` |
| Q6 | `q-compare` | Multi-Queue Comparison | `/reports/queue-compare` |

### Детализация Q1 — Queue Interval Report

**Назначение:** основной оперативный отчёт. Показывает нагрузку и качество сервиса
по интервалам за выбранный период.

**Фильтры:**
- Дата: от/до (по умолчанию: сегодня)
- Очереди: мультиселект (по умолчанию: все очереди группы пользователя)
- Интервал: 30 мин / 60 мин

**Колонки таблицы:**

| # | Заголовок | Источник | Формат |
|---|-----------|----------|--------|
| 1 | Время | `IntervalStart` | HH:mm |
| 2 | Очередь | `QueueName` | текст |
| 3 | Поступило | `CallsOffered` | число |
| 4 | Принято | `CallsAnswered` | число |
| 5 | Потеряно | `CallsAbandoned` | число |
| 6 | Потери % | `AbandonPct` | % (красный > 10%) |
| 7 | SL % | `SlPct` | % (красный < 80%) |
| 8 | ASA | `ASA` | сек |
| 9 | Avg Wait | `AvgWaitTime` | сек |
| 10 | Max Wait | `MaxWaitTime` | сек (жёлтый > 120 сек) |
| 11 | AHT | `AHT` | сек |
| 12 | Occupancy % | `OccupancyPct` | % |

**Сводные тайлы (над таблицей):**
- Всего поступило | Всего принято | Avg SL% | Avg ASA | Max Wait (пиковый)

**Цветовые правила:**
- SL% < 70% → красная ячейка
- SL% 70–80% → жёлтая ячейка
- SL% ≥ 80% → зелёная ячейка
- Abandon% > 10% → красная ячейка
- Max Wait > 120 сек → жёлтая ячейка

---

### Детализация Q5 — Queue Wait Time Report

**Назначение:** профиль времени ожидания по часам суток. Помогает выявить пиковые
периоды и определить достаточность укомплектованности.

**Фильтры:** дата, очереди

**Колонки:**

| # | Заголовок | Формат |
|---|-----------|--------|
| 1 | Интервал | HH:mm |
| 2 | Очередь | текст |
| 3 | Принято | число |
| 4 | Потеряно | число |
| 5 | Avg Wait | сек |
| 6 | Max Wait | сек |
| 7 | Avg до потери | сек |

---

### Группа A — Agent Reports

| ID | Slug | Название | Маршрут |
|----|------|----------|---------|
| A1 | `a-daily` | Agent Daily Performance | `/reports/agent-daily` |
| A2 | `a-interval` | Agent Interval Activity | `/reports/agent-interval` |
| A3 | `a-shrinkage` | Agent Shrinkage | `/reports/agent-shrinkage` |
| A4 | `a-monthly` | Agent Monthly Summary | `/reports/agent-monthly` |
| A5 | `a-shift` | Agent Shift Detail | `/reports/agent-shift` |
| A6 | `a-short-calls` | Short & Long Calls | `/reports/agent-short-calls` |
| A7 | `a-outbound` | Outbound Activity | `/reports/agent-outbound` |

### Детализация A4 — Agent Monthly Summary

**Назначение:** табель оператора за месяц. Используется для оценки нагрузки,
бонусирования, планирования отпусков.

**Фильтры:** Год, Месяц, Агент (мультиселект), Группа агентов

**Колонки:**

| # | Заголовок | Источник | Формат |
|---|-----------|----------|--------|
| 1 | Агент | `AgentDisplayName` | текст |
| 2 | Логин | `AgentLoginName` | текст |
| 3 | Смен | `ShiftCount` | число |
| 4 | Время на линии | `TotalLoginSec` | ч:мм |
| 5 | Звонки | `CallsHandled` | число |
| 6 | Пропущено | `CallsMissed` | число |
| 7 | AHT | `AvgAHT` | сек |
| 8 | Occupancy % | `OccupancyPct` | % |
| 9 | Shrinkage % | `ShrinkagePct` | % |
| 10 | CPH | `CPH` | число |

### Детализация A5 — Agent Shift Detail

**Назначение:** детальный табель — одна строка = одна смена. Используется для
начисления часов, контроля опозданий, сверки с расписанием WFM.

**Фильтры:** Агент (один), Период

**Колонки:**

| # | Заголовок | Источник | Формат |
|---|-----------|----------|--------|
| 1 | Дата | `Date` | DD.MM.YYYY |
| 2 | Вход | `LoginAt` | HH:mm:ss |
| 3 | Выход | `LogoutAt` | HH:mm:ss |
| 4 | Длит. смены | `ShiftDurationSec` | ч:мм |
| 5 | Звонки | `CallsHandled` | число |
| 6 | AHT | `AvgAHT` | сек |
| 7 | Talk Time | `TalkSec` | ч:мм |
| 8 | Перерывы | `BreakSec` | ч:мм |

---

### Группа S — Summary / Management Reports

| ID | Slug | Название | Маршрут |
|----|------|----------|---------|
| S1 | `s-eod` | End-of-Day Report | `/reports/eod` |
| S2 | `s-mgmt-kpi` | Management KPI | `/reports/mgmt-kpi` |
| S3 | `s-agentgroup` | Agent Group Performance | `/reports/agentgroup` |
| S4 | `s-staffing` | Staffing vs Traffic | `/reports/staffing` |

---

## 7. Конструктор пользовательских отчётов

### 7.1 UX — навигация

```
/reports
├── Системные отчёты      ← вкладка (IsSystem=true, все видят)
│     Q1 Queue Interval
│     Q2 Queue Daily
│     ...
│
└── Мои отчёты / Общие    ← вкладка
      [Личные]  Мой SLA отчёт   (IsPublic=false)
      [Общий]   SLA по VIP      (IsPublic=true, виден всем в тенанте)
      [+ Создать отчёт]         ← открывает визард
```

### 7.2 Визард создания отчёта (4 шага)

**Шаг 1 — Источник данных**

```
Название отчёта: [________________]
Описание:        [________________]

Источник данных:
  ( ) Очереди      — данные по нагрузке, SLA, времени ожидания
  ( ) Агенты       — данные по активности, занятости, сменам
  ( ) Группы агентов — агрегированные данные по группам
```

**Шаг 2 — Период и группировка**

```
Гранулярность:
  ( ) По интервалам  [30 мин ▼]
  ( ) По дням
  ( ) По неделям
  ( ) По месяцам

Диапазон дат:
  ( ) Сегодня
  ( ) Вчера
  ( ) Последние 7 дней
  ( ) Эта неделя
  ( ) Прошлая неделя
  ( ) Этот месяц
  ( ) Прошлый месяц
  ( ) Произвольный: [от 01.06.2026] [до 17.06.2026]
```

**Шаг 3 — Выбор метрик**

Для источника `queues`:
```
┌─ Нагрузка ────────────────────────────────────────┐
│ ☑ Поступило       ☑ Принято       ☑ Потеряно      │
│ ☑ Потери %        ☐ Callbacks                      │
├─ Уровень сервиса ─────────────────────────────────┤
│ ☑ SL %  (порог: [20] сек)                          │
│ ☑ ASA              ☑ Avg Wait     ☑ Max Wait        │
│ ☐ Avg до потери                                    │
├─ Обработка ───────────────────────────────────────┤
│ ☑ AHT              ☐ Talk Time    ☐ ACW Time        │
│ ☐ Occupancy %      ☐ Agents Staffed                │
└───────────────────────────────────────────────────┘
```

Для источника `agents`:
```
┌─ Звонки ──────────────────────────────────────────┐
│ ☑ Принято         ☑ Пропущено     ☑ CPH            │
├─ Время ───────────────────────────────────────────┤
│ ☑ AHT             ☐ Talk Time     ☐ ACW Time        │
│ ☐ Hold Time                                        │
├─ Статусы ─────────────────────────────────────────┤
│ ☑ Occupancy %     ☑ Shrinkage %                    │
│ ☐ Ready Time      ☐ Break Time    ☐ Paperwork Time  │
├─ Смены ───────────────────────────────────────────┤
│ ☑ Кол-во смен     ☑ Вход          ☑ Выход           │
│ ☑ Длит. смены                                      │
└───────────────────────────────────────────────────┘
```

**Шаг 4 — Фильтры и сохранение**

```
Очереди:  [Все очереди ▼]  (мультиселект)
Агенты:   [Все агенты ▼]

Сортировка: [Поступило ▼]  [По убыванию ▼]
Строк на стр: [25 ▼]

Доступ:
  ( ) Только я      (IsPublic=false)
  ( ) Все в тенанте (IsPublic=true)

[Предпросмотр] → [Сохранить]
```

### 7.3 Список доступных метрик (Config.metrics)

Для источника **queues:**

| Ключ | Название | Вычисление |
|------|----------|------------|
| `CallsOffered` | Поступило | прямое поле |
| `CallsAnswered` | Принято | прямое поле |
| `CallsAbandoned` | Потеряно | прямое поле |
| `AbandonPct` | Потери % | вычисляемое |
| `SlPct` | SL % | вычисляемое (с SlThresholdSec) |
| `ASA` | ASA | вычисляемое |
| `AvgWaitTime` | Avg Wait | вычисляемое |
| `MaxWaitTime` | Max Wait | прямое поле |
| `AvgTimeToAbandon` | Avg до потери | вычисляемое |
| `AHT` | AHT | вычисляемое |
| `AvgTalkTime` | Avg Talk | вычисляемое |
| `OccupancyPct` | Occupancy % | вычисляемое |
| `AgentsStaffed` | Агентов | прямое поле |

Для источника **agents:**

| Ключ | Название | Вычисление |
|------|----------|------------|
| `CallsHandled` | Принято | прямое поле |
| `CallsMissed` | Пропущено | прямое поле |
| `CPH` | CPH | вычисляемое |
| `AHT` | AHT | вычисляемое |
| `OccupancyPct` | Occupancy % | вычисляемое |
| `ShrinkagePct` | Shrinkage % | вычисляемое |
| `ShiftDurationSec` | Длит. смены | вычисляемое |
| `TotalLoginSec` | Время на линии | SUM(ShiftDurationSec) |
| `ShiftCount` | Смен | COUNT(DISTINCT дата) |
| `SumTalkSec` | Talk Time | прямое поле |
| `SumBreakSec` | Break Time | прямое поле |

### 7.4 MediatR команды для пользовательских отчётов

```csharp
// Получить список
public record GetUserReportsQuery(
    Guid TenantId,
    Guid UserId,
    bool IncludePublic = true
) : IRequest<IReadOnlyList<UserReportSummaryDto>>;

// Сохранить / обновить
public record SaveUserReportCommand(
    Guid? Id,         // null = создание, не null = обновление
    Guid TenantId,
    Guid UserId,
    string Name,
    string? Description,
    string DataSource,
    string ConfigJson,
    bool IsPublic
) : IRequest<Guid>;

// Удалить
public record DeleteUserReportCommand(
    Guid Id,
    Guid TenantId,
    Guid UserId
) : IRequest<Unit>;

// Выполнить пользовательский отчёт
public record RunUserReportQuery(
    Guid ReportId,
    Guid TenantId,
    Guid UserId,
    int Page,
    int PageSize
) : IRequest<PagedResult<Dictionary<string, object?>>>;
```

---

## 8. UI-компоненты и маршруты

### 8.1 Навигационное меню

Добавить в `NavMenu.razor` секцию "Отчёты":

```razor
<NavSection Label="@L["Nav.Reports"]">
    <AuthorizeView Roles="Superadmin,Administrator,Editor,Viewer">
        <NavItem Href="/reports" Icon="bi-bar-chart-line" Label="@L["Nav.Reports.All"]" />
    </AuthorizeView>
</NavSection>
```

### 8.2 ReportFilterBar.razor

Универсальный компонент фильтрации, используется во всех страницах отчётов.

**Параметры:**
```csharp
[Parameter] public DateTime DateFrom { get; set; }
[Parameter] public DateTime DateTo { get; set; }
[Parameter] public EventCallback<(DateTime, DateTime)> OnDateRangeChanged { get; set; }
[Parameter] public bool ShowQueueFilter { get; set; } = false;
[Parameter] public bool ShowAgentFilter { get; set; } = false;
[Parameter] public bool ShowIntervalSelector { get; set; } = false;
[Parameter] public int IntervalMinutes { get; set; } = 30;
[Parameter] public EventCallback<int> OnIntervalChanged { get; set; }
[Parameter] public List<Guid> SelectedQueueIds { get; set; } = new();
[Parameter] public EventCallback<List<Guid>> OnQueuesChanged { get; set; }
[Parameter] public EventCallback OnApply { get; set; }
[Parameter] public EventCallback OnExportCsv { get; set; }
```

### 8.3 ReportTable.razor

Универсальная таблица с пагинацией, сортировкой и цветовыми правилами.

**Параметры:**
```csharp
[Parameter] public IReadOnlyList<object> Rows { get; set; } = Array.Empty<object>();
[Parameter] public IReadOnlyList<ReportColumnDef> Columns { get; set; }
[Parameter] public int TotalCount { get; set; }
[Parameter] public int Page { get; set; }
[Parameter] public int PageSize { get; set; }
[Parameter] public EventCallback<int> OnPageChanged { get; set; }
[Parameter] public bool ShowTotalsRow { get; set; } = true;
```

```csharp
public record ReportColumnDef(
    string Field,
    string Header,
    string Format,          // "number" | "percent" | "seconds" | "hhmmss" | "datetime" | "text"
    string? CssClass = null,
    Func<object, string>? CellClass = null   // для условного цвета
);
```

### 8.4 ReportSummaryTiles.razor

Строка KPI-тайлов над таблицей:

```razor
<div class="report-tiles">
    @foreach (var tile in Tiles)
    {
        <div class="report-tile">
            <span class="report-tile-value @tile.CssClass">@tile.Value</span>
            <span class="report-tile-label">@tile.Label</span>
        </div>
    }
</div>
```

### 8.5 ReportsIndex.razor (`/reports`)

Главная страница раздела. Две вкладки:

**Вкладка "Системные"** — карточки Q1–S4:
```
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Q Queue Interval  │  │ Q Queue Daily     │  │ Q Wait Time       │
│ Интервал. данные │  │ Сводка по дням   │  │ Время ожидания   │
│ [Открыть →]      │  │ [Открыть →]      │  │ [Открыть →]      │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

**Вкладка "Мои / Общие"**:
```
[Личные ▼]  [Общие ▼]  [Поиск...]     [+ Создать отчёт]

Мой SLA Отчёт          Очереди • Интервал  [Открыть] [Изменить] [Удалить]
SLA по VIP (общий)     Очереди • День      [Открыть] [Изменить] [Удалить]
```

### 8.6 CustomReportPage.razor (`/reports/custom/{id}`)

Страница выполнения пользовательского отчёта. Загружает конфиг из БД, строит
параметры фильтра из `Config`, запускает `RunUserReportQuery`, отображает через
`ReportTable` с динамическими колонками по `Config.metrics`.

---

## 9. Экспорт данных

### 9.1 CSV (v1)

Реализация на стороне сервера (C#):

```csharp
// Application/Services/ReportCsvExporter.cs
public class ReportCsvExporter
{
    public byte[] Export<T>(
        IReadOnlyList<T> rows,
        IReadOnlyList<ReportColumnDef> columns)
    {
        // StringBuilder → UTF-8 BOM + запятая-разделитель
        // Заголовки из columns[].Header
        // Данные: форматировать по columns[].Format
        // Числа: культура инвариантная (точка как разделитель)
    }
}
```

Кнопка "Экспорт CSV" в `ReportFilterBar` вызывает JS:

```javascript
// wwwroot/js/app.js
window.ccApp.downloadCsv = function(base64, filename) {
    const blob = new Blob(
        [Uint8Array.from(atob(base64), c => c.charCodeAt(0))],
        { type: 'text/csv;charset=utf-8;' }
    );
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
};
```

### 9.2 Excel / PDF (v2)

- Excel: библиотека `ClosedXML` или `EPPlus` — форматирование, заморозка заголовков,
  условное форматирование цветов SL%
- PDF: `QuestPDF` или `iTextSharp` — для End-of-Day отчёта S1

### 9.3 Email-доставка (v2)

Таблица `report_schedules`:
```sql
CREATE TABLE report_schedules (
    "Id"           uuid PRIMARY KEY,
    "TenantId"     uuid NOT NULL,
    "UserReportId" uuid NOT NULL REFERENCES user_reports("Id"),
    "CronExpression" varchar(100) NOT NULL,   -- "0 8 * * 1-5" = пн-пт 8:00
    "Recipients"   jsonb NOT NULL,            -- ["email@domain.com", ...]
    "Format"       varchar(10) NOT NULL,      -- 'csv' | 'xlsx' | 'pdf'
    "IsActive"     boolean DEFAULT true,
    "LastRunAt"    timestamptz,
    "CreatedAt"    timestamptz DEFAULT NOW()
);
```

---

## 10. Локализация

Все строки UI выносятся в `.resx` файлы. Ключи с префиксом `Reports.`:

| Ключ | EN | RU |
|------|----|----|
| `Reports.Title` | Reports | Отчёты |
| `Reports.SystemReports` | System Reports | Системные отчёты |
| `Reports.MyReports` | My Reports | Мои отчёты |
| `Reports.CreateReport` | + Create Report | + Создать отчёт |
| `Reports.FilterDateFrom` | From | С |
| `Reports.FilterDateTo` | To | По |
| `Reports.FilterQueues` | Queues | Очереди |
| `Reports.FilterAgents` | Agents | Агенты |
| `Reports.FilterInterval` | Interval | Интервал |
| `Reports.Apply` | Apply | Применить |
| `Reports.ExportCsv` | Export CSV | Экспорт CSV |
| `Reports.Q1.Title` | Queue Interval Report | Интервальный отчёт по очередям |
| `Reports.Q5.Title` | Queue Wait Time Report | Время ожидания в очередях |
| `Reports.A4.Title` | Agent Monthly Summary | Табель операторов |
| `Reports.A5.Title` | Agent Shift Detail | Детальный табель |
| `Reports.Col.CallsOffered` | Offered | Поступило |
| `Reports.Col.CallsAnswered` | Answered | Принято |
| `Reports.Col.CallsAbandoned` | Abandoned | Потеряно |
| `Reports.Col.AbandonPct` | Abandon % | Потери % |
| `Reports.Col.SlPct` | SL % | SL % |
| `Reports.Col.ASA` | ASA (sec) | ASA (сек) |
| `Reports.Col.AvgWait` | Avg Wait | Ср. ожидание |
| `Reports.Col.MaxWait` | Max Wait | Макс. ожидание |
| `Reports.Col.AHT` | AHT (sec) | AHT (сек) |
| `Reports.Col.OccupancyPct` | Occupancy % | Загрузка % |
| `Reports.Col.ShiftCount` | Shifts | Смен |
| `Reports.Col.LoginAt` | Login | Вход |
| `Reports.Col.LogoutAt` | Logout | Выход |
| `Reports.Builder.Step1` | Data Source | Источник данных |
| `Reports.Builder.Step2` | Period | Период |
| `Reports.Builder.Step3` | Metrics | Метрики |
| `Reports.Builder.Step4` | Filters & Save | Фильтры и сохранение |
| `Reports.NoData` | No data for selected period | Нет данных за выбранный период |
| `Reports.AggregationRunning` | Data is being collected... | Идёт сбор данных... |

---

## 11. Права доступа

### 11.1 Доступ к разделу

| Роль | Системные отчёты | Мои отчёты | Общие отчёты | Создать отчёт |
|------|-----------------|------------|--------------|---------------|
| Superadmin | ✓ | ✓ | ✓ | ✓ |
| Administrator | ✓ | ✓ | ✓ | ✓ |
| Editor | ✓ | ✓ | ✓ | ✓ |
| Viewer | ✓ | ✓ | ✓ | — |

Viewer может смотреть все отчёты, но не создавать пользовательские.

### 11.2 Фильтрация по Permission Group

Для пользователей с PermissionGroup (не Superadmin):
- Список очередей в фильтре ограничен `pg_queues` (очереди их группы)
- Список агентов в фильтре ограничен агентами из разрешённых очередей
- Данные в агрегатных таблицах уже содержат все очереди тенанта — фильтрация
  происходит в репозитории, а не на уровне агрегации

### 11.3 Пользовательские отчёты — права

- `IsPublic = false`: видит только создатель + Superadmin/Administrator
- `IsPublic = true`: видит весь тенант
- Редактировать/удалять может создатель, Superadmin или Administrator
- Viewer не может создавать, но может запускать любой публичный отчёт

### 11.4 Страницы с `[Authorize]`

```csharp
@page "/reports"
@page "/reports/{*slug}"
@attribute [Authorize]  // минимум — любой аутентифицированный пользователь
```

Дополнительные проверки в обработчике команды:
```csharp
// SaveUserReportCommand handler
if (currentUser.IsViewer())
    throw new ForbiddenException("Viewers cannot create reports");
```

---

## 12. Планы поставки (фазы)

### Фаза 1 — v1 (базовый модуль)

**Цель:** работающий модуль исторических отчётов с ключевыми отчётами и CSV-экспортом.

**Scope:**

*Data Layer (CC-HIST-001):*
- [ ] EF миграция: `hist_queue_intervals`, `hist_agent_intervals`, `user_reports`
- [ ] `HistoricalAggregationService` (BackgroundService)
- [ ] `HistoricalReportRepository`
- [ ] MediatR запросы: Q1, Q5, A4, A5
- [ ] Unit-тесты репозитория (6 тестов)

*UI Layer (CC-HIST-002):*
- [ ] `ReportFilterBar.razor`, `ReportTable.razor`, `ReportSummaryTiles.razor`
- [ ] Страницы: Q1, Q5, A4, A5, `ReportsIndex`
- [ ] Навигация (NavMenu)
- [ ] CSV-экспорт
- [ ] i18n (en-US + ru-RU)
- [ ] `reports.css`
- [ ] Unit-тесты UI (4 теста)

*Пользовательские отчёты (CC-HIST-003):*
- [ ] `UserReport` сущность + EF конфиг
- [ ] `UserReportRepository` + CQRS команды
- [ ] `ReportBuilder.razor` (4-шаговый визард)
- [ ] `UserReportsList.razor`, `CustomReportPage.razor`
- [ ] Seed системных отчётов в `DatabaseInitializer`

**Ожидаемый результат:** /reports работает, Q1+Q5 показывают данные, A4+A5 показывают
данные, пользователи могут создавать собственные отчёты и сохранять их.

---

### Фаза 2 — v2 (расширение)

- [ ] Отчёты Q2, Q3, Q4, Q6 (остальные Queue)
- [ ] Отчёты A1, A2, A3 (активность, интервальная, shrinkage)
- [ ] Отчёты S1, S2, S3, S4 (management)
- [ ] Excel-экспорт (`ClosedXML`)
- [ ] `report_schedules` + BackgroundService email-доставки
- [ ] Инфографика: sparkline-графики в карточках системных отчётов

---

### Фаза 3 — v3 (BI)

- [ ] Комбинированные отчёты (queue + agents в одной таблице)
- [ ] Drill-down: клик по интервалу → детализация по агентам
- [ ] Сравнение периодов (эта неделя vs прошлая)
- [ ] PDF-экспорт (`QuestPDF`)
- [ ] Dashboard-виджет "мини-отчёт" (последние 4 интервала)
- [ ] Публичная ссылка на отчёт (token-based, без логина)

---

## 13. Тестирование

### 13.1 Unit-тесты (Application/Domain)

```csharp
// Tests.Unit/HistoricalReports/QueueMetricsCalculationTests.cs

[Fact]
public void AbandonPct_WhenNoOffered_ReturnsZero()
{
    var dto = QueueIntervalRowDto.Compute(offered: 0, abandoned: 5, ...);
    dto.AbandonPct.Should().Be(0);
}

[Fact]
public void SlPct_WhenNoneAnswered_ReturnsZero()
{
    var dto = QueueIntervalRowDto.Compute(answered: 0, callsInSl: 5, ...);
    dto.SlPct.Should().Be(0);
}

[Fact]
public void ASA_CalculatedCorrectly()
{
    var dto = QueueIntervalRowDto.Compute(answered: 10, sumWaitSec: 200, ...);
    dto.ASA.Should().Be(20);
}

[Fact]
public void MaxWaitTime_TakenFromField()
{
    var dto = QueueIntervalRowDto.Compute(maxWaitTimeSec: 185, ...);
    dto.MaxWaitTime.Should().Be(185);
}

[Fact]
public void AgentMonthly_ShiftCount_CountsUniqueDays()
{
    // 3 интервала 1 янв + 2 интервала 2 янв = 2 смены
    var intervals = BuildIntervals(jan1: 3, jan2: 2);
    var summary = AgentMonthlySummaryDto.Aggregate(intervals);
    summary.ShiftCount.Should().Be(2);
}

[Fact]
public void OccupancyPct_ZeroWhenNoActivity()
{
    var dto = AgentMonthlySummaryDto.Compute(readySec: 0, talkSec: 0, ...);
    dto.OccupancyPct.Should().Be(0);
}
```

### 13.2 Integration-тесты

```csharp
// Tests.Integration/HistoricalReports/AggregationServiceTests.cs

[Fact]
public async Task AggregateAsync_WritesCorrectRowCount()
{
    // Arrange: вставить 5 звонков в RTSData_Interaction за интервал
    // Act: вызвать AggregateQueueIntervalAsync
    // Assert: 1 строка в hist_queue_intervals с CallsOffered=5
}

[Fact]
public async Task AggregateAsync_IsIdempotent()
{
    // Act: агрегировать дважды
    // Assert: в hist_queue_intervals всё ещё 1 строка
}

[Fact]
public async Task GetQueueIntervals_FiltersCorrectlyByTenant()
{
    // Arrange: данные для tenant1 и tenant2
    // Act: запрос для tenant1
    // Assert: только данные tenant1
}
```

### 13.3 Тесты прав доступа

```csharp
// Tests.Security/ReportAccessTests.cs

[Fact]
public async Task Viewer_CannotCreateUserReport()
{
    // Assert: SaveUserReportCommand выбрасывает ForbiddenException
}

[Fact]
public async Task User_CannotSeeOtherTenantsReports()
{
    // Assert: данные tenant2 не возвращаются для пользователя tenant1
}
```

---

## 14. Приложение: метрики системы

### Ключевые метрики источника `RTSGrid_Metric` (207 штук)

**Метрики очередей (используются в hist_queue_intervals):**

| MetricId | MetricParameter | Описание |
|----------|-----------------|----------|
| QueueAvgWaitTimeCalls | — | Среднее время ожидания принятых |
| QueueCurMaxWaitTimeCalls | — | Максимальное время ожидания |
| QueueAvgTimeToAbandCalls | — | Среднее время до потери |
| QueueNumAbandonedCalls | — | Кол-во потерянных |
| QueueNumAnsweredCalls | — | Кол-во принятых |
| QueuePctAnsweredCalls20secInc | — | SL% (порог 20 сек) |
| QueuePctAnsweredCalls30secInc | — | SL% (порог 30 сек) |

**Метрики агентов (используются в hist_agent_intervals):**

| MetricId | MetricParameter | Описание |
|----------|-----------------|----------|
| MonAgentLoginTime | — | Суммарное время входа за день |
| MonAgentFirstLoginTimeStamp | — | Время первого входа |
| MonAgentCurrentLoginTimeStamp | — | Время последнего входа |
| MonAgentBreakDuration | — | Суммарный перерыв |
| MonAgentTalkDuration | — | Суммарный Talk Time |
| MonAgentWrapUpDuration | — | Суммарный ACW |
| MonAgentAvailableDuration | — | Суммарный Ready Time |
| MonAgentUnavailableDuration | — | Суммарный Not-Ready |
| MonAgentPaperworkDuration | — | Суммарный Paperwork |
| UserCPH | — | Звонков в час |
| UserNumMissedCalls | — | Пропущено звонков |

> Эти метрики — реальные значения из RTSGrid_Metric (запрос 2026-06-08).
> При необходимости сверьте с актуальной БД: `SELECT "MetricId", "MetricParameter"
> FROM "RTSGrid_Metric" WHERE "MetricId" LIKE '%Queue%' OR "MetricId" LIKE '%Agent%';`


---

## ADDENDUM A — Two-Tier Data Architecture (Architect Verdict, 2026-06-19) — FOUNDATIONAL, supersedes single-store assumptions

> Verified on live server 234: RTSData_Interaction is NOT being cleared — data accumulated since 2026-06-02 (>=17 days)
> -> RTSData_MidnightClear is disabled or not firing. RT table grows unbounded; no retention, no historical store.
> This addendum SUPERSEDES single-store assumptions in this TZ.

Two tiers:
1. RT-tier — WINDOWED ~1 month retention via the module's OWN reliable purge (scheduled purge / drop partitions). RTSData_MidnightClear is SUPERSEDED — do NOT re-enable. Scheme is role-bi's choice within the contract: (i) purge/partitions ON the RTSData_* tables (touches the RTM external contour → applied ONLY on operator confirmation) OR (ii) a separate reporting-owned RT-tier populated FROM RTSData_* (no contour touch); MARK where it touches the contour. Comparative/short metrics.
2. Historical tier (hist_*) — retention 6-7 years, monthly RANGE partitioning (audit.audit_logs §6 pattern), populated by aggregation from the RT source BEFORE data ages out of the RT window.

Why now: foundational (drives table/partition/aggregator/migration design; retrofit expensive) + structural fix for GAP #5 (aggregator moves RT->historical before RT ages -> midnight race gone).

MidnightClear cause — ESTABLISHED (2026-06-19, diagnosis only, NOTHING changed): the DB nightly wipe is DEAD CODE — RTSData_MidnightClear's sole caller Engine.cs:957 (//_dbMng.midnightClear();) is commented out; the live midnight path Engine.cs:1062 CheckAndClear -> Engine.cs:1106 union.midnightClear(_interactionsList) is IN-MEMORY only and never wipes the DB tables -> RTSData_* grow unbounded (234: since 2026-06-02). The windowed RT mechanism does NOT collide with MidnightClear; it must be the SOLE RT-lifecycle owner -> do NOT uncomment Engine.cs:957. (EXTERNAL RTM contour — diagnosis recorded for operator; no change made.)

Designed by role-bi/coordinator WITHIN contract: exact partition scheme, RT sliding-window purge, 6-7yr archival, possible separate warehouse.

---

## Ревизии документа

| Версия | Дата | Изменения |
|--------|------|-----------|
| 1.0 | 2026-06-17 | Начальная версия |
| 1.1 | 2026-06-19 | ADDENDUM A — two-tier data architecture (architect verdict) |

---

*Проект: RTM View Shell*
