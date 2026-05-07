namespace CcDashboard.Domain.Exceptions;

public class DomainException(string message) : Exception(message);

public class NotFoundException(string entityName, object key)
    : DomainException($"{entityName} with key '{key}' was not found.");

public class ForbiddenException(string message = "Access denied.") : DomainException(message);

public class ConcurrencyException(string message = "Record was modified by another user.")
    : DomainException(message);

public class ValidationException(string message) : DomainException(message);
