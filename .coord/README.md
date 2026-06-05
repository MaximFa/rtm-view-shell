# .coord/ — Multi-session coordination state

Runtime state for the multi-session coordination protocol.
**Full specification: CLAUDE.md §42.** This file is a quick reference only.

## Layout

```
.coord/
├── README.md            ← this file (tracked)
├── .gitignore           ← ignores all runtime state below (tracked)
├── sessions/<slug>.md   ← one file per active Cowork session (claims, heartbeat)
├── locks/commit.lock    ← exclusive commit token — ONE commit at a time, repo-wide
├── journal.md           ← append-only commit log
└── push/
    ├── request.md       ← active push barrier request
    └── acks/<slug>.md   ← per-session push readiness acks (READY / HOLD)
```

## Rules in one breath

1. Register a session file in `sessions/` BEFORE issuing any CC task.
2. Claim modules (`rtm` / `web` / `db` / `docs`) or explicit files; never touch unclaimed paths.
3. Acquire `locks/commit.lock` before any `git add`/`git commit`; release after; append `journal.md`.
4. If `push/request.md` exists — do NOT start new CC tasks; write your ack first.
5. Push only after ALL active sessions ack `READY`, via `tools/cc_prompt_push.md` (§37/§39.6).

All files here except `README.md` and `.gitignore` are untracked runtime state.
All writes must use Python + `os.fsync` (CLAUDE.md §0.3). Recreate missing
subdirectories with `mkdir -p` — they are not tracked in git.

> Note: the stray zero-byte file `.sync` in the repo root is an accident
> (2026-06-04) that cannot be deleted through the Cowork mount. Delete it
> manually from Windows or in a CC session. It is NOT part of this protocol.
