# Garnet PoC — INC-2026.06.20-001 (d) Phase 1

This directory contains the PoC configuration for testing Microsoft Garnet as a Memurai replacement.

## Prerequisites

1. Download Garnet from [GitHub Releases](https://github.com/microsoft/garnet/releases)
   - Get the latest `win-x64` package (e.g., `Garnet.2.0.0-beta.4.win-x64.zip`)
2. Extract to `C:\Garnet\`
3. Ensure no other Redis/Memurai is running on port 6379

## Quick Start

```powershell
# 1. Stop Memurai (if running)
Stop-Service Memurai -ErrorAction SilentlyContinue

# 2. Start Garnet with PoC config
cd C:\Garnet
.\GarnetServer.exe --bind 127.0.0.1 --port 6379 --auth TestPwd123 --checkpointdir C:\Garnet\data

# 3. In another terminal, run the Shell in Development mode
cd "D:\Claude\Projects\RTM View Shell"
dotnet run --project src\CcDashboard.Web --no-launch-profile

# 4. Run the verification script
powershell -File infra\garnet-poc\Verify-GarnetPoC.ps1
```

## Files

- `Verify-GarnetPoC.ps1` — Automated verification script for the parity matrix
- `garnet-args.txt` — Recommended GarnetServer.exe arguments
- `README.md` — This file

## Expected Garnet Arguments

```
--bind 127.0.0.1          # DEPLOY-08/09: localhost only
--port 6379               # Standard Redis port (no app config change needed)
--auth <password>         # requirepass equivalent
--checkpointdir <path>    # RDB-equivalent persistence (DEPLOY-11)
--checkpoint-freq 300     # Checkpoint every 5 minutes
```

## Verification Checklist

Run `Verify-GarnetPoC.ps1` to test all items. Manual verification:

1. **PING**: `redis-cli -h 127.0.0.1 -p 6379 -a <password> PING` → PONG
2. **SignalR backplane**: Open Shell in two browser tabs, verify real-time sync
3. **Pub/Sub**: `redis-cli SUBSCRIBE test` + `redis-cli PUBLISH test hello`
4. **TTL**: `SET mykey val EX 10` → `TTL mykey` returns countdown
5. **Persistence**: Restart Garnet, verify keys survive
