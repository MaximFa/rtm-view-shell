# CC TASK — L10N: завести 19 ключей редактора экранов в три словаря

> Автор: `backend-0919`. §4 координатора получен 2026-09-20T10:22:34Z — материал подтверждён.
> Предмет: `PR234-L10N-KEYLEAK-01`, шаг 1 из 2 (шаг 2 — правка разметки, делает `shell`, ПОСЛЕ нас).
> Материал: `.coord/l10n_screeneditor_terms.md` (блоб `070f34ee`, 9185 B — координатор исправил
> свой же устаревший пин и подтвердил) и `.coord/l10n_screeneditor_translations.md`.
> **Придумывать нечего: все 57 строк даны в §3 дословно. Работа — вставить их, а не сочинить.**

## §0.6a INTEGRITY
Проверка по object store, не по докладу инструмента. Счёт строк доказательством не является.
Каждое число — парой «до/после». Всё меряется в ВЕТКЕ (`git show v3:`), не на диске:
на диске CRLF — норма чекаута (`.gitattributes` + `core.autocrlf=true`).

### §0.6b ФОРМА ОСТАНОВКИ — ПРЕДИКАТ, А НЕ ПРОЗА
```bash
chk(){ # chk "<имя>" "<ожидаемое>" "<фактическое>"
  if [ "$2" = "$3" ]; then echo "OK   $1: exp=$2 got=$3"
  else echo "STOP $1: exp=$2 got=$3"; fi; }
```
**Напечатано хоть одно `STOP` — правка и коммит НЕ делаются, `status: failed`, фактическое число
в `RESULT`. Переформулировать критерий под факт ЗАПРЕЩЕНО.**
**В `RESULT` обязана быть строка `STOP-предикат: <N> критериев, STOP=<M>`.** Нет строки —
единица не сдана независимо от остального.
Форма держала на `0f969d8` (24 критерия, STOP=0). Её отрицательная половина — САМОПРОВЕРКА §1.

## Multi-session sync — MANDATORY
binding: `PR234-L10N-KEYLEAK-01`
Session slug: `backend-0919`
Claims: три файла `SharedResources.{en-US,he-IL,ru-RU}.resx` — и НИЧЕГО больше.

### S1. Push barrier
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

## 0. BINDING PREAMBLE — ПЕРВЫМ действием (`.coord/cc/backend.md`)
Python + `os.fsync`, `newline="\n"`, **запись обязана заканчиваться переводом строки**.
Метку времени СНЯТЬ командой `date -u` и вставить из вывода. Форма «10:3xZ» с иксом —
подделка, а не сокращение.
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_l10n_screeneditor_19.md | status: open
### DIRECTIVE: завести 19 новых ключей редактора экранов в en-US/he-IL/ru-RU.
Claim: три .resx. gate: все 19 отсутствуют 0/0/0 ДО правки; 938/938/938 -> 957/957/957;
каждое имя 1/1/1; he-en=0 ru-en=0; BOM 0 x3; CR в ветке 0; parse OK x3. l10n:.
```

## 1. ЗАМЕР «ДО» — через предикат §0.6b
```bash
blob(){ git --no-optional-locks show v3:"$1"; }
EN=src/CcDashboard.Web/Resources/SharedResources.en-US.resx
HE=src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
RU=src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
for P in "$EN" "$HE" "$RU"; do
  chk "keys ДО $P" "938" "$(blob "$P" | grep -c '<data name=')"
  chk "CR ДО $P"   "0"   "$(blob "$P" | grep -c $'\r')"
done
python3 -c "
import subprocess
for l in ('en-US','he-IL','ru-RU'):
    p='src/CcDashboard.Web/Resources/SharedResources.'+l+'.resx'
    b=subprocess.check_output(['git','--no-optional-locks','show','v3:'+p])
    print('BOM ДО',l,'=',b.count(b'\xef\xbb\xbf'),'(ожидание 0)')
"
chk "САМОПРОВЕРКА прибора" "938" "0"
```
Последняя строка ОБЯЗАНА напечатать `STOP` — это отрицательная половина прибора. Её `STOP`
в счёт §0.6b не идёт и объявляется отдельно: `самопроверка: STOP получен`.
Прибор, не умеющий вернуть красное, проверкой не является.

## 2. ⛔ ГЕЙТ — все 19 имён отсутствуют, четыре соседних существуют. Снять ДО правки
```bash
python3 - <<'PYGATE'
import subprocess
NEW = ['Common_Auto', 'Common_MoveUp', 'Common_MoveDown', 'Common_Default', 'Common_NoMatches', 'Screens_SaveAsTemplate', 'Screens_DeleteTemplate', 'Screens_TemplateName', 'Screens_TemplateNamePlaceholder', 'Screens_NoBusinessUnits', 'Screens_SelectBusinessUnitPlaceholder', 'Screens_ValuePlaceholder', 'Screens_ColumnQueueName', 'Screens_RemoveColumn', 'Screens_RemoveRow', 'Screens_NoColumnsYet', 'Screens_NoRowsYet', 'Screens_NoFilterConditions', 'Screens_NoFilterConditionsHint']
OLD = ["Widgets_BusinessUnit","WidgetCfg_Colors","Common_Cancel","Common_Delete"]
L = ("en-US","he-IL","ru-RU")
B = {}
for l in L:
    p = "src/CcDashboard.Web/Resources/SharedResources." + l + ".resx"
    B[l] = subprocess.check_output(["git","--no-optional-locks","show","v3:"+p]).decode("utf-8")
def cnt(k): return [B[l].count('name="' + k + '"') for l in L]
bad  = [(k,cnt(k)) for k in NEW if cnt(k) != [0,0,0]]
bad2 = [(k,cnt(k)) for k in OLD if cnt(k) != [1,1,1]]
print("GATE новых, которые уже есть:", bad if bad else "пусто")
print("GATE четырёх существующих не 1/1/1:", bad2 if bad2 else "пусто")
print("POSCTL Screens_Title:", cnt("Screens_Title"))
print("NEGCTL ZZZ_Not_A_Key:", cnt("ZZZ_Not_A_Key"))
print("имён в списке:", len(NEW), "уникальных:", len(set(NEW)))
PYGATE
```
**Ожидание: обе строки `пусто` · `POSCTL [1, 1, 1]` · `NEGCTL [0, 0, 0]` · `19 / 19`.**
`GATE новых` не пусто — **СТОП**: ключ уже есть, вставка сделала бы дубль в словаре.
`POSCTL` не `[1, 1, 1]` — прибор не умеет находить в этой области, его нули не считаются, **СТОП**.

## 3. ПРАВКА — вставить дословно, в КОНЕЦ, перед `</root>`
Решение координатора 10:22:34Z: словари не отсортированы, «правильного места» не существует,
поэтому — в конец единым блоком, как легли четыре ключа в `c6ba1b2`. Место НЕ выбирать самому.

Формат строки: два пробела отступа, один ключ — одна строка, без пустых строк между.
Python + `os.fsync`, `newline="\n"`, с явным `encoding="utf-8"`.
Алгоритм: прочитать файл, найти **последнее** вхождение `</root>`, вставить блок перед ним,
записать. НЕ `sed`, НЕ перенабор файла, НЕ переформатирование, НЕ смена кодировки.

⚠ Писать так, чтобы не появился BOM и не появились CR. Оба дефекта мы ловили сегодня:
BOM внесён в `7d67148`, снят в `0f969d8`. Гейт, который однажды сработал, снимается каждый раз.

### en-US — 19 строк
```xml
  <data name="Common_Auto"><value>Auto</value></data>
  <data name="Common_MoveUp"><value>Move up</value></data>
  <data name="Common_MoveDown"><value>Move down</value></data>
  <data name="Common_Default"><value>Default</value></data>
  <data name="Common_NoMatches"><value>No matches</value></data>
  <data name="Screens_SaveAsTemplate"><value>Save as Template</value></data>
  <data name="Screens_DeleteTemplate"><value>Delete Template</value></data>
  <data name="Screens_TemplateName"><value>Template Name</value></data>
  <data name="Screens_TemplateNamePlaceholder"><value>Enter template name...</value></data>
  <data name="Screens_NoBusinessUnits"><value>No Business Units available</value></data>
  <data name="Screens_SelectBusinessUnitPlaceholder"><value>Select Business Unit...</value></data>
  <data name="Screens_ValuePlaceholder"><value>Value...</value></data>
  <data name="Screens_ColumnQueueName"><value>Queue Name</value></data>
  <data name="Screens_RemoveColumn"><value>Remove column</value></data>
  <data name="Screens_RemoveRow"><value>Remove row</value></data>
  <data name="Screens_NoColumnsYet"><value>No columns defined yet.</value></data>
  <data name="Screens_NoRowsYet"><value>No rows defined yet.</value></data>
  <data name="Screens_NoFilterConditions"><value>No filter conditions defined.</value></data>
  <data name="Screens_NoFilterConditionsHint"><value>Add conditions to filter rows before display.</value></data>
```
### he-IL — 19 строк
```xml
  <data name="Common_Auto"><value>אוטומטי</value></data>
  <data name="Common_MoveUp"><value>הזז למעלה</value></data>
  <data name="Common_MoveDown"><value>הזז למטה</value></data>
  <data name="Common_Default"><value>ברירת מחדל</value></data>
  <data name="Common_NoMatches"><value>אין התאמות</value></data>
  <data name="Screens_SaveAsTemplate"><value>שמור כתבנית</value></data>
  <data name="Screens_DeleteTemplate"><value>מחק תבנית</value></data>
  <data name="Screens_TemplateName"><value>שם התבנית</value></data>
  <data name="Screens_TemplateNamePlaceholder"><value>הזן שם תבנית...</value></data>
  <data name="Screens_NoBusinessUnits"><value>אין יחידות עסקיות זמינות</value></data>
  <data name="Screens_SelectBusinessUnitPlaceholder"><value>בחר יחידה עסקית...</value></data>
  <data name="Screens_ValuePlaceholder"><value>ערך...</value></data>
  <data name="Screens_ColumnQueueName"><value>שם התור</value></data>
  <data name="Screens_RemoveColumn"><value>הסר עמודה</value></data>
  <data name="Screens_RemoveRow"><value>הסר שורה</value></data>
  <data name="Screens_NoColumnsYet"><value>לא הוגדרו עמודות עדיין.</value></data>
  <data name="Screens_NoRowsYet"><value>לא הוגדרו שורות עדיין.</value></data>
  <data name="Screens_NoFilterConditions"><value>לא הוגדרו תנאי סינון.</value></data>
  <data name="Screens_NoFilterConditionsHint"><value>הוסף תנאים לסינון שורות לפני התצוגה.</value></data>
```
### ru-RU — 19 строк
```xml
  <data name="Common_Auto"><value>Авто</value></data>
  <data name="Common_MoveUp"><value>Переместить вверх</value></data>
  <data name="Common_MoveDown"><value>Переместить вниз</value></data>
  <data name="Common_Default"><value>По умолчанию</value></data>
  <data name="Common_NoMatches"><value>Нет совпадений</value></data>
  <data name="Screens_SaveAsTemplate"><value>Сохранить как шаблон</value></data>
  <data name="Screens_DeleteTemplate"><value>Удалить шаблон</value></data>
  <data name="Screens_TemplateName"><value>Название шаблона</value></data>
  <data name="Screens_TemplateNamePlaceholder"><value>Введите название шаблона...</value></data>
  <data name="Screens_NoBusinessUnits"><value>Нет доступных подразделений</value></data>
  <data name="Screens_SelectBusinessUnitPlaceholder"><value>Выберите подразделение...</value></data>
  <data name="Screens_ValuePlaceholder"><value>Значение...</value></data>
  <data name="Screens_ColumnQueueName"><value>Название очереди</value></data>
  <data name="Screens_RemoveColumn"><value>Удалить столбец</value></data>
  <data name="Screens_RemoveRow"><value>Удалить строку</value></data>
  <data name="Screens_NoColumnsYet"><value>Столбцы ещё не заданы.</value></data>
  <data name="Screens_NoRowsYet"><value>Строки ещё не заданы.</value></data>
  <data name="Screens_NoFilterConditions"><value>Условия фильтра не заданы.</value></data>
  <data name="Screens_NoFilterConditionsHint"><value>Добавьте условия, чтобы отфильтровать строки перед показом.</value></data>
```
Предъявить парой по каждому файлу: `строк до / после` (ожидание ровно `+19`) и `байт до / после`.

## 4. ПРИЁМКА — через предикат §0.6b, после коммита, по ВЕТКЕ
```bash
for P in "$EN" "$HE" "$RU"; do
  chk "keys ПОСЛЕ $P" "957" "$(blob "$P" | grep -c '<data name=')"
  chk "CR ПОСЛЕ $P"   "0"   "$(blob "$P" | grep -c $'\r')"
  chk "NUL $P" "0" "$(python3 -c "print(open('$P','rb').read().count(b'\x00'))")"
  python3 -c "import xml.etree.ElementTree as E;E.parse('$P');print('parse OK $P')"
done
chk "файлов в коммите" "3" "$(git --no-optional-locks show --format= --name-only HEAD | sed '/^$/d' | wc -l)"
chk ".razor в коммите" "0" "$(git --no-optional-locks show --format= --name-only HEAD | grep -c 'razor')"
```
Плюс тем же скриптом, что в §2: **каждое из 19 имён = `1/1/1`**, `NEGCTL ZZZ_Not_A_Key` = `0/0/0`,
четыре существующих по-прежнему `1/1/1` (не продублированы), `BOM = 0` во всех трёх.
И образец значений: `Common_Auto` = `Auto` / `אוטומטי` / `Авто` — доказывает, что языки не
перепутаны местами.
**Годно ТОЛЬКО когда `STOP` не напечатан ни разу**, кроме объявленной самопроверки §1.

## 5. ГРАНИЦЫ
- Только три `.resx`. **Ни одного `.razor`** — разметку правит `shell` следующей единицей.
  `L[` на несуществующий ключ показывает на экране имя ключа: обратный порядок завёл бы KEYLEAK.
- Четыре существующих ключа (`Widgets_BusinessUnit`, `WidgetCfg_Colors`, `Common_Cancel`,
  `Common_Delete`) НЕ заводить и НЕ трогать.
- Пары-дубли из бэклога (`InfoSlot_`/`InfoSlots_DisplayMode`, `SecondsPerMessage`) не трогать.
  `Report_Title` / `Reports_Title` — **ловушка: они разные по смыслу**, не сливать.
- Существующие 938 ключей не переставлять, не сортировать, не переформатировать.
- `NO push`.

## 6. КОММИТ
```bash
git add -- \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): add 19 screen-editor keys to all three dictionaries" \
           -m "names and translations taken verbatim from .coord/l10n_screeneditor_terms.md (070f34ee) and l10n_screeneditor_translations.md; 938 -> 957 in each file, symmetry preserved; markup is NOT touched here - ScreenEditorPage.razor is a separate unit by shell, in that order so no L[] ever points at a missing key" \
           -- \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
После коммита сверить блоб каждого файла с `git hash-object` того же файла на диске.

## 7. BINDING POSTAMBLE / RESULT — ПОСЛЕДНИМ действием (`.coord/cc/backend.md`)
Тем же способом, что преамбула, с переводом строки в конце:
```
### RESULT: commit <hash> . files en-US/he-IL/ru-RU .resx (+19 keys each)
. keys 938/938/938 -> <факт>/<факт>/<факт> . he-en=<факт> ru-en=<факт>
. все 19 имён 1/1/1: <да|нет, с перечнем расхождений> . NEGCTL ZZZ_Not_A_Key 0/0/0
. четыре существующих по-прежнему 1/1/1 . BOM 0 x3 . CR в ветке 0 x3 . NUL 0 x3 . parse OK x3
. файлов в коммите <факт> . .razor в коммите <факт>
. самопроверка: STOP получен . STOP-предикат: <N> критериев, STOP=<M>
. status done|failed . verified: object-store
<фактический вывод замера ПОСЛЕ>
```
Затем двухстрочный дайджест в `.coord/inbox/coordinator.md` — тем же способом, с `\n` в конце.

## Приложение: 19 имён, по которым сверяется приёмка
```
   1. Common_Auto
   2. Common_MoveUp
   3. Common_MoveDown
   4. Common_Default
   5. Common_NoMatches
   6. Screens_SaveAsTemplate
   7. Screens_DeleteTemplate
   8. Screens_TemplateName
   9. Screens_TemplateNamePlaceholder
  10. Screens_NoBusinessUnits
  11. Screens_SelectBusinessUnitPlaceholder
  12. Screens_ValuePlaceholder
  13. Screens_ColumnQueueName
  14. Screens_RemoveColumn
  15. Screens_RemoveRow
  16. Screens_NoColumnsYet
  17. Screens_NoRowsYet
  18. Screens_NoFilterConditions
  19. Screens_NoFilterConditionsHint
```

> Пункта «подписей ассистента 0» здесь НЕТ намеренно: коммит делает прогон, среда прогона
> дописывает подпись сама, и такая проверка пройти не может.
