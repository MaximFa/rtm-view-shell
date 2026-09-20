# CC TASK — L10N: снять BOM из `SharedResources.ru-RU.resx`

> Автор: `backend-0919`. На §4 координатора ДО запуска.
> Предмет: `PR234-L10N-KEYLEAK-01`, устранение дефекта, внесённого прогоном в `7d67148`.
> Основание: заказ `coordinator-0919b` 2026-09-20T07:33:49Z — «ЧИНИМ СЕЙЧАС, ДО СБОРКИ».
> Дефект: `7d67148` заказанную часть выполнил верно (938/938/938), но дописал в начало файла
> BOM `ef bb bf`. В `7d67148^` первые три байта были `3c 3f 78`. Размер ушёл на `-70` вместо
> `-73`: разница ровно `+3` — это BOM.

## §0.6a INTEGRITY
Проверка по диску и object store, не по докладу инструмента. Счёт строк доказательством не является.
Каждое число — парой «до/после».

### §0.6b ФОРМА ОСТАНОВКИ — ПРЕДИКАТ, А НЕ ПРОЗА
Требование `coordinator-0919b` 2026-09-20T07:33:49Z: три раза за сутки критерий не сошёлся,
а прогон не остановился. Поэтому здесь остановка — исполняемая, а не описанная.
**Каждый критерий в этом промпте печатает ДВЕ половины — ожидаемое и фактическое — и одно
слово: `OK` или `STOP`.** Форма, обязательная к применению в §1, §2, §4:
```bash
chk(){ # chk "<имя>" "<ожидаемое>" "<фактическое>"
  if [ "$2" = "$3" ]; then echo "OK   $1: exp=$2 got=$3"
  else echo "STOP $1: exp=$2 got=$3"; fi; }
```
**Напечатано хоть одно `STOP` — правка и коммит НЕ делаются, `status: failed`, фактическое
число в `RESULT`. Переформулировать критерий под факт ЗАПРЕЩЕНО.** Прецедент 2026-09-19:
прогон заменил числовой критерий словами `CR=CRLF (Windows standard)` и поставил `done` —
это провал единицы, а не её прохождение.
**В `RESULT` обязана быть строка `STOP-предикат: <N> критериев, STOP=<M>`.** Строки нет —
единица не сдана независимо от остального.

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
Python + `os.fsync`, `newline="\n"`, **запись обязана заканчиваться переводом строки**.
После записи предъявить числом: `CR=0`, последний байт `\n`.
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_l10n_drop_bom.md | status: open
### DIRECTIVE: снять BOM (ef bb bf) из SharedResources.ru-RU.resx, внесённый коммитом 7d67148.
Claim: SharedResources.ru-RU.resx. gate: head3 ru = ef bb bf ДО правки -> 3c 3f 78;
размер 90342 -> 90339; ключи 938/938/938 без изменений; NEGCTL en-US: BOM нет ни ДО, ни ПОСЛЕ.
```

## 1. ЗАМЕР «ДО» — через предикат §0.6b
```bash
head3(){ git --no-optional-locks show v3:"$1" | head -c3 | xxd -p; }
size(){ git --no-optional-locks cat-file -s "$(git --no-optional-locks rev-parse v3:"$1")"; }
EN=src/CcDashboard.Web/Resources/SharedResources.en-US.resx
HE=src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
RU=src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
chk "ru head3 ДО"        "efbbbf" "$(head3 $RU)"
chk "ru size ДО"         "90342"  "$(size  $RU)"
chk "NEGCTL en head3 ДО" "3c3f78" "$(head3 $EN)"
chk "NEGCTL he head3 ДО" "3c3f78" "$(head3 $HE)"
chk "ru keys ДО"         "938" "$(grep -c '<data name=' $RU)"
chk "en keys ДО"         "938" "$(grep -c '<data name=' $EN)"
chk "he keys ДО"         "938" "$(grep -c '<data name=' $HE)"
chk "САМОПРОВЕРКА прибора" "efbbbf" "3c3f78"
```
Последняя строка обязана напечатать `STOP` — она и есть отрицательная половина: прибор,
не умеющий вернуть красное, проверкой не является. Её `STOP` в счёт §0.6b не идёт и
**объявляется отдельной строкой** `самопроверка: STOP получен`.
⚠ Всё меряется в ВЕТКЕ (`git show v3:`), не на диске.
`ru head3 ДО` не `efbbbf` — **BOM уже кем-то снят: СТОП, ничего не делать, доложить.**

## 2. ГЕЙТ — BOM ровно один и ровно в `ru-RU`
```bash
python3 - <<'PYGATE'
import subprocess
for L in ("en-US","he-IL","ru-RU"):
    f="src/CcDashboard.Web/Resources/SharedResources.%s.resx"%L
    b=subprocess.check_output(["git","--no-optional-locks","show","v3:"+f])
    print(L, "BOM" if b.startswith(b'\xef\xbb\xbf') else "no-BOM",
          "count=", b.count(b'\xef\xbb\xbf'))
PYGATE
```
**Ожидание: `en-US no-BOM count= 0` · `he-IL no-BOM count= 0` · `ru-RU BOM count= 1`.**
`count` в `ru-RU` больше 1 — **СТОП**: последовательность встречается и внутри тела,
это другой дефект, снимать вслепую нельзя.

## 3. ПРАВКА — снять РОВНО ТРИ ПЕРВЫХ БАЙТА
Python + `os.fsync`, бинарно. НЕ `sed`, НЕ перенабор файла, НЕ перекодирование.
```python
p = "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
b = open(p, "rb").read()
assert b[:3] == b"\xef\xbb\xbf", "BOM не в начале — STOP"
n = b[3:]
assert not n.startswith(b"\xef\xbb\xbf"), "второй BOM — STOP"
# записать n через open(p,'wb'), затем f.flush() и os.fsync(f.fileno())
```
Предъявить парой: `байт до / после` — ожидание ровно `-3`; `строк до / после` — ожидание `0`
(BOM не содержит перевода строки, число строк не меняется).
⚠ Файл писать в режиме `"wb"`. Текстовый режим на Windows превратил бы все `\n` в `\r\n` —
это внесло бы CR во все 938 строк вместо снятия трёх байтов.

## 4. ПРИЁМКА — через предикат §0.6b, после коммита, по ВЕТКЕ
```bash
chk "ru head3 ПОСЛЕ"        "3c3f78" "$(head3 $RU)"
chk "ru size ПОСЛЕ"         "90339"  "$(size  $RU)"
chk "NEGCTL en head3 ПОСЛЕ" "3c3f78" "$(head3 $EN)"
chk "NEGCTL he head3 ПОСЛЕ" "3c3f78" "$(head3 $HE)"
chk "en size ПОСЛЕ"         "73925"  "$(size  $EN)"
chk "he size ПОСЛЕ"         "80484"  "$(size  $HE)"
chk "ru keys ПОСЛЕ"         "938" "$(grep -c '<data name=' $RU)"
chk "en keys ПОСЛЕ"         "938" "$(grep -c '<data name=' $EN)"
chk "he keys ПОСЛЕ"         "938" "$(grep -c '<data name=' $HE)"
chk "сирота InfoSlot_ExpiresAt"  "0" "$(grep -c 'name=\"InfoSlot_ExpiresAt\"'  $RU)"
chk "живой InfoSlots_ExpiresAt"  "1" "$(grep -c 'name=\"InfoSlots_ExpiresAt\"' $RU)"
chk "ru CR в ветке" "0" "$(git --no-optional-locks show v3:$RU | grep -c $'\r')"
chk "ru NUL"        "0" "$(python3 -c "print(open('$RU','rb').read().count(b'\x00'))")"
chk "файлов в коммите" "1" "$(git --no-optional-locks show --stat --format= --name-only HEAD | wc -l)"
python3 -c "import xml.etree.ElementTree as E;E.parse('$RU');print('parse OK')"
```
**Годно ТОЛЬКО когда `STOP` не напечатан ни разу** (кроме объявленной самопроверки §1).
Дополнительно предъявить:
```
итог от 7d67148^: 90412 -> 90339 = -73  (ровно длина удалённой строки, без BOM)
значения живого ключа: en 'Expires At' · he 'תפוגה' · ru 'Истекает' — не изменились
STOP-предикат: <N> критериев, STOP=<M>
```

## 5. ГРАНИЦЫ
- Только `ru-RU`, только первые три байта. `en-US` и `he-IL` НЕ трогать вовсе — в §1 и §4 они
  присутствуют как отрицательный контроль, а не как объект правки.
- Ни одного ключа не добавлять, не удалять, не переименовывать. Число 938 обязано устоять.
- Кодировку не менять, XML-декларацию не переписывать, файл не переформатировать.
- Ни одного `.razor`, ни одного `.cs`.
- `NO push`.

## 6. КОММИТ
```bash
git add -- "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): strip UTF-8 BOM accidentally added to ru-RU in 7d67148" \
           -m "7d67148 removed the orphaned key correctly but prepended ef bb bf; size 90342 -> 90339, net -73 from 7d67148^ as intended; keys 938/938/938 unchanged; en-US and he-IL untouched, no BOM before or after" \
           -- "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
После коммита сверить блоб файла с хешем на диске.

## 7. BINDING POSTAMBLE / RESULT — ПОСЛЕДНИМ действием (`.coord/cc/backend.md`)
Тем же способом, что преамбула, **с переводом строки в конце**:
```
### RESULT: commit <hash> . file SharedResources.ru-RU.resx (-3 bytes, BOM)
. ru head3 <факт ДО> -> <факт ПОСЛЕ> . ru size <факт> -> <факт> . итог от 7d67148^ = <факт>
. keys <факт>/<факт>/<факт> . сирота <факт> . живой <факт> . NUL 0 . CR в ветке 0 . parse OK
. NEGCTL en/he head3 ДО <факт>/<факт> ПОСЛЕ <факт>/<факт> . самопроверка: STOP получен
. STOP-предикат: <N> критериев, STOP=<M>
. status done|failed . verified: object-store
<фактический вывод замера ПОСЛЕ>
```
Затем двухстрочный дайджест в `.coord/inbox/coordinator.md` — тем же способом, с `\n` в конце,
и предъявить `CR=0`.

> Пункта «подписей ассистента 0» здесь НЕТ намеренно: коммит делает прогон, среда прогона
> дописывает подпись сама, и такая проверка пройти не может.
