# StoryDream: Code → Docs Priority Map (Quick Reference)

## 🔴 CRITICAL — Always update immediately

| File | ТЗ | PLAN |
|---|---|---|
| `packages/story-engine/src/constants.ts` | §5 [SAFE-05] — SAFETY_BLOCK | — |
| `packages/story-engine/src/safety.ts` | §5 [SAFE-01]–[SAFE-08] | — |
| `packages/db/schema.prisma` | §7 Data Model | §2 Monorepo |
| `packages/db/migrations/` | §7 | Sprint table |

## 🟠 HIGH — Update same sprint

| File | ТЗ | PLAN |
|---|---|---|
| `packages/story-engine/src/generator.ts` | §4 [AI-01]–[AI-09] | §3 |
| `packages/story-engine/src/builder.ts` | §4 [AI-02], [AI-03] | — |
| `packages/story-engine/src/scenarios.ts` | §3, §16 | — |
| `packages/audio/src/` | §6 [AUDIO-01]–[AUDIO-06] | §3 |
| `packages/images/src/` | §8 [IMG-01]–[IMG-08] | §3 |
| `workers/` | §6 [AUDIO-03], §8 [IMG-02] | §2 |

## 🟡 MEDIUM — Update if content changed

| File | ТЗ | PLAN |
|---|---|---|
| `apps/web/app/api/stories/` | §4, §9 | §2 |
| `apps/web/lib/auth.ts` | §9 [AUTH-01]–[AUTH-05] | — |
| `apps/web/lib/stripe.ts` | §10 | — |
| `apps/web/app/(app)/` | §14 Screens 02–04 | — |
| `packages/story-engine/src/fallback-stories/` | §5 [SAFE-06], [AI-06] | — |

## 🟢 LOW — Optional

`config/voices.json` → §6 [AUDIO-02]
`next.config.ts` → §12 [SEC-02]
`pnpm-workspace.yaml` → §2, §3
`.github/workflows/` → §13 CI/CD

## Safety Quick-Check (every sync)

```bash
REPO=/sessions/adoring-funny-hypatia/mnt/F:--EAIP/
grep -c "SAFETY_BLOCK" "$REPO/packages/story-engine/src/constants.ts" 2>/dev/null || echo "NOT FOUND"
ls "$REPO/packages/story-engine/src/fallback-stories/" 2>/dev/null | wc -l
grep -r "SKIP_SAFETY" "$REPO/packages/story-engine/src/" 2>/dev/null | head -3
```
