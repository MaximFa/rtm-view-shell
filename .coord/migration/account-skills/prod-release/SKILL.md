---
name: prod-release
description: Генерирует CC-промпт для сборки пакета RTM View Shell по требованию и выдаёт готовую команду для установки на сервере. Триггеры: "нужна установка RTM+DB", "собери RTM", "сделай пакет Shell", "нужна сборка", "build release", "create release", "package release", "собери релиз", "сделай пакет", "упакуй релиз".
---

# prod-release skill

## Что делает этот скилл

Пользователь говорит что нужно → скилл запрашивает пароли → пишет cc_prompt → выдаёт две готовые команды:
1. Что запустить в CC (сборка пакета)
2. Что запустить на сервере (установка)

Пользователь делает руками только: запустить CC-промпт, скопировать zip, запустить PS-команду на сервере.

---

## Варианты сборки

| Что сказал пользователь | Mode | Нужны пароли |
|---|---|---|
| "RTM+DB", "RTM с базой" | RTM | PG superuser, App user, Redis |
| "только RTM", "RTM без базы" | RTM | Redis |
| "Shell+DB", "Shell с базой" | Shell | PG superuser, App user |
| "только Shell", "Shell без базы" | Shell | — |
| "Full", "всё", "полная установка" | Full | PG superuser, App user, Redis |

---

## Алгоритм (выполнять строго по порядку)

### Шаг 1 — Определить вариант

Из сообщения пользователя определи:
- `$mode` = "RTM" | "Shell" | "Full"
- `$includeDB` = true | false (нужен ли pg_dump в пакете и рестор на сервере)
- `$includeRedis` = true | false (нужен ли Memurai — всегда true когда mode=RTM или Full)

### Шаг 2 — Запросить пароли через AskUserQuestion

Задай ТОЛЬКО те вопросы, которые нужны для данного варианта.

Если нужен `$includeDB`:
- Вопрос "Пароль суперпользователя PostgreSQL (для pg_dump и CREATE DATABASE)?"
- Вопрос "Пароль приложения (ccdashboard_user)?"

Если нужен `$includeRedis`:
- Вопрос "Пароль Redis/Memurai?"

Если ничего не нужно — сразу к шагу 3.

### Шаг 3 — Написать cc_prompt файл

Запиши файл `tools/cc_prompt_build_rtm.md` через bash (Python + os.fsync):

```python
import os

path = "/sessions/tender-quirky-lamport/mnt/Projects--RTM View Shell/tools/cc_prompt_build_rtm.md"

# Подставь реальные значения переменных
mode       = "RTM"           # RTM | Shell | Full
pg_pwd     = "ПАРОЛЬ"        # пароль postgres суперпользователя (если нужен)
skip_db    = False           # True если без DB
msi        = "tools\\cache\\Memurai-for-Redis-v4.2.2.msi"
include_msi = mode in ("RTM","Full")

build_cmd = f".\\tools\\Build-ProdRelease.ps1 -Mode {mode}"
if not skip_db:
    build_cmd += f' -DBPassword "{pg_pwd}"\'
if include_msi:
    build_cmd += f' -MemuraiMsi "{msi}"\'
if skip_db:
    build_cmd += " -SkipDB"

content = f"""# Build {mode} package

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

## Шаг 1 — Запустить сборку
```powershell
cd "D:\\Claude\\Projects\\RTM View Shell"
{build_cmd}
```
Дождись завершения. Успех = последняя строка содержит `╚`.
При ошибке — показать последние 30 строк вывода.

## Шаг 2 — Проверить zip
```powershell
$zip = Get-ChildItem "Installations\\*_{mode}.zip" | Sort-Object LastWriteTime -Desc | Select-Object -First 1
Write-Host "ZIP: $($zip.FullName)  $([math]::Round($zip.Length/1MB,1)) MB"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$e = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName).Entries.FullName
@("Install-RTMView.ps1","Update-RTMView.ps1","README.txt") | % {{ Write-Host "$(if ($_ -in $e){{\'[OK]  \'}}else{{\'[MISS]\'}}}) $_" }}
Write-Host "RTM bins: $(($e -like \'RTM/*\').Count)  DB sql: $(($e -like \'DB/*.sql\').Count)  Extras: $(($e -like \'Extras/*\').Count)"
```

## Шаг 3 — Сообщить результат
Напиши пользователю: путь к zip, размер, результаты проверки.
"""

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())
print("Written:", path)
```

### Шаг 4 — Показать пользователю две команды

Напиши в чат:

---

**Шаг 1. Запусти в CC:**
```
Выполни задачу из файла tools/cc_prompt_build_rtm.md
```

**Шаг 2. Скопируй zip** из `D:\Claude\Projects\RTM View Shell\Installations\` в `C:\Temp\` на сервере и распакуй.

**Шаг 3. На сервере** (PowerShell от Администратора):

[вставь готовую команду — см. таблицу ниже]

---

### Таблицы готовых команд для сервера

**RTM+DB:**
```powershell
powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 `
    -Mode RTM `
    -DBPassword "PG_PWD" `
    -DBAppUser "ccdashboard_user" -DBAppPassword "APP_PWD" `
    -RedisPassword "REDIS_PWD"
```

**RTM без DB:**
```powershell
powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 `
    -Mode RTM -SkipDB `
    -RedisPassword "REDIS_PWD"
```

**Shell+DB:**
```powershell
powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 `
    -Mode Shell `
    -DBPassword "PG_PWD" `
    -DBAppUser "ccdashboard_user" -DBAppPassword "APP_PWD"
```

**Shell без DB:**
```powershell
powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 `
    -Mode Shell -SkipDB
```

**Full:**
```powershell
powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 `
    -DBPassword "PG_PWD" `
    -DBAppUser "ccdashboard_user" -DBAppPassword "APP_PWD" `
    -RedisPassword "REDIS_PWD"
```

Подставь реальные пароли из шага 2 этого скилла.

---

## KNOWN BUGS (обязательно учитывать при каждой сборке)

**BUG-001 — LF/no-BOM → Unexpected token '}' на Windows:**
Zip уже содержит конвертацию в Build-ProdRelease.ps1.
Если zip пришёл старый — пропатчить:
```python
import zipfile, os
BOM = b'\xef\xbb\xbf'
src = "/path/to/zip"; tmp = src + ".tmp"
patched = {}
with zipfile.ZipFile(src) as zin:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename.endswith(('.ps1','.txt')):
            text = data.decode('utf-8','replace').replace('\r\n','\n').replace('\n','\r\n')
            data = BOM + text.encode('utf-8')
        patched[info.filename] = data
with zipfile.ZipFile(tmp,'w',zipfile.ZIP_DEFLATED) as zout:
    for fname,data in patched.items(): zout.writestr(fname,data)
os.replace(tmp, src); print("Patched")
```

**BUG-002 — Mode не указан → "Folder Shell\ not found":**
Install-RTMView.ps1 теперь автодетектирует Mode по содержимому папки.
Если всё равно падает — передать `-Mode RTM` явно.

**BUG-003 — CC генерирует Read-Host:**
Пароли должны быть в cc_prompt напрямую как строки. Если CC всё равно просит интерактивный ввод — скажи ему: "Пароль уже в файле cc_prompt_build_rtm.md в шаге 1. Скопируй команду как есть."

**BUG-004 — CC не может запустить Build-ProdRelease.ps1 (нет admin):**
#Requires -RunAsAdministrator убран из build-скрипта. Если снова появилось — убрать.

**BUG-005 — Relative path MemuraiMsi не резолвится:**
Скрипт автоматически резолвит относительный путь через $Root. Передавай как `"tools\cache\Memurai-for-Redis-v4.2.2.msi"`.

Детали всех багов: файл памяти `feedback_prod_release_bugs.md`.
