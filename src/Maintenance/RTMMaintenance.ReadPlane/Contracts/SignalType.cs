namespace RTMMaintenance.ReadPlane.Contracts;

/// <summary>
/// Fixed signal enum for /collect/incident (SF-MS-003: anti-RCE).
/// Each signal maps to exactly one read script with validated params.
/// BACKEND owns the allow-list validation; devops pairs on wiring.
/// </summary>
public enum SignalType
{
    /// <summary>
    /// Export Windows Event Log around the incident window.
    /// Read: Event Log Readers membership.
    /// </summary>
    EventLog,

    /// <summary>
    /// Service recovery config (sc qfailure/qc for RTMViewShell/RTMService/Memurai|Garnet).
    /// Read: sc query access.
    /// </summary>
    ServiceRecovery,

    /// <summary>
    /// Redis/Memurai/Garnet INFO + log tail.
    /// Read: connect 127.0.0.1:6379, INFO/PING only.
    /// </summary>
    RedisInfo,

    /// <summary>
    /// Disk and memory performance counters.
    /// Read: Performance Monitor Users membership.
    /// </summary>
    DiskMem,

    /// <summary>
    /// Serilog log file tail around the incident window.
    /// Read: NTFS read on log directory.
    /// </summary>
    SerilogTail,

    /// <summary>
    /// Shell health endpoints (/health + /health/ready).
    /// Read: HTTP GET only.
    /// </summary>
    Health
}
