namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>Single cell value update from RTM Hub updateGridData.</summary>
public sealed record GridCellUpdate(int CellId, string Value, string? Value2 = null);
