---
name: doc-governance-approved-editing
description: "Operator's documentation governance — approved/editing folders, version table, coordinator-assigned release ID, push-barrier ack gate"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 354b8d04-e136-44ac-8d8d-6a17e576c95b
---

Operator's documentation governance for the RTM project (set 2026-06-10). Applies to **each top-level
docs folder** (rolled out in docs/bi/ first; extend to other doc areas as touched). See
docs/bi/README.md.

**Operator decisions 2026-06-12:** (1) superseded doc versions → `docs/archive/` (move via native-CC `git mv`,
never delete); keep the current in place; history lives in the in-doc revision table. (2) **Mass template migration** —
migrate ALL published docs (A-02, B-02, TZ, SAD, Security Overview, Metrics Overview, Backup/Restore, …) into the
Data Connector template NOW (not only on next revision), through governance; old loose copies → `docs/archive/`.

**Folder layout (per top doc folder):**
- `approved/doc/` — approved .docx, version-stamped; `approved/pdf/` — approved .pdf, same version.
- Every approved document is saved in BOTH formats (.docx + .pdf) at the same version.
- Filename carries the version (e.g. `_v1.0`); the push/release id MAY also go in the filename.
- `editing/` — working drafts; `editing/build/` — generator scripts/assets for reproducibility.

**Mandatory in-document revision-history table** near the front of every doc:
`Version | Date | Summary of changes | Product release ID`.
The **Product release ID is assigned by the COORDINATOR** (links the doc version to its code release) —
request it; never invent it.

**Change flow:** edit in `editing/` → submit to **coordinator for review** AND request the release ID →
then present to the **operator** → on approval, fill the release ID, render, and place versioned
.docx + .pdf in `approved/doc` + `approved/pdf`. (Changed docs go to the coordinator first, then the operator.)

**Push-barrier (quorum) duty:** at every push barrier I (Tech Writer) verify whether the pending changes
require doc updates. If yes → update in editing → coordinator review → operator → approved. **Give a READY
ack ONLY when the affected docs are updated and present in `approved/`; otherwise HOLD.**

Related: [[docx-layout-conventions]], [[brand-insightense]].
