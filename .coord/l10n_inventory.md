# СПИСОК НЕЛОКАЛИЗОВАННЫХ КОМПОНЕНТОВ — RTM View Shell

> Составлен `coordinator-0917` 2026-09-19 по решению оператора: **«создай список нелокализованных
> компонентов, пойдём отдельным кругом»**. Это ИНВЕНТАРЬ для отдельного круга работ, не задание.
> Владелец круга оператором ещё не назначен.
>
> Снято двумя независимыми приборами: **кодом** (обход `src/**/*.razor` и `*.cs`, сверка ключей с
> тремя `.resx`) и **живым телом 234** (`https://platform.insightense.com:8444`, Chrome).
> Совпадение приборов отмечено отдельно — там, где они сошлись, находка твёрдая.
>
> ⚠ **Мерить локализацию можно ТОЛЬКО в Chrome.** Встроенная панель браузера подменяет локаль и
> направление: на одном и том же URL она отдала английский LTR, Chrome — `he-IL` + `dir=rtl`.
> Замер тем прибором будет зелёным и ложным.

## 0. МЕХАНИЗМ — НАЙДЕН ТОЧНО, И ОН ОДИН НА ВСЕ «КЛЮЧИ НА ЭКРАНЕ»

[измерено 19.09: подсчёт `<data name=` в трёх файлах ресурсов]

```
SharedResources.en-US.resx   924 ключа
SharedResources.ru-RU.resx   865        (нет 60 из тех, что есть в en)
SharedResources.he-IL.resx   769        (нет 155 из тех, что есть в en)
```

[измерено: обход `L["..."]` по всему `src/`] в коде используется **736** ключей, из них
**112 отсутствуют в `he-IL`**, и **4 не существуют НИ В ОДНОМ** файле ресурсов
(`Common_View`, `Reports_Edit`, `UnknownWidget`, `View`).

**Когда ключа нет в ивритском файле, на экран печатается сам ключ.** Это и есть `Login_OrCredentials`,
`COMMON_WIDGETS`, `InfoSlots_Title`, которые видит пользователь. **Обратного нет: в `he-IL` нет ни
одного ключа, которого не было бы в `en-US`** — то есть перевод не «разошёлся», он ОТСТАЛ.

## 1. КОМПОНЕНТЫ, КОТОРЫЕ ПЕЧАТАЮТ КЛЮЧ ВМЕСТО СЛОВА

Ключи используются правильно, но ивритского перевода для части из них нет.
[измерено: пересечение `L["..."]` каждого файла с ключами `he-IL`]

| компонент | ключей без иврита | всего ключей |
|---|---|---|
| `Dashboard/ScreenEditorPage.razor` | **47** | 165 |
| `Dashboard/InfoSlots/InfoSlotMessages.razor` | **24** | 41 |
| `Admin/InfoSlotAdmin.razor` | **17** | 46 |
| `Dashboard/ScreenListPage.razor` | 13 | 73 |
| `Reports/ReportsListPage.razor` | 12 | 73 |
| `Reports/ReportEditorPage.razor` | 6 | 18 |
| `Widgets/DayTrendWidget.razor` | 5 | 22 |
| `Layout/NavMenu.razor` | 2 | 18 |
| `Widgets/InfoSlotWidget.razor` | **2** | 2 |
| `Admin/PermissionGroupsPage.razor` | 1 | 32 |
| `Auth/ChangePasswordPage.razor` | 1 | 16 |
| `Auth/LoginPage.razor` | 1 | 11 |
| `Auth/TwoFactorPage.razor` | 1 | 15 |
| `Dashboard/ScreenFullscreenPage.razor` | 1 | 6 |
| `ReportWidgets/RenderReportWidget.razor` | 1 | 2 |
| `ReportWidgets/ReportWidgetConfigModal.razor` | 1 | 28 |

**`NavMenu` весит больше своих двух ключей:** это боковое меню, и `Nav_InfoSlots` /
`Nav_InfoSlotsAdmin` видны на КАЖДОМ экране. [подтверждено на 234: оба ключа присутствуют на всех
девяти пройденных страницах.]

**`InfoSlotWidget` — 2 из 2: у компонента нет НИ ОДНОГО переведённого ключа.**

## 2. КОМПОНЕНТЫ БЕЗ ПОДКЛЮЧЁННОЙ ЛОКАЛИЗАЦИИ ВООБЩЕ

[измерено: отсутствие подстроки `L[` в файле] **18 из 70** `.razor`.
Часть из них локализовать нечего — это разметочный каркас без текста; часть несёт текст для
пользователя. **Разделить обязан владелец круга, я это по имени файла не решаю.**

```
App.razor · Routes.razor · _Imports.razor · Layout/AuthLayout.razor      каркас, текста может не быть
Auth/LogoutPage.razor · Auth/SsoPage.razor
Pages/AccessDenied.razor · Pages/Error.razor                             ТЕКСТ ДЛЯ ПОЛЬЗОВАТЕЛЯ
Home.razor · Dashboard/RenderWidget.razor
Shared/AppBadge · AppBreadcrumb · AppEmptyState · AppPageHeader · AppSkeleton
Widgets/AgentStatusWidget.razor · Widgets/KpiWidget.razor · Widgets/QueueSummaryWidget.razor
```

⛔ **Три виджета в этом списке — `AgentStatusWidget`, `KpiWidget`, `QueueSummaryWidget` — это то,
что пользователь видит на экране постоянно.** Их отсутствие в списке §1 означает не «у них всё
переведено», а «они не переводятся в принципе».

## 3. ЗАШИТЫЕ АНГЛИЙСКИЕ ЛИТЕРАЛЫ В РАЗМЕТКЕ

Локализация в файле работает, но конкретные строки идут мимо неё.
[измерено: `title=` / `placeholder=` / `<option>` / `aria-label=` с латиницей]

| компонент | литералов | что именно |
|---|---|---|
| `Admin/Configuration/SitesPage.razor` | 38 | список часовых поясов `UTC+00:00 …` — **скорее данные, чем подписи; решает владелец** |
| `Dashboard/ScreenEditorPage.razor` | 22 | `Move up`, `Move down`, `Remove column`, `Remove row`, `Delete template`, `Save as template`, `Auto`, `Default`; плейсхолдеры `Enter template name...`, `Select Business Unit...`, `Value...`, `Goal < 5%` |
| `Widgets/QueueGridWidget.razor` | 20 | попап фильтра: `Apply`, `Clear`, `Close`, `Filter value...`, все восемь операторов |
| `Widgets/AgentGridWidget.razor` | 12 | тот же попап |
| `Admin/TenantsPage.razor` | 6 | `English`, `Hebrew`, `Russian` — **названия языков в выпадающем списке** |
| `Admin/TenantSettingsPage.razor` | 2 | плейсхолдеры `en-US`, `http://localhost:5045` — **образцы ввода, вероятно не дефект** |
| `Shared/AppBreadcrumb.razor` | 1 | `aria-label="Breadcrumb"` — читает только экранный диктор |
| `Admin/UserAdminPage.razor` | 1 | `English (US)` |

**`ScreenEditorPage` попал во ВСЕ ТРИ списка сразу** — 47 ключей без иврита и 22 зашитых литерала.
Это самый нелокализованный компонент приложения, и он же — главный рабочий экран редактирования.

## 4. ПОДТВЕРЖДЕНО НА ЖИВОМ ТЕЛЕ 234

[измерено 19.09 в Chrome; 9 страниц из 14 в навигации, 1 экран из 6, диалоги НЕ открывались]

- `/admin/info-slots` — **девять ключей на одной странице**, включая `<title>` вкладки
  (`InfoSlots_Title — RTM View Shell`). Ключи в ДВУХ регистрах (`InfoSlots_Name` и `INFOSLOTS_NAME`).
- `/info-slots` — `InfoSlots_ViewerTitle`, `InfoSlots_NoSlotsViewer`, титул вкладки тоже ключ.
- **все девять страниц** — `Nav_InfoSlots`, `Nav_InfoSlotsAdmin`.
- `/screens` — `COMMON_WIDGETS`, `COMMON_CREATEDBY`, `COMMON_UPDATEDBY`; заголовки виджетов
  `Queue Grid` и `Agent Grid` по-английски.
- экран входа — `Login_OrCredentials`.
- `/widget-catalogue` — **79 латинских слов, витрина английская целиком.**
- чистые по обеим иглам: `/reports`, `/admin/categories`, `/admin/permission-groups`.

## 5. ЧТО Я НАМЕРЕННО НЕ НАЗЫВАЮ ДЕФЕКТОМ

Разделить подпись и данные по виду строки нельзя, и я этого не делаю:
- `/admin/audit` — 12 латинских значений (`Login Success`, `Dashboard Created`, `WidgetsUpdated`):
  может быть машинный код события.
- `/admin/configuration/metrics` — 79 латинских слов: это имена метрик и их `DisplayName`,
  справочник, а не интерфейс.
- названия подразделений (`Israel`, `Main Office`, `Aman-Maint`) — данные арендатора.
- `Everyone`, `Nobody`, `Editor`, `Viewer`, `local` — **похожи на подписи, но не проверены.**

## 6. ЧЕГО В ЭТОМ СПИСКЕ НЕТ — назвать, чтобы не считать его полным

- не пройдены страницы `supergroups`, `sites`, `platform/tenants`;
- из шести экранов открыт один (`Presentation1`);
- **не открыт НИ ОДИН диалог, модальное окно и форма редактирования** — а `ScreenEditorPage`,
  худший по обоим приборам, живёт именно там;
- `.cs`-файлы просмотрены только на предмет ключей `L[`, не на предмет зашитых строк в коде;
- сообщения об ошибках и валидации не проверялись вовсе.

## 7. ПОРЯДОК, ЕСЛИ КРУГ ОТКРОЮТ — предложение, не решение

1. **155 недостающих ключей `he-IL`** — это ОДНА работа над файлом ресурсов, закрывающая разом
   почти весь §1. Дешевле всего и снимает больше всего видимого.
2. **4 ключа, которых нет нигде** — они сломаны и в английском тоже.
3. **`InfoSlots` целиком** — единственная функция, где нет перевода ни в одном месте.
4. **Зашитые литералы** по §3, начиная со `ScreenEditorPage`.
5. **Три виджета без локализации** (`AgentStatus`, `Kpi`, `QueueSummary`).
6. `ru-RU` отстаёт на 60 ключей — **отдельный вопрос оператору: поддерживаем ли мы русский вообще.**

— `coordinator-0917`, 2026-09-19
