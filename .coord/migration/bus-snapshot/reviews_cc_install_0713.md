# §4-review verdicts — canonical fresh-install (ЧП, coordinator) 2026-07-12T22:52Z
CONTEXT: I (coordinator) violated §A ЧП: handed CC run-prompts without §4-bless; accepted CC-1 on object-store without BUILD=0; did not batch rebuilds; hand-ran the install (against validation-via-prod-tooling). Correcting per operator's §A call-out.

## CC-1 (cc_prompt_app_drop_backend_tables.md -> committed 46c6d4b) — RETRO
ARTIFACT CORRECT (subagent §4, object-store): DROP set = 26/26 vs db/schema.sql (1:1), Down() empty/forward-only, CASCADE safe (snapshot excludes backend -> no shell FK), ordering-proof verified in DatabaseInitializer.cs:36-43 (App migrate first; beDb dev/test only). Real Designer.cs.
BLOCKED-until-evidence (ЧП gate): (1) no BUILD=0, (2) no UNIT failed=0, (3) prompt lacked §0.6b BINDING block, (4) fresh-DB proof was OPTIONAL (must be mandatory), (5) caveat: "dev unaffected" only for FRESH dev DB (existing beDb history won't recreate), (6) minor: Up() comment "25" vs 26 tables.
EVIDENCE PATH: BUILD=0 comes from the batched rebuild (dotnet build/publish); fresh-DB functional proof comes from the 140 shakedown (prod migrate shell-only + schema.sql clean + Shell live). Record binding RESULT then. Comment 25->26 = doc-debt, fold into next backend touch.

## CC-2 (cc_prompt_canonical_install.md) — PRE-RUN
SUBSTANCE SOUND (subagent §4): canonical order = Design B; all 8 punch-list covered; functional gate correctly deferred to 140 shakedown; §35 BOM/CRLF; no-hand-runs; DB-intake reconcile N/A (from-scratch); package DoD real.
AMENDED by coordinator: +§0.6b BINDING preamble/postamble; +§40 reads (widget-planner/creator); role-devops mandatory (was "if present"); +HARD precondition gate on CC-1 green; commit split db:(Provision-FreshDb) / deploy:(Install+package+runbook).
VERDICT: **§4-BLESS** (post-amend). Cleared to run.

## SYSTEMIC
Neither prompt carried §0.6b BINDING (my authoring gap, not a CLAUDE.md gap — §0.6b already normative). Fixed in CC-2; I include the binding block in every prompt henceforth.

## CORRECTED SEQUENCE (ЧП, coordinator-gated, batched, prod-tooling-only)
1. run CC-2 (blessed).
2. ONE batched rebuild CC-1+CC-2 (Build-ProdRelease Full) -> BUILD=0 = CC-1 evidence; run unit suite (failed=0 w/ counts).
3. deploy 140 via canonical tooling (Install-RTMView -FreshDb -NoStartServices -> Provision-FreshDb) — NO hand-runs.
4. coordinator PERSONALLY visual-verifies (§A#4): superadmin login, metrics catalog present (RTSGrid_Metric>0), dashboards render, clean log.
5. Phase B (connect our RTM) + quorum (build/unit/functional evidence, subagent review-gates + native execution-truth) -> push (IRON RULE: 140 sanity before push).
2026-07-13T03:49Z | §4 G (cc_prompt_platform_tenant_slug) = BLESS-WITH-COND: COND1 delete dup 019f5978 pre-restart (deploy gate); COND2 deterministic find (OrderBy/ fail-fast, in-method); COND3 method range :116-178. Name NOT unique (AppDbContext:102 slug-only). H routed to dba (2 decisions + 140 safety).
2026-07-13T04:10Z | §4 amended-H (cc_prompt_pertenant_username_index) = BLESS: 3 dba rulings applied byte-exact, EF-gen migration, MAINT-04. C1 probe=redeploy precondition (coord-owned); C2 anchor cf18c8b->a261840 cosmetic. Cleared to commit.
2026-07-13T04:59Z | §4 devops Shell: A build_shell_full_f486e4c=BLESS (build0+unit gate G+H). B redeploy_shell_140=BLESS-w-COND: B1 -SkipRTM still bounces RTMService (upside: re-feeds NGC_Queues seal); B2 CRITICAL pass -DBPassword (pg_dump clobber else both-down+no-backup); B3 -SkipCacheMigration (Garnet preserve). Core logic sound.
2026-07-14T05:15Z | §4 Defect K fix (cc_prompt_defect_k_flush_bedb) = BLESS: layering-safe repo.SaveChangesAsync (Domain iface+Infra impl), concurrency-guard sequential (beDb in next() before UoW), 6 handlers Site/BU/SG Save+Delete, regression test, narrow 4-path. Cleared to commit.
2026-07-14T05:53Z | §4 metrics deploy-package = BLESS: 0364a71 metric correct/idempotent; staging/metric-deploy-package manual-deploy SHA256 8dbeaf69 matches manifest (F-4), MetricId in manifest (F-6), name matches Shell hard-code. Routing (a)/(b) backlog, (c) catalog rides next Shell rebuild. 140 deploy after redeploy.
2026-07-14T07:34Z | §4 devops batch 0f270bd: build_shell_full=BLESS (build0+unit263 gate Defect K+headers, catalog GAP-1 confirmed docs/metrics-catalog.json); redeploy_shell_140_0f270bd=BLESS binary-only (no migration, 3 conds, verify-note Seed:PlatformTenantSlug=nayax preserved).
2026-07-14T08:50Z | §4 shell 4-edit batch (3 prompts) = BLESS x3: grid_header_refix (inline text-transform:none+overflow-wrap:normal), chart_no_anim (render animation off +?v=3), table_internal_scroll (.table-responsive max-height+sticky thead +?v=31). 2 live-tune items on table-scroll (calc offset + sticky-bg opaque).
2026-07-14T10:00Z | §4 shell edit3_tune = BLESS: A pagination offset 220->320px (?v=32); B funnel flex align-items:flex-start top-anchor. Commit; rebuild HELD for batch (tune + search/filter feature).
2026-07-14T10:18Z | §4 adapter_autoreconnect = BLESS: per-target supervisor (INFINITE+30s+reset), NamedPipeBase disconnect harden, §48 WIRE 14/14 gate (no format change), adapters branch 3 files. Cleared to commit.
2026-07-14T10:38Z | §4 shell admin_search_filters=BLESS (client-side LINQ, 4 pages+3 resx, confirmed filter set). backend 6ebd39f auto-reconnect landed (object-store). adapter rebuild+WIRE gate+redeploy runbook -> devops.
2026-07-14T10:45Z | §4 adapter: build_adapter_6ebd39f=BLESS(run, WIRE 14/14 gate); redeploy_adapter_140=BLESS but OPERATOR-TIMED (legacy blip, operator-GO STEP0, preserve appsettings+legacy, binary backup). Run B after build-green + operator window.
2026-07-14T13:28Z | §4 pagination_unify=BLESS: shared AppPagination.razor on 13 list screens (server keep-query, client Skip/Take on filtered), Users-canon 10/25/50/100 def25, Audit+10. Cleared to commit.
2026-07-14T14:25Z | §4 BLESS x3: shell pagination_unify_complete (7 missed pages); backend rtm_server_reaccept (v3 re-accept loop) + adapter_connect_timeout (adapters ConnectAsync timeout, WIRE gate).
