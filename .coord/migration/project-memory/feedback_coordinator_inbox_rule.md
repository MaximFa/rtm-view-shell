---
name: coordinator-inbox-rule
description: Всегда скидывать результаты и вопросы к координатору в его инбокс (.coord/inbox/coordinator.md)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c7605633-ccbd-41c0-b102-09e4396f78ac
---

Всегда флашить результаты и вопросы к координатору в его инбокс.

**Why:** Координатор читает `.coord/inbox/coordinator.md` — не чат. Если сказать только в чате, при следующем "коорд: входящие" это не появится. Важные ответы, статусы и вопросы исчезают.

**How to apply:** После любого ответа на задачу координатора / после любого вопроса к нему — аппендить блок в `.coord/inbox/coordinator.md` через Python+fsync (§0.3). Формат: `## <UTC> | from: <slug> | to: coordinator`. Не ждать отдельной просьбы.

Ошибка 2026-06-10: прочёл security findings, дал анализ в чат, не скинул в инбокс — координатор пришлось спрашивать повторно.
