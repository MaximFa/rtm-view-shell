# ADR Index — RTM View Shell

This is the authoritative registry of all Architecture Decision Records.
**Rules:**

- ADR IDs are monotonic three-digit numbers (`ADR-001`, `ADR-002`, ...). **Never reuse.**
- An ADR file is created from `_template.md`.
- When an ADR is superseded, set its `Status` to `Superseded by ADR-XXX` — do not delete.
- The TZ (`CC_Dashboard_Shell_TZ_v1.3_EN.docx` and later versions) references ADRs by ID.

## Open

| ID | Title | Tags | Owner | Date |
|---|---|---|---|---|

## Accepted

| ID | Title | Tags | Date |
|---|---|---|---|

## Superseded

| ID | Title | Superseded by | Date |
|---|---|---|---|

## Withdrawn

| ID | Title | Reason | Date |
|---|---|---|---|

---

## How to write an ADR

1. Copy `_template.md` to `ADR-NNN-short-slug.md` (next free ID, kebab-case slug).
2. Fill in **Context** with enough detail that a reader six months later can reconstruct
   the situation without asking.
3. Document **at least two options**. "Do nothing" or "keep current behaviour" is a
   legitimate option.
4. **Rationale** must reference concrete requirements/markers — vague justification is
   a red flag.
5. List **Open Questions** explicitly. An ADR with unanswered OQs can still be Accepted
   if the OQs don't block implementation; mark them clearly.
6. Add an entry to the appropriate table in this index file.

## When NOT to write an ADR

- A coding-style preference (use a linter / `.editorconfig`).
- A trivial library choice with no alternatives debated (just commit it).
- A bug fix (use a commit message).

The litmus test: *Will a future developer/auditor want to know "why did we do this?"
six months from now?* If yes → ADR.
