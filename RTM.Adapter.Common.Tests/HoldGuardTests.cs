using RTM.Tools;
using RTM.Types;
using System.Collections.Concurrent;
using Xunit;

namespace RTM.Adapter.Common.Tests;

/// <summary>
/// PR234-ENGINE-NRE-DICTSERIALIZER-01, adapter layer: setHoldAsync must not send the shell of a call (Id only).
/// Negative half: the shell IS found by the FriendlyName lookup setHoldAsync does, so without the guard it would be sent.
/// </summary>
public class HoldGuardTests
{
    [Fact]
    public void Shell_IsFoundByLookup_ButNotSent()
    {
        var interactions = new ConcurrentDictionary<string, Interaction>();
        interactions.TryAdd("WT0123", new Interaction("WT0123")); // what the task handler leaves after isLateEvent

        Assert.True(interactions.TryGetValue("WT0123", out var found)); // negative half: the lookup alone lets it through
        Assert.Null(found!.InteractionId);
        Assert.False(HoldGuard.CanSend(found));
    }

    [Fact]
    public void FilledInteraction_IsSent()
    {
        var i = new Interaction("WT0123") { InteractionId = "WT0123", Workgroup = "Sales" };
        Assert.True(HoldGuard.CanSend(i));
        Assert.False(HoldGuard.CanSend(null));
        Assert.False(HoldGuard.CanSend(new Interaction("WT0123") { InteractionId = "" }));
    }
}
