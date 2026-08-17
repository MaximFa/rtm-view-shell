---
name: docx-gen-divergence
description: Branded docx generators (mk_*.py / gen_*.js) carry a HAND-CODED body — they do NOT read the editing .md; edits must be ported to BOTH or the docx lags
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 354b8d04-e136-44ac-8d8d-6a17e576c95b
---

The branded "RTM View Shell Data Connector" docx generators (`editing/build/mk_*.py` → `gen_*.js`,
e.g. `mk_runbook.py`, `gen.js` for BI, `gen_a07.js`) build the document body from **hand-coded
docx-js helper calls** (H1/H2/P/bullets/tbl/callout). They do **NOT** parse the editing `.md`.

**Consequence (md↔gen divergence):** editing the `.md` source does NOT change the rendered docx.
Every content change must be ported into BOTH the `.md` (source of truth for review) AND the
generator body, or the filed docx silently lags the md. This bit the runbook v1.2 filing
(2026-06-13): I'd added 10 NORM-CUR norms to the editing md but they were absent from the docx until
I hand-ported every delta into `mk_runbook.py`'s `BODY` string and re-ran.

**How to apply when filing/regenerating a branded docx:**
- After editing the `.md`, port the same deltas into the generator's `BODY`/`COVER` (find the anchor
  string, str.replace via Python — Edit tool is banned on the mount; patch in `/tmp/build` then copy
  back to `editing/build/`).
- **ALWAYS verify before filing:** extract the docx text (`zipfile` → `word/document.xml` → strip
  tags) and grep for every token/norm that must be present. Do not file on md-coverage alone.
- Render pipeline: `mk_*.py` → `node gen_*.js` (→ docx in /tmp/build) → UNO `topdf.py` (populates the
  TOC; plain soffice/pandoc leaves it empty). Launch soffice + render + `kill` it in ONE bash call
  (a lingering background soffice makes the tool call exit 143).

**Durable fix proposed to coordinator (2026-06-13):** a single `md → branded-docx` renderer so the md
becomes the one source and every filing is one regen (serves the operator's anti-lag rule:
"regenerate against the norm log at EACH filing"). Pending go-ahead.

Related: [[docx-layout-conventions]], [[doc-governance-approved-editing]].
