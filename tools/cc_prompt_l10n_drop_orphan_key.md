# CC TASK — L10N: снять осиротевший ключ `InfoSlot_ExpiresAt` из `ru-RU`

> Автор: `backend-0919`. На §4 координатора ДО запуска.
> Предмет: `PR234-L10N-KEYLEAK-01`, завершающая единица backend.
> Основание: `shell` починил опечатку в разметке (`d9a0811`), ключ больше никем не зовётся.
> Заказ: `coordinator-0919b` 2026-09-20T07:07:47Z.

## §0.6a INTEGRITY
Проверка по диску и object store, не по докладу инструмента. Счёт строк доказательством не является.
Каждое число — парой «до/после».
**Не сошлось с ожидаемым — `status: failed` с фактическим числом. Переформулировать критерий вместо
остановки ЗАПРЕЩЕНО.**
**Удаление ключа необратимо в смысле экрана: гейт §2 снимается ДО правки и предъявляется.**

## Multi-session sync — MANDATORY
binding: `PR234-L10N-KEYLEAK-01`
Session slug: `backend-0919`
Claims: `src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx` — **ОДИН файл**.

### S1. Push barrier
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; echo "STOP"; exit 1
fi
```
### S2. Claims
```bash
python3 tools/coord_check_claims.py backend-0919 src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
```
### S3. commit.lock вокруг `git add`/`git commit` — форма `tools/cc_prompt_sync_block.md`.
### S4. `bash tools/cc_post_commit.sh backend-0919 $(git log -1 --format=%h)`, затем `sync`.
### S5. НЕ `git push` (§37).

---

## 0. BINDING PREAMBLE — ПЕРВЫМ действием (`.coord/cc/backend.md`)
Python + `os.fsync`, `newline="\n"`, **запись обязана заканчиваться переводом строки** (прецедент
2026-09-19: `RESULT` лёг без `\n`, следующая запись приклеилась бы). После записи предъявить
числом: `CR=0`, последний байт `\n`.
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_l10n_drop_orphan_key.md | status: open
### DIRECTIVE: снять осиротевший ключ InfoSlot_ExpiresAt из SharedResources.ru-RU.resx.
Claim: SharedResources.ru-RU.resx. gate: обращений в коде 0 ДО правки; ru 939 -> 938; ru-en +1 -> 0;
InfoSlot_ExpiresAt 0/0/1 -> 0/0/0; InfoSlots_ExpiresAt 1/1/1 без изменений; parse OK. l10n:.
```

## 1. ЗАМЕР «ДО»
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") \
bad=$(grep -c 'name="InfoSlot_ExpiresAt"' "$F") \
good=$(grep -c 'name="InfoSlots_ExpiresAt"' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
CR_BRANCH=$(git --no-optional-locks show v3:"$F" | grep -c $'\r')"
done
```
**Ожидание:** `en-US keys=938 bad=0 good=1` · `he-IL keys=938 bad=0 good=1` ·
`ru-RU keys=939 bad=1 good=1`; `NUL=0`, `CR_BRANCH=0` во всех трёх. Не сошлось — СТОП.
⚠ CR меряется в ВЕТКЕ: на диске CRLF — норма чекаута (`.gitattributes` + `core.autocrlf=true`).

## 2. ⛔ ГЕЙТ — обращений в коде НОЛЬ. Снять ДО правки, напечатать, и только потом править
```bash
echo "GATE bad_in_code = $(grep -rl --include=*.razor --include=*.cs --include=*.cshtml \
    'InfoSlot_ExpiresAt' src/ 2>/dev/null | wc -l)"
echo "POSCTL good_in_code = $(grep -rl --include=*.razor --include=*.cs \
    'InfoSlots_ExpiresAt' src/ 2>/dev/null | wc -l)"
printf 'InfoSlots_ExpiresAt\n' | grep -c 'InfoSlot_ExpiresAt'   # игла не ловит соседа -> 0
```
**Ожидание: `GATE bad_in_code = 0` · `POSCTL good_in_code = 2` · игла = 0.**
`GATE` не ноль -> **СТОП, ключ не сирота, правку НЕ делать.**
`POSCTL` ноль -> прибор не умеет находить в этой области, его нули не считаются -> СТОП.
[измерено backend-0919 2026-09-20T07:1xZ: GATE=0, POSCTL=2 файла / 3 вхождения, игла=0;
упоминания в `tools/*.md` — это наши промпты, не вызовы.]

## 3. ПРАВКА — удалить РОВНО ОДНУ строку из `ru-RU`
Python + `os.fsync`. НЕ `sed`, НЕ перенабор файла. Удаляемая строка (в ветке — 762-я), дословно:
```
  <data name="InfoSlot_ExpiresAt"><value>Истекает</value></data>
```
Соседи, которые обязаны остаться нетронутыми:
```
  <data name="InfoSlot_NoMessages"><value>Нет сообщений</value></data>
  <data name="InfoSlot_ScrollBehaviour"><value>Поведение прокрутки</value></data>
```
Алгоритм: прочитать файл, найти строки, содержащие `name="InfoSlot_ExpiresAt"`;
**убедиться, что найдена РОВНО ОДНА** (иначе СТОП); удалить её; записать; предъявить:
```
строк до / после  (ожидание: ровно -1)
байт  до / после  (ожидание: -73, длина удалённой строки с переводом)
```
⚠ Игла — `name="InfoSlot_ExpiresAt"` в кавычках: без `name=` и кавычек она поймает
`InfoSlots_ExpiresAt` в соседней строке и удалит ЖИВОЙ ключ.

## 4. ПРИЁМКА
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") \
bad=$(grep -c 'name="InfoSlot_ExpiresAt"' "$F") \
good=$(grep -c 'name="InfoSlots_ExpiresAt"' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F")"
  python3 -c "import xml.etree.ElementTree as E,sys;E.parse(sys.argv[1]);print('  parse OK')" "$F"
done
```
**Годно ТОЛЬКО при всём сразу:**
```
en-US 938 · he-IL 938 · ru-RU 938          (ru ровно -1, остальные НЕ менялись)
разности: he-en = 0 · ru-en = 0             <- впервые полная симметрия
bad  = 0 / 0 / 0
good = 1 / 1 / 1                            (живой ключ на месте во всех трёх)
NUL 0 · parse OK по всем трём
после коммита: CR в ВЕТКЕ = 0 по всем трём
в коммите ОДИН файл, ни одного .razor, 1 удаление, 0 вставок
```

## 5. ГРАНИЦЫ
- Только `ru-RU`, только этот один ключ. `en-US` и `he-IL` НЕ трогать вовсе.
- `InfoSlots_ExpiresAt` (мн. ч.) НЕ трогать ни в одном словаре — это живой ключ, 3 вызова в коде.
- Ни одного `.razor`. Разметку правит shell, она уже починена.
- Пары из бэклога (`Report_Title`/`Reports_Title`, `InfoSlot(s)_DisplayMode`,
  `InfoSlot(s)_SecondsPerMessage`) НЕ трогать.
- `NO push`.

## 6. КОММИТ
```bash
git add -- "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): drop orphaned InfoSlot_ExpiresAt from ru-RU" \
           -m "markup typo fixed in d9a0811, key no longer referenced (0 in code); ru 939 -> 938; dictionaries now symmetric 938/938/938; InfoSlots_ExpiresAt untouched 1/1/1" \
           -- "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
После коммита сверить блоб файла с хешем на диске.

## 7. BINDING POSTAMBLE / RESULT — ПОСЛЕДНИМ действием (`.coord/cc/backend.md`)
Тем же способом, что преамбула, **с переводом строки в конце**:
```
### RESULT: commit <hash> . file SharedResources.ru-RU.resx (-1 key InfoSlot_ExpiresAt)
. GATE bad_in_code = <факт> (снят ДО правки) . keys ru 939 -> <факт> . he-en=<факт> ru-en=<факт>
. bad <факт>/<факт>/<факт> . good <факт>/<факт>/<факт> . NUL 0 . CR в ветке 0 . parse OK x3
. status done|failed . verified: object-store
<фактический вывод замера ПОСЛЕ>
```
Затем двухстрочный дайджест в `.coord/inbox/coordinator.md` — тем же способом, с `\n` в конце,
и предъявить `CR=0`.

> Пункта «подписей ассистента 0» здесь НЕТ намеренно: коммит делает прогон, среда прогона
> дописывает подпись сама, и такая проверка пройти не может.
