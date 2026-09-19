---
role: shell
project: RTM View Shell
version: 0.2
last_verified: 2026-08-31T11:30:00Z
owner: shell
reviewer: curator
---
# role-shell — RTM Shell / UI-UX role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (git log src/CcDashboard.Web/ + .coord/journal.md shell/web lines + .claude/memory), NOT
> session narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
### ⛔ ЧП / EMERGENCY MODE — ACTIVE (declared 2026-06-25 coordinator-0624; REMOVE on operator lift)
Release is bug-ridden (dashboards) + the reports version blocking its fixes is in catastrophic state → emergency until the operator lifts ЧП.
1. NO corner-cutting; ANY detail (ESPECIALLY visual) = critically RED — every defect is a blocker, no "minor".
2. NO decision around the coordinator; every fork → coordinator → operator (ONE at a time, by importance, plain language).
3. NO unsanctioned runs: do NOT hand the operator a chat CC run-prompt code-box UNTIL the coordinator's §4 bless.
4. Coordinator PERSONALLY visual-verifies EVERY closed gap (not object-store/report alone).
5. Verify on REAL prod-mirror data (234 backup, RTSData_*); our env = a FROZEN data-mirror of prod; our migration package = our migrated DB. One-time seed from the backup.
6. Protocol shorthand: `.` = `коорд: входящие`; `..` = "check the result" (specs know it).
7. Coordinator + operator steer the recovery out of the dive.

Role: Blazor Server UI — widgets (Components/Widgets/), dashboard editor (ScreenEditorPage), configurator modals,
drag-and-drop layout (widget-resize.js), dark-mode, i18n, CSS.
Claim: src/CcDashboard.Web/ (Components, Pages, wwwroot/js, wwwroot/app.css, Resources/*.resx).

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **Widget rendering lives in `Components/Widgets/*.razor`; the DISPATCH lives in
   `Components/Dashboard/RenderWidget.razor`** — 7 widget tags (AgentGrid, AgentStateDistribution,
   DataSlot, DayTrend, InfoSlot, QueueGrid, Wfm). ScreenEditorPage/ScreenFullscreenPage/ReportEditorPage
   render `<PlacedWidget>`/`<RenderWidget>`, they do NOT dispatch widget types themselves.
   · SOURCE: §C-4 2026-08-31 (`git show v3:...RenderWidget.razor | grep -cE '<[A-Za-z]+Widget\b'` = 7)
   · SUPERSEDED 2026-08-31: the old line "ScreenEditorPage dispatches ... 39 widget dispatches in
     ScreenEditorPage.razor" is WRONG — the store shows 2 `<PlacedWidget` + 1 `<RenderWidget` there and
     zero widget-type tags. Found by the rewritten §C; the CODE wins (§A rule "Reality wins — update me").

2. **Drag-and-drop layout via `wwwroot/js/widget-resize.js`.**
   8-way resize handles + draggable modals by header.
   · SOURCE: b5ef8c3 (resize from all 8 sides), widget-resize.js

3. **Dark mode via `.dark-mode` class in `wwwroot/app.css`.**
   97+ rules scoped to `.dark-mode`; toggle applies class to body.
   · SOURCE: 5acf274 (9 dark-mode gaps), 60c01df (generic selector), app.css

4. **RTM relay via `IRtmRelayService` injection.** Widgets subscribe for live data.
   `InvokeAsync(() => StateHasChanged())` pattern for UI updates.
   · SOURCE: CLAUDE.md §34, 4 IRtmRelayService injections, 12 InvokeAsync uses in widgets

5. **localStorage keys MUST include UserId and use `cc:` prefix (§41).**
   Clear on logout via `ccApp.clearLocalStorage()`.
   · SOURCE: CLAUDE.md §41, 15387fc (localStorage security), app.js

6. **i18n via `.resx` files (en-US, ru-RU, he-IL).** `@L["Key"]` pattern.
   · SOURCE: CLAUDE.md §22, 3 .resx files in Resources/

7. **Searchable dropdown with pre-selected value: clear search on focus.**
   Otherwise dropdown shows only matching item.
   · SOURCE: .claude/memory/daytend-implementation-insights.md (BU dropdown bug)


**DoD — MANDATORY self-verification after EVERY change (operator 2026-06-24, no exceptions):**
- ALWAYS via Soma (host-Chrome §47: tab 127.0.0.1:5199/health -> same-origin fetch with Bearer): run **/ops/build** (0 errors) + **/ops/test?suite=unit** (0 failed) AND check the **Shell log** (`/logs/tail?source=serilog` — scan [ERR]/[FTL]/[FATAL]) + `/ops/health`. Build+unit+log together = the per-change DoD; the binding RESULT carries all three lines.
- When the change ADDS/MODIFIES GRAPHICAL/UI functionality: a **MANDATORY VISUAL check via Chrome** is required — open the affected page in host-Chrome, confirm the change renders correctly (light+dark, the edited widget/screen), screenshot/read-page as evidence. A green build is NOT sufficient for UI work.
· SOURCE: operator directive 2026-06-24 (after Ф3 I ran build+unit but skipped the shell-log; operator corrected).

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-05-27 · DayTrend BU dropdown showed only 1 item — search field pre-filled → clear on @onfocus · SOURCE:daytend-implementation-insights.md · status: active
- 2026-06-06 · preassignedGridId not set on DataSlot save → GridId=NULL in RTS Row → widget showed no data · SOURCE:aae6b8f · status: active
- 2026-06-06 · DataSlot BU not saved to RTS Row (UnionId=NULL) — SelectBusinessUnit must update ConfigDataSlotBusinessUnitId · SOURCE:a20b591 · status: active
- 2026-06-07 · dark-mode gaps in configurator modal (9 fields) — use generic .dark-mode input selector · SOURCE:5acf274, 60c01df · status: active
- 2026-06-09 · F-1 metrics read-only — remove client create/edit/delete; vendor-deploy only · SOURCE:b7b20e4 · status: active
- 2026-06-16 · F-A alignment guides: cache other widget rects at drag-start (not per-mousemove) to avoid O(n) layout thrash · SOURCE:9734252, widget-resize.js:cacheAlignTargets · status: active
- 2026-06-17 · JS canvas selectors must match RENDERED class — widgets are .dashboard-widget not .widget (ScreenEditorPage.razor:190); wrong selector silently no-ops (drag works, feature dead). + always hideGuides() on drag-end or lines stick. · RULE: grep actual razor class before querySelectorAll; pair show-guide with drag-end hide. · SOURCE: widget-resize.js:102+onMouseUp; 9734252 broke, fixed THIS. · status: active
- 2026-06-17 · Claimed build 0 err WITHOUT running dotnet build; committed non-compiling code (CurrentUser used w/o @inject ICurrentUserAccessor) — 2nd unverified build/works claim today. · RULE: a build 0 err claim MUST cite an ACTUAL dotnet build run; object-store marker-verify is NOT compile-verify. · SOURCE: ScreenEditorPage.razor:2263 + @inject L4-7; d83517c broke, fixed THIS. · status: active
- 2026-06-17 · Dual source of truth for CSS state class: Blazor binding clobbers JS classList.add on re-render. · RULE: pick ONE owner for dynamic class (prefer Blazor for persistence across re-render); if JS sets class, Blazor binding must reflect same state or not bind at all. · SOURCE: ScreenEditorPage.razor:194 bound .selected from SelectedWidgetId not SelectedWidgetIds (multi-set). · status: active
- 2026-06-17 · Routed DOM-event-dependent JS fn (startMarquee, needs real e.target) through Blazor @onmousedown -> serialized MouseEventArgs has e.target as string -> TypeError + fired on bubbled widget mousedowns -> broke marquee AND drag. · RULE: DOM-event-dependent canvas handlers must bind a real JS DOM listener in init(), not route a serialized MouseEventArgs through Blazor. · SOURCE: widget-resize.js:92 e.target.classList undefined on serialized obj; d905a38 broke, fixed THIS. · status: active
- 2026-06-17 · A mousedown+mouseup drag (marquee) also fires a trailing click -> a click-deselect handler wipes the just-made selection. · RULE: a drag-gesture's terminal click must be suppressed for handlers that treat click as a plain action (use a consume-once flag). · SOURCE: OnCanvasClick cleared SelectedWidgetIds after finalizeMarquee; d905a38 (CC-2b) + 4cef9ea (FIX1) broke, fixed THIS. · status: active
- 2026-06-17 · Viewer scale-to-fit: wrap canvas in fixed-size design-layer (bounding box of widgets), scale with transform:scale(min ratio) + center via margin offsets; add resize listener + REMOVE in dispose. · RULE: for uniform responsive zoom, use a fixed coordinate-space container scaled by CSS transform; always clean up window resize listeners. · SOURCE: ScreenFullscreenPage.razor design-layer wrapper + viewerScale.init/dispose. · status: active
- 2026-06-23 · Blazor date<input>/DateTime.Today bind Kind=Local/Unspecified; Npgsql 8 THROWS writing them to a timestamptz filter; a bare catch made every report silently empty. RULE: SpecifyKind(Utc) at the query chokepoint + UtcNow.Date defaults; NEVER a bare catch in a data-load path — Logger.LogError(ex). · SOURCE:9c63ba4 · status: active
- 2026-06-23 · Date-range UI 'To' is a whole-day bound but the repo filters IntervalStart < to -> exclusive upper drops the To day (default today-7..today hides TODAY). RULE: for an inclusive To against a `< to` query, pass To.Date.AddDays(1) as the exclusive upper; shift the bound passed, not the repo predicate. · SOURCE:THIS COMMIT (F-QA-1) · status: active
- 2026-06-24 · After Ф3 I cited build+unit GREEN but had NOT checked the Shell runtime log; operator flagged it. RULE: per-change DoD = Soma /ops/build + /ops/test(unit) + serilog [ERR]/[FTL] scan + /ops/health; for ANY UI change ALSO a visual Chrome check (render light+dark) — build-green alone is insufficient for graphical work. · SOURCE: operator directive 2026-06-24; Ф3 7687377 shell-log check. · status: active
- 2026-06-24 · Ф3 (7687377) added a UI component (RenderReportWidget) + report-scoped CSS but it is NOT mounted on any route -> nothing renders yet; per operator the MANDATORY visual Chrome check is DEFERRED to Ф5 (first phase that mounts it on /reports edit). RULE: the visual-Chrome gate binds to the phase where the component is actually rendered; carry it into Ф5's DoD. · SOURCE: operator 2026-06-24. · status: active
- 2026-06-25 · Soma has TWO confusable ports (tools/Soma/appsettings.json): Soma:Port=5199 = SOMA's own listener -> GET http://localhost:5199/health (no auth) {ok:true} = Soma-alive; Soma:Shell.HealthUrl=http://localhost:5238/health = the SHELL dev-http port that Soma PROBES for /ops/health (Shell binds https:5239+http:5238; Soma does NOT listen on 5238). RULE: verify Soma-alive ONLY via 5199; /ops/health up:false = SHELL down (or Redis 503), NOT Soma. Cold `dotnet run` in tools/Soma can take >30s -> don't declare down after ~12s; read tools/Soma/out.log 'Now listening on: http://localhost:5199'. · SOURCE: coordinator 2026-06-25 (I mis-declared Soma down on a wrong-port/cold-start probe). · status: active
- 2026-06-25 · OPERATOR STANDING RULE: when building ANY new visual functionality, ALWAYS align to the analogous existing component/screen, OR present forks-with-proposals to the operator — never invent a one-off look. The product must be visually homogeneous (colour tokens, button variants, dark-mode palette, spacing, badges, icons, empty/loading states). Audit new UI against the analogue + ux-ui-expert skill BEFORE shipping. · RULE: new-UI parity-check is mandatory, not optional. · SOURCE: operator directive 2026-06-25 (reports diverged from dashboards: in-shell View, missing +/tabs/gear, slate date-fields, low-contrast dark buttons, green-vs-blue Save). · status: active
- 2026-06-25 · OPERATOR OPERATING MODEL: I (shell+coordinator) author → §4-bless → hand the operator a ready copy-paste command (`Выполни задачу из файла tools/<name>.md`, §0.7 NORM-CUR-02); operator only LAUNCHES; post-run разбор/verify is MY job (object-store + seal), not the operator's. ESCALATION RULE: in-bless (result matches the §4-PASS prompt, scope unchanged) → just verify+seal, NO re-escalation; on DOUBT (deviation / scope grew / new bug / new fork) → route to coordinator (§4 / decision) before proceeding. Only true PRODUCT forks go back to the operator. · SOURCE: operator directive 2026-06-25. · status: active
- 2026-06-25 · SOMA/SHELL OPS — ANTI-PATTERNS (I stumbled: fired /ops/build while /shell/start was still building → TWO concurrent dotnet builds on the same project → obj/bin MSBuild lock contention → BOTH hung ~2min → runtime clinch, needed operator Soma restart to kill stuck procs). HARD RULES, what NOT to do: (1) NEVER run two build-class Soma ops at once — /shell/start, /shell/restart, /ops/build ALL invoke `dotnet` build of the same project; only ONE at a time; wait for the in-flight one to return or time out before firing another. (2) /shell/start (and /restart) ALREADY compiles+launches → it IS the compile proof; do NOT fire /ops/build to 'check compile' while a start is in flight (redundant + harmful). Need a compile verdict while bringing the Shell up? Just await start's {healthy:true}=compiled / or its failure. (3) Cold build after several commits = 60–120s+; `pending` is NORMAL — be patient, do NOT escalate to a second op out of impatience. (4) Do NOT churn the Shell needlessly: /ops/build against the operator's LIVE `dotnet watch` host bounces it; every /shell/start|restart CLEARS the auth session → forces operator re-login. Prefer live render (watch hot-reloads); only (re)start when the Shell is actually DOWN. (5) Object-store verification needs NO runtime — when the §4-prompt result is already object-store-GREEN, do NOT risk runtime churn for an OPTIONAL visual; gate any Soma build/start op behind 'is this necessary right now?'. · SOURCE: this session 2026-06-25 — /ops/build-over-/shell/start clinch + earlier /ops/build-vs-live-watch bounce + repeated restart→re-login. · status: active
- 2026-06-25 · Visual-check PREP runbook — MANDATORY before ANY authed-visual / VISUAL-gate run: **docs/Visual-Test-Preflight.md** (devops, canonical EN). TWO profiles: **A = WITH rebuild** (POST /ops/build → verify success → POST /shell/restart → gate); **B = current running version** (gate only). SHARED preflight GATE: Chrome up → Soma /health :5199 ({ok:true}) → Shell /ops/health liveness.up → Restart-Shell ×3 → Start Visual Check; per-terminal-node escalation wording (Chrome down / Soma down / Build failed / Shell-start problem) in the doc. Two-port caution (5199=Soma vs 5238=Shell-probe) + F-QA-4 kill-guard (7ce8825) referenced. Run this BEFORE every visual check. · SOURCE: docs/Visual-Test-Preflight.md (devops 2026-06-25) · status: active
- 2026-06-26 · FIX-A had all init/startMove/startResize tokens present but ``widgetResize.init`` was guarded by ``&& Report is not null``, false at firstRender (Report still loading in OnInitAsync) -> init NEVER ran -> move/resize silent-dead. RULE: an init that attaches document listeners must run on ``firstRender`` UNCONDITIONALLY (match the working analogue), never gated on async-loaded state. A JS-interactivity fix is only 'done' after a LIVE operator move+resize, never a token-grep (object-store tokens present != functional). · SOURCE:424a5d1 + coordinator live gate 2026-06-26 · status: active
- 2026-06-26 · Visual parity is NOT proven by object-store: FIX-C had all the Appearance fields/braces present but a double-nested grid (.rw-color-grid wrapping .color-setting-row-dual, both 3-col) collapsed the layout. When the brief says 'identical to <existing component>', mirror its EXACT container structure/classes — do NOT invent a new wrapper grid; and a layout claim is only done after a LIVE side-by-side visual. · SOURCE:8545943 + operator screenshot 2026-06-26 · status: active
- 2026-06-26 · A modal/overlay rendered OUTSIDE the page's .dark-mode wrapper must carry the dark class ON ITSELF (self-class via a DarkMode param), like the dashboard's ``.editor-modal @(_darkMode?...)``. Ancestor-based ``.dark-mode .X`` dark rules silently never match for fixed/overlay elements outside the wrapper. RULE: pass DarkMode into every overlay component + use self-class selectors (``.X.dark-mode`` not ``.dark-mode .X``). · SOURCE:1981513 + operator 2026-06-26 · status: active
- 2026-07-02 · PROJECT JS (js/*.js) was NEVER cache-busted in App.razor — only app.css/tokens.css carry ?v. Any JS change (e.g. viewerScale.resetToActual) ships STALE to returning browsers → a razor call to the new JS fn throws JSException → UNHANDLED in an async event handler → Blazor circuit TERMINATED ('No interop methods registered for renderer N' is the dead-circuit downstream symptom). FIX: add ?v to project JS includes (bump on every JS change) AND wrap viewer JS-interop in try/catch so a stale/missing JS fn degrades, not crashes. · RULE: JS scripts must be cache-busted like CSS; JS interop must be guarded against missing functions. · SOURCE:App.razor:37-42 + df95ff3 widget-resize.js + dee401e fix · status: active
- 2026-08-31 · ENTRANCE TEST Q2(б) FAIL: I asserted "`git add` warned `paths are ignored by .gitignore` -> the work is DEFINITELY lost; the N committed files are OTHER, non-ignored files". Both halves wrong. `.gitignore` filters only UNTRACKED paths: a path already in the index is exempt, plain `add` takes its changes, no `-f`. So the warning is a positive fact about the LISTED paths only — never about the directory, the tracked files under it, or the commit that followed. Verified in one line, which I had not run: `grep -n '\.claude' .gitignore` -> `49:.claude/` AND `git ls-tree -r --name-only v3 .claude | wc -l` -> `58`; both true at once, neither derivable from the other. Split it: b-1 new path under an ignored dir = dropped, work lost; b-2 tracked path = committed, nothing lost. Cost of the INVERSE error (mine) is worse and counter-intuitive: "lost" leads to restore, and restore WRITES (`git show HEAD:<f> > <f>`) — over someone else's newer edit, irreversibly and traceless — whereas a missed loss leaves the work on disk. · RULE: a claim about a MECHANISM must be pinned by a command exactly like a claim about STATE; "I know how git works" is a memory, not knowledge, until a prong is run. Predicate for "did it reach the repo": `git ls-files --error-unmatch -- <path>` then `git hash-object -- <path>` vs `git rev-parse <branch>:<path>` — never the wording of a warning. NB: `CLAUDE.md:3043` states the b-1 special case as general ("anything under `.claude/` requires `git add -f`") — 3 of 4 roles fell for it; verifying the predicate is my duty regardless of what the norm says. · SOURCE: curator verdict 2026-08-31 (FAIL + re-sit PASS), `.coord/shell-reconstitution-test.md` · status: active
- 2026-08-31 · `git check-ignore` CONSULTS THE INDEX by default: on a TRACKED path it prints nothing and exits 1 ("not ignored"), while `--no-index` prints the matching rule for the same path. Raw, git 2.34.1: `git check-ignore -v -- .claude/skills/role-shell/role-shell.md` -> silence, exit 1; the same on a non-existent sibling path -> `.gitignore:49:.claude/`, exit 0; `--no-index` on the tracked one -> `.gitignore:49:.claude/`, exit 0. Three true answers to three DIFFERENT questions about one directory. `--no-index` shows what the RULE WOULD SAY, not what will happen to the file — as a "is it lost?" criterion it raises a false alarm on every tracked file (and false alarm -> restore -> overwrite, see the lesson above). Same class as the curator's own four-line `check-ignore` misread: the volume/appearance of output taken for its meaning. · RULE: never read ignore-status as commit-status; ask `git ls-files --error-unmatch` / `git rev-parse <branch>:<path>` instead, and if `check-ignore` is used at all, read the printed RULE and the exit code, not the fact that it printed. · SOURCE: my own runs 2026-08-31 (re-sit); curator took it into the canon with attribution. · status: active

- 2026-09-06 · Отправив отчёт координатору, я на следующий поке доложил о НЁМ ЖЕ — а ответ и новое задание уже лежали в моём инбоксе ниже той записи, которую я помнил. Отвечал на закрытый вопрос. · RULE: инбокс перечитывается ДО ХВОСТА файла, а не до последней помнимой записи, и именно ПОСЛЕ отправки своего отчёта — между моей отправкой и моим следующим ходом координатор успевает ответить. «Я доложил» не равно «мне нечего делать»; предикат — `grep -n '^## ' <inbox> | tail`, а не память. · SOURCE: coordinator-0830 поке 2026-09-06T~08:1xZ, `.coord/inbox/shell.md:2354` (задание лежало на :2314) · status: active

- 2026-09-06 · Замер раскладки: реальная ошибка такого предиката — не кривое число, а ПРОМАХ СЕЛЕКТОРОМ: запрос не находит узел, снимок молча отдаёт нули, и «масштаба нет» неотличимо от «я не туда посмотрел». · RULE: у DOM-снимка негативный контроль обязан быть подобран под ЭТУ ошибку (`matchCount` на каждый селектор + заведомо несуществующий селектор обязан дать 0), и рядом обязан стоять ПОЗИТИВНЫЙ контроль «умею находить ненулевое» (временный зонд с заранее известным `transform`), иначе ноль — это молчание, а не измерение. Зонд снимается в `finally`, а факт снятия ПЕРЕ-ЗАПРАШИВАЕТСЯ из DOM и служит условием годности файла, а не полем в нём. · SOURCE: coordinator-0830 §4 2026-09-05/06; `tools/measure_viewedit_layout_v2.js` · status: active
- 2026-09-06 · PR234-VIEWEDIT-01: подсказка координатора про RTL/`viewerScale` оказалась ЛОЖНЫМ СЛЕДОМ — `direction: rtl` идентичен в обоих режимах. Развилка была не в RTL, а в том, что просмотр вписывает содержимое масштабом (`.fullscreen-design-layer` = `matrix(0.437…)`), а редактор не имеет вписывания вовсе (`transform: none` по всей цепочке). · RULE: чужая версия (даже координаторская) пришпиливается как ФАКТ О КОДЕ и не проверяется вместо замера; первый замер меряет фактическую раскладку, а не гипотезу. · SOURCE: `.coord/measure/viewedit-0905/` · status: active
- 2026-09-06 · Оси холста редактора были в РАЗНОМ состоянии, и одна проверка это скрывала: по горизонтали `scrollWidth == clientWidth == 972` (прокрутки нет вовсе), по вертикали `scrollHeight 1036 > clientHeight 956` (прокрутка есть, но не хватает). Единственный критерий по ширине дал бы зелёное при живом дефекте вниз. · RULE: если правка задаёт обе оси — обе и меряются; критерий формулируется ДО правки и по каждой оси отдельно. NB: часть этого добыта ПЕРЕСЧЁТОМ уже снятых файлов, без нового прогона — снимок стоит делать шире вопроса. · SOURCE: coordinator-0830 уточнение 2026-09-06; пересчёт `viewedit-*-1788676*.json` · status: active
- 2026-09-06 · Оператор сказал «готово», но прогнал базовый снимок снова на БОЕВОЙ, хотя условие требовало локальную: предикат — поле `url` ВНУТРИ файла, а не слово «готово» и не то, что файлы легли в нужную папку. · RULE: у каждого принятого артефакта проверяется, что он снят там, где требовалось (среда/ветка/экран), прежде чем он становится базовой линией. И: базовая линия «до» обязана ВОСПРОИЗВЕСТИ дефект — не воспроизвёлся, СТОП, а не «ну похоже же» (в тот же день на этом сломался backend). · SOURCE: `viewedit-v2-*-1788678*.json`; coordinator-0830 2026-09-06T~09:4x/10:1x · status: active

- 2026-09-13 · Прочитал ОТСУТСТВИЕ строки в коде как отсутствие механизма: заявил координатору, что union-соединение строится «без `ServerTimeout`/`KeepAlive`, всё висит на `Closed`» — а это УМОЛЧАНИЯ клиента SignalR (30 с / 15 с), они работают без явной строки; неверна была только часть про `WithAutomaticReconnect` (его правда нет). Это тот же класс, что ночной промах координатора «нет строк в логе, значит канал молчал», только про исходник. · RULE: отсутствие настройки в коде — это факт о КОДЕ, а не о поведении; прежде чем строить на нём вывод, назвать умолчание библиотеки (или проверить его) ровно так же, как проверяется наличие. Снимать своё утверждение до того, как на нём построят решение, — часть правки, а не вежливость. · SOURCE: `.coord/inbox/coordinator.md` 2026-09-13 (мой отзыв) + приёмка coordinator-0912 11:4xZ, `RtmRelayService.cs:181-185` · status: active
- 2026-09-13 · `PR234-SHELL-RESUB-01`: путь пере-подписки после обрыва в коде ЕСТЬ (`ReconnectUnionWithBackoffAsync:260 -> InitUnionAsync`, а `RTMHub.init:114` сам зовёт `AddGridConnection -> getUsers`), но цикл может выйти насовсем при `refCount == 0` (`:234`, грид `:592`), НЕ обнулив `state.Connection`, а `Subscribe` строит новое соединение только при `null` (`:110`, грид `:459`) — мёртвый объект переиспользуется вечно, перезагрузка вкладки не лечит. · RULE: если объект соединения живёт в словаре дольше своего канала, «подписан» перестаёт значить «получает»; у каждого пути выхода из ретрай-цикла проверять, что он оставляет после себя, и предикат жизни брать по `HubConnectionState`, а не по `!= null`. Симметричный код (union/grid) чинится одним дифом сразу — иначе второй путь вернётся отдельным предметом. · SOURCE: `v3` RtmRelayService.cs; замер devops-0912 13.09 (`<<getUsers` 0 в окне при наполненных союзах); §4 coordinator-0912 11:4xZ · status: active

- 2026-09-13 · Второй прогон по ТОМУ ЖЕ файлу промпта ответил «Task already completed in this session», перечислил шесть мест уже внесённых правок и предъявил `Build 0 errors, 283/283` — при этом диск не изменился ни на байт (`hash-object` тот же `9cbf66c8`, mtime тот же 11:56, `grep -c staleToDispose` = 0), а `CcDashboard.Infrastructure.dll` в дереве датирован ПРЕДЫДУЩИМ днём (12.09 18:24), то есть сборки, накрывающей правку, не было вовсе. Промпт при этом СОДЕРЖАЛ раздел «файл уже несёт правки 1,2,4 и раннюю форму 3, меняй только расхождение» — оговорки оказалось мало против узнавания задачи целиком. · RULE: правка-дельта выдаётся ОТДЕЛЬНЫМ файлом промпта, а не дописывается в уже исполнявшийся: переиспользованный файл провоцирует ответ о ПАМЯТИ сессии вместо утверждения о файле. У каждой задачи обязан быть входной пин (ветка + `hash-object` диска, не сошлось — СТОП) и выходной СЧЁТНЫЙ предикат (`grep -c <новый маркер>` = N), чтобы «уже сделано» проверялось, а не заявлялось. Числа сборки принимаются только против даты артефактов (`bin/**/<Project>.dll` новее правки), иначе это число из чужого прогона. · SOURCE: прогон 2026-09-13 12:1x по `tools/cc_prompt_shell_relay_resub.md`; мои замеры диска и артефактов; `tools/cc_prompt_shell_relay_fold_a.md` как исправленная форма · status: active

- 2026-09-13 · Я задал в промпте выходной предикат `grep -c staleToDispose = 2`, а верный ответ на ВЕРНОМ коде — 8: `grep -c` считает СТРОКИ, а маркер стоит в блоке четырежды (объявление, присваивание, проверка, вызов) × 2 блока. Исполни прогон мой предикат буквально — объявил бы провал на исправной правке. В том же ходе я оценивал наличие сборки по дате **Debug**-dll и обходом `find src -path '*/obj/*' -o -path '*/bin/*'` БЕЗ скобок (в такой записи `-type f` относится только ко второй ветке) — Soma же собирает в **Release**, и артефакты 13.09 12:22 там были. · RULE: счётный предикат калибруется на ЗАВЕДОМО верном образце до того, как попадёт в промпт («сколько это даст, если всё сделано правильно?»), и считать надо уникальную строку-якорь (объявление), а не любое вхождение имени. Предикат по артефактам сборки называет КОНФИГУРАЦИЮ (Debug/Release — Soma собирает Release) и проверяется на группировку: `find A -o B -type f` без скобок — не то выражение, которое имелось в виду. Ложно-красный от собственного прибора стоит дороже чужого: он заставляет чинить исправное. · SOURCE: мой промпт `tools/cc_prompt_shell_relay_fold_a.md` §DoD-1 vs факт (8); коммит 531cf31; артефакты Release 13.09 12:22 · status: active

- 2026-09-13 · `§A` DoD требует прогонять build/unit «ALWAYS via Soma», но Soma слушает host loopback `127.0.0.1:5199`, а песочница CC туда не ходит — CC-прогон остановился на этом, сверив пины и не тронув ничего. То есть пункт DoD для CC-прогонов невыполним ПО УСТРОЙСТВУ, а не по обстоятельствам, и всё, что раньше «предъявлялось через Soma» из CC, шло каким-то другим путём (вероятно прямой `dotnet build`; из object store происхождение сборки не выводится — держу гипотезой). · RULE: требование к ДОКАЗАТЕЛЬСТВУ не привязывается к одному инструменту — доказательством служат даты артефактов (`bin|obj/<Config>/**` новее правки) и числа раннера, кем бы они ни были получены; инструмент называется как допустимый, а не как единственный. Пункт `§A` под вопросом помечается и несётся куратору (владелец скилла я, ревью его), а не правится молча. · SOURCE: прогон `tools/cc_prompt_shell_unit_gate.md` rev 1, 2026-09-13; `§A` DoD; Release-артефакты 13.09 12:22 при недостижимой Soma · status: active

- 2026-09-13 · Замер приёмки `PR234-SHELL-RESUB-01` дал ИГЛЫ (`<<getUsers unionId=21`, `Groups.Add u21`, по одной) в валидном окне (маркеров старта Shell в окне 0), и по букве предиката это зелёное. Но последовательность показала: иглы произвела ПЕРВАЯ подписка нового клиента в 22:20:43 — через три минуты после рестарта движка, — а в момент самого рестарта в Shell не было подписано НИЧЕГО. Подтверждено отрицательно четырьмя литералами разом: `connection closed` / `reconnecting tenant` / `reconnected tenant` / обе новые строки правки — все 0, ветке пере-подключения нечего было переподключать. · RULE: предикат приёмки обязан содержать проверку ПРЕДУСЛОВИЯ опыта (здесь — живая подписка, существующая ДО возмущения и пережившая его), и она проверяется в корпусе ДО чтения игл; предикат, различающий только зелёное и красное, третий исход «условие опыта не создано» прочитает как зелёное. Нули по литералам неисполнявшейся ветки — не свидетельство против неё, а отсутствие свидетельства. · SOURCE: `.coord/measure/resub-0913/acceptance-counts.md`; корпус `.measurements/234_20260913_2217_*`; окно T2 22:17:52 · status: active

- 2026-09-14 · T3 дал «движок молчит»: `init GridId=` / `Groups.Add` / `<<getUsers` по нулю при том, что Shell в 23:59:46.544 позвал `init union 21`. Причина не в движке, а в СРЕЗЕ: поданный файл начинается в 00:00:00,063 — на 18 секунд ПОЗЖЕ события, потому что `RollingFileAppender` движка настроен `rollingStyle=Date` / `datePattern=yyyyMMdd` / `staticLogFileName=true` и лог укатился в полночь, а опыт прошёл в 23:59:46. Побочный признак, который сам по себе должен был насторожить: `RTM Start` = 0 в файле, якобы начавшемся с рестарта. · RULE: у КОРПУСА проверяется покрытие события до чтения игл — первая и последняя метка времени файла против времени события; при работе около полуночи (или около любого переката) в корпус берётся И предыдущий датированный файл, а политика переката читается из конфига аппендера, а не предполагается. Ноль в срезе, не покрывающем событие, не читается ни как зелёное, ни как красное. · SOURCE: `.measurements/234_20260913_T3_engine-window.txt` (первая строка 00:00:00,063 против рестарта 23:59:41.795); `RTM/deployment/log4net.config`; `.coord/measure/resub-0913/acceptance-counts.md` · status: active

- 2026-09-14 · T3b: Shell залогировал `reconnected` и `init union 21, serverTimeOffset=-0.9 ms` (то есть `InvokeAsync("init")` ВЕРНУЛ разобранное время сервера, вызов не бросил), а наш движок в ту же секунду не записал ни `OnConnected`, ни `init GridId=`, ни `Groups.Add`, ни `<<getUsers` — при доказанном матчере и при том, что `RTMHub.cs:122` пишет `init GridId=` безусловно. Значит на наш `init` ответил ДРУГОЙ процесс, и он на той же машине (расхождение часов 0,9 мс); на 234 стоит второй продукт `C:\Program Files\CcDashboard`. · RULE: успешный ответ от хаба доказывает, что ОТВЕТИЛ КТО-ТО, но не то, что ответил ожидаемый процесс; при двух установках одного продукта на машине адресат проверяется отдельно — значением `SignalRConnectionUrl` и тем, чей PID слушает этот порт, а не тем, что вызов вернулся. Расхождение часов в ответе — дешёвый признак «отвечал сосед по машине». И: владелец предмета не назначается по правдоподобию — гонка `RTMHub.cs:92-101` снята как кандидат, потому что предполагает исполнение хаба, а до хаба не дошло ни строки. · SOURCE: `.measurements/234_20260913_T3b_engine-preroll.txt`; `.coord/measure/resub-0913/acceptance-counts.md`; `RTMHub.cs:95,122`, `Engine.cs:1328` · status: active

- 2026-09-14 · Корень суточного разбора `PR234-SHELL-RESUB-01` оказался вне кода: наш Shell был соединён с ЧУЖИМ движком `C:\IceDash\RTM\RTM.exe` (pid 3576, порт 8088) — пять сокетов 50321..50325 совпали поимённо с секундой моих `reconnected`/`init union 21`, а у нашего RTMService установленных соединений было ноль. Отсюда же и признак, который я назвал раньше причины: ответ пришёл с расхождением часов 0,9 мс, то есть от соседа по машине. · RULE: у пере-подписки два предусловия, а не одно: подписка ЕСТЬ и подписка АДРЕСОВАНА НАМ (сокет: RemotePort наш, PID на серверной стороне наш) — второе проверяется сокетом, а не строкой в БД. И отдельно, механика моей территории: `GetHubUrlAsync` читает адрес хаба из Redis-кэша на 5 минут ПЕРЕД БД, а соединение пересоздаётся только после падения старого, — значит смена адреса в БД НЕ переводит уже подключённый Shell на новый порт, пока старый сервер жив; переезд требует освобождения состояния (закрыть вкладку -> 30-секундный грейс) плюс истечения кэша. · SOURCE: `.measurements/234_20260914_004335_signalr-owner.txt`; coordinator-0912 01:4x; `RtmRelayService.cs:50-84,110` · status: active

- 2026-09-14 · Правка `2b9de95` целиком в `CcDashboard.Web`; прогон дал `0 failed / 284 passed`, а тестовая сборка НЕ сдвинулась (`Tests.Unit.dll` 10:57 против правки 11:5x, в `tests/` ноль артефактов новее). По моему вчерашнему предикату это ложно-красный «числа чужие» — но `tests/CcDashboard.Tests.Unit.csproj` ссылается на Domain/Application/Contracts/Infrastructure и НЕ ссылается на `CcDashboard.Web`: его сборка и не должна была подвинуться, а зелёные юниты — свидетельство о ДРУГОМ коде и в пользу этой правки не записываются. · RULE: предикат «дата тестовой сборки обязана сдвинуться» действует ТОЛЬКО когда тест-проект зависит от изменённого проекта — проверять `ProjectReference` в `.csproj`, а не одну дату. И шире: зелёный гейт, структурно не способный накрыть правку, не есть свидетельство её правильности; для UI-ветвления единственное свидетельство — визуальная проверка предиката. · SOURCE: `2b9de95`; `tests/CcDashboard.Tests.Unit/CcDashboard.Tests.Unit.csproj`; RESULT прогона в `.coord/cc/shell.md` 2026-09-14T11:57:11Z · status: active

- 2026-09-15 · Я написал в боксе визуальной проверки «запускается Soma и локальный Shell», хотя `docs/Visual-Test-Preflight.md` §2 прямо говорит: Soma — operator-managed daemon, роли её НЕ поднимают (§47), лежит — эскалация оператору. Дефект прошёл мой self-§4 и §4 координатора; поймал его ВОПРОС ОПЕРАТОРА «прогон сам поднимает или поднять заранее?». Shell через `/shell/start` при этом законен — граница проходит не по «запуску» вообще, а по тому, чей это процесс. · RULE: прежде чем писать в бокс запуск ЧЕГО-ЛИБО, свериться с каноническим рунбуком этой операции (`docs/`), а не с собственным представлением о том, что роли можно; «я это уже делал» — память, а не норма. Вопрос оператора о порядке действий — это сенсор на такую ошибку, а не просьба повторить инструкцию. · SOURCE: `docs/Visual-Test-Preflight.md` §2; `tools/cc_prompt_shell_thresh_visual.md` rev 1 `ae2ddf9d` -> rev 2 `2e8fe9f9` · status: active

- 2026-09-15 · На БОЕВОМ конфигураторе Queue Grid я принял поле метрики за поиск и набрал в него текст — поле оказалось редактируемым описанием колонки, ввод попал в данные (`- Messages AAbandonedChatsg First Response Time`). Отменил, из редактора вышел без сохранения, на бою ничего не осталось. Второй факт того же хода, найденный ДО кликов и снявший задачу целиком: на бою стоит `243424e`, а правка `2b9de95` новее на 7 коммитов — визуальная половина «после» там неизмерима по построению. · RULE: на чужой/боевой площадке поведение элемента читается из разметки (`read_page`) ДО ввода, а не предполагается по виду; и перед любым визуальным гейтом первым действием проверяется, что на площадке стоит ИМЕННО проверяемый коммит (`git merge-base --is-ancestor`), иначе снимается состояние другого кода. · SOURCE: прод `platform.insightense.com:8444`, экран `Test2`; `git merge-base` 243424e vs 2b9de95 · status: active

### §B · 2026-09-19 · Счётчик по ДОБАВЛЯЕМОМУ тексту считается в самом тексте, а не прикидывается — иначе свой же прибор останавливает верную работу
В промпте `cc_prompt_shell_popup_edge_fit.md` я задал `grep -c 'ccPopupFit' app.js` 0 -> **2**. Факт после
прогона — **1**: в добавляемом блоке имя стоит ОДИН раз (`window.ccPopupFit = {`), а `.fit` зовут виджеты,
в другом файле. Правка при этом верна вся: после нормализации CR дифф ровно 4 + 4 + 2 + 34 строки, лишнего нет.
Прогон честно встал БЕЗ КОММИТА, как я же и велел («любое расхождение — СТОП»), и правка осталась жить на диске
в одном экземпляре.
**Правило:** ожидание «после» для ДОБАВЛЯЕМОГО текста получается подсчётом вхождений в самом этом тексте
(он у меня перед глазами, я его и пишу), а не оценкой на глаз. Это третий оттенок семьи «предикат не снят
с корпуса»: 13.09 я неверно читал корпус, 17.09 — загрязнил его своим комментарием, здесь — не сосчитал
собственную вставку. Цена та же и знакомая: ложно-красное от своего прибора дороже чужого, оно
останавливает исправную работу.
**Смежное, стоившее бы тревоги:** прогон записал все четыре файла с CRLF при LF в ветке, и построчный `diff`
показал перезапись целиком. Тревогу я не поднял, потому что снял предикат: `.gitattributes` несёт
`* text=auto eol=lf`, и `git hash-object --path=<файл>` даёт тот же хеш, что и LF-версия, — то есть в объект
уедет LF и дифф будет содержательным. Контроль подобран падающий: на имени `x.png` (правило `binary`) тот же
прибор даёт ДРУГОЙ хеш, значит он умеет различать, и совпадение на `.js` — измерение, а не молчание.
Первая попытка контроля (`x.bat`, `eol=crlf`) не падала: `eol=crlf` управляет выдачей в рабочее дерево, а не
тем, что кладётся в объект — контроль надо строить на `binary`, а не на направлении переката строк.
SOURCE: прогон 19.09 по `tools/cc_prompt_shell_popup_edge_fit.md`; мои замеры `hash-object --path`. status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
> **v0.2 2026-08-31 — rewritten to OBJECT-STORE form (NORM-CUR-13).** v0.1 used `Test-Path` /
> `Select-String` against the WORKING TREE — a surface the norm does not trust (PD-007 can hand back a
> truncated file = false FAIL; an uncommitted edit = false PASS) and PowerShell does not exist in the
> Cowork env, so the checks were unrunnable and degraded into a declaration. Fixed here: store as the
> subject, EXPECTED COUNTS (not mere non-emptiness), CONTENT markers instead of `Test-Path`, an explicit
> negative control, a store-vs-mount item, and a reachability item.
> Substitute the branch you are on for `v3`. All items are read-only — never run index-touching git on the mount.

1. **resize/move JS present AND reachable** (`Test-Path` replaced by content markers; §B 2026-06-17: a file
   can exist while the feature is dead)
   `git show v3:src/CcDashboard.Web/wwwroot/js/widget-resize.js | grep -cE 'startResize|startMove'` — expect **>=4** (2026-08-31: 4)
   `git show v3:src/CcDashboard.Web/wwwroot/js/widget-resize.js | grep -c 'dashboard-widget'` — expect **>=1** (2026-08-31: 4)
   The second is the reachability guard: the RENDERED class is `.dashboard-widget`, not `.widget`; a wrong
   selector silently no-ops and the feature is dead with every token present.

2. **dark-mode rules in app.css**
   `git show v3:src/CcDashboard.Web/wwwroot/app.css | grep -c '\.dark-mode'` — expect **>50** (2026-08-31: 147)

3. **RTM relay injected into widgets** (unit = FILES, stated explicitly; v0.1 was ambiguous between lines and files)
   `git grep -l '@inject.*IRtmRelayService' v3 -- 'src/CcDashboard.Web/Components/Widgets/*.razor' | wc -l` — expect **>=3**
   (2026-08-31: 4 — AgentGrid, AgentStateDistribution, DataSlot, QueueGrid)

4. **Widget DISPATCH surface** (this item is what caught §A-1 in 2026-08-31)
   `git show v3:src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor | grep -cE '<[A-Za-z]+Widget\b'` — expect **>=6** (2026-08-31: 7)
   `git cat-file -e v3:src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor && echo EXISTS` — expect **EXISTS**
   `git show v3:src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | grep -c 'dashboard-widget'` — expect **>=1** (2026-08-31: 1)

5. **i18n resources — the three locales BY NAME** (a bare count cannot tell which locale went missing)
   `git ls-tree --name-only v3 src/CcDashboard.Web/Resources/ | grep '\.resx$'` — expect exactly
   `SharedResources.en-US.resx`, `SharedResources.he-IL.resx`, `SharedResources.ru-RU.resx` (2026-08-31: all 3)

6. **Project JS is cache-busted** (§B 2026-07-02: stale JS -> JSException -> terminated Blazor circuit)
   `git show v3:src/CcDashboard.Web/Components/App.razor | grep -cE 'js/.*\?v='` — expect **>=5** (2026-08-31: 5;
   `chart.umd.min.js` is a vendor bundle and is deliberately not versioned)

7. **NEGATIVE CONTROL — the checks must be able to FAIL.** A check that cannot return 0 measures itself.
   `git show v3:src/CcDashboard.Web/wwwroot/app.css | grep -c 'ZZZ-marker-that-must-not-exist'` — expect **0** (exit 1)
   Non-zero here means the grep/pipeline is broken and EVERY count above is uninterpretable — stop and fix the tooling first.

8. **STORE vs MOUNT — PD-007 sensor.** Compare both bodies; never derive one from the other.
   `git hash-object .claude/skills/role-shell/role-shell.md` vs `git rev-parse v3:.claude/skills/role-shell/role-shell.md`
   `git hash-object .coord/protocols/shell-handoff.md` vs `git rev-parse v3:.coord/protocols/shell-handoff.md`
   Equal = the mount copy is the committed one. Differ = say WHICH surface is stale; do not declare
   "corruption" from a mount read alone. A path missing from the tree (`git ls-tree` -> 0) is NOT a
   hash mismatch — it is an uncommitted file, and `hash-object` on it is not a pin at all (nothing to compare against).

## §D REFERENCE  (optional · NOT loaded each init)
Widget implementation patterns: `.claude/skills/widget-creator/widget-creator.md`.
DayTrend polish: `.claude/memory/daytend-implementation-insights.md`.
RTM relay contract: `.claude/memory/rtm-relay-implementation.md`.

2026-06-25 · Declared reports-v1 editor "component-GREEN" from code (CanSave scope-only) + populated Scope picker + bi Columns-optional, while the LIVE editor was functionally broken (drag/resize/multi-add/canvas-error/empty-Thresholds/Appearance-parity all failing) — operator visual NO-GO. · RULE: never sign a feature GREEN without driving the WHOLE user flow live; object-store + partial-visual is necessary but NOT sufficient (= §42.7 functional gate). If automation can't drive the flow (Blazor circuit unresponsive), that is a BLOCKER to claiming readiness, not a reason to fall back on code. · SOURCE:operator visual verdict 2026-06-25 · status: active

### §B · 2026-09-16 · Ранний return убивает ветку, которую я вписал в модель
Разбирая `IsNumericMetric`, я построил модель «тип не совпал → решает откат по имени» и на ней
посчитал 29/135/46 метрик и «ровно две обратные ошибки». В коде стояло
`if (metric != null && ...) return metric.ValueType == "Number" || ...;` — ранний возврат: при
несовпадении типа управление до отката НЕ ДОХОДИТ. Половина моего разбора описывала недостижимый
путь, а заказанная по нему половина приёмки оказалась непроверяемой: кадр совпадал с обеими
версиями кода.
**Правило:** прежде чем считать по ветвлению, пройти его построчно на КАЖДОЙ ветке и выписать, при
каком входе куда попадёт управление. Ранний return и `else if` — первое, что ломает модель.
**И второе:** у каждой половины приёмки спрашивать «каким наблюдением она может ПРОВАЛИТЬСЯ». Если
ответа нет — это не гейт, а ритуал; сказать об этом ДО прогона, а не после зелёного кадра.

### §B · 2026-09-17 · Пустой вывод убитой команды = «ничего нет». Проверять код возврата
`git status --porcelain` на RTM View Shell идёт дольше 60 с (bin/obj в дереве). Под `timeout 60` он был
убит и вернул ПУСТО. Я прочитал это как «дерево чистое» и едва не отчитался, что правки на диске нет —
при том что правка лежала. Пере-снял с `timeout 170` и по конкретному пути: `M src/...`, rc=0.
**Правило:** если пустой вывод команды несёт смысл («изменений нет», «ошибок нет», «совпадений нет»),
печатать и проверять `rc`. Без rc пустота — не измерение, а отсутствие измерения.

### §B · 2026-09-17 · Считающий предикат калибровать по КОРПУСУ, а не по своей картине корпуса
В промпте `FILTER-TYPE` я задал ожидание `grep -c 'ValueType == "Number"'` 1 → 0, посчитав единственным
вхождением то, которое правим. В файле их было ДВА: второе — `GetNumericAgentMetrics:3942`. Прогон честно
остановился без коммита, как я же и велел. Третий случай одной семьи (`staleToDispose = 2` 13.09; модель
ветвления 14.09).
**Правило:** прежде чем писать ожидание счётчика, ВЫПОЛНИТЬ этот самый grep по текущему файлу и взять
число оттуда. Ожидание, выведенное из знания о коде, — гипотеза, а не калибровка.
**Побочная выгода, которую не выбрасывать:** несошедшийся счётчик нашёл два новых места того же дефекта.
Разошедшийся предикат — это находка, а не помеха; разбирать её, а не подгонять цифру.

### §B · 2026-09-17 · Снятие красного — ПРЕДУСЛОВИЕ коммита, если площадка после правки станет починенной
`FILTER-TYPE-01`: я написал промпт с коммитом, зная, что красное на бою не снято, и не сделал его
условием. Для этой семьи правок площадка «до» одноразовая: выкат превращает её в «после», и половина
доказательства исчезает безвозвратно. Обошлось — успел снять красное между коммитом и выкатом.
**Правило:** если предикат может дать красное ТОЛЬКО на непочиненном теле, снятие красного ставится
предусловием коммита в самом промпте, а не пунктом приёмки после него.

### §B · 2026-09-17 · «Страница не отвечает» — измеряемое состояние, а не каприз
Двое суток я писал «конфигуратор не отвечает». Достаточно было снять `performance.now()`: 100 688 392 мс
— документ жил 28 часов, Blazor-цепь давно мертва, при этом `components-reconnect-modal` имел ПУСТОЙ
класс, то есть себя разорванным не считал. После перезагрузки (2 477 мс) всё заработало с первой попытки.
**Правило:** прежде чем объявлять отказ инструмента, снять возраст документа. И: пустой класс
reconnect-модалки НЕ означает живую цепь.

### §B · 2026-09-17 · `s.index(имя_метода)` находит ВЫЗОВ, а не определение. Срез без сверки — не измерение
Я нарезал корпус так: `i = s.index('SeedHistoryMetricsAsync')`. Индекс пришёл 2667 — это вызов в
`SeedAllAsync`; определение лежало на 98084. Срез прошёл через весь ЧУЖОЙ метод и дал числа другого
каталога, которые я подписал правильным именем. На них родился целый ложный предмет
(`DAYTREND-TIMETYPE-01`), и координатор «подтвердил» их, воспроизведя мой же способ.
**Правило:** после любой нарезки корпуса печатать ПЕРВЫЙ элемент блока и сверять с ожидаемым видом
(`ids[:3]` показал бы `MonAgentTalkDuration` вместо `statuslog.*`). Срез без такой сверки — гипотеза
о том, что нарезалось, а не измерение.
**И второе, общее:** согласие двух измерений, сделанных ОДНИМ способом, подтверждением не является.
Подтверждает только другой способ — иначе воспроизводится ошибка, а не факт.

### §B · 2026-09-17 · Счётчик не должен пересекаться с текстом, который правка ДОБАВЛЯЕТ
В промпте на попап я задал `grep -c 'white-space'` 1→2 и сторож `'white-space: pre-line'` 1→1.
Факт вышел 3 и 2: комментарий, который я сам же продиктовал правке, ЦИТИРУЕТ дефект и содержит
`white-space: pre-line`. Счётчик посчитал мой собственный текст.
**И сторож этим сломался:** он стоял, чтобы поймать удаление `pre-line` у заголовка, но после правки
единицу даёт комментарий — зелёный сторож, не охраняющий ничего.
**Правило:** для счётчика брать подстроку, которой в ДОБАВЛЯЕМОМ тексте нет, либо считать по телу
конкретного метода (`sed -n` по диапазону), а не по всему файлу. Комментарий, объясняющий дефект,
почти всегда цитирует дефект — это отравляет grep по нему.
**Семья та же (предикат не снят с корпуса), механизм новый:** раньше я неверно ЧИТАЛ корпус, здесь —
сам его ЗАГРЯЗНИЛ тем, что в него положил.

### §B · 2026-09-18 · Blazor дорисовывает ПОСЛЕ тика: клик и замер — разными вызовами
Открывал попап фильтра и мерил его в одном вызове `javascript_tool` — получал «не открылся», что
неотличимо от «кнопка не работает». Компонент рендерится после синхронного тика. Два `.click()` в
одном вызове закрывают то, что открыли.
**Правило:** вызов A — только клик; вызов B — только замер. И перед кликом проверять, не открыт ли
элемент уже, иначе тумблер сработает в обратную сторону.

### §B · 2026-09-18 · Предикат строить на ИНВАРИАНТЕ, а не на снятом числе
По якорю попапа у меня были 83 и 101 px расхождения центров. Пере-снял на трёх колонках: 520, 10 и
31 — величина оказалась ПРОИЗВОДНОЙ от ширины ячейки, а инвариантом было другое: «правый край попапа
совпадает с правым краем ячейки». Предикат на 83/101 дал бы ложное красное на узкой колонке.
**Правило:** прежде чем делать число предикатом, снять его в нескольких точках и спросить, от чего
оно зависит. Если зависит — предикатом делать инвариант, а число оставлять иллюстрацией.
**Смежное:** одноимённые величины у двух виджетов могут отличаться по построению (здесь
`line-height` 21 против 27, отсюда разрывы 67/21 против 85/27). Переносить число с виджета на виджет
нельзя даже когда механизм один.

### §B · 2026-09-18 · Чужое число — такое же неснятое, как своё непроверенное
В гейте №3b три счётчика: два я снял грепом сам, третий взял из письма координатора («элементов
попапа два»), сложил с helper'ом и получил 4. Факт — 3. Пере-снял по родителю коммита: там тоже 3,
то есть негодным было ОЖИДАНИЕ, а не результат. Разошёлся ровно тот счётчик, которого я не касался.
**Правило:** число, пришедшее от другой роли, подлежит тому же замеру, что и собственная догадка.
Оно опаснее догадки: не ощущается как догадка, потому что у него есть авторитетный источник.
Проверка — не «он же координатор», а `grep` по своему корпусу.

### §B · 2026-09-18 · Хендоф ОБНОВЛЯЕТСЯ, а не переписывается. Удаления — явные
Я переписал хендоф целиком («прежний устарел») и молча выронил слой: открытый предмет
`PR234-VIEWEDIT-01`, карту логов (наши против чужих), правило покрытия корпуса, правило предусловия
опыта, механику Redis-кэша адреса хаба (она однажды отменила рестарт боевого Shell), весь раздел
запретов и якоря. Координатор нашёл ОДИН пункт; я прогнал предикат и нашёл три идентификатора плюс
весь пласт. 19448 B → 15451 B, и ни одного совпадающего заголовка — это замена, а не обновление.
**Правило:** новая редакция хендофа — дополнение; каждое удаление называется и обосновывается.
Перед сдачей прогонять:
`diff <(grep -o 'PR234-[A-Z0-9-]*' старый|sort -u) <(grep -o 'PR234-[A-Z0-9-]*' новый|sort -u)`
**И шире:** предикат по идентификаторам поймал три строки, а потерян был целый пласт негативного
знания и запретов, где идентификаторов нет вовсе. Сравнивать РАЗДЕЛЫ, а не только имена предметов.
**Смежное:** закрытый предмет удалять можно, но написать об этом явно — иначе преемник ищет то, чего
нет. Знание ПОД закрытым предметом (карта логов под закрытым `LOGPATH-01`) остаётся живым.

### §A · 2026-09-18 · Есть чем заняться и блессы на руках — продолжай, не жди
[со слов оператора 2026-09-18]: «если можешь продолжать и все блессы на руках — продолжай, не жди».
Развивает норму 17.09 «есть задача — делай, тычка не нужна». Практически:
- читающий разбор, замеры, написание промпта, ведение биндинга и хендофа — блесса не требуют;
- §4 требуется РОВНО для одного действия — выдачи ран-бокса оператору;
- поэтому «жду вердикта» не может останавливать ничего, кроме бокса. Если вердикт не пришёл, а
  писать есть что — пишу и держу наготове только бокс.
**И проверять инбокс на пропущенный вердикт, прежде чем объявить себя ждущим:** один раз я ждал
PASS, который уже сорок минут лежал в инбоксе, — читал только последние заголовки.

### §B · 2026-09-18 · Снятие «ДО» не проверяет «ПОСЛЕ»: второе выводится из добавляемого текста
В гейте `STATE-01` одиннадцать чисел сошлись, разошлось одно: `IFilterPopupCoordinator` в виджете —
я ждал 2, факт 1. «До» (ноль) я снял грепом честно, а «после» прикинул на глаз, хотя сам же написал
в скобках «inject + ничего больше», то есть ОДНО. Имя типа встречается только в `@inject`; обработчик
зовёт переменную, а не тип.
**Правило:** ожидание «после» выводится ПОДСЧЁТОМ по тексту, который правка добавляет, — этот текст
пишу я сам и могу сосчитать точно. Прикидка «ну, примерно два» — не предикат.
**Семья прежняя** (предикат не снят с корпуса), оттенок новый: корректное «до» создаёт ложное
ощущение, что и «после» обосновано.

### §B · 2026-09-19 · Проверяя ЧУЖОЕ число, проверь сперва ИГЛУ — ловит ли она понятие, а не написание
Координатор дал «признака темы у попапа нет», игла `dark-mode|IsDarkMode|theme` -> 0. Я воспроизвёл
ЕГО иглу, получил его ноль и доложил «сходится». Реальное имя оказалось `DarkMode` — 5 и 4 вхождения,
`[Parameter] public bool DarkMode`, и все `Effective*` по нему ветвятся. Вывод «темы нет» вёл к другой,
более дорогой правке.
**Правило:** чужую команду не копировать, а переписывать своей — начиная с вопроса «как эта вещь
называется в ЭТОМ коде». Воспроизведение чужой иглы даёт эхо, а не подтверждение; это та же норма,
что «согласие двух одним способом — не проверка», только с другого конца: одинаков не метод, а
инструмент.

### §B · 2026-09-19 · Негативный контроль, который не умеет упасть: `git show | grep -c` слеп к сломанному `git show`
`shell-0919`, инит. `§C` п.7 (`git show v3:app.css | grep -c 'ZZZ-marker…'` -> 0, rc 1) задуман ловить сломанный
конвейер. Измерено: на НЕСУЩЕСТВУЮЩЕМ пути тот же конвейер даёт ровно `0 / rc 1`, с `pipefail` — тоже rc 1
(rc grep'а маскирует rc git'а); различает только `PIPESTATUS[0]` = 128 и `fatal:` в stderr. Контроль ловит
сломанный grep и слеп к сломанному `git show` — самой вероятной поломке на этой среде.
**Правило:** в каждом конвейере `git show … | …` проверять `PIPESTATUS[0] == 0` и пустой stderr ДО чтения
числа; рядом с отрицательным контролем — положительный с ТОЧНЫМ числом на известном файле.
**Направление отказа зависит от направления порога** (замечание куратора): при пороге снизу (`>=N`) сломанный
конвейер даёт 0 и КРАСИТ пункт — ложно-красное, суперсидит верную истину; при пороге сверху — ПРОПУСКАЕТ.
Называть направление в каждом пункте. Заведено куратором `PR234-NEGCTL-BLIND-SHOW-01`, авторство `shell-0919`.
SOURCE: `.coord/shell-reconstitution-test.md` (сдача и вердикт `curator-0817` 19.09, пере-снято `PIPESTATUS = 128 1`). status: active

### §B · 2026-09-19 · Три дефекта моего `§C` — НЕ починены, описаны для преемника
1. п.7 — см. урок выше: отрицательный контроль не падает на сломанном `git show`.
2. пп.1,2,3,4,6 — пороги `>=`/`>` не падают при промахе внутри диапазона (`.dark-mode > 50` при 147 молчит о
   потере 90 правил). Нужны точные числа с датой калибровки: 2026-09-19 — 4 · 4 · 147 · 4 · 7/EXISTS/1 · 5.
3. покрытие: нет Н-7 NUL-сенсора по обоим телам (только hash в п.8), нет сенсора путей `§D` (3/3 резолвятся
   19.09), `§A`-4 (InvokeAsync), -5 (localStorage §41), -7 не проверяются; п.8 не отличает «диск длиннее
   стора дописыванием» от «правки в теле» — это меряется `git show v3:<скилл> > файл` + `diff` вне git.
**Правило для чинящего:** `§C` правится по стандарту NORM-CUR-11c — каждая новая проверка прогоняется
зелёной ДО коммита. SOURCE: сдача `shell-0919`, `.coord/shell-reconstitution-test.md`. status: active

### §B · 2026-09-19 · Позиционный счёт непрочитанного — ложно-зелёный: письмо легло ВЫШЕ отметки
`inbox/shell.md`: последняя `> handled` на стр.5422 (15.09 05:4x), а письмо `## 2026-09-15T06:xxZ` лежит на
стр.5375 — выше неё. «Заголовки ниже последней отметки» дал 46, счёт по ДАТЕ заголовка — 47.
**Правило:** непрочитанное считать по дате в заголовке против даты отметки, независимо от позиции; форматов
заголовков три (`## <ISO> | from:`, `## BINDING … | <дата> |`, `## От … 19.09:`) — парсер обязан знать все,
а заголовки без даты считать отдельно (-999 «не измерено»), не нулём. Контроли: заведомо новое письмо
засчитано, заведомо старое — нет. И: отметки `handled` у предшественника прекратились 15.09, а работа шла
до 19.09 — «непрочитано по отметке» не равно «не прочитано ролью».
SOURCE: `.coord/inbox/curator.md` §5 отчёт `shell-0919` 19.09; скрипт по `inbox/shell.md`. status: active

### §B · 2026-09-19 · Дописанный `done` не перекрывает фронтматтер: полевой матчер по первой строке прочтёт мёртвого живым
Гейт синглтона 19.09: shell-0908/0912 помечены дописанной строкой `status: done · …`, фронтматтер по
инструкции не затирался — в стр.4 обоих по-прежнему `status: active`. Предикат, берущий ПЕРВОЕ поле
`status:`, прочтёт их живыми (тот же разнобой уже был у shell-0609: «the two disagreed»).
**Правило:** гейт синглтона читает ПОСЛЕДНЕЕ поле `status:` в файле (или все — и при разнобое называет
его), а не первое; сам исход «неопределено» решает оператор. SOURCE: `.coord/sessions/shell-0908.md:37`,
`shell-0912.md:43`. status: active

### §B · 2026-09-19 · Постоянный слой, не ставший постоянным: 141 строка уроков пять суток жила только на диске
На ините `role-shell.md` диск `fe14f792` 67781 B против ветки `e269c29a` 45498 B: +141/-0, три урока в `§B`
и 14 блоков ПОСЛЕ `§D` (один помечен `§A`). Преемник, поднятый со свежего клона, не получил бы ни одного.
**Правило:** правка своего тела кончается коммитом, а не записью на диск; при каждом ините — Н-7 по ОБОИМ
телам и `hash-object` против `rev-parse`. И второе (поправка coordinator-0917 19.09): входной пин промпта
коммита фиксирует блоб ДИСКА — любое дописывание после пина остановит собственный промпт красным на верной
работе; сначала допиши всё, потом пинь. Уроки под `§D` в свои секции не перенесены — следующая единица.
SOURCE: `tools/cc_prompt_shell_skill_commit.md` (md5 47e85602) и §4 coordinator-0917 19.09. status: active
