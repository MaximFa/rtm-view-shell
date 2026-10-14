# WfmTypes: "unknown N" has to be expressible

Target file (v4): `src/CcDashboard.Application/Wfm/WfmTypes.cs`. Snapped 2026-10-14T10:17:19Z.
Coordinator's word 1 (10:13:07Z): nullable, backend edits this file, shell does the widget side in
the same leg.

## BEFORE (`:21-57`, read from v4)

```csharp
/// <summary>Input values used for WFM calculations.</summary>
public sealed record WfmInputs(
    double LambdaPerHour,
    double AhtSec,
    int NActual,
    bool WrapIncluded);
```

```csharp
public sealed record WfmSnapshot(
    Guid TenantId,
    string QueueId,
    DateTime AsOfUtc,
    int WindowMin,
    WfmInputs Inputs,
    WfmErlang Erlang,
    string State,
    IReadOnlyDictionary<string, string> Rag)
```

## AFTER

```csharp
/// <summary>
/// Input values used for WFM calculations.
/// NActual is nullable because "we do not know how many agents are serving" is a real state, not a
/// zero: the engine may have no cell for a configured group, or no value pushed yet. A zero here
/// would make every Erlang output read as "infinitely understaffed" with full confidence.
/// </summary>
public sealed record WfmInputs(
    double LambdaPerHour,
    double AhtSec,
    int? NActual,
    bool WrapIncluded);
```

```csharp
/// <summary>
/// Snapshot of all WFM metrics for a (tenant, queue) at a point in time.
/// Written by the WFM hosted loop (B1), read by Shell widgets.
/// Erlang is null exactly when Inputs.NActual is null: with no N there is nothing to compute, and
/// publishing zeroed metrics would put numbers on the wire that mean nothing. UnknownReason says
/// WHY, so the widget can show the cause instead of an empty cell with no explanation.
/// </summary>
public sealed record WfmSnapshot(
    Guid TenantId,
    string QueueId,
    DateTime AsOfUtc,
    int WindowMin,
    WfmInputs Inputs,
    WfmErlang? Erlang,
    string State,
    IReadOnlyDictionary<string, string> Rag,
    string? UnknownReason = null)
```

`UnknownReason` is added **last and with a default**, so every existing positional construction of
`WfmSnapshot` keeps compiling. `Erlang` and `NActual` changing to nullable do not have that luxury:
every read site has to be checked. I cannot compile here (no `dotnet`, v4 not mounted), so the read
sites are listed rather than claimed clean — this is **read**, not verified:

- `WfmRealtimeLoop.cs` — writes both; covered by `FRAGMENT_LOOP.md`;
- the widget side — shell's half of this leg, per your word 1;
- `IWfmSnapshotStore` and its implementation — store and fetch only, no arithmetic on the fields
  (read: the store keeps `WfmSnapshot` whole, keyed by (TenantId, QueueId));
- anything else the compiler finds. The box will say.

## Why not the alternatives

1. **Keep `Erlang` non-null and zero it**, relying on `State == "nodata"`. That leaves numbers on the
   wire that mean nothing, and the 13.10 work exists precisely because a plausible wrong number beats
   an empty cell at being believed.
2. **Reuse `WfmSentinel.NoData`** (`WfmTypes.cs:8`). The snapshot carries no `WfmMetricResult`, so
   this would add a second parallel shape for one answer.
