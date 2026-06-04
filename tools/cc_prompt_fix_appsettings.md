# Fix: RTM appsettings.json — LogConfig path

## Контекст
В `RTM/RTM/appsettings.json` поле `LogConfig` содержит устаревший путь:
  `D:\\IceDash\\Logs\\RTMLogs\\Logs`

Целевая папка установки: `C:\RTMView\RTM` (из Install-RTMView.ps1 $RTMDest).
Логи должны писаться туда же.

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

---

## Шаг 1 — Исправить RTM/RTM/appsettings.json

Python read→modify→write + os.fsync():

```
OLD: "LogConfig": "D:\\IceDash\\Logs\\RTMLogs\\Logs",
NEW: "LogConfig": "C:\\RTMView\\RTM\\Logs",
```

После записи: sync && grep -i "logconfig\|log\|icedash" RTM/RTM/appsettings.json

---

## Шаг 2 — Git commit

```bash
bash tools/pre-commit-check.sh RTM/RTM/appsettings.json

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add RTM/RTM/appsettings.json
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: RTM LogConfig path -> C:\\RTMView\\RTM\\Logs"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Шаг 3 — Resync

```bash
git show HEAD:"RTM/RTM/appsettings.json" > "RTM/RTM/appsettings.json"
echo "Re-synced ($(wc -l < RTM/RTM/appsettings.json) lines)"
sync
```

## Сообщить результат
Хэш коммита + содержимое LogConfig строки после фикса.
