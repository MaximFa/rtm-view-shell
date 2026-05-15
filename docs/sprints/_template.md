# Sprint NN: <name>

**Status:** Draft | Approved | In Progress | Closed
**Window:** YYYY-MM-DD .. YYYY-MM-DD
**Owner:** <name/role>
**Related ADRs:** ADR-XXX, ADR-XXX

---

## 1. Scope

### In scope

- ...
- ...

### Explicitly out of scope

- ...
- ...

*(Listing what is OUT prevents scope drift later. Be specific — "widget rendering" is
out, not "UI improvements".)*

---

## 2. Architectural micro-choices (gate before start)

These must be agreed **before any code is written**. Each item: state the question, list
options, give a recommendation. Do not start work until all are answered.

1. **<question 1>**
   - A: ...
   - B: ...
   - Recommendation: ... — Decision: ___
2. **<question 2>**
   - ...
   - Decision: ___
3. ...

*(3–7 items typical. If more than 7 — sprint is too big, split into Phase A / Phase B.)*

---

## 3. Definition of Done

Each item must be **independently checkable** (a reviewer can verify yes/no without
asking the author).

- **DoD-1:** ...
- **DoD-2:** ...
- **DoD-3:** ...
- **DoD-4:** ...
- **DoD-5:** ...
- **DoD-6:** ...
- **DoD-7:** ...
- **DoD-8 (test coverage):** ≥ N tests in `tests/CcDashboard.Tests.<layer>/`, covering ...
- **DoD-9 (security):** `/security-pre-merge` passes
- **DoD-10 (architecture):** `/architecture-check` passes
- **DoD-11 (audit):** All state-changing operations write the required `audit.audit_logs`
  events (cf. CLAUDE.md §16)

*(7–11 items typical. Less than 7 — probably underspecified. More than 11 — split.)*

---

## 4. Known limitations

What this sprint deliberately does **not** solve, and why:

- ...
- ...

---

## 5. Open questions

Questions raised during planning that don't block start but need an answer before close:

- **OQ-1:** ... — Status: Open
- **OQ-2:** ... — Status: Open

---

## 6. Implementation notes

Free-form: pointers to relevant code, sequence diagrams, sample payloads, gotchas
discovered during planning.

---

## 7. Phase split (if applicable)

Only fill this section if the sprint is large enough to warrant a Phase A / Phase B
split with an intermediate commit and `STOP-FOR-REVIEW` gate.

### Phase A
- Goal: ...
- Exit criteria: ...
- Commit message format: `Sprint NN Phase A: ...`

### Phase B
- Goal: ...
- Exit criteria: ...
- Commit message format: `Sprint NN Phase B: ...`
