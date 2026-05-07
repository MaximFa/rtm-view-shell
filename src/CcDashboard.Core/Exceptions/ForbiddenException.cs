namespace CcDashboard.Core.Exceptions;

public class ForbiddenException : DomainException
{
    public ForbiddenException() : base("Access denied.") { }
    public ForbiddenException(string message) : base(message) { }
}
