using CcDashboard.Domain.Interfaces;
using Microsoft.Extensions.Configuration;
using System.Net;
using System.Net.Mail;

namespace CcDashboard.Infrastructure.Email;

public class SmtpEmailSender(IConfiguration config) : IEmailSender
{
    private record SmtpSettings(string Host, int Port, bool UseSsl, string Username, string Password, string FromAddress);

    public async Task SendAsync(string to, string subject, string body, CancellationToken ct = default)
    {
        var s = config.GetSection("Smtp").Get<SmtpSettings>()
            ?? throw new InvalidOperationException("Smtp configuration missing.");

        using var client = new SmtpClient(s.Host, s.Port)
        {
            EnableSsl = s.UseSsl,
            Credentials = new NetworkCredential(s.Username, s.Password),
        };
        using var msg = new MailMessage(s.FromAddress, to, subject, body) { IsBodyHtml = false };
        await client.SendMailAsync(msg, ct);
    }
}
