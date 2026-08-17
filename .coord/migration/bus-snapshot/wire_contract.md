# WIRE CONTRACT — Adapter ↔ RTM Service (durable, [WIRE-01..05]) — 2026-07-11
> Canonical in CLAUDE.md §48. This is a STANDING VALIDATION on ANY change touching the wire (adapter IPC/serializer/Agent
> OR RTM Service pipe handlers/Agent/serializer), on BOTH branches (v3 + adapters). QA-gated at every relevant push barrier.

Adapter code (RTM.Adapter.Common on `adapters` branch) is decoupled from RTM-core, BUT the WIRE FORMAT is a shared contract.
Duplicating code is safe; FORMAT divergence is the failure mode.

[WIRE-01] Pipe JSON dict shape — "method" (10 values) + every field name case-sensitive; customCallData1..20;
          messageEventReceived sends both "MessageId" and "messageId"; messageId string-or-long.
[WIRE-02] DictionarySerializer DateFormatString = "yyyy-MM-ddTHH:mm:ss.fffffffK" — identical both sides.
[WIRE-03] Agent DTO JSON PascalCase prop names (UserId..Workgroups + LastStatus/LastStatusGroup/BeforeHold*/TimeStamp) — no rename.
[WIRE-04] NamedPipe framing: StreamString Encoding.Unicode (UTF-16LE) + PipeTransmissionMode.Message + pipe name match (RtmTarget.Pipe ↔ AppConfig.PipeName).
[WIRE-05] DictionarySerializer settings parity (no TypeNameHandling/null-handling/naming drift).

VALIDATION (mandatory gate): contract round-trip test — serialize per-method dict + List<Agent> through ADAPTER copy,
deserialize through RTM SERVICE copy, assert equal (and reverse). GREEN required on the changed side before "done".
Cross-branch: whoever changes one side flags the counterpart so both re-validate together.

Minimal adapter lib (RTM.Adapter.Common) = 9 files (verified, zero RTM-core dep):
 RTM.Tools: AsyncLogger, DictionarySerializer, IPCConnection(IClient/MessageReceivedEventArgs), NamedPipeBase, NamedPipeClient, StreamString
 RTM.Types: Agent, Interaction, Reservation
 (EXCLUDED as noise/coupling: DBAdapter[Npgsql], NamedPipeServer, IServer, WindowsServiceHelper, NGCLog, Site, Statistic, StatisticParameter)
