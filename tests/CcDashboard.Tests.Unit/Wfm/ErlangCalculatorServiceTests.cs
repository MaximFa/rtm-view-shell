using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Wfm;
using FluentAssertions;
using Xunit;

namespace CcDashboard.Tests.Unit.Wfm;

/// <summary>
/// Unit tests for ErlangCalculatorService against spec §7 worked anchor.
/// Inputs: lambda=160/hr, AHT=180s, N=10, t=20s, target=0.80, trunk=100.
/// </summary>
public class ErlangCalculatorServiceTests
{
    private readonly IErlangCalculatorService _sut = new ErlangCalculatorService();

    // Spec §7 anchor constants
    private const double Lambda = 160.0;    // calls/hour
    private const double Aht = 180.0;       // seconds
    private const int NActual = 10;
    private const int TSec = 20;
    private const double TargetSl = 0.80;
    private const int TrunkCapacity = 100;

    [Fact]
    public void TrafficIntensity_SpecAnchor_Returns8Erlang()
    {
        // Spec §7: A = 160*180/3600 = 8.0
        var result = _sut.TrafficIntensity(Lambda, Aht);
        result.Should().Be(8.0);
    }

    [Fact]
    public void ErlangB_SpecAnchor_ReturnsApprox0_1217()
    {
        // Spec §7: ErlangB(10, 8) ≈ 0.1217
        var result = _sut.ErlangB(10, 8.0);
        result.Should().BeApproximately(0.1217, 0.005);
    }

    [Fact]
    public void ErlangC_SpecAnchor_ReturnsApprox0_4092()
    {
        // Spec §7: ErlangC(10, 8) ≈ 0.409
        var result = _sut.ErlangC(10, 8.0);
        result.Should().NotBeNull();
        result!.Value.Should().BeApproximately(0.4092, 0.005);
    }

    [Fact]
    public void PredictedSl_SpecAnchor_ReturnsApprox0_6724()
    {
        // Spec §7: PredictedSL(10, 8, 180, 20) ≈ 0.672 (67.2%)
        var result = _sut.PredictedSl(NActual, 8.0, Aht, TSec);
        result.Should().NotBeNull();
        result!.Value.Should().BeApproximately(0.6724, 0.005);
    }

    [Fact]
    public void PredictedAsaSec_SpecAnchor_ReturnsApprox36_83()
    {
        // Spec §7: PredictedASA(10, 8, 180) ≈ 36.8 s
        var result = _sut.PredictedAsaSec(NActual, 8.0, Aht);
        result.Should().NotBeNull();
        result!.Value.Should().BeApproximately(36.83, 0.5);
    }

    [Fact]
    public void RequiredAgents_SpecAnchor_Returns11()
    {
        // Spec §7: RequiredAgents(8, 180, 20, 0.80) == 11
        // PredictedSL(10) ≈ 0.672, PredictedSL(11) ≈ 0.824 >= 0.80
        var (required, capped) = _sut.RequiredAgents(8.0, Aht, TSec, TargetSl);
        required.Should().Be(11);
        capped.Should().BeFalse();
    }

    [Fact]
    public void StaffVariance_SpecAnchor_ReturnsMinus1()
    {
        // Spec §7: StaffVariance(10, 11) = -1
        var result = _sut.StaffVariance(NActual, 11);
        result.Should().Be(-1);
    }

    [Fact]
    public void OccupancyPct_SpecAnchor_Returns80()
    {
        // Spec §7: OccupancyPct(8, 10) = 80%
        var result = _sut.OccupancyPct(8.0, NActual);
        result.Should().NotBeNull();
        result!.Value.Should().Be(80.0);
    }

    [Fact]
    public void UnderstaffPct_SpecAnchor_ReturnsApprox9_09()
    {
        // Spec §7: UnderstaffPct(11, 10) = max(0, 11-10)/11*100 ≈ 9.09%
        var result = _sut.UnderstaffPct(11, NActual);
        result.Should().NotBeNull();
        result!.Value.Should().BeApproximately(9.09, 0.05);
    }

    [Fact]
    public void ErlangB_HighN_NoOverflow()
    {
        // Spec §6: ErlangB(100, 8) < 1e-60 (no overflow with high N)
        var result = _sut.ErlangB(TrunkCapacity, 8.0);
        result.Should().BeLessThan(1e-60);
        result.Should().BeGreaterThanOrEqualTo(0);
    }

    // ─── Edge case tests ───────────────────────────────────────────────────

    [Theory]
    [InlineData(8, 8.0)]   // N == A
    [InlineData(7, 8.0)]   // N < A
    public void ErlangC_Overload_ReturnsNull(int n, double a)
    {
        // Spec §6: N <= A => SystemOverloaded (null)
        var result = _sut.ErlangC(n, a);
        result.Should().BeNull();
    }

    [Theory]
    [InlineData(8, 8.0)]
    [InlineData(7, 8.0)]
    public void PredictedSl_Overload_ReturnsNull(int n, double a)
    {
        var result = _sut.PredictedSl(n, a, Aht, TSec);
        result.Should().BeNull();
    }

    [Fact]
    public void OccupancyPct_ZeroAgents_ReturnsNull()
    {
        var result = _sut.OccupancyPct(8.0, 0);
        result.Should().BeNull();
    }

    [Fact]
    public void UnderstaffPct_ZeroRequired_ReturnsNull()
    {
        var result = _sut.UnderstaffPct(0, 5);
        result.Should().BeNull();
    }

    [Fact]
    public void RequiredAgents_LowCapHit_ReturnsCapped()
    {
        // With cap=9 and A=8, minimum viable N is 9 but PredictedSL(9,8,...)=~0.47 < 0.80
        // So cap is hit without meeting the 80% target
        var (required, capped) = _sut.RequiredAgents(8.0, Aht, TSec, TargetSl, cap: 9);
        required.Should().Be(9);
        capped.Should().BeTrue();
    }

    [Fact]
    public void PredictedSl_ZeroAht_ReturnsNull()
    {
        var result = _sut.PredictedSl(10, 8.0, 0, TSec);
        result.Should().BeNull();
    }

    [Fact]
    public void ErlangB_ZeroServers_Returns1()
    {
        // B(0, A) = 1 by definition
        var result = _sut.ErlangB(0, 8.0);
        result.Should().Be(1.0);
    }

    [Fact]
    public void ErlangB_ZeroLoad_Returns0()
    {
        // B(N, 0) = 0 for any N > 0
        var result = _sut.ErlangB(10, 0);
        result.Should().Be(0.0);
    }
}
