# CC TASK — L10N: четыре недостающих ключа в три `.resx`

> Автор промпта: `backend-0919`. На §4 координатора ДО запуска.
> Предмет: `PR234-L10N-KEYLEAK-01`, единица backend. Решение по пятому ключу — вариант (а),
> `InfoSlot_ExpiresAt` в словари НЕ заводится (правит разметку `shell`).
> Источник заказа: `coordinator-0919b` 2026-09-19T23:12:39Z в `.coord/inbox/backend.md`.

## §0.6a INTEGRITY
Любое «сделано» проверяется по диску и object store, не по докладу инструмента.
Счёт строк доказательством не является. Каждое число предъявляется парой «до/после».
**Если измеренное не сошлось с ожидаемым — `status: failed` с фактическим числом. Переформулировать
критерий вместо остановки ЗАПРЕЩЕНО** (прецедент 19.09: прогон заменил числовой критерий словами
«CRLF (Windows standard)» и поставил `done`).

## Multi-session sync — MANDATORY, NO EXCEPTIONS
binding: `PR234-L10N-KEYLEAK-01`
Session slug: `backend-0919`
Claims: `src/CcDashboard.Web/Resources/SharedResources.en-US.resx`,
`src/CcDashboard.Web/Resources/SharedResources.he-IL.resx`,
`src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx`

### S1. Push barrier — before ANY work
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; echo "STOP"; exit 1
fi
```
### S2. Claims
```bash
python3 tools/coord_check_claims.py backend-0919 \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
```
### S3. commit.lock вокруг `git add`/`git commit` — форма `tools/cc_prompt_sync_block.md`.
### S4. `bash tools/cc_post_commit.sh backend-0919 $(git log -1 --format=%h)`, затем `sync`.
### S5. НЕ `git push` (§37).

---

## 0. BINDING PREAMBLE — ПЕРВЫМ действием (`.coord/cc/backend.md`, Python + os.fsync, newline="\n")
Дописать в конец, не перезаписывая:
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_l10n_four_missing_keys.md | status: open
### DIRECTIVE: четыре ключа, спрошенных разметкой и отсутствующих в словарях: Common_View,
Reports_Edit, UnknownWidget, View -> en-US/he-IL/ru-RU.
gate: 934/934/935 -> 938/938/939, каждое имя 1/1/1, NEGCTL 0/0/0, целостность, parse OK. l10n:.
```
**Любая запись в `.coord/**` — Python + `os.fsync`, `newline="\n"`, затем предъявить `CR=0` числом.**
Дайджест в конце — тем же способом. (Прецедент 19.09: прогон внёс три CRLF в шину.)

## 1. ЗАМЕР «ДО»
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
FFFD=$(grep -c $'\xef\xbf\xbd' "$F") \
CR_BRANCH=$(git --no-optional-locks show v3:"$F" | grep -c $'\r')"
done
```
**Ожидание:** `en-US 934 · he-IL 934 · ru-RU 935`; `NUL=0`, `FFFD=0`, `CR_BRANCH=0` во всех трёх.
⚠ CR меряется **в ветке**, не на диске: на диске CRLF — это норма чекаута (`.gitattributes`
`* text=auto eol=lf` + `core.autocrlf=true`), и число на диске к правке отношения не имеет.
Не сошлось — СТОП.

## 2. ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА — по ЭТИМ именам
```bash
for K in Common_View Reports_Edit UnknownWidget View; do
  for L in en-US he-IL ru-RU; do
    printf "%s %s = %s\n" "$K" "$L" \
      "$(grep -c "name=\"$K\"" src/CcDashboard.Web/Resources/SharedResources.$L.resx)"
  done
done
for L in en-US he-IL ru-RU; do
  printf "NEGCTL ZZZ_Not_A_Key %s = %s\n" "$L" \
    "$(grep -c 'name="ZZZ_Not_A_Key"' src/CcDashboard.Web/Resources/SharedResources.$L.resx)"
done
grep -c 'name="Common_Close"' src/CcDashboard.Web/Resources/SharedResources.en-US.resx   # POSCTL -> 1
```
**Ожидание: 12 нулей по четырём именам, NEGCTL 0/0/0, POSCTL 1.**
⚠ Игла `name="View"` — в кавычках и с `name=`, иначе матчит `PG_ColView`, `View_ScaleMode_*`,
`InfoSlots_ViewerTitle` и даёт ложно-ненулевое.

## 3. ПРАВКА — четыре строки в каждый файл, ПЕРЕД `</root>`
Формат как у соседей: два пробела отступа, один `<data>` в строке, без `xml:space`.
Python + `os.fsync`; НЕ `sed`, НЕ перенабор файла.

**en-US:**
```xml
  <data name="Common_View"><value>View</value></data>
  <data name="Reports_Edit"><value>Edit Report</value></data>
  <data name="UnknownWidget"><value>Unknown widget</value></data>
  <data name="View"><value>View</value></data>
```
**he-IL:**
```xml
  <data name="Common_View"><value>צפייה</value></data>
  <data name="Reports_Edit"><value>עריכת דוח</value></data>
  <data name="UnknownWidget"><value>ווידג'ט לא מוכר</value></data>
  <data name="View"><value>צפייה</value></data>
```
**ru-RU:**
```xml
  <data name="Common_View"><value>Просмотр</value></data>
  <data name="Reports_Edit"><value>Редактирование отчёта</value></data>
  <data name="UnknownWidget"><value>Неизвестный виджет</value></data>
  <data name="View"><value>Просмотр</value></data>
```
⚠ Копировать ПОБАЙТОВО. В `he` апостроф в `ווידג'ט` — обычный ASCII `'`, как в существующем
`Widgets_Name` = `שם הווידג'ט`; НЕ типографский `’`. В `ru` буква «ё» в «отчёта» — намеренно,
словарь держит `Отчёты` через «ё».

## 4. ПРИЁМКА
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
FFFD=$(grep -c $'\xef\xbf\xbd' "$F")"
  python3 -c "import xml.etree.ElementTree as E,sys;E.parse(sys.argv[1]);print('  parse OK')" "$F"
done
for K in Common_View Reports_Edit UnknownWidget View; do
  for L in en-US he-IL ru-RU; do
    printf "%s %s = %s\n" "$K" "$L" \
      "$(grep -c "name=\"$K\"" src/CcDashboard.Web/Resources/SharedResources.$L.resx)"
  done
done
```
**Годно ТОЛЬКО при всём сразу:**
```
en-US 938 · he-IL 938 · ru-RU 939        (ровно +4 в каждом)
разности: he-en = 0 · ru-en = +1          как было
каждое из четырёх имён = 1 в каждом из трёх   (не 0 и не 2)
NUL 0 · FFFD 0 · parse OK по всем трём
после коммита: CR в ВЕТКЕ = 0 по всем трём
```

## 5. ГРАНИЦЫ
- Только эти четыре ключа и только эти три файла.
- **`InfoSlot_ExpiresAt` НЕ заводить** — решение координатора, вариант (а); его правит shell в разметке.
- **`InfoSlot_ExpiresAt` в `ru-RU` НЕ удалять** — пока разметка его зовёт, он не сирота. Отдельная единица.
- Ни одного `.razor` в коммите. Разметку правит shell.
- `Report_Title` / `Reports_Title`, `InfoSlot(s)_DisplayMode`, `InfoSlot(s)_SecondsPerMessage` НЕ трогать — бэклог.
- `Common_Save` НЕ трогать.
- `NO push`.

## 6. КОММИТ
```bash
git add -- "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
           "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
           "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): add 4 keys requested by markup but missing from dictionaries" \
           -m "Common_View, Reports_Edit, UnknownWidget, View; keys 934/934/935 -> 938/938/939; he-en=0 ru-en=+1 unchanged; parse OK x3" \
           -- "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
              "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
              "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
После коммита сверить блоб каждого файла с хешем на диске.

## 7. BINDING POSTAMBLE / RESULT — ПОСЛЕДНИМ действием (`.coord/cc/backend.md`)
```
### RESULT: commit <hash> . files SharedResources.en-US/he-IL/ru-RU.resx (+4 keys)
. keys 934/934/935 -> <факт>/<факт>/<факт> . he-en=<факт> ru-en=<факт>
. Common_View/Reports_Edit/UnknownWidget/View = <факт> в каждом . NUL/FFFD 0 . CR в ветке 0
. parse OK x3 . status done|failed . verified: object-store
<фактический вывод замера ПОСЛЕ>
```
Числа — из СВОЕГО вывода. Затем двухстрочный дайджест в `.coord/inbox/coordinator.md`
(Python + fsync, `newline="\n"`, предъявить `CR=0`).

> Пункта «подписей ассистента 0» здесь НЕТ намеренно: коммит делает прогон, среда прогона
> дописывает подпись сама, и такая проверка пройти не может.
