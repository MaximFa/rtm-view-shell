---
name: deploy-shell-connstring-grabli
description: "RTMViewShell 28P01 auth-fail — install never injects the Shell prod conn-string; local pw in appsettings.Development.json"
type: process
updated: 2026-07-02
---

**Грабли (2026-07-02, ~3ч): RTMViewShell как Windows-сервис падает на старте с `Npgsql 28P01: password authentication failed for user "ccdashboard_user"`.**

Корень — НЕ пароль в БД (он верный). `deploy/Install-RTMView.ps1` **не вписывает** DB conn-string в развёрнутый Production-конфиг Shell: `-DBAppPassword` используется ТОЛЬКО в блоке восстановления БД (~L359), пропускаемом при `-SkipDB`. Развёрнутый `C:\RTMView\Shell\appsettings.json` остаётся с `Password=REPLACE_ME` (репо src/CcDashboard.Web/appsettings.json L7). Сервис бежит в **Production** → 28P01.

Настоящий локальный пароль ccdashboard_user = значение в `src/CcDashboard.Web/appsettings.Development.json`. dev-Shell (`dotnet`, Development env) с ним коннектится; сервис (Production) читает appsettings.json — ДРУГОЙ файл.

Быстрый фикс: пропатчить `C:\RTMView\Shell\appsettings.json` REPLACE_ME→реальный пароль + restart RTMViewShell.
Durable (крит. 234): install должен писать ConnectionStrings:Default (из -DBAppPassword) в Production-конфиг НЕЗАВИСИМО от -SkipDB (или env `ConnectionStrings__Default`). Заведено devops. Часть саги «прод-как-сервис»: git-stderr под -Stop, $ScriptDir порядок, Garnet-args (`--recover true`, без `--checkpoint-freq`), conn-string.


**ДОП. ГРАБЛИ (2026-07-02, тоже часы отладки): деплой-конфиг = `appsettings.json`, НЕ `appsettings.Production.json`.**
В этом проекте файла `appsettings.Production.json` НЕТ (проверено: find по репо/publish — пусто). Сервис бежит в Production-окружении, но за отсутствием Production-файла читает базовый `appsettings.json`. Значит install и любые правки деплой-конфига (conn-string, Kestrel/HTTPS, порт/домен/cert) пишутся в `C:\RTMView\Shell\appsettings.json`, а НЕ в `appsettings.Production.json` (запись туда — no-op, приложение её не увидит). НЕ создавать Production-вариант «для чистоты» — это ломает и путает. Только `appsettings.json`.
