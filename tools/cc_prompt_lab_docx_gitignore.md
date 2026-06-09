# CC TASK — Method Lab: gitignore TheMethod.docx (2nd lab commit, single-concern)

> Drafted by lab-0609. Recommendation pending coordinator §4. Issued by operator.
> Follow-up к c43347c (charter v0.5 git-home). Закрывает «silent untracked» по E-023 для TheMethod.docx.

## SCOPE — как и charter-коммит
- Worktree `D:\\Claude\\Projects\\RTM-Lab`, ветка `lab`. НЕ v2-backend. БЕЗ §42/commit.lock/sync-block. NO push (§37).
- TheMethod.docx = сырой транскрипт сессии RTM-координатора (263K симв + 6 jpeg); дистилляция уже tracked
  (Method-Discussion-Log.md). Решение: НЕ git-домить бинарник, а явно .gitignore (raw operational scratch).

## ШАГ 0 — integrity
```
cd /d "D:\\Claude\\Projects\\RTM-Lab"
git rev-parse --abbrev-ref HEAD     REM = lab
git log --oneline -1                REM = c43347c (charter v0.5)
```

## ШАГ 1 — создать .gitignore
Создать `D:\\Claude\\Projects\\RTM-Lab\\.gitignore` с содержимым (ровно эти строки):
```
# Raw session transcripts / scratch (distillation lives in Method-Discussion-Log.md) — E-023: explicit, not silent-untracked
TheMethod.docx
```

## ШАГ 2 — commit
```
git add .gitignore
git status --short      REM staged: только .gitignore; TheMethod.docx теперь ignored (НЕ в ??)
git commit -m "method: gitignore TheMethod.docx (raw RTM-coordinator transcript scratch; distillation in Method-Discussion-Log.md, E-023)"
```

## ШАГ 3 — verify (НЕ push)
```
git log --oneline -2
git status --short          REM чисто; TheMethod.docx больше НЕ untracked-?? (ignored)
git check-ignore TheMethod.docx    REM должно вернуть TheMethod.docx
git ls-files | findstr /i ".gitignore"
```
Доложи: hash 2-го коммита, что TheMethod.docx теперь ignored (не ??), push НЕ делался.
