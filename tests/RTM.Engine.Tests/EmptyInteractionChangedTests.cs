using FluentAssertions;
using RTM;
using RTM.Tools;
using Xunit;

namespace RTM.Engine.Tests;

/// <summary>
/// PR234-ENGINE-NRE-DICTSERIALIZER-01. 83 NullReferenceException on 234 (22..27.10): DictionarySerializer.getList(null)
/// in RTMAdapter.interactionChanged, all on an EMPTY interactionChanged (interactionId null, only isHeld set) sent by the
/// adapter's setHoldAsync for a call left as a shell after isLateEvent (NREHOLD4: 25 of 26).
/// Two layers: getList(null) is an empty list, and an id-less message is dropped before it goes deeper.
/// Negative half: with getList fixed, nothing in the field parsing stops the empty message any more - only the id guard does.
/// </summary>
public class EmptyInteractionChangedTests
{
    // Shape of the record from RTM.log20261022 09:49:46 (messageId 48802), custom data trimmed.
    private const string EmptyShell =
        "{\"method\":\"interactionChanged\",\"workgroup\":null,\"isAdded\":false,\"interactionId\":null,\"segmentId\":1,\"isDisconnect\":false," +
        "\"callType\":null,\"interactionType\":null,\"direction\":null,\"state\":null,\"stateChangedTime\":\"0001-01-01T00:00:00.0000000\"," +
        "\"duration\":\"00:00:00\",\"timeInWorkgroupQueue\":\"00:00:00\",\"isConsult\":false,\"localUserId\":null,\"changedAttributeNames\":null," +
        "\"isHeld\":true,\"remoteAddress\":null,\"lastMessageSid\":\"\",\"messageId\":\"48802\",\"timeStamp\":\"2026-10-22T09:49:46.6286964+03:00\"}";

    [Fact]
    public void GetList_Null_IsEmpty_NotAnException()
    {
        var dic = DictionarySerializer.DeserializeFromJson(EmptyShell);
        dic["changedAttributeNames"].Should().BeNull("the production record carries a JSON null here");

        var act = () => DictionarySerializer.getList(dic["changedAttributeNames"]);
        act.Should().NotThrow();
        act().Should().BeEmpty();
    }

    [Fact]
    public void EmptyShell_IsDropped_RealCall_IsNot()
    {
        var shell = DictionarySerializer.DeserializeFromJson(EmptyShell);
        RTMAdapter.IsInteractionChangedWithoutId(shell).Should().BeTrue();

        // positive control: the same message with a call id goes on as before
        var real = DictionarySerializer.DeserializeFromJson(EmptyShell.Replace("\"interactionId\":null", "\"interactionId\":\"WT0123\""));
        RTMAdapter.IsInteractionChangedWithoutId(real).Should().BeFalse();

        // a message without the key at all is also id-less
        var noKey = DictionarySerializer.DeserializeFromJson("{\"method\":\"interactionChanged\",\"isHeld\":false}");
        RTMAdapter.IsInteractionChangedWithoutId(noKey).Should().BeTrue();
    }

    [Fact]
    public void NegativeHalf_WithOnlyGetListFixed_TheEmptyMessageParsesCleanly_SoOnlyTheGuardStopsIt()
    {
        var dic = DictionarySerializer.DeserializeFromJson(EmptyShell);
        // Before the fix getList threw here and the catch swallowed the message (by accident it never went deeper).
        // After the getList fix every field parses: the engine would be called with empty workgroup and interactionId.
        var parse = () => new object[]
        {
            DictionarySerializer.getString(dic["workgroup"]), DictionarySerializer.getString(dic["interactionId"]),
            DictionarySerializer.getInt(dic["segmentId"]), DictionarySerializer.getBool(dic["isHeld"]),
            DictionarySerializer.getDateTime(dic["stateChangedTime"]), DictionarySerializer.getTimeSpan(dic["duration"]),
            DictionarySerializer.getList(dic["changedAttributeNames"]), DictionarySerializer.getLong(dic["messageId"])
        };
        parse.Should().NotThrow();
        parse()[0].Should().Be(string.Empty);
        parse()[1].Should().Be(string.Empty);
        RTMAdapter.IsInteractionChangedWithoutId(dic).Should().BeTrue("the guard is now the only barrier");
    }
}
