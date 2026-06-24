namespace RTMMaintenance.ReadPlane.Models;

/// <summary>
/// Security configuration for the read-plane service.
/// Defense-in-depth: mTLS + bearer token + IP allow-list (ALL three required).
/// </summary>
public class SecurityOptions
{
    /// <summary>
    /// Client certificate thumbprints allowed to connect (mTLS validation).
    /// Only allow-listed thumbprints accepted. Annual manual rotation.
    /// </summary>
    public List<string> AllowedClientThumbprints { get; set; } = new();

    /// <summary>
    /// IP addresses allowed to connect (operator workstation only per A2).
    /// </summary>
    public List<string> AllowedIpAddresses { get; set; } = new();

    /// <summary>
    /// Bearer token TTL in minutes. Short-lived (default 60 min).
    /// Pin-at-build (b): concrete short-TTL + revocation path.
    /// </summary>
    public int TokenTtlMinutes { get; set; } = 60;

    /// <summary>
    /// Enable token revocation list checking. When true, revoked tokens
    /// are rejected even if not expired. Revocation list stored locally.
    /// Pin-at-build (b): token-revoke path.
    /// </summary>
    public bool TokenRevocationEnabled { get; set; } = true;
}
