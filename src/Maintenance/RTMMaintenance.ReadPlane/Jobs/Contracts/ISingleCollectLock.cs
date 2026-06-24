namespace RTMMaintenance.ReadPlane.Jobs.Contracts;

/// <summary>
/// SF-MS-003: Single collect job lock (mirrors commit.lock discipline, design-review C2).
///
/// Ensures only ONE collect job runs at a time per server.
/// This prevents resource exhaustion and simplifies output management.
/// </summary>
public interface ISingleCollectLock
{
    /// <summary>
    /// Attempts to acquire the collect lock.
    /// </summary>
    /// <param name="jobId">The job ID requesting the lock.</param>
    /// <returns>
    /// A lock handle if acquired, or null if another job holds the lock.
    /// </returns>
    ICollectLockHandle? TryAcquire(Guid jobId);

    /// <summary>
    /// Gets the current lock holder, if any.
    /// </summary>
    CollectLockInfo? CurrentHolder { get; }

    /// <summary>
    /// Checks if a job can be started (lock is free).
    /// </summary>
    bool IsLockFree { get; }
}

/// <summary>
/// Handle to a held collect lock. Dispose to release.
/// </summary>
public interface ICollectLockHandle : IDisposable
{
    /// <summary>
    /// The job ID holding this lock.
    /// </summary>
    Guid JobId { get; }

    /// <summary>
    /// When the lock was acquired.
    /// </summary>
    DateTime AcquiredAt { get; }
}

/// <summary>
/// Information about the current lock holder.
/// </summary>
public record CollectLockInfo(Guid JobId, DateTime AcquiredAt);
