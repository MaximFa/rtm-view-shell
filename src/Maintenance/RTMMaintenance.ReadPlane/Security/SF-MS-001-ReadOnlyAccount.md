# SF-MS-001: Read-Only Dedicated Account

> **Spec ref:** docs/MaintenanceService-v1-ReadPlane-Spec.md §4

## Account: `RTMMaint-ReadPlane`

Non-admin local account. Runs the read-plane Windows Service.

## Read-Only Privileges (Complete Set)

| Resource | Access | How Granted |
|----------|--------|-------------|
| Windows Event Log | Read | Event Log Readers |
| Serilog log files | Read | NTFS ACL |
| Redis/Garnet | INFO/PING | Connect 127.0.0.1:6379 |
| Service status | Query | sc query/qfailure/qc |
| Disk/memory counters | Read | Performance Monitor Users |
| Shell health | HTTP GET | /health, /health/ready |

## Explicitly DENIED

- Service start/stop/restart
- pg_dump / any DB access
- Write to C:\Program Files\CcDashboard
- Redis FLUSHALL/CONFIG SET

## Pin-at-build (c): Credential Isolation

1. **Separate accounts**: RTMMaint-ReadPlane vs RTMMaint-WritePlane (v2)
2. **DPAPI isolation**: Profile-bound keys, cannot decrypt each other
3. **Config isolation**: Separate appsettings.json with restrictive NTFS ACL
4. **No shared secrets**: Per-service bearer tokens

## Manual Fallback

Agent down → fall back to manual §43 relay (operator carries scripts).
