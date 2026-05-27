---
name: infra-local-env
description: "Local dev environment — PostgreSQL version, pg_dump path, pgpass setup"
type: impl
updated: 2026-05-27
---

## PostgreSQL

- Version: **18** (not 16)
- pg_dump path: `C:\Program Files\PostgreSQL\18\bin\pg_dump.exe`
- DB: `RTMViewDB`, user: `ccdashboard_user`
- pgpass file: `%APPDATA%\postgresql\pgpass.conf`
  - Format: `localhost:5432:RTMViewDB:ccdashboard_user:<password>`
  - Avoids password prompt in pg_dump commands

## Redis

- Memurai, `localhost:6379`

## App URL (dev)

- Blazor Web: `https://localhost:7196` (or configured port in launchSettings.json)
