# Reports v1 — Functional Acceptance Checklist + Gap Analysis + Fix Plan
> coordinator-0624 · 2026-06-25 · covers BOTH specs: Reports-Frontend-v1-Spec.md + Reports-Backend-v1-Spec.md (under master Reports-AsDashboards-v1-Spec.md).
> Readiness is asserted ONLY from a FULL end-to-end functional pass of EVERY item below, operator/QA-run. Object-store/commit/per-slice ≠ ready.
> **#1 acceptance for a HISTORICAL-REPORTS product = widgets render REAL historical data.** No data on screen ⇒ not ready, period.
> Status legend: ✅ PASS (functionally verified) · ❌ GAP (known broken) · ❓ UNVERIFIED (never functionally checked → treat as gap until proven).

## A. Reports List (/reports)
| # | Visual check | Status | Note |
|---|---|---|---|
| VC1 | List renders (cards/table: Name/Category/Access/Status/Updated), PG-scoped | ❓ | partial visual only |
| VC2 | Filters work: search / category / PG / status | ❓ | |
| VC3 | "+New" create-modal: fields + validation | ✅ | visual PASS (create works) |
| VC4 | Create → new report appears (Draft) + nav to editor | ✅ | |
| VC5 | Settings gear modal: rename / status / category / IsPublic / PG-access | ❓ | |

## B. Editor — canvas mechanics (the core "widget-based screen")
| # | Visual check | Status | Note |
|---|---|---|---|
| VC6 | Editor opens as fullscreen overlay (covers shell) — parity with ScreenEditorPage | ✅ | chrome verified |
| VC7 | Palette: 5 widget types grouped (Queues/Agents/Analytics), drag-add to canvas | ✅ | drag-place once worked |
| VC8 | Place widget #1 → renders WITHOUT a red error | ❌ | **G-PLACE-ERR** (operator NO-GO #4) |
| VC9 | Add a 2nd+ widget (multiple widgets on ONE canvas) | ❌ | **G-MULTIADD** (NO-GO #2) |
| VC10 | Move a placed widget (drag header) | ❌ | **G-MOVE** (NO-GO #1) |
| VC11 | Resize a placed widget (corner handles) | ❌ | **G-RESIZE** (NO-GO #3) |
| VC12 | Align-guides / marquee multi-select / group-move — parity with dashboard editor | ❓ | likely shares G-MOVE root |
| VC13 | Save layout → reopen → positions/sizes/widget-set intact | ❓ | **G-SAVE-PERSIST** (blocked by VC8-11) |

## C. Editor — config modal (per tab + DASHBOARD parity)
| # | Visual check | Status | Note |
|---|---|---|---|
| VC14 | Gear opens config modal ABOVE the editor overlay (z-index) | ✅ | R2 a3a0d25 |
| VC15 | Scope tab: queues/BU mode, pickers POPULATE, AgentAxis | ✅ | R3 1e3efce (pickers populate) |
| VC16 | General tab: title, pageSize | ❓ | |
| VC17 | Columns tab: honest "v1.1" note (Columns optional, server defaults) | ✅ | ruling (b), a7e213b |
| VC18 | **Thresholds tab: add/edit thresholds — IDENTICAL to dashboard-widget Thresholds** | ❌ | **G-THRESH** (NO-GO #5, empty) + **G-PARITY** |
| VC19 | **Appearance tab: fonts/colours/dark — IDENTICAL to dashboard-widget Appearance** | ❌ | **G-APPEAR** (NO-GO #6, not parity) + **G-PARITY** |
| VC20 | Chart tab (Distribution widget): series/axis | ❓ | |
| VC21 | Config Save → ConfigJson persists → reopen → config intact | ❓ | **G-SAVE-PERSIST** |

## D. Per-widget-type DATA OUTPUT — #1 ACCEPTANCE (historical-reports product)
| # | Visual check | Status | Note |
|---|---|---|---|
| VC22 | **QueueInterval** widget renders REAL hist_queue_intervals rows (scoped + date-range) | ❓ | **G-DATA** — never verified in the NEW widget path |
| VC23 | **QueueWaitTime** widget renders REAL data + OverallAsa header | ❓ | **G-DATA** |
| VC24 | **AgentMonthly** widget renders REAL hist_agent_intervals rows | ❓ | **G-DATA** |
| VC25 | **AgentShiftDetail** widget renders REAL data | ❓ | **G-DATA** |
| VC26 | **Distribution** widget renders chart over Q1/Q5 REAL data | ❓ | **G-DATA** |
| VC27 | ALL 5 types on ONE canvas, each fully configured, ALL showing data | ❓ | **G-DATA composite** (operator's explicit ask) |
| VC28 | Data matches the OLD /reports for the same scope+range (correctness cross-check) | ❓ | **G-DATA** correctness |

## E. View Mode
| # | Visual check | Status | Note |
|---|---|---|---|
| VC29 | View opens as overlay (parity ScreenFullscreenPage) + single date-bar | ✅ | d0fb4dd/582563d visual |
| VC30 | Date-bar Apply cascades to ALL widgets → data REFRESHES per range | ❓ | **G-DATA/cascade** |
| VC31 | Widgets render data read-only, positioned from PositionJson | ❓ | **G-DATA** |
| VC32 | Export / Schedule buttons present (stubs Ф6/Ф7) | ✅ | visual |

## F. Trash + hard-delete
| # | Visual check | Status | Note |
|---|---|---|---|
| VC33 | Reports Trash tab: deleted list + Restore + hard-delete + confirm | ✅ | visual PASS (reports + dashboards) |

## G. Cross-cutting
| # | Visual check | Status | Note |
|---|---|---|---|
| VC34 | Dark-mode parity across editor / view / all modals | ❓ | |
| VC35 | RTL (he-IL) + a11y on editor/view/modals | ❓ | |
| VC36 | Scope enforcement live: non-Superadmin sees ONLY PG-allowed data (SF-BI-001) | ❓ | **G-SCOPE** functional |

---

## GAP SUMMARY (what blocks "works")
| Gap | Checks | Owner(s) | Severity |
|---|---|---|---|
| **G-DATA** — no proof any widget renders REAL historical data (new path) | VC22-28, VC30-31 | bi (query/seed) + shell (render) | **#1 / CRITICAL** |
| **G-MOVE / G-RESIZE / G-MULTIADD** — editor canvas mechanics broken | VC9-12 | shell | HIGH (core) |
| **G-PLACE-ERR** — red error on placing a widget | VC8 | shell (+bi if query) | HIGH |
| **G-THRESH** — Thresholds tab empty, not at dashboard parity | VC18 | shell (+bi persist) | HIGH |
| **G-APPEAR** — Appearance tab not at dashboard parity | VC19 | shell | MED-HIGH |
| **G-SAVE-PERSIST** — full-config save round-trip unverified | VC13, VC21 | shell + bi | HIGH (blocked) |
| **G-PARITY** — config-modal identity vs dashboard (esp Thresholds/Appearance) | VC18-19 | shell | MED |
| **G-SCOPE** — live BU∩PG enforcement unverified | VC36 | QA + security | MED |

## FIX PLAN — step-by-step by spec (each step → the gap it closes)
1. **DATA-PROOF FIRST (bi+shell):** bi seeds a minimal data-bearing report-screen (≥1 widget per type, scope=real queue/PG-all) + confirms RunReportWidgetQuery returns rows vs old /reports; shell confirms RenderReportWidget renders those rows in View. → closes **G-DATA** (VC22-28,30-31). *Prereq: hist data present in the running dev DB (operator/DBA confirm/re-seed).*
2. **Editor canvas mechanics (shell):** root-cause + fix widget-resize.js wiring in the report editor (DOM classes/data-widget-id/handlers + multi-add state). → closes **G-MOVE/G-RESIZE/G-MULTIADD** (VC9-12).
3. **Place-error (shell, +bi if query):** fix RenderReportWidget place-time config/data path. → closes **G-PLACE-ERR** (VC8).
4. **Thresholds tab (shell, +bi persist):** implement Thresholds add/edit to DASHBOARD parity (or operator-ruled v1.1). → closes **G-THRESH + G-PARITY** (VC18).
5. **Appearance tab (shell):** bring Appearance to dashboard-widget parity (reuse the same fields/markup). → closes **G-APPEAR + G-PARITY** (VC19).
6. **Save round-trip (shell+bi):** verify SaveReportWidgets persists full ConfigJson (scope+columns+thresholds+appearance) + reload intact. → closes **G-SAVE-PERSIST** (VC13,21).
7. **FULL FUNCTIONAL PASS (operator/QA):** run EVERY VC above incl all-5-types-on-one-canvas + data + parity + dark/RTL + scope. → the readiness bar. Only GREEN here = ready.

*This doc is the reports v1 acceptance bar. v3 push HELD until step 7 is GREEN.*
