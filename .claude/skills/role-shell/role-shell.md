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
