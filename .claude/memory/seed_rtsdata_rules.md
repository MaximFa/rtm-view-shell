---
name: seed-rtsdata-rules
description: RTSData seed rules for DayTrend widget - dates, queues, agent status timing
metadata:
  type: project
---

# RTSData Seed Rules for DayTrend Widget

## Critical Requirements

### 1. Dates Must Be Today
- OnDate must equal DateOnly.FromDateTime(DateTime.UtcNow).ToString("dd/MM/yyyy")
- InQueueDateTime / StartTime must use today's date components from DateTime.UtcNow
- Widget queries filter by today's date - stale data won't display

### 2. Queue Coverage
RTSData_Interaction must include ALL queues mapped to Business Units:
- Q001 -> Sales Department (BU 1)
- Q002, Q003, Q005 -> Support Department (BU 2)
- Q004 -> Billing Department (BU 3)

Mapping lives in NGC_BusinessUnitQueueClassification. If a BU's queues have no interaction data, that BU's chart will be empty.

### 3. Agent Status Timing
RTSData_UserStatusLog seed must create data for the FULL working day (08:00-18:00 UTC), NOT relative to current time.

Why: The original code used while (cursor < now.AddHours(-0.5)) which failed if app started early in the day - loop exited immediately.

Fixed pattern:
var endOfDay = new DateTime(now.Year, now.Month, now.Day, 18, 0, 0, DateTimeKind.Utc);
while (cursor < endOfDay) { ... }

### 4. Idempotent Check
Both seeds check AnyAsync(r => r.OnDate == today). If data exists for today, seed is skipped.

To force re-seed delete today's data first:
DELETE FROM RTSData_Interaction WHERE OnDate = 'DD/MM/YYYY';
DELETE FROM RTSData_UserStatusLog WHERE OnDate = 'DD/MM/YYYY';

## Related Files
- DatabaseInitializer.cs: SeedDevRtsInteractionsAsync, SeedDevRtsUserStatusLogAsync
- fn_daytrendinteractions: filters by OnDate, groups by InQueueDateTime intervals
- fn_daytrendagentstatus: filters by OnDate, groups by StartTime intervals
