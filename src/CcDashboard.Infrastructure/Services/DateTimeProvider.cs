using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Infrastructure.Services;

public class DateTimeProvider : IDateTimeProvider
{
    public DateTime UtcNow => DateTime.UtcNow;
}
