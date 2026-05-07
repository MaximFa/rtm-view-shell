namespace CcDashboard.Domain.Interfaces;

public interface IDateTimeProvider
{
    DateTime UtcNow { get; }
}
