---
role: <role>
project: <RTM View Shell | Agent Desktop>
version: 0.1
last_verified: <UTC>
owner: <role>
reviewer: curator
---
# role-<role> — <Role> role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (git log of <territory> + .coord/journal.md + prod logs + .claude/memory), NOT session
> narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: <one line — what this role owns + its claim/territory>.
**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.
Cardinal truths (3-7, each SOURCE-pinned):
> ROUTING (operator 2026-06-22): §A holds ONLY CRITICAL AMPLIFIERS — load-bearing invariants that change init-time behaviour / high recurrence / large blast-radius. Everything else stays in §B. Keep within the ~40-line cap.
- <truth 1> · SOURCE:<commit/file:line/journal-ts>
- <truth 2> · SOURCE:<...>
- ...

## §B LESSONS  (append-only · dated · source-pinned · status)
> ROUTING: record EVERY lesson here (append-only, nothing too small). Elevate to §A as a source-pinned cardinal ONLY if it is a critical amplifier (see §A). Default = §B. SOURCE: operator 2026-06-22 / role-skill-standard 'Capture discipline'.
- <date> · <what happened> · <rule> · SOURCE:<...> · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
- <check 1: how to verify cardinal truth 1 against the code/artifact today>
- <check 2: ...>

## §D REFERENCE  (optional · NOT loaded each init)
## COMMIT-block guidance (AGNOSTIC, curator-blessed 2026-06-21)
COMMIT must be an EXPLICIT executable step (NOT under `##` comments — commands under `##` are read as docs and do not run) + `git add -f .claude/skills/...` + verify HEAD advanced + `git cat-file -e HEAD:<path>`.
