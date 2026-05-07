using System.ComponentModel.DataAnnotations;

namespace CcDashboard.Web.Models;

public class TwoFactorFormModel
{
    public Guid UserId { get; set; }

    [Required]
    [RegularExpression(@"^\d{6}$", ErrorMessage = "Code must be exactly 6 digits.")]
    public string Code { get; set; } = string.Empty;
}
