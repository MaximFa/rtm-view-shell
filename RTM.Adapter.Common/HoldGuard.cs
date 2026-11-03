using RTM.Types;

namespace RTM.Tools
{
    /// <summary>
    /// PR234-ENGINE-NRE-DICTSERIALIZER-01 (adapter layer): a task handler that exits early (isLateEvent, inactive reservation)
    /// leaves new Interaction(id) in the dictionary with only Id set. A later hold/unhold on that call found the shell and sent
    /// interactionChanged with interactionId/workgroup/state all null (83 NRE in the engine, 22..27.10). Such a shell is not sent.
    /// </summary>
    public static class HoldGuard
    {
        public static bool CanSend(Interaction? interaction) =>
            interaction is not null && !string.IsNullOrEmpty(interaction.InteractionId);
    }
}
