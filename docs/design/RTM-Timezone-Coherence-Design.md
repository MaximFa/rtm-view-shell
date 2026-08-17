# RTM Timezone Coherence — Design (DRAFT, design-first, NO code)

> Owner: backend-0626 · Reviewer: dba (DB/storage angle), coordinator §4 · Status: DRAFT for operator decision.
> Trigger: DE DayTrend ~4h lag traced to `NGC_Site.TimeZone` = `"-01:00"` (should be +02:00 CEST). The
> three consumers of site TZ — interaction **stamping**, the restart **load filter**, and DayTrend
> **display** — are currently INCOHERENT. This doc pins the code paths and surfaces the DECISIONS the
> operator must take. No implementation here.

---

## 0. The problem (observed on 140)

All DE interactions carry `TimeZone = "-01:00"`. Consequence:
- `InQueueDateTime` (and `UpdateTime`) are stamped ~1h early (offset applied as `UtcNow + (-01:00)`).
- DayTrend buckets by `InQueueDateTime` and the widget renders bucket labels in UTC; operator reads Israel wall (+3).
- Net perceived lag ≈ **~3h (UTC-vs-Israel display) + ~1h (wrong -01:00 stamp) + ~30m (bucket floor) ≈ 4h.**

Coordinator TZ audit (July 2026, static offsets): **DE -01:00 wrong**, IL +02:00 & UK +00:00 wrong for winter (no DST), NZ +12:00 & US -04:00 currently OK. => a STATIC per-site offset is **DST-broken by design** (needs seasonal edits twice a year).

---

## 1. Read path — how Site TZ reaches `InQueueDateTime` (TZ-1a, code-pinned)

The Edit-Site modal writes `NGC_Site.TimeZone`. That value reaches stamping through this exact chain:

1. `NGC_Site.TimeZone` (DB) — edited via the Site modal.
2. `RealtimeData.getSiteTable()` (`RealtimeData.cs:93-123`) reads it via SP `NGC_GetSiteTable` into `Site.TimeZone`, keyed by `SiteId`. Called from `Engine.LoadData` (`Engine.cs:371`) → `SitesTable`.
3. `Engine.LoadData` union build (`Engine.cs:425-441`): `union.TimeZone = timeZone` — set for EVERY union in the union-queue-classification result (existing unions too, not just new).
4. `Union.TimeZone` is a property whose **setter propagates** (`Union.cs:82-87`): `set { _timeZone = value; QueueInteractions.TimeZone = _timeZone; UsersInteractions.TimeZone = _timeZone; }` → the interaction **bag** TimeZone updates immediately.
5. `IDInteractionBag.Add` (`IDInteractionBag.cs:28`): `interaction.TimeZone = TimeZone` — each interaction, **when it enters the queue**, is stamped with the bag's current TimeZone.
6. `IDInteraction.getLocalDateTime()` (`IDInteraction.cs:253-288`) uses `this.TimeZone` → offset → `InQueueDateTime = DateTime.UtcNow.Add(offset)` (`:255,:280`). Stored to DB (`DBMng.cs:396` / `RTSData_SetInteraction`).

**CONCLUSION (TZ-1a):** the `-01:00` on DE rows == `NGC_Site.TimeZone` for the DE site. The modal DOES feed stamping. Link **proven**.

Note: `getLocalDateTime` already supports BOTH forms — an offset string ("+02:00") AND an IANA/Windows zone id (`FindSystemTimeZoneById`, `IDInteraction.cs:276`). So IANA names are already parseable by the existing stamping code.

---

## 2. `/LoadData` re-read + restart behavior (TZ-1b, code-pinned)

`RtmConfigurationApiHook` already calls RTM `GET /LoadData` on config saves, and **"Site" is in its event set** — so a Site-TZ save already triggers a full `/LoadData` (no manual restart).

What `/LoadData` does with the TZ:
- **Re-reads** `NGC_Site.TimeZone` (`getSiteTable`, `Engine.cs:371`). ✓
- **Re-applies** to `union.TimeZone` for all classified unions (`Engine.cs:441`), and the setter **propagates to the bag** (`Union.cs:85`). ✓

Therefore, effect of a Site-TZ correction via the modal (hook → `/LoadData`), WITHOUT restart:
- **NEW interactions** entering the queue after `/LoadData` get the corrected TZ. ✓ (restart NOT required for new stamping)
- **EXISTING in-queue interactions** keep the OLD TZ — `interaction.TimeZone` is set once at `bag.Add` and not re-touched. ✗ (not re-stamped)
- **Already-stored DB rows** (`InQueueDateTime` written with -01:00) are **never** re-stamped by `/LoadData` or by a restart. ✗ (DayTrend history stays wrong until corrected or the day rolls / OnDate ages out).

Restart behavior: a restart does NOT re-stamp either. Per `Engine.cs:274`, the DB reload only re-adds `!isInQueue` interactions; in-queue ones are dropped and re-enter live with the corrected TZ. So restart ≈ "drop in-flight + repopulate correctly"; it does not fix stored history.

**CONCLUSION (TZ-1b):** the existing full-`/LoadData` hook already picks up a Site-TZ change for NEW stamping — no restart needed for that. The gap is (i) existing in-queue interactions and (ii) stored history, neither of which any current path re-stamps. Caveat to verify at implementation: `/LoadData` refreshes only unions present in the union-queue-classification result — a union with no classification row would not be refreshed.

---

## 3. DECISION 1 — Site TZ representation (operator choice)

| Option | Pros | Cons |
|---|---|---|
| **(a) Corrected STATIC offsets** (fix DE→+02:00, IL, UK, etc.) | Minimal change; data-only edit; `getLocalDateTime` already parses "+HH:MM" | **DST-broken**: every offset is wrong for half the year (CEST/CET, BST/GMT, IDT/IST). Requires manual seasonal edits per site, twice a year. This is the same class of bug we just hit. |
| **(b) IANA zone names** (`Europe/Berlin`, `Asia/Jerusalem`, `Europe/London`, `Pacific/Auckland`, `America/New_York`) | **DST-automatic** (correct year-round); `getLocalDateTime` ALREADY supports it (`FindSystemTimeZoneById`); one-time data + UI change | Site modal + `NGC_Site.TimeZone` values change from offset strings to zone ids; validation/UI update; must ensure the Windows/ICU zone db is present on the host. |

**Recommendation: (b) IANA zone names.** The TZ saga (4 burns) and the audit (IL/UK wrong in winter) prove static offsets are structurally fragile. Stamping code already accepts IANA. This is the durable fix.

---

## 4. DECISION 2 — What "today" means for the restart interaction-load filter

The restart/`GET /LoadData` reload uses `RTSData_GetInteractions`; commit `01dbc2c` currently filters "today" by **server-local** `current_setting('TimeZone')`. For a multi-site tenant (US/UK/DE/IL/NZ share one `TenantId`, split by site/workgroup) this is a decision:

| Option | Meaning | Implication |
|---|---|---|
| **(a) Server-local "today"** (current) | One day boundary = the server's zone (Israel) for all sites | Simple, single query. But a site whose local day differs (e.g. NZ) loads a window misaligned with its own day; near midnight a site can miss/duplicate its own day's rows. |
| **(b) Per-site "today"** | Each site's rows filtered by that site's local day boundary | Correct per site, but the load fn must resolve each row's site TZ (join `NGC_Site` via workgroup/BU) and compute the boundary per-site — heavier query; couples the load fn to the TZ representation chosen in Decision 1. |

**Recommendation: align with Decision 1.** If IANA per-site is adopted, per-site "today" (b) is the coherent choice but should be scoped as its own step (dba to design the query). Interim: keep server-local (a) until sites' TZs are corrected, since the dominant current bug is the wrong offset, not the day boundary. dba review required here.

---

## 5. Coherence — end-to-end for one DE interaction (recommended model: IANA `Europe/Berlin`)

Goal: stamping, load filter, and DayTrend display must AGREE. Under IANA `Europe/Berlin` (+02:00 in July, DST-aware):

1. **Stamp:** `getLocalDateTime` resolves `Europe/Berlin` → +02:00 (July) → `InQueueDateTime` = correct Berlin wall time (or, preferably, store true UTC — see §6 open question).
2. **Load filter:** "today" computed for the site's zone (Decision 2b) → the reload picks exactly the site's current-day rows.
3. **Display:** DayTrend renders bucket labels in a DEFINED zone — the viewer's or the site's — NOT raw UTC. (Shell/`daytrendChart.js` change; shell-owned.)

The current incoherence: stamp uses `site offset added to UtcNow then stored as-UTC`, load uses server-local, DayTrend renders UTC — three different zones. The design must pick ONE storage convention (recommend: **store true UTC**, convert to site/viewer zone only at display) and make all three consume it consistently. **This storage-convention question is the core dba item** (see §6).

---

## 6. Migration / impact + stored-row correction

A coherent fix touches:
- **Site config data + UI** (Decision 1): `NGC_Site.TimeZone` values (offsets → IANA) + Edit-Site modal validation. (shell + data)
- **RTM stamping** (`getLocalDateTime` / storage convention): decide store-UTC vs store-local-as-UTC. Today it stores `UtcNow + offset` labeled UTC (`DBMng.cs:396` SpecifyKind Utc; `RTSData_SetInteraction` `AT TIME ZONE 'UTC'`) — the local-as-UTC pattern that caused the display confusion. **dba + backend** decide the storage convention.
- **DB load fn** (`RTSData_GetInteractions`, Decision 2): per-site vs server-local "today". (dba)
- **DayTrend display** (`daytrendChart.js` / `DayTrendResult` formatting): render buckets in a defined zone. (shell)

**Stored-row correction (open decision):** existing rows stamped with wrong offsets (all DE `-01:00`) stay wrong until corrected. Options: (i) leave — they age out as `OnDate` rolls (DayTrend history for past days stays wrong, live corrects after fix); (ii) one-off UPDATE to re-derive `InQueueDateTime`/`UpdateTime` from the corrected site TZ (dba migration, risky — needs the true UTC basis, which may be unrecoverable if only local-as-UTC was stored). **dba to assess feasibility.**

---

## 7. T2 tie-in — interim vs targeted pickup

The "how a Site-TZ change is picked up" overlaps the paused T2 live-pickup epic (targeted, not full-`/LoadData`, metrics excluded).

- **(a) INTERIM — rely on the existing full-`/LoadData` hook.** Per §2 (TZ-1b), it ALREADY re-reads + propagates the site TZ to the bag → NEW interactions corrected without restart, TODAY. Ship the Decision-1 data/UI fix and lean on the existing hook.
- **(b) TARGETED — fold site-TZ re-read into T2's targeted pickup.** Cleaner long-term (no full reload for a TZ edit), but blocked on T2.

**Recommendation: ship (a) INTERIM now** (the hook already covers new stamping per code), and log "targeted site-TZ pickup" as a T2 sub-item for later. No need to block the TZ correctness fix on T2.

---

## 8. DECISIONS FOR THE OPERATOR (crisp)

1. **Site TZ representation:** corrected static offsets (simple, DST-broken) **vs → recommended: IANA zone names** (DST-automatic; stamping already supports it).
2. **"Today" for restart load:** server-local (current) **vs** per-site local-day (coherent with IANA; dba to design). Interim: keep server-local until offsets corrected.
3. **Storage convention:** keep store-local-as-UTC **vs → recommended: store true UTC, convert only at display** (removes the display confusion; dba + backend).
4. **Stored-row correction:** leave to age out **vs** one-off dba re-stamp migration (feasibility TBD by dba).
5. **Pickup mechanism:** ship INTERIM (existing full-`/LoadData` already re-reads TZ) now **vs** wait to fold into T2 targeted pickup. Recommended: INTERIM now.

Once the operator picks 1–5, backend + dba author the implementation prompts (site data/UI, stamping/storage, load fn, DayTrend display), self-§4 → coordinator §4 → CC. No code until then.
