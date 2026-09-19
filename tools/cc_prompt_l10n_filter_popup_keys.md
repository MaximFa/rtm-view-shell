# CC TASK — L10N: девять ключей фильтр-попапа в три `.resx`

> Автор промпта: `backend-0919`. На §4 координатора ДО запуска.
> Предмет: `PR234-L10N-FILTERPOPUP-KEYS`. Источник имён и значений — единственный:
> блок `coordinator-0919b` от 19.09 19:2xZ в `.coord/inbox/backend.md` (финальный список).

## §0.6a INTEGRITY
Любое «сделано» проверяется по диску и object store, не по докладу инструмента.
Счёт строк доказательством не является. Каждое число предъявляется парой «до/после».

## Multi-session sync — MANDATORY, NO EXCEPTIONS
binding: `PR234-L10N-FILTERPOPUP-KEYS`
Session slug: `backend-0919`
Claims for this task: `src/CcDashboard.Web/Resources/SharedResources.en-US.resx`,
`src/CcDashboard.Web/Resources/SharedResources.he-IL.resx`,
`src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx`

### S1. Push barrier check — before ANY work
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py backend-0919 \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
```
Трогать ТОЛЬКО эти три файла. Нужен файл вне claims — СТОП и доклад.

### S3. Commit lock — around EVERY git add/commit
Взять `.coord/locks/commit.lock` по форме `tools/cc_prompt_sync_block.md` (phantom-aware),
держать на время `git add` + `git commit`, не удалять чужой лок.

### S4. Post-commit
`bash tools/cc_post_commit.sh backend-0919 $(git log -1 --format=%h)`, затем `sync`.

### S5. НЕ `git push` (§37).

---

## 1. ЗАМЕР «ДО» — снять ПЕРВЫМ, до единой правки, и напечатать
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") bytes=$(wc -c <"$F") \
CR=$(grep -c $'\r' "$F") NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
FFFD=$(grep -c $'\xef\xbf\xbd' "$F")"
done
```
**Ожидание [измерено backend-0919 19.09 15:37Z]:**
```
en-US keys=924   he-IL keys=924   ru-RU keys=925
CR=0 · NUL=0 · FFFD=0 — во всех трёх
```
Не сошлось хоть одно — СТОП, не править: файл изменился с момента замера.

## 2. ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА — снять ДО правки и напечатать
```bash
for K in Widgets_MatchType_LessThan Widgets_MatchType_LessOrEqual \
         Widgets_MatchType_GreaterThan Widgets_MatchType_GreaterOrEqual \
         Common_Apply Widgets_Filter_List Widgets_Filter_SelectValues \
         Widgets_Filter_ValuePlaceholder Widgets_Filter_TimePlaceholder; do
  for L in en-US he-IL ru-RU; do
    printf "%s %s %s\n" "$K" "$L" \
      "$(grep -c "name=\"$K\"" src/CcDashboard.Web/Resources/SharedResources.$L.resx)"
  done
done
grep -c 'name="Common_Save"' src/CcDashboard.Web/Resources/SharedResources.en-US.resx   # POSCTL -> 1
```
**Ожидание: все 27 значений = 0, POSCTL = 1.** Ненулевое -> СТОП: ключ уже есть, доклад.

## 3. ПРАВКА — девять строк в каждый из трёх файлов, ПЕРЕД `</root>`
Формат строки — ровно как у соседей: два пробела отступа, один `<data>` в строке, без `xml:space`.
Вставлять Python + `os.fsync`, НЕ `sed`, НЕ ручным перенабором файла.

**en-US:**
```xml
  <data name="Widgets_MatchType_LessThan"><value>Less Than</value></data>
  <data name="Widgets_MatchType_LessOrEqual"><value>Less Or Equal</value></data>
  <data name="Widgets_MatchType_GreaterThan"><value>Greater Than</value></data>
  <data name="Widgets_MatchType_GreaterOrEqual"><value>Greater Or Equal</value></data>
  <data name="Common_Apply"><value>Apply</value></data>
  <data name="Widgets_Filter_List"><value>List</value></data>
  <data name="Widgets_Filter_SelectValues"><value>Select values...</value></data>
  <data name="Widgets_Filter_ValuePlaceholder"><value>Filter value...</value></data>
  <data name="Widgets_Filter_TimePlaceholder"><value>e.g. 30:00</value></data>
```

**he-IL:**
```xml
  <data name="Widgets_MatchType_LessThan"><value>קטן מ</value></data>
  <data name="Widgets_MatchType_LessOrEqual"><value>קטן או שווה</value></data>
  <data name="Widgets_MatchType_GreaterThan"><value>גדול מ</value></data>
  <data name="Widgets_MatchType_GreaterOrEqual"><value>גדול או שווה</value></data>
  <data name="Common_Apply"><value>החל</value></data>
  <data name="Widgets_Filter_List"><value>רשימה</value></data>
  <data name="Widgets_Filter_SelectValues"><value>בחר ערכים...</value></data>
  <data name="Widgets_Filter_ValuePlaceholder"><value>ערך לסינון...</value></data>
  <data name="Widgets_Filter_TimePlaceholder"><value>לדוגמה 30:00</value></data>
```

**ru-RU:**
```xml
  <data name="Widgets_MatchType_LessThan"><value>Меньше</value></data>
  <data name="Widgets_MatchType_LessOrEqual"><value>Меньше или равно</value></data>
  <data name="Widgets_MatchType_GreaterThan"><value>Больше</value></data>
  <data name="Widgets_MatchType_GreaterOrEqual"><value>Больше или равно</value></data>
  <data name="Common_Apply"><value>Применить</value></data>
  <data name="Widgets_Filter_List"><value>Список</value></data>
  <data name="Widgets_Filter_SelectValues"><value>Выберите значения...</value></data>
  <data name="Widgets_Filter_ValuePlaceholder"><value>Значение фильтра...</value></data>
  <data name="Widgets_Filter_TimePlaceholder"><value>напр. 30:00</value></data>
```

⚠ Значения копируются ПОБАЙТОВО из этого файла. Ивритские строки не переставлять, не «выправлять»
порядок, не добавлять и не убирать многоточия и пробелы. Многоточие — три ASCII-точки `...`,
НЕ символ `…`.

## 4. ПРИЁМКА — предъявить числа ПОСЛЕ
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") CR=$(grep -c $'\r' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
FFFD=$(grep -c $'\xef\xbf\xbd' "$F")"
  python3 -c "import xml.etree.ElementTree as E,sys;E.parse(sys.argv[1]);print('  parse OK')" "$F"
done
```
**Годно ТОЛЬКО при всём сразу:**
```
en-US 933 · he-IL 933 · ru-RU 934          (ровно +9 в каждом)
разности между файлами как были: he-en = 0 · ru-en = +1   (ru несёт +1 исторически — НЕ трогать)
CR=0 · NUL=0 · FFFD=0 во всех трёх         (как было ДО)
parse OK по всем трём
каждое из девяти имён: ровно 1 в каждом из трёх файлов (повтор проверки §2, ожидание 1, не 0 и не 2)
```
Ключ, попавший в два файла из трёх, — будущая утечка имени ключа на экран; ловится разностью, не суммой.

## 5. ГРАНИЦЫ — жёстко
- Только эти девять ключей и только эти три файла.
- Существующие значения НЕ трогать, в том числе `Widgets_MatchType_*` (семь существующих верны).
- `Common_Save` = `שמור ←` в he-IL **НЕ чинить** — чужая строка, другой предмет, владелец назначается отдельно.
- `.razor`-разметку НЕ трогать: это ход `shell-0919b`, и он идёт ПОСЛЕ ключей.
- `NO push`. Подписей ассистента в коммите ноль.

## 6. КОММИТ
Узкими явными путями, без `-A` и без каталогов:
```bash
git add -- "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
           "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
           "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): add 9 filter-popup keys to en/he/ru" \
           -m "keys 924/924/925 -> 933/933/934; CR=0 NUL=0 FFFD=0 unchanged; all three parse" \
           -- "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
              "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
              "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
Числа уходят В СООБЩЕНИЕ коммита: каталоги замеров не отслеживаются, сообщение переживёт уборку.
После коммита сверить блоб каждого файла с хешем на диске.
