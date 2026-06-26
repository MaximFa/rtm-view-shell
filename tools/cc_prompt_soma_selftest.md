# CC-задача: self-test панели Soma (ТОЛЬКО ЧТЕНИЕ, без изменений)

## Назначение
Проверка сквозного запуска через панель Soma: панель → /cc/run → `claude` headless → лог → бейдж ✅.
Эта задача НИЧЕГО НЕ МЕНЯЕТ — она нужна только чтобы убедиться, что цепочка работает.

## ЖЁСТКИЕ ОГРАНИЧЕНИЯ
- НЕ изменяй ни одного файла. НЕ создавай и НЕ удаляй файлов.
- НЕ выполняй `git add` / `git commit` / `git push`.
- Только чтение и вывод в stdout.

## Задача
1. Выведи текущий UTC-таймстамп.
2. Подтверди, что можешь прочитать `tools/Soma/Program.cs`, и выведи число строк в нём (`wc -l`).
3. Выведи строку: `Soma panel self-test OK`.

## В САМОМ конце — RESULT-блок в stdout:
```
RESULT: status=done · files changed=none · commits=none · build/test=skipped (read-only self-test) · blockers=none
```
