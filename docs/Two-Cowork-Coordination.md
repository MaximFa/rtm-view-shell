# Two-Cowork Coordination — protocol proposal (extends CLAUDE.md §42)

> **Status:** PROPOSAL — 2026-06-08, drafted by coordinator-0608, pending operator adoption.
> On adoption: fold into the `session-coord` skill + a new **CLAUDE.md §44**.
>
> **Decided with operator (2026-06-08):** two **separate clones/branches** (not a shared mount);
> coordinators sync over a **git-backed channel**; work split **by layer/role**.

This document scales §42 (single shared working tree, one coordinator) up to **two Cowork
instances, each with its own coordinator**, kept in sync. §42 stays **unchanged INTRA-Cowork**;
this layer governs only the seam BETWEEN the two Coworks.

---

## 1. Topology

Two Cowork instances, each = its own repo clone/worktree + its own internal `.coord/` bus +
**one coordinator** (the full §42 protocol runs inside each, untouched).

| Cowork | Role bundle (specialization 9-role map) | Working branch |
|---|---|---|
| **A — "Backend"** | RTM Server, Metrics, DBA, Devops | `v2-backend` |
| **B — "Frontend"** | Shell, UX-UI, Widget, QA | `v2-frontend` |
| **Security** | Shared release gate — **mandatory ack before any prod release** | exercised at integration (§5) |

- **Integration trunk:** `v2` on origin (the shared release branch).
- **Release captain:** one designated coordinator runs the cross-level barrier and the prod push.
  Default = **Cowork-A** (it owns Devops + release tooling: prod-release, orchestrators, Compare-ToBaseline).

---

## 2. Why git, not a shared mount

The mount is our *unreliable* channel (L-SC-04 async cross-view drops, L-SC-10 phantom dirents);
the file-bus `.coord/` is best-effort even inside ONE Cowork (this is the standing
**[CRITICAL]** backlog item). Across two instances a mount channel would be strictly worse.

Git is our *proven* channel (L-SC-18 "git = truth", L-SC-19 append-reliability). Therefore:

- Same-file overlap across branches surfaces as a **git merge conflict — safe and recoverable**,
  unlike the **silent lost-update** on a shared mount (L-SC-09 — the second writer destroys the
  first with no warning).
- Cross-coordinator messages travel as **commits** — ordered, atomic, no drop, no phantom.

---

## 3. Cross-coordinator channel — orphan `coord` branch

A dedicated git branch **`coord`** holding ONLY coordination files (no source code) — keeps the
cross-channel out of `v2` and conflict-light. Both coordinators pull/push it.

Files under `.coord/cross/` on the `coord` branch:

| File | Purpose |
|---|---|
| `ownership.md` | module→Cowork map + **seam-file single-owner table** (cross source of truth, §6) |
| `inbox-coord-A.md`, `inbox-coord-B.md` | directed cross messages (block format = §11 of session-coord) |
| `ledger.md` | append-only cross events: branch push, integration, barrier, release |
| `barrier.md` | active cross-release barrier state (presence = **content-based** `-s`+`cat`, never `-f`, per L-SC-10) |

**Handshake (every cross write):**
```
git fetch origin coord  ->  rebase local coord  ->  read  ->  act
  ->  append message (Python + os.fsync)  ->  commit  ->  git push origin coord
```
Push rejected (peer pushed first) -> `fetch` + `rebase` (append-only files auto-merge) -> retry.
**Backstop** when even git is contested: the coordinator reports the message to the operator in
chat, who relays it (operator + git are the reliable channels; mirrors L-SC-19).

---

## 4. Branch model & integration

- Each Cowork works on its own branch and pushes to origin **after its own L1 §42.7 barrier**.
- **L2 integration:** the release captain merges `v2-backend` + `v2-frontend` -> `v2`.
  Cadence: **daily / per-epic-completion** — small deltas = fewer seam conflicts.
- After each integration both Coworks `git merge origin/v2` back into their branch to resync
  (keeps drift small).

---

## 5. Two-level push / release barrier

**L1 (intra-Cowork):** the existing §42.7 barrier inside each Cowork -> pushes that Cowork's own
branch to origin. Unchanged.

**L2 (cross integration / release):**
1. Captain writes `barrier.md` on `coord`: proposes integrating `A@<sha>` + `B@<sha>` -> `v2`.
2. Each coordinator **cross-acks** (its branch is clean and L1-pushed at `<sha>`) via its
   cross-inbox / `ledger.md`.
3. Captain: fetch both branches -> merge to `v2` -> resolve any **seam conflicts** with the peer
   coordinator (via cross-inbox) -> run cross-build / integration tests -> **Security ack
   (mandatory)** -> push `v2` -> cut the prod release if applicable.
4. Both Coworks resync from `v2`. Captain journals `INTEGRATED` / `RELEASED` on `ledger.md`.

---

## 6. Seam files — single-owner rule

Files both sides legitimately touch get **one owner** declared in `ownership.md`; the non-owner
requests a change via the peer's cross-inbox (a cross-Cowork version of the §9 FIFO queue).

Defaults (confirm in `ownership.md`):

| Seam file | Owner | Rule |
|---|---|---|
| `CLAUDE.md` | captain | append-only §-sections auto-merge; edits to an EXISTING shared section -> captain only |
| `src/CcDashboard.Web/Program.cs` | B (Frontend/Shell host) | non-owner requests via cross-inbox |
| `db/schema.sql`, `db/baseline.sql` | A (DBA) | regenerated only by A's Export-All |
| `src/.../RtsEntities.cs` | A (DBA/RTM) | — |
| `NavMenu.razor`, layout/CSS tokens | B (UX-UI/Shell) | — |

**A whole release stays in ONE Cowork** — never split a release across both (e.g. the Server-234
upgrade is wholly in A).

---

## 7. Operator role across two Coworks

Sessions never poll; the operator is the **scheduler across BOTH apps** — now also relaying pokes
between the two Cowork instances. New cross commands (prefix `коорд:`, intra-Cowork set unchanged):

| Command | Addressee | Action |
|---|---|---|
| `коорд: кросс-статус` | a coordinator | read `coord` branch -> report cross state (branches, barrier, integration debt) |
| `коорд: кросс-ack` | a coordinator | confirm own branch clean + L1-pushed at `<sha>`, write ack on `coord` |
| `коорд: интеграция` | captain | propose / run L2 integration (§5.1–5.4) |
| `коорд: релиз` | captain | run L2 release barrier incl. **Security ack** + prod push |

---

## 8. Migration from the current single Cowork

1. **This Cowork -> Cowork-A (Backend).** Sessions `devops-2`, `metrics-2` fit directly.
   `daytrend-2` (RTM / DB / widget data path) stays in A; its Shell-component touches become
   **seams** -> cross-request to B.
2. **Spin up Cowork-B (Frontend)** for Shell / UX-UI / Widget / QA; migrate `test-5` (QA) there.
3. **Create the `coord` orphan branch** and seed `.coord/cross/ownership.md`. Branch
   `v2-backend` / `v2-frontend` from `v2`.
4. **Finish the Server-234 upgrade in A first** — do not split a release mid-flight.

---

## 9. Open defaults to confirm with the operator

- Branch names: `v2-backend` / `v2-frontend` vs `v2-a` / `v2-b`.
- Release captain = Cowork-A (Backend) — owns Devops. (Alternative: rotate, or B owns release.)
- Integration cadence: daily vs per-epic.
- Cross-channel carrier: orphan `coord` branch (recommended) vs `.coord/cross/` committed on `v2`.
- Whether Security is its own (3rd) Cowork or a role-skill loaded by the captain at L2.

---

*Drafted 2026-06-08 by coordinator-0608. Uncommitted in working tree — commit via CC task or next
barrier; flagged in coordinator handoff so PD-007 cannot silently drop it.*
