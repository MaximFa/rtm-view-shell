# CC task — DEVOPS: Soma HealthUrl template default fix (F-QA-11 / shell /ops/health up:false)
> **§4-PASS** (coordinator-0624 2026-06-24T18:45Z — object-store verified: launchSettings 5239=HTTPS/5238=HTTP; example HealthUrl=7196 stale). Owner devops-0619. CLEARED to run in a v3 window (commit.lock retry 5×60s).
> Branch **v3**. Claim file-mode: `tools/Soma/appsettings.example.json` + `tools/Soma/USAGE.md` ONLY. NARROW-ADD. NO push. fix: prefix. Non-blocking tooling.

## STEP 0 — PRE-FLIGHT
- MANDATORY READ (§40/§0.8): `.claude/skills/role-devops/role-devops.md` (§A+§C) + `.claude/skills/session-coord/session-coord.md`.
- INIT: `git checkout v3`; verify `--abbrev-ref`==v3 AND `rev-parse HEAD`==v3 tip by-SHA (§0.5). §0.2 integrity. §42.6 S1 freeze-check (`cat .coord/push/request.md` — STOP on OPEN FREEZE). Single v3 tree — run after backend releases it.
- NARROW-ADD: stage ONLY the two files; git status --short = only those; zero file-deletion stat.

## ROOT CAUSE (grounded)
Soma `/ops/health` probes the Shell at `Soma:Shell.HealthUrl`. The Shell binds (launchSettings) `https://localhost:5239;http://localhost:5238` — port **5239 = HTTPS**, **5238 = HTTP**. The template default `http://localhost:7196/health` is stale (old Kestrel port) and the live operator config points `http://localhost:5239` (HTTP scheme against the HTTPS port) -> probe fails -> `up:false` even when the Shell serves fine. (Live appsettings.json is gitignored operator config — operator edits it; see RELAY. /health itself also returns 503 when Redis is down — F-QA-11, env.)

## THE FIX
1. `tools/Soma/appsettings.example.json`: `Soma:Shell.HealthUrl` `http://localhost:7196/health` -> **`http://localhost:5238/health`** (the Shell's dev HTTP port; HTTP avoids dev-cert validation).
2. `tools/Soma/USAGE.md`: add a one-line note — "Shell.HealthUrl must match the running Shell's bound scheme/port per environment: dev = http://localhost:5238 (HTTP); prod = the prod Shell URL. Probing the HTTPS port over http (5239) yields up:false. /health also reports 503 if Redis/Memurai/Garnet is down."

(Optional, only if trivial+low-risk: make Soma's probe tolerant of an https HealthUrl by accepting the loopback cert — NOT required for this fix; the HTTP-port default suffices. Skip unless you can verify it.)

## VERIFY (object-store)
- appsettings.example.json HealthUrl == http://localhost:5238/health; USAGE.md note present; only 2 files changed; no deletions.

## COMMIT (fix:, NO push) under commit.lock — NARROW ADD
`fix(soma): HealthUrl template default 7196->5238 (Shell dev HTTP port) + USAGE note — fixes /ops/health up:false scheme/port mismatch (F-QA-11) [devops]`
then §0.6 post-commit + §0.6b binding -> .coord/cc/devops.md + §0.7 re-sync.

## ACCEPTANCE
template HealthUrl = http://localhost:5238/health; USAGE note; narrow-add (2 files); NO push. Submit §4 BEFORE run; EXECUTE in a v3 window. (Operator separately: start Redis + point local appsettings.json HealthUrl to 5238 + restart Soma.)

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash, files, NO push.
