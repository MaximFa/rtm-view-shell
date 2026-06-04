# Task: Push only RTM commits to origin

## Goal

Push ONLY the two RTM-specific commits to origin, without pushing Shell/relay/install commits.

Commits to push:
- `fe502d8` fix(RTM): idempotent createBusinessUnit — check existence before INSERT
- `2165798` fix(RTM): GetScalar returns string, not object — use string.IsNullOrEmpty

## Working directory

`D:\Claude\Projects\RTM View Shell`

## Steps

### Step 1 — Create branch from origin/v2

```bash
git fetch origin
git checkout -b rtm-backend origin/v2
```

### Step 2 — Cherry-pick the two RTM commits

```bash
git cherry-pick fe502d8
git cherry-pick 2165798
```

If any conflicts arise — resolve them, then `git cherry-pick --continue`.

### Step 3 — Push the branch

```bash
git push origin rtm-backend
```

### Step 4 — Switch back to v2

```bash
git checkout v2
```

### Step 5 — Verify

```bash
git log origin/rtm-backend --oneline -5
```

Must show both cherry-picked commits on top of origin/v2.

## No file writes in this task — no pre-commit-check needed
