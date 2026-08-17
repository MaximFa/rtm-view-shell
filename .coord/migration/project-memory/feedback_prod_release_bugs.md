---
name: prod-release-bugs
description: "Known bugs and fixes for prod-release packaging workflow (Build-ProdRelease.ps1, Install-RTMView.ps1)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cbc0c0e4-5dd0-4745-8a2e-6630ecf10159
---

# Prod Release — баги и фиксы

**Why:** Выявлены при первом тестовом прогоне (2026-06-01). Повторяются при каждой сборке если не учитывать.

## BUG-001 — LF endings + no BOM → PowerShell parser crash (КРИТИЧНЫЙ)
**Симптом:** `Unexpected token '}'` / `Missing closing '}'` при запуске PS1 на Windows сервере.
**Причина:** Файлы .ps1/.txt создаются на Linux (LF, без BOM). Windows PowerShell требует CRLF + UTF-8 BOM.
**Как применить:** ВСЕГДА перед упаковкой в zip конвертировать PS1 и TXT:
```python
BOM = b'\xef\xbb\xbf'
text = open(f).read().replace('\r\n','\n').replace('\n','\r\n')
data = BOM + text.encode('utf-8')
```
Build-ProdRelease.ps1 уже содержит PowerShell-версию этой конвертации в секции ZIP.
Для патча существующего zip — см. prod-release SKILL.md секция "Patch existing zip".

## BUG-002 — #Requires -RunAsAdministrator в build-скрипте
**Симптом:** CC не может запустить Build-ProdRelease.ps1 (нет admin прав у CC).
**Фикс:** Строка удалена. Admin нужен ТОЛЬКО Install-RTMView.ps1 (sc.exe, Start-Service).

## BUG-003 — Read-Host в build-скрипте
**Симптом:** Скрипт зависает в неинтерактивном режиме (CC, CI, scheduled tasks).
**Фикс:** Read-Host полностью удалён из Build-ProdRelease.ps1. Заменён на Write-Error.

## BUG-004 — Относительный путь -MemuraiMsi не резолвится
**Симптом:** "Memurai MSI not found" хотя файл `tools\cache\Memurai-for-Redis-v4.2.2.msi` существует.
**Причина:** `Test-Path` зависит от текущей директории, а не от расположения скрипта.
**Фикс:** В Build-ProdRelease.ps1 добавлена авторезолюция: `if (-not [IO.Path]::IsPathRooted($MemuraiMsi)) { $MemuraiMsi = Join-Path $Root $MemuraiMsi }`.

## BUG-005 — CC генерирует Read-Host несмотря на запрет в промпте
**Симптом:** CC предлагает пользователю самому запустить команды с Read-Host или открыть отдельный терминал.
**Фикс:** Пароль захардкожен напрямую в `tools/cc_prompt_build_rtm.md`. После смены пароля обновить файл.

## BUG-006 — Реальное имя Memurai MSI
Файл называется `Memurai-for-Redis-v4.2.2.msi`, не `memurai-developer.msi`.
В cc_prompt и при вызове Build-ProdRelease.ps1 передавать явно: `-MemuraiMsi "tools\cache\Memurai-for-Redis-v4.2.2.msi"`.

## Итоговые правила для будущих сборок
1. После любого изменения deploy/*.ps1 — пересобрать zip (не патчить вручную).
2. Верификация zip перед передачей: BOM=True, CRLF=True (см. Step 6 в SKILL.md).
3. CC не может запускать скрипты требующие admin или интерактивный ввод — использовать cc_prompt с захардкоженными параметрами.
4. Сборка (dotnet publish) должна выполняться на Windows через CC или вручную.
