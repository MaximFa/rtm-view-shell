---
name: feedback-docs-concrete
description: "Docs must be concrete for the real reader with end-to-end worked examples, not generic"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9db921d7-ff36-45cb-b8ef-1eacba950afd
---

Documentation deliverables must be PREDMETNO/concrete for the specific real reader, not generic abstractions.

**Why:** 2026-06-10 the operator rejected the first BI integration guide (docs/bi/RTM_BI_Integration_Guide_*.docx)
as "слишком обще, непредметно — представитель BI-команды клиента совершенно не понял бы." The schema facts were
correct, but the doc described concepts abstractly without showing a reader how to actually do the job.

**How to apply:** write from the named reader's seat (e.g. a BI/data-warehouse engineer at the client). Include
end-to-end WORKED examples: sample rows of the real tables with realistic values → a concrete business question →
the exact SQL → the resulting numbers the reader can reproduce. Add a "getting started in N minutes" path and a
common-mistakes section. Verify every technical fact against db/schema.sql + CLAUDE.md before writing. Final test:
"could THIS reader do the work from this text alone?" Owned going forward by RTM Tech Writer (techwriter-0610);
see [[project_coordinator_checkpoint_0609]] roster (standing specialist #9, docs/** authoring, in push quorum).
