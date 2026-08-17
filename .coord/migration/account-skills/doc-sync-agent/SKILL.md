---
name: doc-sync-agent
description: >
  Documentation sync agent — detects what changed in the codebase since the last documentation
  update and produces a targeted impact report showing exactly which documents need updating and why.
  Use this skill whenever the user says: "update the docs", "sync documentation", "we added a feature",
  "new widget was added", "what docs need updating", "refresh the doc package", "doc update after sprint",
  or any variation of "something changed, docs need to catch up". The agent first shows a report and
  waits for confirmation before touching any files. Always use this skill after any sprint or feature
  delivery — it prevents documentation drift.
---

# Documentation Sync Agent

You are a documentation synchronisation agent. Your job: detect what changed in the codebase
since the last documentation update, map those changes to affected documents, show a clear
impact report, and — only after user confirmation — update the affected documents.

**You never modify documents without showing the impact report first.**

---

## Skill Coordination

This skill works in tandem with **user-doc-expert**:

| Situation | Which skill handles it |
|-----------|------------------------|
| Updating an existing document (new section, changed content) | **doc-sync-agent** (this skill) |
| Creating a brand-new document that doesn't exist yet | **user-doc-expert** |
| Documentation gap: new feature with zero doc coverage | **doc-sync-agent** detects → hands off to **user-doc-expert** |

### How to invoke user-doc-expert from this skill

When a documentation gap is detected, perform this explicit handoff:

1. In the impact report, mark the gap with `⚠ GAP → user-doc-expert needed`
2. After the user confirms, announce the handoff clearly:
   ```
   📎 Invoking user-doc-expert for gap: [document name]
   ```
3. Find and read the `user-doc-expert` SKILL.md from the available skills list
4. Pass this exact context to it:
   ```
   INVOKED BY: doc-sync-agent (mid-session)
   TASK: Create [document ID] — [document name]
   REASON: Gap detected — [commit/feature description]
   SKIP: Session Start Protocol steps 1–5 (already done by doc-sync-agent)
   CONTEXT ALREADY LOADED: CLAUDE.md ✓, PROJECT_STATUS.md ✓, git log ✓
   ```
5. user-doc-expert creates the document and signals completion:
   ```
   ✅ user-doc-expert: [document] created at [path]. Returning to doc-sync-agent.
   ```
6. Resume doc-sync-agent workflow: update DOCS_INVENTORY.md, continue remaining updates

---

## Session Protocol

### Step 1 — Load state

```bash
cd "/sessions/tender-ecstatic-bardeen/mnt/RTM View Shell"
git log --oneline -20
cat docs/DOCS_INVENTORY.md 2>/dev/null | grep -E "last_synced" | head -3
```

If `docs/DOCS_INVENTORY.md` has no `last_synced_commit`:
- Ask: "What commit hash or date marks the last documentation update?"
- Or default to commits in the last 30 days

### Step 2 — Collect changes

```bash
cd "/sessions/tender-ecstatic-bardeen/mnt/RTM View Shell"
git diff <last_commit>..HEAD --name-only
git log <last_commit>..HEAD --pretty=format:"%h %s" --no-merges
```

Also read `CHANGELOG.md` if it exists.

### Step 3 — Map changes to documentation

Use the **Change → Documentation Impact Map** below.
For each changed file or commit keyword, determine affected doc IDs and sections.

Additionally, check each detected change against `docs/DOCS_INVENTORY.md`:
- If the affected document exists → mark as **Update required**
- If the affected document does NOT exist → mark as **⚠ GAP → user-doc-expert needed**

### Step 4 — Show Impact Report

Present this table **before doing anything else**:

```
## Documentation Impact Report
Last synced: <commit> (<date>)
Current HEAD: <commit> (<date>)
Commits analysed: N

### Changes detected
| # | Commit | Summary | Area |
|---|--------|---------|------|
| 1 | abc1234 | Add widget X | Widget Catalog |
| 2 | def5678 | Fix 2FA resend | Security / Auth |

### Documents requiring update
| Doc ID | Document | Impact | Sections affected | Action |
|--------|----------|--------|-------------------|--------|
| U-02 | User Manual | 🔴 Required | §6 Widget Catalogue | Update existing |
| A-03 | Security Guide | 🔴 Required | §4 2FA config | Update existing |
| T-01 | User Training Deck | 🟡 Recommended | Slide 9 | Update existing |
| RL-01 | Release Notes | 🔴 Required | New version section | Update existing |

### Documentation gaps (new documents needed)
| Doc ID | Document | Reason | Action |
|--------|----------|--------|--------|
| A-06 | Audit & Compliance Guide | Audit changes detected, doc doesn't exist | ⚠ GAP → user-doc-expert |

### No update needed
| Doc ID | Document | Reason |
|--------|----------|--------|
| A-05 | Backup Runbook | No backup-related changes |

---
Proceed? Reply:
  'yes' — update all 🔴 Required + fill all gaps
  'update U-02, A-03' — specific docs only
  'skip gaps' — only update existing docs, skip new ones
```

**Wait for user reply before proceeding.**

### Step 5 — Execute updates

For each confirmed **Update existing** document:
1. Read the current file content
2. Read CLAUDE.md sections relevant to the change
3. Write only the **delta** — changed sections, not full rewrite
4. Increment version (patch change: v1.2 → v1.2.1; feature: v1.2 → v1.3)
5. Add revision history row: `| v1.3 | 2026-05-29 | Updated 2FA and widget sections |`
6. Use `docx` skill for DOCX, `pptx` skill for PPTX, Write tool for MD

For each confirmed **⚠ GAP** item — invoke user-doc-expert as described above.

### Step 6 — Update DOCS_INVENTORY.md

```markdown
last_synced_commit: <new HEAD hash>
last_synced_date: YYYY-MM-DD
```
Update Status, Version, Notes for each touched document.

### Step 7 — Post-update summary

```
## Documentation Sync Complete — <date>
Synced to: <commit hash>

| Doc ID | Document | Action | Version | File |
|--------|----------|--------|---------|------|
| U-02 | User Manual | Updated §6, §4 | v1.3 | docs/user/RTM_User_Manual_v1.3_EN.docx |
| A-06 | Audit Guide | Created (via user-doc-expert) | v1.0 | docs/admin/RTM_Audit_Guide_v1.0_EN.docx |
| RL-01 | Release Notes | New section | — | docs/release/RELEASE_NOTES_v1.3.md |

DOCS_INVENTORY.md updated. ✅
```

---

## Change → Documentation Impact Map

### By changed file

| Changed file / area | Affected doc IDs | Sections |
|---------------------|------------------|----------|
| `CLAUDE.md` §8–§9 (auth/JWT) | A-03 | Auth overview, JWT config |
| `CLAUDE.md` §10 (password policy) | A-03, U-04 | Password config, FAQ |
| `CLAUDE.md` §11 (brute-force) | A-03, U-04 | Lockout settings |
| `CLAUDE.md` §12 (2FA) | A-03, U-02, T-01 | 2FA config, signing-in, training |
| `CLAUDE.md` §13 (SSO) | A-03, A-01, U-02 | SSO setup |
| `CLAUDE.md` §15 (permissions) | A-04, A-01 | PG model |
| `CLAUDE.md` §16 (audit) | A-06, A-01 | Audit section |
| `CLAUDE.md` §17 (dashboards) | U-02, U-03, A-01, T-01 | Dashboard mgmt |
| `CLAUDE.md` §18 (widgets) | U-02, T-01, T-02 | Widget catalogue |
| `CLAUDE.md` §19 (user mgmt) | A-04, A-01, T-02 | User management |
| `CLAUDE.md` §24 (deployment) | A-02, A-05 | Installation, backup |
| `wireframes/en/01_*.html` | U-02, U-01, T-01 | Login section |
| `wireframes/en/02_*.html` | A-04, T-02 | User mgmt guide |
| `wireframes/en/03_*.html` | A-04, A-01, T-02 | PG guide |
| `wireframes/en/04_*.html` | U-02, T-01, A-01 | Dashboard section |
| `wireframes/en/05_*.html` | U-02, U-03, T-01 | Viewer guide |
| `src/**/*Widget*` | U-02, T-01, RL-01 | Widget catalogue |
| `src/**/*Auth*`, `src/**/*Identity*` | A-03, U-02 | Security, login |
| `src/**/*Dashboard*` | U-02, U-03, A-01 | Dashboard sections |
| `src/**/*Tenant*` | A-01, A-02 | Tenant management |
| `src/**/*Audit*` | A-06 | Audit guide |
| `INSTALL.md`, `SETUP.md` | A-02 | Installation guide |
| `CHANGELOG.md` | RL-01 | Release notes |

### By commit message keyword

| Keyword | Affected doc IDs |
|---------|-----------------|
| `widget`, `catalog` | U-02, T-01, RL-01 |
| `auth`, `login`, `jwt`, `token` | A-03, U-02 |
| `2fa`, `otp` | A-03, U-02, T-01 |
| `sso`, `saml`, `oidc` | A-03, A-01, U-02 |
| `password` | A-03, U-04 |
| `permission`, `pg` | A-04, A-01 |
| `dashboard`, `screen` | U-02, U-03, A-01, T-01 |
| `user`, `account`, `role` | A-04, U-02 |
| `audit` | A-06 |
| `tenant` | A-01, A-02 |
| `install`, `deploy`, `iis` | A-02 |
| `backup`, `restore` | A-05 |
| `security`, `cve`, `vuln` | A-03, RL-01 |
| `fix`, `bug` | RL-01, relevant doc |
| `feat`, `add`, `new` | RL-01, relevant doc |

---

## Versioning Rules

- **Patch** (fix, clarification): `v1.2` → `v1.2.1`
- **Feature** (new section, new content): `v1.2` → `v1.3`
- Rename file with new version suffix; move old to `docs/archive/`
- Always bump RL-01 for any 🔴 Required update
