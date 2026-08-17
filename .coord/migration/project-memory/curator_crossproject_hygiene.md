---
name: curator-crossproject-hygiene
description: "RTM<->AD bus hygiene: parity of DECISIONS, never cross-post bus content; curator is the sole bridge"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 28320b02-5f3f-492f-81ac-eec5ea8b4b8e
---

Operator directive 2026-06-21: maintain strict hygiene between RTM View Shell and Agent Desktop buses.

**Rule:** NORM-CUR-01 means parity of DECISIONS/NORMS across both projects — it does NOT mean cross-posting bus content. Each project's `.coord/` bus content stays project-local. The ONLY cross-project bridge is the curator, via its dedicated channels (RTM `inbox/curator.md`; AD `curator-replies.md` ↔ AD `inbox/curator.md`).

**Why:** keeps each project's coordinator inbox clean and project-scoped; prevents leakage/noise; the curator is the single accountable conduit.

**How to apply:** do NOT write an AD-side note (e.g. "AD rollout started") into the RTM coordinator's inbox, or vice versa. If a decision must reflect on both, apply it on each project's OWN bus via that project's own roles — the curator routes intent, not raw cross-posts. When tempted to "mirror a note," ask first; default is hold.

Pin: when AD role-skill rollout was dispatched (2026-06-21), I offered to mirror a note to RTM coordinator-0612; operator said no — "соблюдаем гигиену между RTM и AD". Related: [[curator-checkpoint-0620]].

**AD work is PAUSED / handled SEPARATELY (operator 2026-06-23).** Do NOT initiate AD-side reconciliations or parity actions for now — e.g. the role-test (RTM) ≡ role-qa (AD) functional-gate overlap was flagged; operator said "AD пока не трогай, будем работать отдельно". Note parity gaps for later, but do not act on the AD side until the operator reopens AD work. NORM-CUR-01 stays a standing norm but its AD-side application is deferred by operator.

**ANY AD change → only through the OPERATOR (2026-06-21).** Operator rule: every change in the Agent Desktop project goes through Max. Incident: I added the `incident` role to AD for RTM-parity in the rollout runbook (it wasn't in AD before) — operator approved post-factum but set the rule. Going forward the curator does NOT introduce AD roles/CLAUDE.md/code/workflow changes unilaterally; any AD-side change (incl. the §40-analog mandatory-skill-load directive, CLAUDE.md edits, mass live-adoption pokes) must be drafted → operator-approved → then committed (native-CC, NO push). The curator gives discipline-level directives but binds their APPLICATION to operator approval. (Discipline directives mirror RTM but are norm-level, not code-gated.)
