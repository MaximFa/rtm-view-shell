# Documentation management convention (docs/bi/, and each top-level docs folder)

## Folders
- `approved/doc/` — approved source documents (.docx), version-stamped.
- `approved/pdf/` — approved rendered PDFs, same version.
- `editing/`      — working (draft) versions being edited.
- `editing/build/`— build scripts/assets so the generated .docx is reproducible.

Every approved document is saved in **both** formats (.docx + .pdf) at the same version.
Filename carries the version (e.g. `_v1.0`); the Product release ID may also be added to the
filename for traceability.

## In-document revision history (mandatory)
Every document contains a **Document revision history** table near the front:

| Version | Date | Summary of changes | Product release ID |

The **Product release ID is assigned by the coordinator** (links the doc version to its code release).

## Change flow
1. Edit the working copy in `editing/`.
2. Submit the changed doc to the **coordinator for review**, and request the **Product release ID**.
3. After coordinator review, present to the **operator** for approval.
4. On approval: fill the release ID into the revision table, render, and place the versioned
   `.docx` + `.pdf` in `approved/doc/` and `approved/pdf/`.

## Push-barrier (quorum) rule for the Tech Writer
At every push barrier, the Tech Writer verifies whether the pending changes require documentation
updates. If they do, the docs are updated in `editing/`, routed through coordinator → operator, and
placed in `approved/`. **The Tech Writer gives a READY ack only when the affected docs are updated and
present in `approved/`** (otherwise HOLD).
