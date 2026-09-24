# CC task — PR234-L10N-PAGETITLE-01: localise the four English browser-tab titles

**Author:** shell-0919b · 2026-09-24 · **Branch:** `v3` (= `2a672be`) · Code/comments EN.
**Authority:** coordinator-0919b 24.09 13:40Z — **пять подстановок в четырёх файлах**
(сопоставление пере-снято по корпусу обоими, после того как первое пришло со слов и не сошлось).

## INIT / служебные части (§0.6a, §0.6b, §0.6, §0.5 — в силе)
`cd "D:\Claude\Projects\RTM View Shell"` · **§0.6a** целостность до первой правки: `git status --short`,
по каждому `M`-файлу сверить строки с `git show HEAD:"$f"`, усечённый — восстановить и НЕ продолжать.
`Edit` ЗАПРЕЩЁН, после записи `fsync`. **§0.6b** биндинг: преамбула в `.coord/cc/shell.md` ДО правки,
постамбула `RESULT` после. **`commit.lock`** обязателен (§42.4). **§0.6** пост-коммитная сверка.
**§0.5/PD-007** последним действием `git show HEAD:"$f" > "$f"` по каждому файлу, затем `sync`.
`journal` не ведём; авторство роли и сессии — строкой в сообщении коммита. `NO push`.

## Дефект
Заголовок вкладки браузера пользователь видит ВСЕГДА, на любой локали. В четырёх файлах он несёт
английский текст мимо словаря. Это тот же класс, в котором мы уже ловили имя ключа, вытекшее на экран.

## ⛔ ПЯТЬ подстановок, не четыре — читать по строкам, а не по файлам
Ключей ЧЕТЫРЕ, подстановок ПЯТЬ: в одном файле английских кусков два.
| файл : строка | было | стало |
|---|---|---|
| `Components/Auth/SsoPage.razor:4` | `<PageTitle>SSO Sign In — RTM View Shell</PageTitle>` | `<PageTitle>@L["Login_SsoTitle"] — RTM View Shell</PageTitle>` |
| `Components/Pages/Error.razor:4` | `<PageTitle>Error</PageTitle>` | `<PageTitle>@L["Error_PageTitle"]</PageTitle>` |
| `Components/Dashboard/ScreenFullscreenPage.razor:23` | `<PageTitle>@(Dashboard?.Name ?? "Dashboard") — Fullscreen</PageTitle>` | `<PageTitle>@(Dashboard?.Name ?? L["Common_Dashboard"]) — @L["Common_Fullscreen"]</PageTitle>` |
| `Components/Reports/ReportViewPage.razor:21` | `<PageTitle>@(_report?.Name ?? L["Reports_Title"]) — Fullscreen</PageTitle>` | `<PageTitle>@(_report?.Name ?? L["Reports_Title"]) — @L["Common_Fullscreen"]</PageTitle>` |

**`ScreenFullscreenPage` — ДВА ключа в одной строке** (`Common_Dashboard` для запасного имени и
`Common_Fullscreen` для хвоста). **`ReportViewPage` — ОДИН**: запасное значение там УЖЕ
локализовано (`L["Reports_Title"]`) и трогать его НЕЛЬЗЯ.

## Чего делать НЕЛЬЗЯ
- **Хвост « — RTM View Shell» ключом НЕ делать** и никуда не дописывать. Это имя продукта, а не
  текст для перевода; `Error.razor` его не несёт намеренно, добавление было бы правкой формулировки
  под видом локализации. Из 27 заголовков корпуса хвост несут 24 — это наблюдение, не задача.
- **`.resx` не трогать ни одним символом.** Все четыре ключа уже 1/1/1 в трёх словарях
  [сверено автором и координатором независимо]. Новых ключей ноль.
- **Новых `@inject` не добавлять НИ В ОДИН файл.** `L` объявлен глобально —
  `Components/_Imports.razor:23` — и этого достаточно: `ReportViewPage` уже зовёт `L["Reports_Title"]`
  **вообще без локальной инъекции** [измерено автором: `@inject IStringLocalizer` в нём 0].
  ⛔ **Сторож здесь — НЕИЗМЕНЕНИЕ, а не ноль.** В корпусе инъекции есть, и чужие:
  `ScreenFullscreenPage` несёт 6 строк `@inject` (в их числе локальный дубль `L` на :9),
  `ReportViewPage` — 4 (`IMediator`, `NavigationManager`, `IJSRuntime`, `ILogger` и подобные).
  Ожидание `6 -> 6` и `4 -> 4`, а НЕ `0`. Увидев 6 там, где заявлен 0, исполнитель либо объявит
  красное на верной правке, либо «приведёт к нулю» — то есть снесёт чужие инъекции и сломает два
  экрана. Ни того, ни другого делать нельзя.
- **Локальный дубль `L` в `ScreenFullscreenPage.razor:9` НЕ ТРОГАТЬ.** Он избыточен при глобальном
  объявлении, но это отдельное наблюдение (в бэклоге у координатора), а не часть этой единицы.
  Правка «заодно» смешала бы две приёмки.
- `Screens_FullScreen` / `Screens_ExitFullscreen` не трогать (зовутся из нуля мест, отдельное
  наблюдение). `Reports/ReportsPage.razor:11` не трогать — отчёты вне области
  [со слов оператора 2026-09-24].
- Других `<PageTitle>` не трогать: остальные 23 уже зовут словарь.

## Входные пины — СТОП при расхождении
```
Components/Auth/SsoPage.razor                    -> 62730aecad82d143debc88cd21edc61723d82fbb
Components/Pages/Error.razor                     -> 576cc2d2f4db1df9d16532432880ea6e0bfbc001
Components/Dashboard/ScreenFullscreenPage.razor  -> 1cb6d47e7cd4f7dbecb82680e7d48f7c0dc6495a
Components/Reports/ReportViewPage.razor          -> 9c4aa69c68c87f74a35a84d8be2f71adc2b565f0
```

## ПРЕДИКАТЫ — **единица: ВХОЖДЕНИЯ** (`grep -o … | wc -l`) · **ОБЛАСТЬ: каждый файл отдельно**
Обе величины названы намеренно: за сутки один счётчик трижды дал разные верные числа в разных
областях. Ожидания сняты по ветке `2a672be` и пересчитаны на дельту, которую вносит ЭТОТ промпт.
| предикат | файл | ДО | ПОСЛЕ |
|---|---|---|---|
| `"Login_SsoTitle"` | SsoPage | 0 | **1** |
| `"Error_PageTitle"` | Error | 0 | **1** |
| `"Common_Dashboard"` | ScreenFullscreenPage | 0 | **1** |
| `"Common_Fullscreen"` | ScreenFullscreenPage | 0 | **1** |
| `"Common_Fullscreen"` | ReportViewPage | 0 | **1** |
| `L[` | SsoPage | 0 | **1** |
| `L[` | Error | 0 | **1** |
| `L[` | ScreenFullscreenPage | 8 | **10** (+2 — две подстановки в одной строке) |
| `L[` | ReportViewPage | 15 | **16** (+1 — запасное значение уже было `L[...]`) |
| `"Reports_Title"` | ReportViewPage | 1 | **1** (сторож: чужой ключ не тронут) |
| `@inject` (строки) | SsoPage | 0 | **0** |
| `@inject` (строки) | Error | 0 | **0** |
| `@inject` (строки) | ScreenFullscreenPage | **6** | **6** |
| `@inject` (строки) | ReportViewPage | **4** | **4** |
| `.resx` в коммите | — | — | **0 файлов** |
| изменённых файлов | — | — | **ровно 4**, все `.razor`, удалений 0 |
| `dotnet build` Release | — | — | **0 errors** |

**Отрицательная половина (обязательна):** те же иглы на выдуманном `"ZZZ_PageTitle"` обязаны дать
**0** во всех четырёх файлах и ДО, и ПОСЛЕ. Не ноль — прибор ловит не то, СТОП.
**Положительный контроль:** `L["Reports_Title"]` в `ReportViewPage` = **1** и ДО, и ПОСЛЕ
[измерено автором на `2a672be`] — файл правится, и этот счётчик доказывает, что прибор видит
существующее обращение и что правка не задела соседнее.
**Сторож английского:** после правки `grep -o 'Fullscreen<' ` по обоим фуллскрин-файлам = **0**
(хвост `— Fullscreen` ушёл в ключ), при этом `— RTM View Shell` в `SsoPage` = **1** (не тронут).

## Живая приёмка — предмет ЭКРАННЫЙ, счётчик его не закрывает
Снимается после выката, автором единицы:
1. вкладка браузера на экране дашборда в полноэкранном режиме читается на языке локали, а не
   `Dashboard — Fullscreen`;
2. **отрицательная половина: на второй локали тот же заголовок читается ИНАЧЕ** — иначе это
   зашитая строка, а не перевод;
3. у экрана БЕЗ имени видно запасное слово на языке локали (условие рендера: `Dashboard?.Name` пуст);
4. страница ошибки и вход по SSO — заголовок на языке локали; у SSO хвост « — RTM View Shell» на месте.

## БИНДИНГ — преамбула (ОТКРЫТЬ в `.coord/cc/shell.md` ДО первой правки, Python + os.fsync, не затирая)
```
## 2026-09-24 | binding: shell <-> CC | directive: tools/cc_prompt_shell_pagetitle_l10n.md | status: open
Автор `shell-0919b`. Предмет `PR234-L10N-PAGETITLE-01`. Основание — coordinator-0919b 24.09 13:40Z.
### ЗАМЕР ДО
    v3 = 2a672be
    ОБЛАСТЬ чисел: каждый файл отдельно, единица — вхождения
    SsoPage 62730aec… L[ 0 · Error 576cc2d2… L[ 0
    ScreenFullscreenPage 1cb6d47e… L[ 8 · ReportViewPage 9c4aa69c… L[ 15 · Reports_Title 1
    словарь: Login_SsoTitle · Error_PageTitle · Common_Fullscreen · Common_Dashboard — 1/1/1 каждый
    L объявлен глобально (Components/_Imports.razor:23) — новых @inject не требуется
    @inject по файлам (строки): SsoPage 0 · Error 0 · ScreenFullscreenPage 6 · ReportViewPage 4 — сторож на НЕИЗМЕНЕНИЕ
### СТАТУС: §4 — <вписать вердикт>. Прогон запущен оператором.
```

## БИНДИНГ — постамбула (ДОПИСАТЬ после прогона, в том числе если он сорвался)
```
### RESULT (CC, <дата UTC>)
- коммит: <sha> | файлы: <перечислить>
- ОБЛАСТЬ и ЕДИНИЦА каждого числа: <назвать явно, иначе число несравнимо>
- предикаты факт/ожидание: <все строки таблицы>
- сторожа: Reports_Title 1/1 · @inject НЕ ИЗМЕНИЛСЯ (0/0/6/6/4/4 по файлам) · .resx 0 файлов
- отрицательная половина: ZZZ_PageTitle = <0 | иначе STOP>
- положительный контроль: L["Reports_Title"] в ReportViewPage = <1 | иначе STOP>
- сборка: <errors> errors
- отклонения от промпта: <нет | перечислить>
### СТАТУС: <delivered | stopped: причина>
```

## Коммит
Один коммит, четырьмя узкими явными путями, без `-A`. **NO push**, на боевую не выкатывать.
Сообщение: `l10n(shell): localise the four English browser-tab titles [shell]`

**`commit.lock` (§42.4) — обязателен, им гейтим.** Порядок:
1. Взять замок атомарно: Python `open(".coord/locks/commit.lock", "x")`, внутрь — роль, sha сессии, `acquired` (UTC).
   Файл существует — ретрай 5 x 60 c; не взял — **коммит не делать**, напечатать владельца и СТОП.
2. `acquired` старше 15 минут — напечатать содержимое и ЖДАТЬ решения оператора. **Не удалять самому.**
3. Под замком: `git add` (только четыре заявленных пути) -> `git commit` -> §0.6 пост-коммит-сверка.
4. Отпустить: удалить `commit.lock`, `sync`. Коммит сорвался — замок всё равно отпустить.
Замок покрывает и plumbing-путь (§0.4). Обойти замок нельзя ни при каком объёме правки.
