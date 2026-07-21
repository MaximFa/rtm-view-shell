using CcDashboard.Application.Interfaces;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// Pure Erlang B/C math functions for WFM metrics (Phase 1).
/// Implements spec: docs/wfm-phase1-erlang-core-spec.md
/// Formulas verified against §7 worked anchor.
/// </summary>
public sealed class ErlangCalculatorService : IErlangCalculatorService
{
    /// <inheritdoc/>
    public double ErlangB(int n, double a)
    {
        // Spec §2: overflow-safe recursion B = (A*B)/(k + A*B) for k in 1..N
        if (n < 0 || a < 0) return 0;

        double b = 1.0;
        for (int k = 1; k <= n; k++)
        {
            b = (a * b) / (k + a * b);
        }
        return b;
    }

    /// <inheritdoc/>
    public double? ErlangC(int n, double a)
    {
        // Spec §2: C = B / (1 - rho + rho*B), rho = A/N
        // Guard: N <= A => system overloaded (rho >= 1, queue diverges)
        if (n <= a) return null;
        if (n <= 0) return null;

        double b = ErlangB(n, a);
        double rho = a / n;
        return b / (1 - rho + rho * b);
    }

    /// <inheritdoc/>
    public double TrafficIntensity(double lambdaPerHour, double ahtSec)
    {
        // Spec §3 M-01: A = lambda * AHT / 3600
        if (lambdaPerHour < 0 || ahtSec < 0) return 0;
        return lambdaPerHour * ahtSec / 3600.0;
    }

    /// <inheritdoc/>
    public double? PredictedSl(int n, double a, double ahtSec, int tSec)
    {
        // Spec §3 M-03: SL = 1 - C*exp(-(N-A)*t/AHT)
        // Guard: N <= A => null (SystemOverloaded)
        if (n <= a) return null;
        if (ahtSec <= 0) return null;

        var c = ErlangC(n, a);
        if (c == null) return null;

        double exponent = -((n - a) * tSec) / ahtSec;
        return 1.0 - c.Value * Math.Exp(exponent);
    }

    /// <inheritdoc/>
    public double? PredictedAsaSec(int n, double a, double ahtSec)
    {
        // Spec §3 M-04: ASA = C * AHT / (N - A)
        // Guard: N <= A => null
        if (n <= a) return null;
        if (ahtSec <= 0) return null;

        var c = ErlangC(n, a);
        if (c == null) return null;

        return c.Value * ahtSec / (n - a);
    }

    /// <inheritdoc/>
    public (int RequiredAgents, bool Capped) RequiredAgents(double a, double ahtSec, int tSec, double targetFraction, int cap = 200)
    {
        // Spec §3 M-05: min N in [ceil(A)+1 .. cap] where PredictedSL(N) >= target
        // Start from ceil(A)+1 because N must be > A for ErlangC to be defined
        int minN = (int)Math.Ceiling(a) + 1;

        if (ahtSec <= 0 || tSec < 0 || targetFraction < 0 || targetFraction > 1)
            return (cap, true);

        for (int n = minN; n <= cap; n++)
        {
            var sl = PredictedSl(n, a, ahtSec, tSec);
            if (sl.HasValue && sl.Value >= targetFraction)
                return (n, false);
        }

        // None found in range — capped
        return (cap, true);
    }

    /// <inheritdoc/>
    public double? OccupancyPct(double a, int nActual)
    {
        // Spec §3 M-08: Occupancy = A / N_actual * 100
        // Guard: N_actual <= 0 => null
        if (nActual <= 0) return null;
        return (a / nActual) * 100.0;
    }

    /// <inheritdoc/>
    public double? UnderstaffPct(int required, int nActual)
    {
        // Spec §3 M-11: UnderstaffPct = max(0, Required - N_actual) / Required * 100
        // Guard: Required <= 0 => null
        if (required <= 0) return null;
        double understaff = Math.Max(0, required - nActual);
        return (understaff / required) * 100.0;
    }

    /// <inheritdoc/>
    public int StaffVariance(int nActual, int required)
    {
        // Spec §3 M-07: StaffVariance = N_actual - Required (signed)
        return nActual - required;
    }
}
