namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Pure Erlang B/C math functions for WFM metrics (Phase 1).
/// Deterministic, unit-testable, no I/O.
/// </summary>
public interface IErlangCalculatorService
{
    /// <summary>Erlang B (blocking probability) — overflow-safe recursion.</summary>
    double ErlangB(int n, double a);

    /// <summary>Erlang C (prob. of wait). Returns null if n &lt;= a (system overloaded).</summary>
    double? ErlangC(int n, double a);

    /// <summary>Traffic intensity in Erlangs: A = lambda * ahtSec / 3600.</summary>
    double TrafficIntensity(double lambdaPerHour, double ahtSec);

    /// <summary>Predicted SL (fraction 0..1). Returns null if n &lt;= a.</summary>
    double? PredictedSl(int n, double a, double ahtSec, int tSec);

    /// <summary>Predicted ASA in seconds. Returns null if n &lt;= a.</summary>
    double? PredictedAsaSec(int n, double a, double ahtSec);

    /// <summary>
    /// Minimum agents needed to meet SL target.
    /// Returns (requiredAgents, capped) where capped=true if search hit cap without meeting target.
    /// </summary>
    (int RequiredAgents, bool Capped) RequiredAgents(double a, double ahtSec, int tSec, double targetFraction, int cap = 200);

    /// <summary>Occupancy percentage (A/N * 100). Returns null if nActual &lt;= 0.</summary>
    double? OccupancyPct(double a, int nActual);

    /// <summary>Understaff percentage. Returns null if required &lt;= 0.</summary>
    double? UnderstaffPct(int required, int nActual);

    /// <summary>Staff variance: nActual - required (signed).</summary>
    int StaffVariance(int nActual, int required);
}
