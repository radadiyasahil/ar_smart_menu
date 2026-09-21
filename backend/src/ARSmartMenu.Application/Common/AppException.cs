namespace ARSmartMenu.Application.Common;

public class AppException : Exception
{
    public string Code { get; }
    public int StatusCode { get; }

    public AppException(string message, string code = "APP_ERROR", int statusCode = 400)
        : base(message)
    {
        Code = code;
        StatusCode = statusCode;
    }
}

public class NotFoundException : AppException
{
    public NotFoundException(string message)
        : base(message, "NOT_FOUND", 404) { }
}

public class UnauthorizedException : AppException
{
    public UnauthorizedException(string message = "Unauthorized")
        : base(message, "UNAUTHORIZED", 401) { }
}

public class ForbiddenException : AppException
{
    public ForbiddenException(string message = "Forbidden")
        : base(message, "FORBIDDEN", 403) { }
}

public class ConflictException : AppException
{
    public ConflictException(string message)
        : base(message, "CONFLICT", 409) { }
}

public class ValidationException : AppException
{
    public ValidationException(string message)
        : base(message, "VALIDATION_ERROR", 400) { }
}
