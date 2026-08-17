---
name: rtm-devops-session
description: "RTM Devops сессия 2026-06-01 — prod-release агент, статус, что сделано, что тестировать в новой сессии"
metadata: 
  node_type: memory
  type: project
  originSessionId: cbc0c0e4-5dd0-4745-8a2e-6630ecf10159
---

# RTM Devops — состояние на 2026-06-01

**Why:** Пользователь открыл новую сессию "продолжаем devops" — здесь весь контекст.
**How to apply:** Прочитать этот файл, предложить протестировать prod-release скилл.

---

## Что сделано в этой сессии

### Созданы файлы в D:\Claude\Projects\RTM View Shell\

| Файл | Назначение |
|---|---|
| `tools/Build-ProdRelease.ps1` | Сборка пакета (Mode: Full/Shell/RTM, pg_dump, Memurai, zip) |
| `deploy/Install-RTMView.ps1` | Установка на сервер (автодетект Mode, CREATE DB/USER, Memurai, Windows Services) |
| `deploy/Update-RTMView.ps1` | Обновление (stop → backup → deploy → start) |
| `deploy/README.txt` | Инструкция в каждом zip |
| `tools/cc_prompt_build_rtm.md` | CC-промпт для сборки (пароль: !@#qweASDzxc) |
| `tools/cache/.gitkeep` | Папка для Memurai MSI |
| `Installations/.gitkeep` | Папка для готовых zip-пакетов |

Также добавлен **§35 в CLAUDE.md** — правило всегда использовать prod-release скилл при запросе сборки.

### Установлен Cowork skill: prod-release
- Физически: `.claude/skills/prod-release/SKILL.md` (209 строк)
- Триггеры: "нужна установка RTM+DB", "собери RTM", "сделай пакет", "build release" и др.
- **В текущей сессии скилл НЕ работал** через Skill-tool (установлен во время сессии → не в available_skills)
- **В новой сессии должен работать автоматически**

---

## Что нужно сделать в новой сессии

### Тест 1 — Проверить что скилл подхватывается
Пользователь скажет: "нужна установка RTM+DB"
→ Скилл должен сработать автоматически
→ Если нет — вызвать вручную по инструкции в SKILL.md

### Тест 2 — Полный цикл RTM+DB
Скилл должен:
1. Задать 3 вопроса (PG пароль, App пароль, Redis пароль)
2. Записать `tools/cc_prompt_build_rtm.md` с заполненными паролями
3. Показать команду для CC (сборка)
4. Показать команду для сервера (установка)

Тестовые пароли: `!@#qweASDzxc` для всех трёх.

### Тест 3 — Запустить CC-промпт
После генерации промпта: запустить в CC
```
Выполни задачу из файла tools/cc_prompt_build_rtm.md
```
Zip должен появиться в `Installations/DDMMYYYY.HHMM_RTM.zip`.

### Тест 4 — Установка на сервере
Скопировать zip в C:\Temp, распаковать, запустить Install-RTMView.ps1 с параметрами из скилла.

---

## Известные детали

- **Memurai MSI:** `tools/cache/Memurai-for-Redis-v4.2.2.msi` ✅ уже в cache
- **app.dat:** `RTM/deployment/app.dat` — включается в zip автоматически
- **data.sys:** НЕ в zip, копируется вручную в C:\RTMView\RTM\
- **БД:** RTMViewDB, суперпользователь postgres, app user: ccdashboard_user
- **Порты:** Shell=5000, RTM=8088
- **Целевые пути:** C:\RTMView\Shell и C:\RTMView\RTM
- **Service names:** RTMViewShell, RTMService

## Критичные баги (уже исправлены)
Все баги задокументированы в памяти: `feedback_prod_release_bugs.md`
Главный: PS1/TXT в zip ОБЯЗАТЕЛЬНО UTF-8 BOM + CRLF (иначе Unexpected token на Windows).
