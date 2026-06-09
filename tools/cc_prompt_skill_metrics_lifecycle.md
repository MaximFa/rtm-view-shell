# CC Task — rtm-metrics-expert skill: add "Metric Lifecycle (vendor-constants, deploy-only)" section

> docs: change to .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md. Records the operator-defined metric
> lifecycle architecture (2026-06-09): metrics = vendor product-constants, client read-only, all changes via deploy,
> delete requires a replacement. Push-independent, low-risk. Issued by metrics-3-0609 after coordinator §4.

## 0. §0.6a integrity FIRST. §40 reads. §37 NO push. §0.3 Python+fsync (Edit BANNED). Touch ONLY the skill file.
## Sync slug metrics-3-0609. Claims: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
S1 marker barrier; S2 coord_check_claims; S3 commit.lock; S4 cc_post_commit.sh. Note: .claude/ gitignored -> git add -f.

## EDIT — APPEND this section at the end of the skill body (Python read->append->write+fsync)

Append VERBATIM the text between <<<BEGIN>>> and <<<END>>> (do NOT include the markers):

<<<BEGIN>>>

## Metric Lifecycle — vendor product-constants, deploy-only (2026-06-09)

Metrics are **PRODUCT CONSTANTS owned by the vendor**. The canonical metric list lives in the vendor source
(repo: `db/data/02_metrics.sql`, catalogue JSON). Client installations NEVER mutate metrics in-app.

### Client = fully read-only
`MetricsPage` (Shell) is **fully read-only**: no create / edit / delete, no Parameter/Format/Function editing,
no DisplayName/Description/localization editing. The ONLY mutation channel is the **vendor deploy**. A client
needing ANY metric change (even a description) raises a request to the vendor.

**Security rationale:** metric `Parameter`/`Format` are string-interpolated into C# and Roslyn-compiled in the
RTM process (RCE-capable). Allowing client free-text = code-injection / privilege escalation (app-admin -> server
RCE). Read-only client + vendor-curated source removes the input surface entirely (closes finding F-1).

### Vendor process (Metrics session, via the опросник)
ADD / CHANGE / DELETE a metric = vendor-initiated, authored on the vendor source FIRST, shipped in product
versions; installed clients receive a TARGETED deploy.

- **ADD:** опросник -> migration (+ history mirror if applicable) -> install package (migration + manifest carrying
  per-migration SHA-256 + RT/history flag) -> deploy. Dev-first validation (Calc/[MetricId] compiles, mirror complete).
- **CHANGE:** any field (Parameter/Format/Function/DisplayName/Description/localization) — same path, NO in-app edit.
  The package carries localization too, not only Parameter.
- **DELETE: NEVER naked.** The Metrics session MUST author a REPLACEMENT — create a new replacing metric OR
  designate an existing one. The deletion package carries the mapping `{deletedMetricId -> replacementMetricId}`.
  Deploy applies: remove the metric + RE-POINT every usage to the replacement so screens never break. Usage spans
  TWO layers: (1) the **grid binding** `RTSGrid_Cell.Value` — the PRIMARY metric reference in vendor-shipped
  widget grids, re-pointed in the same migration (exactly as the `20260605_004` dedup did). NB: `RTSGrid_Column`
  has NO MetricId — the binding is `RTSGrid_Cell.Value` (common error). (2) **client widget configs** —
  `dashboard_widgets` ConfigJson / dashboard layout that reference the metricId, re-pointed at the client on deploy.
  Usage-validation = locate every reference across BOTH layers; the mandatory replacement closes the gap.

### Deploy mechanism (hot-reload)
The change ships in the install package (migration + manifest). At the client, the read-only MetricsPage **Deploy**
tab shows the delta (package vs the per-metric deploy-ledger, §38a) -> Superadmin clicks Deploy -> privileged
apply-service applies the migration (catalogue-owner DB role, fail-closed token, SHA-256 hash-integrity) + writes
the ledger + audit -> SignalR `compileMetrics(RT MetricIds)` -> RTM incrementally compiles the new/changed metric
**live, no restart**. History half (dotted-id) = no compile (query-time). See `docs/metrics-hot-reload-contract.md`.

<<<END>>>

## Verify + commit
- grep the section header "Metric Lifecycle — vendor product-constants" present; tail -3 proper close; headings intact.
- `git add -f .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md` ; commit:
  `docs: rtm-metrics-expert — metric lifecycle (vendor-constants, read-only client, deploy-only add/change/delete+replacement)`
- §0.6 verify + cc_post_commit.sh + HEAD re-sync. NO push (rides next barrier).

## Report: section appended + commit hash. NO push.
