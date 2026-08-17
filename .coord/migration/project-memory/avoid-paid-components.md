---
name: avoid-paid-components
description: Standing operator constraint — RTM View Shell avoids paid components; pick free/open stack
metadata: 
  node_type: memory
  type: project
  originSessionId: ec3dcfc9-7e7f-4538-87dd-29db4ee1f809
---

**Standing constraint (operator, 2026-06-21):** "Важно — избегать платных компонентов." RTM View Shell must be built on FREE / open-source / already-licensed components only. No paid products or paid licenses introduced without explicit operator approval.

**Why:** cost control; the project runs on a single Windows Server all-in-one with free stack.

**How to apply:**
- Default to free/open or already-bundled (e.g. Windows Server built-in roles) for any new dependency.
- This drove two live decisions: (1) INC-2026.06.20-001 root = Memurai **Developer** (free but 10-day auto-shutdown + non-prod license) → replace with FREE prod-Redis (Microsoft Garnet / WSL2-Valkey), NOT paid Memurai. (2) MaintenanceService D4 certs = self-signed (free) / Windows AD Certificate Services (free built-in role), NOT a paid public CA. PKI is NOT inherently paid — only public CAs cost money; internal certs are free.
- When evaluating any tool: flag the license/cost dimension explicitly; a paid tier is a blocker unless the operator OKs it.

Related: [project_rtm_view_shell](project_rtm_view_shell.md), MaintenanceService design (docs/MaintenanceService-Design-Review.md §F).
