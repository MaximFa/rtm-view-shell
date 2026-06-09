# Metrics Hot-Reload — Apply-Endpoint Contract (design)

> Owner: devops-2-0607. Status: DESIGN (not implementation). Part of the 4-session hot-reload feature
> (meeting_hotreload_0609.md). This doc fixes the Shell->ops apply-service interface so Shell, Metrics and
> Backend can build against a stable contract. Impl is a follow-up task.

## 1. Scope & position in the flow
End-to-end (meeting brief): Metrics ships migration+manifest in the install package -> Shell "Deploy new
metrics" tab shows the undeployed delta + Deploy button -> **Shell triggers THIS apply-endpoint** -> the
apply-service applies the metric-migration as catalogue-owner + writes the per-metric ledger + audit ->
returns the applied RT-MetricId set -> **Shell** fires `compileMetrics(appliedRtMetricIds)` over its own
RtmRelay HubConnection (Option A: apply-service is compile-AGNOSTIC). RTM hot-compiles incrementally.

This contract covers ONLY the Shell->ops apply step + ledger. Compile (SignalR) is Shell+Backend; not here.

## 2. Security model (the reason this endpoint exists)
- **No web-DML.** The Shell (web tier) must NOT hold INSERT/DDL grants on `RTSGrid_Metric` or the ledger —
  that is privilege creep (CLAUDE.md CODE-03, least-privilege). Catalogue mutation belongs to a privileged
  apply-service running under a **catalogue-owner DB identity**, distinct from the Shell app pool/service.
- Shell only TRIGGERS; it never executes the migration SQL.
- The apply-service is the sole holder of catalogue-write credentials.

## 3. Transport — DECISION: localhost HTTP (synchronous). Rationale vs queue.
Option A requires Shell to receive `appliedRtMetricIds[]` back so it can fire `compileMetrics`. A synchronous
HTTP response delivers that in one round-trip; a queue would force Shell to poll for completion + result.
=> **HTTP, bound to 127.0.0.1** (never externally reachable; Windows Firewall already blocks non-443, §DEPLOY-08).
Apply is short (a few INSERTs); synchronous is fine. (Queue remains a fallback if a future apply becomes long
-running — then RESPONSE becomes an applyId + a poll/SignalR completion; out of scope now.)

Hosting model (IMPL decision, flagged — NOT fixed here): a small dedicated localhost service (Kestrel minimal
API or Windows service) co-located with Shell but running under the catalogue-owner account. Do NOT host it
inside the Shell process (that would re-give Shell the creds). Decide at impl time.

## 4. AUTH
- Endpoint bound to 127.0.0.1 only.
- Caller must present a **shared service token** (provisioned at deploy, stored per §CODE-05 — not in source/plain config).
- Trigger is **Superadmin-only**: Shell asserts the authenticated user is Superadmin BEFORE calling; the
  apply-service re-validates the token and (if the request carries a user context) logs the triggering UserId.
- Every apply -> audit `System.MetricsDeployed` written by the apply-owner (§16). Shell logs the trigger
  separately (its own audit line) — two records, two responsibilities.

## 5. REQUEST (Shell -> apply-service)
```jsonc
POST http://127.0.0.1:<port>/apply-metrics
Authorization: Bearer <service-token>
{
  "packageRef":  "daaa7c3|160259a|...",   // source commit / package id the migration came from (-> sourceCommit in ledger)
  "migrationRef":"20260609_0NN_add_<metric>.sql", // the metric-migration file in the package to apply
  "metricIds":   ["<MetricId>", ...],     // the undeployed set Shell computed from manifest MINUS ledger;
                                          // apply-service treats this as the EXPECTED set (cross-check vs what the migration actually inserts)
  "triggeredBy": "<UserId>"               // Superadmin who clicked Deploy (audit only; auth is the token)
}
```
Notes: `metricIds` is advisory/cross-check — the migration body is the source of truth for what is inserted.
If the migration inserts a MetricId NOT in `metricIds` (or vice-versa) -> report it in the response `warnings`.

## 6. RESPONSE (apply-service -> Shell)
```jsonc
200 OK
{
  "success": true,
  "appliedRtMetricIds": ["<MetricId>", ...],  // RT-half ONLY (history-half excluded HERE, at apply = R1 SOURCE-OF-TRUTH).
                                              // Shell passes EXACTLY this set to compileMetrics — never the raw package set.
  "ledgerRows": [ { "metricId":"<id>", "deployedAt":"<UTC>", "sourceCommit":"160259a" }, ... ], // §38a per-metric
  "warnings": [ "..." ],     // e.g. metricIds mismatch, a MetricId already present (idempotent skip)
  "auditId": "<System.MetricsDeployed audit row id>"
}
// on failure: success=false + "error" (apply rolled back as one tx; ledger NOT written; no partial catalogue state)
```

## 7. RT vs history split — decided HERE (R1)
A metric definition has an RT half (live RTSGrid_Metric, compiled by RTM) and a history mirror. **Only RT
MetricIds are hot-compilable.** The apply-service classifies at apply time and returns ONLY the RT subset in
`appliedRtMetricIds`. This makes the apply step the single source-of-truth for "what RTM should compile" (R1),
so Shell/Backend never have to re-derive the RT/history split.

## 8. Side effects of a successful apply (single DB transaction)
1. INSERT the metric rows into `RTSGrid_Metric` (+ history mirror) as catalogue-owner — idempotent
   (ON CONFLICT DO NOTHING; an already-present MetricId -> skipped + a `warnings` entry).
2. Write a per-metric **ledger** row (§38a) per applied MetricId: `{MetricId, deployedAt, sourceCommit}`.
3. Self-record the migration in `db_patch_history` (§38a) — same mechanism, file-level.
4. Write audit `System.MetricsDeployed` (apply-owner). 
All four in ONE tx -> on any error, full rollback, response success=false, nothing half-applied.

## 9. Ledger (the read-side Shell consumes; shared with E-010b)
- A per-metric deploy ledger: row per (MetricId) actually applied on THIS client DB.
  Minimal columns: `MetricId, DeployedAt (timestamptz), SourceCommit (text)`. (TenantId N/A — RTSGrid_Metric
  is platform-wide cross-tenant, §6.1/WGT-01.)
- **Shell delta** (read-only, no DML in web): `undeployed = package-manifest MetricIds  MINUS  ledger MetricIds`.
- **E-010b synergy**: the same ledger (+ db_patch_history) is the read-before-upgrade "what's already applied"
  source for the orchestrator. ONE ledger mechanism, two consumers (Shell tab + upgrade delta). Build once.

## 10. Compile seam — explicit (apply != live)
- The apply step records a metric as **'applied'** (catalogue+ledger durable). It does NOT make it live in RTM.
- **Compile-state is SEPARATE.** Live-in-RTM happens only after `compileMetrics` succeeds (Shell-fired, Option A).
- Therefore a metric can be 'applied' (ledger present, tab shows deployed) yet not live if the fire-and-forget
  compile failed (the seam shell-0609 flagged).
- **Recompile / R2 affordance**: re-firing `compileMetrics(MetricId)` must be possible WITHOUT a re-apply
  (apply is already done + idempotent anyway). Shell offers "Recompile" that calls compileMetrics for the
  already-applied MetricIds. The apply-endpoint is not involved in Recompile. (Whether to surface a true
  compile-status back to the tab = Backend/Shell decision; the apply ledger alone cannot show compile liveness.)

## 11. Idempotency & failure
- Re-clicking Deploy for an already-applied metric: INSERT ON CONFLICT skips, ledger row exists -> response
  success=true, appliedRtMetricIds may be empty + a `warnings` "already deployed". Safe.
- Migration error: tx rollback, success=false, ledger untouched, Shell shows the error, no compile fired.
- Compile failure after a successful apply: not the apply-endpoint's concern (fire-and-forget); covered by R2.

## 12. Open impl decisions (NOT decided here)
- Hosting of the apply-service (dedicated Windows service vs co-located privileged Kestrel) — §3.
- Token provisioning/rotation mechanism (Data Protection / Credential Manager, §CODE-05).
- Exact ledger table name + whether it folds into db_patch_history or is a sibling `metric_deploy_log`.
- Whether compile-status is surfaced back to the tab (Backend/Shell call).

## 13. Consumers / unblocks
- Shell gate (c): apply-endpoint contract -> can draft the Deploy tab + trigger + delta read.
- Backend: RT-only `appliedRtMetricIds` confirms the compileMetrics(string[]) payload domain.
- Metrics: manifest must carry, per MetricId, the RT-vs-history flag so §7 classification is unambiguous.
- Devops (me): the apply-service impl + ledger DDL migration = the follow-up build task (post-design).
