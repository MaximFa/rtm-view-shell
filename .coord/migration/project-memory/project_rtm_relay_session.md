---
name: project-rtm-relay-session
description: "RTM Relay — полностью закрыт (2026-06-01): виджеты подключены, баги исправлены, single-port model работает"
metadata: 
  node_type: memory
  type: project
  originSessionId: c5992e15-8746-48da-a4a0-fbafdeb05715
---

## RTM Relay — FULLY CLOSED (2026-06-01)

**Браузер использует только порт 443. RTM Service недоступен напрямую из браузера.**

### Все коммиты

| Коммит | Что |
|---|---|
| `0c3c902` | CC-003: RtmRelayService (677 lines), IRtmRelayService, domain models, RtmRelayHub, DI |
| `1838685` | Docs: CHANGELOG v1.6, widget-framework.md, architecture.md |
| `245ee49` | Виджеты подключены к IRtmRelayService (QueueGrid, DataSlot, AgentStateDistribution, AgentGrid) |
| `1473000` | Баги relay: `/signalr` URL fix + Newtonsoft protocol; CORS убран из симулятора |

### Ключевые факты

- `SignalRConnectionUrl` хранит BASE URL без `/signalr` (e.g. `http://localhost:5045`)
- `GetHubUrlAsync` автоматически добавляет `/signalr`
- Relay подключается с `AddNewtonsoftJsonProtocol(DefaultContractResolver)` — PascalCase
- Симулятор: CORS убран, только server-to-server
- QueueGrid: ONE `SubscribeGridAsync` на виджет независимо от числа BU-строк
- AgentGrid: `SubscribeUnionAsync` → handler обрабатывает `InitialSnapshot | AgentsUpserted | AgentsRemoved`

### Архитектура (итог)

```
Browser → port 443 → Blazor circuit → IRtmRelayService (Singleton)
                                           ↓ server-to-server
                                      HubConnection → RTM Service /signalr
```

### How to apply

Relay полностью закончен. Следующие задачи не связаны с relay:
- ToDo.txt: валидация конфигуратора, DataSlot warning, DataSlot доделать, импортировать дату
