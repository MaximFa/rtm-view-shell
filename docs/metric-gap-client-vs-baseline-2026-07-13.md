# Client-vs-baseline metric gap — authoritative semantic diff (2026-07-13)

> Author: metrics specialist (metrics-3-0609). Inputs: client `10072026/Metrics_13072026.csv` (176 metrics) vs
> baseline `db/data/02_metrics.sql` (202 metrics). Method: exact MetricId match, then SEMANTIC match on
> `MetricFunction` + whitespace-canonical `MetricParameter` (per rtm-metrics-expert §3). Read-only; no baseline edit.

## SUMMARY (one line)
176 client / 202 baseline → 170 common, 6 client-only, 32 ours-only. Of the 6 client-only: **1 GENUINE GAP**
(`QueueNumberOfCompletedIncomingCalls`); the other 5 = 2 client typos + 3 deduped duplicates (all have baseline equivalents).

## A/B. THE 6 CLIENT-ONLY — verdicts
| # | Client MetricId | Verdict | Baseline equivalent |
|---|---|---|---|
| 1 | QueueNumAbandonefCalls | CLIENT TYPO of QueueNumAbandonedCalls (identical def) → NOT a gap | `QueueNumAbandonedCalls` |
| 2 | QueueNumAbandonefCallbacks | CLIENT TYPO of QueueNumAbandonedCallbacks (identical def) → NOT a gap | `QueueNumAbandonedCallbacks` |
| 3 | QueueNumAcceptedCallbacks | NOT a gap. Client def `(Callback & External & **Incoming** & IsAnswered)` is byte-canonically IDENTICAL to our `QueueNumAnsweredCallbacks`. Do NOT match it to `QueueNumCompletedCallbacks` — that one is **Outgoing** (`Callback & External & Outgoing & IsAnswered`), a different metric we ALSO have. So both directions are covered: Incoming-answered = our AnsweredCallbacks (=client Accepted); Outgoing-answered = our CompletedCallbacks. | `QueueNumAnsweredCallbacks` (Incoming) |
| 4 | QueueNumOnCallAgents | Deduped duplicate → NOT a gap. UsersInStatusGroupCount(ONPHONE) = our on-call metric. | `UsersSumOnCall` |
| 5 | **QueueNumberOfCompletedIncomingCalls** | **GENUINE GAP** — no baseline func+param equivalent. | — (nearest ≠, see below) |
| 6 | QueueNumberOfLoggedAgents | Deduped duplicate → NOT a gap. LogedInUsersCount = logged-in agents per queue. | `QueueLoginDataNumLoggedUsers` |

> **Callback direction clarity (operator 2026-07-13):** `QueueNumCompletedCallbacks` = Outgoing answered callback `(Callback & External & Outgoing & IsAnswered)`; `QueueNumAcceptedCallbacks` / our `QueueNumAnsweredCallbacks` = Incoming answered callback `(Callback & External & Incoming & IsAnswered)`. Verified against baseline: we hold BOTH the Incoming (`QueueNumAnsweredCallbacks`) and Outgoing (`QueueNumCompletedCallbacks`) variants, so the client `QueueNumAcceptedCallbacks` is fully covered — not a gap.

(Confirms the 2026-06-05 dedup audit / migration `20260605_004`: #3/#4/#6 are the three IDs we intentionally
consolidated to canonical metrics — the client still carries the pre-dedup duplicates.)

## D. GENUINE-GAP LIST (client-has, we-don't) — ready to pick
**1 metric.**

### GAP-1 — `QueueNumberOfCompletedIncomingCalls`
Full client definition (import-ready):
| Field | Value |
|---|---|
| MetricId | `QueueNumberOfCompletedIncomingCalls` |
| Description | QM - Number of Completed Incoming Calls |
| DataType | Interactions Summary |
| MetricFunction | InteractionsCount |
| MetricParameter | `(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && !IsTalk` |
| MetricFormat | NULL |
| DefaultValue | NULL |

Notes for the operator:
- **NOT the same as our `QueueNumIncomingCompletedCalls`.** Ours excludes `!IsCallbackRequest`; the client excludes
  `!IsTalk`. Client "Completed" = incoming external calls that finished the interaction (not in queue AND not currently
  talking = disconnected). Ours "IncomingCompleted" = finished queueing (answered+abandoned, excl. callback requests).
  Different intent → this is a real distinct metric, not a rename.
- **Load-bearing:** two client Calc metrics reference it — `QueueExclCallbackReqAnsweredPct` and
  `QueueInclCompCallbacksAnsweredPct` (both are name-common with ours but their client def points at this ID; see
  reverse-scan). If the operator wants those client SL% formulas as-defined, this base metric must exist first.
- CSV row: `QueueNumberOfCompletedIncomingCalls,QM - Number of Completed Incoming Calls,Interactions Summary,InteractionsCount,"(InteractionType==""Call"") && (CallType==""External"")  && Direction == ""Incoming"" && !IsInQueue && !IsTalk",NULL,NULL`

## C. REVERSE SCAN (secondary) — 21 name-matches whose CLIENT def DRIFTED from ours (noted, NOT resolved)
Grouped by pattern:

**(i) "Interactions" family — client DROPS the Chat+email restriction (13).** Our def restricts to
`(InteractionType=="Chat" || InteractionType=="email")`; the client uses only `CallType=="External"` (i.e. counts ALL
external interactions, not just digital). IDs: `QueueNumAbandonedInteractions`, `QueueNumActiveInteractions`,
`QueueNumAnsweredInteractions`(+`30/60/120sec`), `QueueNumWaitingInteractions`, `QueueNumIcomingOnlineInteractions`,
`QueueNumIncomingCompletedInteractions`, `QueueAvgWaitTimeInteractions`, `QueueCurMaxWaitTimeInteractions`,
`QueueAvgTimeToAbandInteractions`. → business/definitional divergence (what counts as an "Interaction"). Operator decision.

**(ii) "Answered Calls" add `!IsTalk` (4).** `QueueNumAnsweredCalls`(+`30/60/120sec`): client excludes
currently-talking calls from "answered". Drift.

**(iii) Calc SL% re-pointed (2).** `QueueExclCallbackReqAnsweredPct`, `QueueInclCompCallbacksAnsweredPct`: client
denominators reference `QueueNumberOfCompletedIncomingCalls` (GAP-1) instead of `QueueNumIncomingOnlineCalls`;
`QueueInclComp…` also swaps `QueueNumCompletedCallbacks`→`QueueNumCallbackRequests`. Drift tied to GAP-1.

**(iv) Likely client DEFECTS (2) — flag, do not import as-is:**
- `MonAgentNumChatsCompleted`: client uses `CallType=="Chat"` — `CallType` is only `External`/`Intercom`, never
  "Chat" → the client predicate matches NOTHING (ours correctly uses `InteractionType=="Chat"`).
- `QueuePctAbandonedInteractionsTotal`: client Calc references `[QueueNumIncomingCompletedIntreactions]` — a typo
  ("Intreactions") → unresolved identifier in the client.
- (also `MonAgentNumberOfInboundCallsOnly`: client adds `|| CallType=="Intercom"` — intentional-looking widening, not a defect.)

## Out of scope
- 32 ours-only metrics (we-have, client-doesn't) — not part of "client-has, we-don't"; count only, listed on request.
