---
name: coordinator-inbox-permanent-not-slug
description: "CORRECTED 2026-06-21: write to the PERMANENT inbox/coordinator.md — slug inboxes (coordinator-<MMDD>.md) are DEPRECATED (§42.8). The earlier 'use slug' rule is OBSOLETE."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 354b8d04-e136-44ac-8d8d-6a17e576c95b
---

When flushing to the coordinator on the .coord bus, write to the **active coordinator's SLUG inbox**
(e.g. `.coord/inbox/coordinator-0609.md`), NOT the generic `.coord/inbox/coordinator.md`.

**Why:** 2026-06-11 the operator reported the coordinator "didn't see" my messages — I had been
flushing to `.coord/inbox/coordinator.md` (a large legacy/generic file, 6000+ lines). The active
coordinator (coordinator-0609) reads its **slug** inbox `.coord/inbox/coordinator-0609.md` — that's
where other specialists (e.g. devops-2-0607) post and where it actually replies. The generic
coordinator.md is stale/unread.

**How to apply:** find the current coordinator's slug from `.coord/sessions/` (the active `role:
coordinator` session), and append to `.coord/inbox/<that-slug>.md`. The coordinator slug rotates over
time (coordinator-0606 / -0608 / -0609 …) — re-check each session. Protocol §11 nominally says
`coordinator.md`, but practice/operator ground-truth is the slug inbox. Related: [[coordinator-inbox-rule]].

**✅ RESOLVED 2026-06-21 (operator ground-truth, Max):** the canonical target is the **PERMANENT role
mailbox `inbox/coordinator.md`** — NOT a slug inbox. Slug inboxes (`inbox/coordinator-<MMDD>.md`) are
**DEPRECATED** per CLAUDE.md §26.1 / §42.8 (permanent `inbox/<role>.md` is the NORM; auto-archival
NORM-CUR-06 keeps it tamed). Max explicitly corrected me this session after I posted Security verdicts to
`inbox/coordinator-0612.md`. **Go-forward: write ONLY to `inbox/coordinator.md`. No more double-write, no
slug.** The original "write to slug" advice (06-11) is OBSOLETE. This applies to ALL role mailboxes:
write to the recipient's permanent `inbox/<role>.md`, the recipient writes its own `> handled` marker.
