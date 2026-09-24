# CC TASK — L10N: завести 4 ключа под заголовки вкладок браузера

> Автор: `backend-0919`. Переводы — `coordinator-0919b`, `.coord/l10n_pagetitle_translations.md`
> (блоб `01a5904a`, 3195 B, CR 0, BOM нет — пере-снято мной).
> Предмет: `PR234-L10N-PAGETITLE-01`, шаг 1 из 2. Шаг 2 — правка `<PageTitle>` в четырёх `.razor`,
> делает `shell`, ПОСЛЕ нас. Порядок обратный завёл бы KEYLEAK: `L[...]` на несуществующий ключ
> выводит на экран ИМЯ ключа.
> **Все 12 строк даны в §3 дословно. Работа — вставить их, а не сочинить.**

## §0.6a INTEGRITY
Проверка по object store, не по докладу инструмента. Счёт строк доказательством не является.
Каждое число — парой «до/после». Всё меряется в ВЕТКЕ (`git show v3:`), не на диске:
на диске CRLF — норма чекаута (`.gitattributes` + `core.autocrlf=true`).
**Иглы по словарю строятся БЕЗ УЧЁТА РЕГИСТРА** — норма от 2026-09-24: в словаре живут и
`Screens_FullScreen`, и `Screens_ExitFullscreen`, и регистрозависимая игла теряет половину.

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
Форма проверена мишенью `tools/cc_prompt_selftest_stop.md`: на красном прогон останавливается.

## Multi-session sync — MANDATORY
binding: `PR234-L10N-PAGETITLE-01`
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
Метку времени СНЯТЬ командой `date -u` и вставить из вывода. Форма «09:3xZ» с иксом — подделка.
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_l10n_pagetitle_4.md | status: open
### DIRECTIVE: завести 4 ключа под заголовки вкладок в en-US/he-IL/ru-RU.
Claim: три .resx. gate: все 4 отсутствуют 0/0/0 ДО правки; 957/957/957 -> 961/961/961;
каждое имя 1/1/1; he-en=0 ru-en=0; BOM 0 x3; CR в ветке 0; parse OK x3. l10n:.
```

## 1. ЗАМЕР «ДО» — через предикат §0.6b
```bash
blob(){ git --no-optional-locks show v3:"$1"; }
EN=src/CcDashboard.Web/Resources/SharedResources.en-US.resx
HE=src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
RU=src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
for P in "$EN" "$HE" "$RU"; do
  chk "keys ДО $P" "957" "$(blob "$P" | grep -c '<data name=')"
  chk "CR ДО $P"   "0"   "$(blob "$P" | grep -c $'\r')"
done
chk "САМОПРОВЕРКА прибора" "957" "0"
```
Последняя строка ОБЯЗАНА напечатать `STOP` — отрицательная половина прибора. Её `STOP` в счёт
§0.6b не идёт и объявляется отдельно: `самопроверка: STOP получен`.

## 2. ⛔ ГЕЙТ — четыре имени отсутствуют. Снять ДО правки
```bash
python3 - <<'PYGATE'
import subprocess, re
NEW = ['Login_SsoTitle', 'Error_PageTitle', 'Common_Dashboard', 'Common_Fullscreen']
L = ("en-US","he-IL","ru-RU")
B = {}
for l in L:
    p = "src/CcDashboard.Web/Resources/SharedResources." + l + ".resx"
    B[l] = subprocess.check_output(["git","--no-optional-locks","show","v3:"+p]).decode("utf-8")
def cnt(k): return [B[l].count('name="' + k + '"') for l in L]
bad = [(k,cnt(k)) for k in NEW if cnt(k) != [0,0,0]]
print("GATE новых, которые уже есть:", bad if bad else "пусто")
print("POSCTL Screens_Title:", cnt("Screens_Title"))
print("NEGCTL ZZZ_Not_A_Key:", cnt("ZZZ_Not_A_Key"))
print("имён в списке:", len(NEW), "уникальных:", len(set(NEW)))
# игла БЕЗ регистра: не заводим ли мы двойника уже существующего имени
names = re.findall(r'<data name="([^"]+)"', B["en-US"])
low = {n.lower() for n in names}
clash = [k for k in NEW if k.lower() in low]
print("CASE-CLASH (имя отличается только регистром от существующего):", clash if clash else "пусто")
PYGATE
```
**Ожидание: `GATE ... пусто` · `POSCTL [1, 1, 1]` · `NEGCTL [0, 0, 0]` · `4 / 4` ·
`CASE-CLASH пусто`.**
`GATE` не пусто — **СТОП**: ключ уже есть, вставка сделала бы дубль.
`POSCTL` не `[1, 1, 1]` — прибор не находит в этой области, его нули не считаются, **СТОП**.
`CASE-CLASH` не пусто — **СТОП**: заводим имя, отличающееся от существующего только регистром,
а это ровно тот дефект словаря, из-за которого игла врала (`FullScreen` / `Fullscreen`).

## 3. ПРАВКА — вставить дословно, в КОНЕЦ, перед `</root>`
Словари не отсортированы, порядок в них исторический — «правильного места» не существует.
Вставка в конец единым блоком, как легли 19 ключей в `6863b61`. Место НЕ выбирать самому.

Формат: два пробела отступа, один ключ — одна строка, без пустых строк между.
Python + `os.fsync`, `newline="\n"`, с явным `encoding="utf-8"`.
Алгоритм: прочитать файл, найти **последнее** вхождение `</root>`, вставить блок перед ним,
записать. НЕ `sed`, НЕ перенабор файла, НЕ переформатирование, НЕ смена кодировки.

⚠ Писать так, чтобы не появился BOM и не появились CR. Оба дефекта мы ловили 20.09:
BOM внесён в `7d67148`, снят в `0f969d8`.

### en-US — 4 строки
```xml
  <data name="Login_SsoTitle"><value>SSO Sign In</value></data>
  <data name="Error_PageTitle"><value>Error</value></data>
  <data name="Common_Dashboard"><value>Dashboard</value></data>
  <data name="Common_Fullscreen"><value>Fullscreen</value></data>
```
### he-IL — 4 строки
```xml
  <data name="Login_SsoTitle"><value>כניסה עם SSO</value></data>
  <data name="Error_PageTitle"><value>שגיאה</value></data>
  <data name="Common_Dashboard"><value>לוח מחוונים</value></data>
  <data name="Common_Fullscreen"><value>מסך מלא</value></data>
```
### ru-RU — 4 строки
```xml
  <data name="Login_SsoTitle"><value>Вход через SSO</value></data>
  <data name="Error_PageTitle"><value>Ошибка</value></data>
  <data name="Common_Dashboard"><value>Дашборд</value></data>
  <data name="Common_Fullscreen"><value>Полноэкранный режим</value></data>
```
Предъявить парой по каждому файлу: `строк до / после` (ожидание ровно `+4`) и `байт до / после`.

## 4. ПРИЁМКА — через предикат §0.6b, после коммита, по ВЕТКЕ
```bash
for P in "$EN" "$HE" "$RU"; do
  chk "keys ПОСЛЕ $P" "961" "$(blob "$P" | grep -c '<data name=')"
  chk "CR ПОСЛЕ $P"   "0"   "$(blob "$P" | grep -c $'\r')"
  chk "NUL $P" "0" "$(python3 -c "print(open('$P','rb').read().count(b'\x00'))")"
  python3 -c "import xml.etree.ElementTree as E;E.parse('$P');print('parse OK $P')"
done
chk "файлов в коммите" "3" "$(git --no-optional-locks show --format= --name-only HEAD | sed '/^$/d' | wc -l)"
chk ".razor в коммите" "0" "$(git --no-optional-locks show --format= --name-only HEAD | grep -c 'razor')"
```
Плюс тем же скриптом, что в §2: **каждое из 4 имён = `1/1/1`**, `NEGCTL ZZZ_Not_A_Key` `0/0/0`,
`BOM = 0` во всех трёх, `he-en = 0`, `ru-en = 0` (симметрия наборов имён).
И отдельной строкой — **сверка `Common_Fullscreen` с существующим `Screens_FullScreen`**:
`he` и `ru` обязаны совпасть ДОСЛОВНО (`מסך מלא` / `Полноэкранный режим`), `en` обязан
РАЗЛИЧАТЬСЯ (`Fullscreen` против `Full Screen`) — так решил координатор, и это заявлено заранее,
а не подогнано после.
**Годно ТОЛЬКО когда `STOP` не напечатан ни разу**, кроме объявленной самопроверки §1.

## 5. ГРАНИЦЫ
- Только три `.resx`. **Ни одного `.razor`** — `<PageTitle>` правит `shell` следующей единицей.
- `Screens_FullScreen` и `Screens_ExitFullscreen` НЕ трогать, НЕ переименовывать, НЕ удалять.
  Оба зовутся из нуля мест — это отдельное наблюдение, не эта единица.
- Существующие 957 ключей не переставлять, не сортировать, не переформатировать.
- Хвост « — RTM View Shell» — имя продукта, ключом не становится.
- Пары-дубли из бэклога (`InfoSlot_`/`InfoSlots_`, `Report_Title`/`Reports_Title`) не трогать.
- `NO push`.

## 6. КОММИТ
```bash
git add -- \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
git commit -m "l10n(resx): add 4 browser-tab title keys to all three dictionaries" \
           -m "names by backend, translations by coordinator (.coord/l10n_pagetitle_translations.md, blob 01a5904a), taken verbatim; 957 -> 961 in each file, symmetry preserved; Common_Fullscreen reuses the he/ru wording of the existing Screens_FullScreen on purpose - same term, different role, so a separate key but not a second translation; markup is NOT touched here, the four PageTitle tags are a separate unit by shell, in that order so no L[] ever points at a missing key" \
           -- \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx"
```
После коммита сверить блоб каждого файла с `git hash-object` того же файла на диске.

## 7. BINDING POSTAMBLE / RESULT — ПОСЛЕДНИМ действием (`.coord/cc/backend.md`)
Тем же способом, что преамбула, с переводом строки в конце:
```
### RESULT: commit <hash> . files en-US/he-IL/ru-RU .resx (+4 keys each)
. keys 957/957/957 -> <факт>/<факт>/<факт> . he-en=<факт> ru-en=<факт>
. все 4 имени 1/1/1: <да|нет, с перечнем> . NEGCTL ZZZ_Not_A_Key 0/0/0 . CASE-CLASH <факт>
. Common_Fullscreen he/ru == Screens_FullScreen: <да|нет> . en различается: <да|нет>
. BOM 0 x3 . CR в ветке 0 x3 . NUL 0 x3 . parse OK x3
. файлов в коммите <факт> . .razor в коммите <факт>
. самопроверка: STOP получен . STOP-предикат: <N> критериев, STOP=<M>
. status done|failed . verified: object-store
<фактический вывод замера ПОСЛЕ>
```
Затем двухстрочный дайджест в `.coord/inbox/coordinator.md` — тем же способом, с `\n` в конце.

> Пункта «подписей ассистента 0» здесь НЕТ намеренно: коммит делает прогон, среда прогона
> дописывает подпись сама, и такая проверка пройти не может.
