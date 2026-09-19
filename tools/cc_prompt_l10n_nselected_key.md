# CC TASK — L10N: десятый ключ фильтр-попапа `Widgets_Filter_NSelected` в три `.resx`

> Автор промпта: `backend-0919`. На §4 координатора ДО запуска.
> Предмет: `PR234-FILTER-L10N-01`, вторая единица (после девяти ключей, `e592f8b`).
> Источник термина — единственный: блок `coordinator-0919b` от 19.09 20:05:12Z в `.coord/inbox/backend.md`.

## §0.6a INTEGRITY
Любое «сделано» проверяется по диску и object store, не по докладу инструмента.
Счёт строк доказательством не является. Каждое число предъявляется парой «до/после».

## Multi-session sync — MANDATORY, NO EXCEPTIONS
binding: `PR234-FILTER-L10N-01`
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
Трогать ТОЛЬКО эти три файла.

### S3. Commit lock — around EVERY git add/commit
Взять `.coord/locks/commit.lock` по форме `tools/cc_prompt_sync_block.md` (phantom-aware),
держать на время `git add` + `git commit`, чужой лок не удалять.

### S4. Post-commit
`bash tools/cc_post_commit.sh backend-0919 $(git log -1 --format=%h)`, затем `sync`.

### S5. НЕ `git push` (§37).

---

## 0. BINDING PREAMBLE — ПЕРВЫМ ДЕЙСТВИЕМ, до замера (`.coord/cc/backend.md`, Python + os.fsync)
Дописать в конец файла, не перезаписывая:
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_l10n_nselected_key.md | status: open
### DIRECTIVE: десятый ключ фильтр-попапа Widgets_Filter_NSelected в три SharedResources.*.resx (en/he/ru).
Claim: SharedResources.en-US.resx + SharedResources.he-IL.resx + SharedResources.ru-RU.resx.
gate: 933/933/934 -> 934/934/935, he-en=0, ru-en=+1, NSel=1 в каждом, CR/NUL/FFFD 0, parse OK. l10n:.
```
После записи — сверка байтов: NUL=0, прирост размера сходится с дописанным.

## 1. ЗАМЕР «ДО» — снять ПЕРВЫМ, напечатать
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") \
CR=$(grep -c $'\r' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
FFFD=$(grep -c $'\xef\xbf\xbd' "$F")"
done
```
**Ожидание [измерено backend-0919 19.09 20:0xZ]:** `en-US 933 · he-IL 933 · ru-RU 934`,
`CR=0 · NUL=0 · FFFD=0` во всех трёх. Не сошлось — СТОП, файл уехал с момента замера.

## 2. ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА — по ЭТОМУ имени, не перенесённая с прошлых девяти
```bash
for L in en-US he-IL ru-RU; do
  printf "NSelected %s = %s\n" "$L" \
    "$(grep -c 'name="Widgets_Filter_NSelected"' src/CcDashboard.Web/Resources/SharedResources.$L.resx)"
done
grep -c 'name="Widgets_Filter_SelectValues"' src/CcDashboard.Web/Resources/SharedResources.en-US.resx  # POSCTL -> 1
```
**Ожидание: три нуля и POSCTL = 1.** Ненулевое -> СТОП: ключ уже есть.

## 3. ПРАВКА — одна строка в каждый из трёх файлов, ПЕРЕД `</root>`
Формат как у соседей: два пробела отступа, один `<data>` в строке, без `xml:space`.
Вставлять Python + `os.fsync`; НЕ `sed`, НЕ ручным перенабором файла.

```xml
en-US:  <data name="Widgets_Filter_NSelected"><value>{0} selected</value></data>
he-IL:  <data name="Widgets_Filter_NSelected"><value>נבחרו: {0}</value></data>
ru-RU:  <data name="Widgets_Filter_NSelected"><value>выбрано: {0}</value></data>
```

⚠ Значения копируются ПОБАЙТОВО из этого файла.
- Плейсхолдер — ровно `{0}`, фигурные скобки ASCII. Ни `{ 0 }`, ни `%s`, ни `{n}`.
- В he-IL число стоит В КОНЦЕ строки намеренно (bidi переставляет LTR-кусок в начале RTL-строки) —
  порядок НЕ менять, двоеточие НЕ переносить.
- В ru-RU строчная «в» в начале — намеренно, НЕ «Выбрано».

## 4. ПРИЁМКА — предъявить числа ПОСЛЕ
```bash
for L in en-US he-IL ru-RU; do
  F="src/CcDashboard.Web/Resources/SharedResources.$L.resx"
  echo "$L keys=$(grep -c '<data name=' "$F") CR=$(grep -c $'\r' "$F") \
NUL=$(python3 -c "import sys;print(open(sys.argv[1],'rb').read().count(b'\x00'))" "$F") \
FFFD=$(grep -c $'\xef\xbf\xbd' "$F") \
NSel=$(grep -c 'name="Widgets_Filter_NSelected"' "$F")"
  python3 -c "import xml.etree.ElementTree as E,sys;E.parse(sys.argv[1]);print('  parse OK')" "$F"
done
grep -c '{0}' src/CcDashboard.Web/Resources/SharedResources.he-IL.resx   # плейсхолдер на месте, >=1
```
**Годно ТОЛЬКО при всём сразу:**
```
en-US 934 · he-IL 934 · ru-RU 935            (ровно +1 в каждом)
разности: he-en = 0 · ru-en = +1             как было
NSel = 1 в каждом из трёх                    (не 0 и не 2)
CR=0 · NUL=0 · FFFD=0 во всех трёх           как было ДО
parse OK по всем трём
```

## 5. ГРАНИЦЫ
- Только этот один ключ и только эти три файла.
- `Widgets_Filter_SelectValues` НЕ трогать — он покрывает второй возврат того же метода.
- Девять ключей из `e592f8b` НЕ трогать.
- `Common_Save` = `שמור ←` в he-IL НЕ чинить — чужая строка, другой предмет.
- `.razor`-разметку НЕ трогать: ход `shell-0919b`, он ПОСЛЕ ключа.
- `NO push`.

## 6. КОММИТ
Узкими явными путями, без `-A` и без каталогов:
```bash
git add -- "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
           "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
           "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): add Widgets_Filter_NSelected to en/he/ru" \
           -m "keys 933/933/934 -> 934/934/935; he-en=0 ru-en=+1 unchanged; CR/NUL/FFFD 0; all three parse" \
           -- "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
              "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
              "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
Числа уходят В СООБЩЕНИЕ коммита: каталоги замеров не отслеживаются.
После коммита сверить блоб каждого файла с хешем на диске.

## 7. BINDING POSTAMBLE / RESULT — ПОСЛЕДНИМ действием (`.coord/cc/backend.md`, Python + os.fsync)
Дописать в конец файла:
```
### RESULT: commit <hash> . files SharedResources.en-US/he-IL/ru-RU.resx (+1 key Widgets_Filter_NSelected)
. keys 933/933/934 -> <факт>/<факт>/<факт> . he-en=<факт> ru-en=<факт> . NSel=<факт>/<факт>/<факт>
. CR/NUL/FFFD 0 . parse OK x3 . status done|failed . verified: object-store (blob диска == blob ветки)
<вставить сюда фактический вывод замера ПОСЛЕ>
```
Числа в RESULT — из СВОЕГО вывода, не из ожиданий этого промпта. Не сошлось — `status: failed`
и фактические числа, а не подгонка под ожидание.
Затем двухстрочный дайджест в `.coord/inbox/coordinator.md`: хеш коммита + три числа ключей.

> **Про подписи ассистента:** этот коммит делает ПРОГОН, а среда прогона дописывает подпись
> сама — поэтому пункта «подписей 0» здесь НЕТ намеренно. Проверка, которая не может пройти,
> проверкой не является (основание: `coordinator-0919b` 19.09 22:3xZ, перепись 25 коммитов:
> подписи ровно у двух, и оба сделаны прогоном).
