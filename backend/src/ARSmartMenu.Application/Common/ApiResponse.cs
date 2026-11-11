namespace ARSmartMenu.Application.Common;

/// <summary>Standard API response envelope used across all endpoints.</summary>
public class ApiResponse<T>
{
    public bool Success { get; init; }
    public T? Data { get; init; }
    public string? Message { get; init; }
    public string? Error { get; init; }
    public string? Code { get; init; }

    public static ApiResponse<T> Ok(T data, string? message = null) => new()
    {
        Success = true,
        Data = data,
        Message = message,
    };

    public static ApiResponse<T> Fail(string error, string? code = null) => new()
    {
        Success = false,
        Error = error,
        Code = code,
    };
}

public class PagedResult<T>
{
    public required IReadOnlyList<T> Items { get; init; }
    public int Total { get; init; }
    public int Page { get; init; }
    public int Limit { get; init; }
    public int TotalPages => Limit > 0 ? (int)Math.Ceiling(Total / (double)Limit) : 0;
}

public class PaginationQuery
{
    public int Page { get; init; } = 1;
    public int Limit { get; init; } = 20;
    public string Sort { get; init; } = "created_at";
    public string Order { get; init; } = "desc";

    public int Skip => (Math.Max(Page, 1) - 1) * Math.Clamp(Limit, 1, 100);
}
