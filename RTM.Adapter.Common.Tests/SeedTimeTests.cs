using RTM.Tools;
using Xunit;

namespace RTM.Adapter.Common.Tests;

/// <summary>
/// ADAPTER-SEED-STATUS-MOMENT-01: the seed moment is Twilio's DateStatusChanged converted to machine local.
/// Negative half: the UTC value sent without conversion differs from the expected one by the local offset.
/// </summary>
public class SeedTimeTests
{
    private static readonly DateTime NowLocal = DateTime.Now;

    [Fact]
    public void Utc_IsConvertedToMachineLocal()
    {
        var utc = DateTime.SpecifyKind(NowLocal.ToUniversalTime().AddMinutes(-47), DateTimeKind.Utc);
        var expected = utc.ToLocalTime();

        var got = SeedTime.ToEngineLocal(utc, NowLocal, out var fallback);

        Assert.False(fallback);
        Assert.Equal(expected, got);
        Assert.Equal(DateTimeKind.Local, got.Kind);
        // negative half: on a machine with a non-zero offset (the 234 agent is Israel) raw UTC would be off by it
        var offset = TimeZoneInfo.Local.GetUtcOffset(utc);
        Assert.Equal(offset, got - DateTime.SpecifyKind(utc, DateTimeKind.Unspecified));
        if (offset != TimeSpan.Zero) Assert.NotEqual(DateTime.SpecifyKind(utc, DateTimeKind.Unspecified), DateTime.SpecifyKind(got, DateTimeKind.Unspecified));
    }

    [Fact]
    public void Unspecified_IsReadAsUtc_AndLocalIsKept()
    {
        var utc = NowLocal.ToUniversalTime().AddHours(-2);
        Assert.Equal(DateTime.SpecifyKind(utc, DateTimeKind.Utc).ToLocalTime(),
            SeedTime.ToEngineLocal(DateTime.SpecifyKind(utc, DateTimeKind.Unspecified), NowLocal, out _));

        var local = NowLocal.AddHours(-2);
        Assert.Equal(local, SeedTime.ToEngineLocal(local, NowLocal, out var fb));
        Assert.False(fb);
    }

    [Fact]
    public void NullMinOrFuture_FallsBackToNow()
    {
        Assert.Equal(NowLocal, SeedTime.ToEngineLocal(null, NowLocal, out var a)); Assert.True(a);
        Assert.Equal(NowLocal, SeedTime.ToEngineLocal(DateTime.MinValue, NowLocal, out var b)); Assert.True(b);
        var future = DateTime.SpecifyKind(NowLocal.ToUniversalTime().AddMinutes(5), DateTimeKind.Utc);
        Assert.Equal(NowLocal, SeedTime.ToEngineLocal(future, NowLocal, out var c)); Assert.True(c);
    }
}
