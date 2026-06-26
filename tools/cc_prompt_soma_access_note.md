# CC task — §47 add Soma ACCESS note (Cowork-via-Chrome vs native-CC-direct)
> Coordinator-authored (IRON #9 exception: coordinator owns CLAUDE.md). Executor: native CC. Branch **v3**. Commit `docs:`. **NO push** (§37).
> WHY: QA established (tool-boundary, 2026-06-23) that Cowork bash CANNOT reach the host loopback — Soma is reached from Cowork via the host Chrome (same-origin fetch on a 127.0.0.1 tab). §47 lacks this; document it so ALL roles (not just test) know the access method.

## INIT — branch v3 + integrity
- `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 (object-store, not mount status §0.5).
- §0.2 integrity. §0.3 Python read/modify/write + os.fsync; after write: sync + tail -3 + wc -l + NUL-check (0).
- Read: .claude/skills/session-coord/session-coord.md.

## §42.6 sync — slug coordinator-0623 (file-mode)
- S1: `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (current = CLOSED tombstone -> proceed).
- S2 claims (file-mode): `CLAUDE.md` ONLY.
- S3 commit.lock (owner coordinator-0623). §0.6b binding PRE/POST -> .coord/cc/coordinator.md. NO push.

## EDIT — insert ACCESS note into §47, right after the ВЫЗОВ line
Python read CLAUDE.md. Anchor (unique, =1 — verified):
```
**ВЫЗОВ:** HttpClient / Invoke-RestMethod с `Authorization: Bearer <token>`. Полный каталог эндпойнтов + примеры → `tools/Soma/USAGE.md`.
```
INSERT the following line IMMEDIATELY AFTER that anchor line (newline before it, keep one blank line after), via `text.replace(anchor, anchor + "\n\n" + NEW_LINE, 1)`:

```
**ДОСТУП:** native CC / хост-процессы дёргают Soma напрямую на `http://127.0.0.1:<PORT>`. **Cowork-сессии НЕ достают хостовый loopback из bash-песочницы** (отдельная VM, её `127.0.0.1` ≠ хост) → ходят через **хостовый Chrome**: открыть вкладку на `http://127.0.0.1:<PORT>/health`, затем same-origin `fetch('/<endpoint>')` с заголовком `Authorization: Bearer <token>`. Источник: QA tool-boundary 2026-06-23.
```

## VERIFY (before commit)
- `grep -c "ДОСТУП:" CLAUDE.md` = 1; the ВЫЗОВ anchor still present once right before it; `git diff --name-only` = `CLAUDE.md` ONLY; tail -3 proper EOF; 0 NUL.

## Commit (docs:, commit.lock, NO push)
`bash tools/pre-commit-check.sh CLAUDE.md` -> `git add CLAUDE.md` -> commit -m "docs: §47 add Soma ACCESS note — Cowork reaches Soma via host Chrome (loopback not bash-reachable); native CC direct [coordinator-0623]" -> §0.6 post-commit (`git show v3:CLAUDE.md | grep -c "ДОСТУП:"` = 1) -> `bash tools/cc_post_commit.sh coordinator-0623 <hash>` -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/coordinator.md (done): commit <hash>; §47 ДОСТУП note inserted (grep=1); 1 file; NO push. verified: object-store.
## Report (chat): commit hash; the edit via git show v3; confirm 1 file; NO push.
