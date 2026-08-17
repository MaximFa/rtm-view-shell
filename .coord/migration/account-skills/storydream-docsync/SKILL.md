---
name: storydream-docsync
description: Post-sprint documentation sync for StoryDream. Detects code changes via git, maps them to ТЗ/PLAN sections (safety pipeline and data model are CRITICAL priority), shows an impact report, waits for confirmation, then drafts patches. Trigger when user says: "sync docs", "doc sync", "обнови доки после спринта", "синхронизировать документацию", or at the end of any sprint.
---


# storydream-docsync

> Post-sprint documentation sync for the **StoryDream** project.
> Detects code changes since the last sprint, maps them to ТЗ/PLAN sections,
> shows a prioritised impact report, waits for confirmation, then drafts patches.
> **Safety pipeline and data model changes are always CRITICAL priority.**

---

## When this skill is triggered

Invoke when the user says any of:
- "sync the docs after Sprint N"
- "doc sync"
- "update the documentation"
- "синхронизировать документацию"
- "обнови доки после спринта"
- "документация актуальна?"
- at the end of a storydream-sprint workflow

---

## Project File Paths

| Resource | Windows path | Bash path |
|---|---|---|
| Repo root | `F:\EAIP` | `/sessions/adoring-funny-hypatia/mnt/F:--EAIP/` |
| Technical Spec (ТЗ) | `F:\EAIP\ТЗ_StoryDream.md` | `/sessions/adoring-funny-hypatia/mnt/F:--EAIP/ТЗ_StoryDream.md` |
| Implementation Plan | `F:\EAIP\PLAN_StoryDream.md` | `/sessions/adoring-funny-hypatia/mnt/F:--EAIP/PLAN_StoryDream.md` |
| Sprint reports | `F:\EAIP\sprint-reports\Sprint{N}_Report.md` | — |
| Sync log | `F:\EAIP\docs\docsync-log.json` | — |
| Safety audits | `F:\EAIP\docs\safety-audits\YYYY-MM.md` | — |

---

## Step 1 — Determine Change Window

Ask the user (or infer from context): which sprint just finished?

### 1a. If git repo exists — use tags

```bash
# Check for sprint tags
git -C /sessions/adoring-funny-hypatia/mnt/F:--EAIP/ tag | grep sprint

# Get changed files since a tag (e.g., sprint/2)
git -C /sessions/adoring-funny-hypatia/mnt/F:--EAIP/ \
  log --name-only --pretty=format: sprint/2..HEAD 2>/dev/null \
  | sort -u | grep -v '^$'
```

### 1b. If git repo exists but no tags — use date

```bash
# Changed files in the last 2 weeks (adjust as needed)
git -C /sessions/adoring-funny-hypatia/mnt/F:--EAIP/ \
  log --name-only --pretty=format: --since="2 weeks ago" 2>/dev/null \
  | sort -u | grep -v '^$'
```

### 1c. No git repo yet (early project phase)

Ask the user to list changed files. Accept a comma-separated or line-separated list.
Proceed to Step 2 with that list.

### 1d. Cross-reference sprint report

If `F:\EAIP\sprint-reports\Sprint{N}_Report.md` exists, read it — it may list
the files changed this sprint explicitly.

---

## Step 2 — Build the Impact Map

For every changed file, look it up in the mapping table below.
Build a list of `(priority, file, ТЗ sections, PLAN sections, note)` tuples.

### Code → Documentation Mapping

| Priority | File pattern | ТЗ section(s) | PLAN section(s) | Notes |
|---|---|---|---|---|
| 🔴 CRITICAL | `packages/story-engine/src/constants.ts` | §5 [SAFE-05] | — | SAFETY_BLOCK must match exactly. If changed, document why. |
| 🔴 CRITICAL | `packages/story-engine/src/safety.ts` | §5 [SAFE-01]–[SAFE-08] | — | Any change to moderation layer = mandatory update |
| 🔴 CRITICAL | `packages/db/schema.prisma` | §7 (Data Model) | §2 Monorepo | Field additions/removals reflected in Prisma excerpt |
| 🔴 CRITICAL | `packages/db/migrations/` | §7 | Sprint table | New migration = new sprint DB note in PLAN |
| 🟠 HIGH | `packages/story-engine/src/generator.ts` | §4 [AI-01]–[AI-09] | §3 Tech Stack | Model name, streaming, fallback logic |
| 🟠 HIGH | `packages/story-engine/src/builder.ts` | §4 [AI-02], [AI-03] | — | Prompt construction changes |
| 🟠 HIGH | `packages/story-engine/src/scenarios.ts` | §3 Functional Req., §16 | — | Added/removed scenarios |
| 🟠 HIGH | `packages/story-engine/src/scenario-templates/` | §16 | — | Per-scenario prompt changes |
| 🟠 HIGH | `packages/audio/src/` | §6 [AUDIO-01]–[AUDIO-06] | §3 | Provider, voice map, SSML |
| 🟠 HIGH | `packages/images/src/` | §8 [IMG-01]–[IMG-08] | §3 | Provider, prompt prefix, safety scan |
| 🟠 HIGH | `workers/audio-generator/` | §6 [AUDIO-03] | §2 Monorepo | Queue logic, retry |
| 🟠 HIGH | `workers/image-generator/` | §8 [IMG-02] | §2 Monorepo | Queue logic, per-story count |
| 🟡 MEDIUM | `apps/web/app/api/stories/` | §4, §9 Auth | §2 | Rate limiting, SSE streaming, CRUD |
| 🟡 MEDIUM | `apps/web/app/api/webhooks/stripe/` | §10 [PAY-05] | — | Webhook events handled |
| 🟡 MEDIUM | `apps/web/lib/auth.ts` | §9 [AUTH-01]–[AUTH-05] | — | Session config, magic link |
| 🟡 MEDIUM | `apps/web/lib/stripe.ts` | §10 Payments | — | Stripe client changes |
| 🟡 MEDIUM | `apps/web/app/(app)/create/` | §14 Screen 02 | — | Wizard steps |
| 🟡 MEDIUM | `apps/web/app/(app)/story/` | §14 Screen 03 | — | Story viewer |
| 🟡 MEDIUM | `apps/web/app/(app)/library/` | §14 Screen 04 | — | Library grid |
| 🟡 MEDIUM | `apps/web/app/(marketing)/` | §14 Screen 01 | — | Landing page |
| 🟡 MEDIUM | `packages/story-engine/src/fallback-stories/` | §5 [SAFE-06], [AI-06] | — | Count must stay ≥ 20 |
| 🟢 LOW | `config/voices.json` | §6 [AUDIO-02] | — | Voice map |
| 🟢 LOW | `next.config.ts` | §12 [SEC-02] | — | CSP headers |
| 🟢 LOW | `apps/web/components/` | §14 UI Screens | — | Component-level UI |
| 🟢 LOW | `pnpm-workspace.yaml`, `package.json` | §2 Tech Stack | §3 Tech Stack table | Dependency changes |
| 🟢 LOW | `.github/workflows/` | §13 CI/CD | §7 CI/CD pipeline | CI step changes |
| 🟢 LOW | `apps/web/app/api/auth/` | §9 Auth | — | NextAuth route changes |

Files not in the table: skip unless they directly implement a named ТЗ section.

---

## Step 3 — Safety Pipeline Quick-Check

Always run these checks, regardless of which files changed:

```bash
REPO=/sessions/adoring-funny-hypatia/mnt/F:--EAIP/

# 1. Verify SAFETY_BLOCK exists and is not empty
grep -c "SAFETY_BLOCK" "$REPO/packages/story-engine/src/constants.ts" 2>/dev/null \
  || echo "FILE NOT FOUND"

# 2. Count fallback stories
ls "$REPO/packages/story-engine/src/fallback-stories/" 2>/dev/null | wc -l || echo "0"

# 3. Check SKIP_SAFETY guard exists
grep -r "SKIP_SAFETY" "$REPO/packages/story-engine/src/" 2>/dev/null | head -5

# 4. Verify moderation calls present in safety.ts
grep -c "openai\|moderation\|azure\|anthropic" \
  "$REPO/packages/story-engine/src/safety.ts" 2>/dev/null || echo "FILE NOT FOUND"
```

If `packages/story-engine/` doesn't exist yet (pre-Sprint 3), note "Not implemented yet" for all safety checks.

---

## Step 4 — Generate Impact Report

Present this report, then **STOP and wait for user confirmation**.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  StoryDream Doc Sync — Sprint [N] Impact Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Change window : [git tag range or date range]
Files changed : [N total]

🔴 CRITICAL  (update before next sprint review)
──────────────────────────────────────────────
[file] → ТЗ [section]: [one-line description of what changed and why it matters]
...

🟠 HIGH  (update this sprint)
──────────────────────────────────────────────
[file] → ТЗ/PLAN [section]: [description]
...

🟡 MEDIUM  (update if content changed)
──────────────────────────────────────────────
...

🟢 LOW  (optional)
──────────────────────────────────────────────
...

⚠️  Safety Pipeline Status
──────────────────────────────────────────────
SAFETY_BLOCK     : [unchanged ✅ / CHANGED ⚠️ — describe change]
Fallback stories : [N files] [✅ ≥20 / ⚠️ BELOW MINIMUM]
SKIP_SAFETY guard: [present ✅ / missing ⚠️]
Layer coverage   : [all 7 ✅ / missing: list them]

📄 ТЗ_StoryDream.md — sections to update:
  • [§N Title]
  • ...

📄 PLAN_StoryDream.md — sections to update:
  • [§N Title]
  • ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Proceed? [yes / yes to all / no / skip §X]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Do not touch any files until the user confirms.**

Accepted responses:
- `yes` or `да` — confirm section by section
- `yes to all` / `всё` — apply all without further per-patch prompts
- `no` / `нет` — abort, nothing written
- `skip §5` — skip that section, apply the rest

---

## Step 5 — Draft and Apply Patches

Work through sections in CRITICAL → HIGH → MEDIUM → LOW order.

### For each section:

**5a.** Read current content with the `Read` tool.

**5b.** Read the changed source file(s) with the `Read` tool.

**5c.** Show patch proposal (unless user said "yes to all"):
```
📝 Patch: ТЗ §[N] [Section title]
──────────────────────────────────
CURRENT:
  [excerpt — up to 10 lines]

PROPOSED:
  [updated text]

Reason: [one sentence — what changed in code, why doc needs updating]
```

**5d.** Apply — use `Edit` tool. After each write, verify with `tail -5 <path>`.

### Safety-specific patch rules (ТЗ §5)

- **SAFETY_BLOCK changed** → add callout immediately after the constant block:
  ```markdown
  > ⚠️ Changed in Sprint N: [reason for change]
  ```
- **Moderation layer added/removed** → update pipeline diagram AND layer list.
- **Fallback count changed** → update `>= 20` reference in [SAFE-06] and [AI-06].
- **Safety REGRESSION** (layer removed or bypassed in code):
  - **Never** silently update the doc to match the code.
  - Insert at the top of §5:
    ```markdown
    > ⚠️ SAFETY REGRESSION detected in Sprint N — requires immediate safety review before next deploy.
    ```
  - Log `"safetyRegression": true` in the sync log.
  - Escalate explicitly in the closing summary.

### Data Model patch rules (ТЗ §7)

- New field → add `// Added Sprint N` inline comment in the Prisma excerpt.
- Removed field → keep as comment for one sprint: `// Removed Sprint N — [reason]`.
- New model → add full model block to the excerpt.
- Index change → update the **[DATA-02]** indexes list.

### PLAN sprint table patch rules

Cross-check Sprint N row against the sprint report file if it exists.
Propose updates to velocity/SP and carryover notes.

---

## Step 6 — Update Sync Log

After all patches, update `F:\EAIP\docs\docsync-log.json`.
If it doesn't exist, create `F:\EAIP\docs\` directory first.

Append this entry to the `"syncs"` array (create the file with this structure if new):

```json
{
  "syncs": [
    {
      "sprint": N,
      "date": "YYYY-MM-DD",
      "changeWindow": "sprint/N-1..HEAD or date range",
      "filesChanged": N,
      "sectionsPatched": ["ТЗ §5", "ТЗ §7"],
      "safetyBlockUnchanged": true,
      "safetyRegression": false,
      "fallbackStoryCount": 20,
      "skippedSections": [],
      "notes": ""
    }
  ]
}
```

---

## Step 7 — Closing Summary

```
✅ Sprint [N] doc sync complete
   Sections patched : [N]
   Sections skipped : [N]
   Files modified   : ТЗ_StoryDream.md, PLAN_StoryDream.md
   Safety pipeline  : [SAFE ✅ / ⚠️ CHANGES FLAGGED — see §5]
   Sync log updated : F:\EAIP\docs\docsync-log.json

Next sync: after Sprint [N+1] completes.
```

---

## Edge Cases

| Situation | Action |
|---|---|
| No git repo | Ask user to list changed files manually |
| Repo exists, no commits | Ask for file list |
| ТЗ or PLAN file missing | Report path, ask user to confirm location |
| Safety REGRESSION in code | Never patch silently — flag and escalate |
| User says "everything automatically" | Still show impact report first; then apply CRITICAL→LOW without per-patch confirm |
| Sprint > 8 | Treat like any sprint; PLAN has no pre-defined row, add one |
| No files changed | Report "No changes detected." — still run safety quick-check |
| `docsync-log.json` missing | Create it with the first entry |
