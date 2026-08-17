
---
## 2026-06-07T12:50Z — coordinator: явные дома урока (align/baseline)
В repo-fix коммите зафиксируй урок про align/baseline-direction в ДВУХ durable-домах (не «loosely»):
1. **.claude/skills/rtm-service-expert/rtm-service-expert.md §10 (lessons)** — текст:
   "Compare align.sql предполагает baseline=истина. Когда baseline устарел
   (db/functions/*.sql расходится с db/schema.sql) — align откатывает ПРАВИЛЬНЫЙ прод
   (42809-шторм: DROP PROCEDURE + CREATE FUNCTION). Перед запуском align на проде —
   проверить направление дрейфа по объектам, а не слепо доверять delta."
2. **CLAUDE.md §38** — одна строка-указатель на этот урок (held: если CLAUDE.md занят — оставь в rtm-service-expert + align.sql header, §-строку добавим отдельным окном).
3. **align.sql header** — операционный WARNING (как и договаривались).
git add -f для .claude/ (gitignore).

> 2026-06-09T18:25Z coordinator-0609: STALE — superseded by inbox/devops-2-0607.md (current devops slug). Do NOT use this file.


>>> DEPRECATED 2026-06-12T09:32Z: SUCCESSOR (permanent) INBOX = inbox/devops.md — READ THERE NOW. <<<
