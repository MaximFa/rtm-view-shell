---
name: docx-layout-conventions
description: "Operator's pagination/layout rules for the BI .docx deliverables (no split tables, no orphan headings, tight packing) and how to implement them in docx-js"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 354b8d04-e136-44ac-8d8d-6a17e576c95b
---

**STANDING RULE (operator directive 2026-06-11, permanent — not session-only): ALL project documents
use the "RTM View Shell Data Connector" template.** That means every document (BI guides, runbooks,
methodology, admin/user guides, etc.) is produced with the branded docx-js generator framework
(`editing/build/gen*.js`): INSIGHTENSE cover with the logo, the mandatory revision-history table, a
Contents/TOC populated via the UNO render (not plain soffice/pandoc), navy/blue headings, firm-styled
tables (navy header + zebra), callout boxes, dark monospace code blocks, keep-together pagination, and
a logo header + page footer. Markdown may be the editing source, but the approved docx/pdf MUST use this
template. Do NOT ship plain pandoc/soffice output as the approved copy. See [[brand-insightense]].

Operator's layout preferences for the RTM View Shell Data Connector .docx guides (chosen track =
plain Word .docx, built with docx-js; the document-design HTML/PDF and Diátaxis tracks were rejected).

**Why:** the operator reviews pagination closely and wants a clean, tightly-packed Word doc with no
awkward breaks. These rules were iterated 2026-06-10 and approved.

**How to apply (docx-js generator rules):**
- **Tables must not split across a page.** Set `cantSplit:true` on every `TableRow`, AND `keepNext:true`
  on each row's cell paragraph **for all rows EXCEPT the last** (the last row has NO keepNext so the
  table stays whole but does not drag the following block into a chain). Putting keepNext on the last
  row too over-chains and wastes pages.
- **The 195-row metrics catalogue is the exception** — it cannot fit one page, so use only per-row
  `cantSplit:true` (no keepNext); let it break between rows.
- **Headings never orphan from their block.** `keepNext:true` on every H1/H2/H3.
- **An intro line before a list/table stays with it.** Auto-rule: a paragraph whose text ends with `:`
  gets `keepNext:true` (e.g. "Every agent status belongs to one of these groups:").
- **Bullet / numbered lists stay together.** `keepNext:true` on all items EXCEPT the last (so e.g. the
  status-group list doesn't orphan UNAVAILABLE).
- **Callouts & code blocks** are single-cell tables — `cantSplit:true` on the one row keeps them whole.
- **Pack pages:** remove redundant forced `PageBreak`s between short consecutive sections (e.g. About +
  How-to-read share one page). Keep page breaks only for true section starts (title, Contents, Part 1/2).
- **TOC:** generated `TableOfContents` needs `features:{updateFields:true}` so Word populates it on open
  (LibreOffice render shows it empty — that's a converter artdefact, not a bug).
- **Logo:** INSIGHTENSE color logo via `ImageRun` centered on the title page + small in the header
  (PNG from docs/assets/brand/Logo Files/png/). See [[brand-insightense]].

**Verify pagination** by converting to PDF with the docx skill's soffice.py + pdftoppm and eyeballing
pages; remember the empty-TOC-in-LibreOffice caveat.
