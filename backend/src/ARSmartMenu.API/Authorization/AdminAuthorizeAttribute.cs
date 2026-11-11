using Microsoft.AspNetCore.Authorization;

namespace ARSmartMenu.API.Authorization;

/// <summary>Restricts access to platform administrators.</summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public class AdminAuthorizeAttribute : AuthorizeAttribute
{
    public AdminAuthorizeAttribute() : base("Admin") { }
}
