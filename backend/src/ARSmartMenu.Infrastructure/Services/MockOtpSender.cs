using ARSmartMenu.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Services;

/// <summary>Logs OTP to console in development; replace with MSG91 in production.</summary>
public class MockOtpSender : IOtpSender
{
    private readonly ILogger<MockOtpSender> _logger;
    private readonly IConfiguration _config;

    public MockOtpSender(ILogger<MockOtpSender> logger, IConfiguration config)
    {
        _logger = logger;
        _config = config;
    }

    public Task SendAsync(string mobileNumber, string otp, CancellationToken ct = default)
    {
        if (_config.GetValue("Otp:MockMode", true))
        {
            _logger.LogWarning(
                "[DEV OTP] Mobile: {Mobile} | OTP: {Otp} | Dev bypass also accepts: {Bypass}",
                mobileNumber,
                otp,
                _config["Otp:DevBypassCode"] ?? "123456");
        }

        return Task.CompletedTask;
    }
}
