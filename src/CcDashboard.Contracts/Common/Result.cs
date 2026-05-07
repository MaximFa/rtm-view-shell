namespace CcDashboard.Contracts.Common;

public record Result
{
    public bool IsSuccess { get; init; }
    public string? Error { get; init; }
    public bool IsFailure => !IsSuccess;

    public static Result Success() => new() { IsSuccess = true };
    public static Result Failure(string error) => new() { IsSuccess = false, Error = error };
    public static Result<T> Success<T>(T value) => new() { IsSuccess = true, Value = value };
    public static Result<T> Failure<T>(string error) => new() { IsSuccess = false, Error = error };
}

public record Result<T> : Result
{
    public T? Value { get; init; }
}
