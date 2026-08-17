---
name: feedback-jtoken-newtonsoft
description: "On<JsonElement> молча дропает сообщения при Newtonsoft SignalR протоколе — использовать On<JToken>"
metadata:
  type: feedback
  updated: 2026-06-03
---

## Правило: Newtonsoft SignalR протокол — никогда не использовать JsonElement

**Когда HubConnection использует `AddNewtonsoftJsonProtocol`, нельзя регистрировать `On<System.Text.Json.JsonElement>`.**

Newtonsoft.Json не умеет десериализовать в `System.Text.Json.JsonElement` (чужой тип).
Результат: handler **молча никогда не вызывается**, все входящие сообщения дропаются без ошибок и без логов.

**Правильно:**
```csharp
conn.On<JToken>("updateGridData", cells => HandleAsync(cells));

// В handler:
if (cells is not JArray arr) return;
foreach (var item in arr)
{
    var cellId = item["CellId"].Value<int>();
    var value  = item["Value"].Value<string>() ?? "";
}
```

**Неправильно (молча не работает):**
```csharp
conn.On<JsonElement>("updateGridData", cells => HandleAsync(cells)); // НИКОГДА!
```

**Why:** Newtonsoft и System.Text.Json — независимые библиотеки. STJ.JsonElement — struct без публичного конструктора для Newtonsoft.

**How to apply:** Любой `On<T>` с Newtonsoft-протоколом — использовать `JToken`, `JArray`, `JObject` или `string`.

Этот баг стоил нескольких дней отладки (2026-06-02/03).
