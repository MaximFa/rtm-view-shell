using CcDashboard.Application.DTOs;
using FluentValidation;

namespace CcDashboard.Application.Validators;

public class CreatePermissionGroupRequestValidator : AbstractValidator<CreatePermissionGroupRequest>
{
    public CreatePermissionGroupRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(256);

        RuleFor(x => x.Description)
            .MaximumLength(1000);

        RuleFor(x => x.MenuPermissions)
            .NotNull();

        RuleForEach(x => x.MenuPermissions)
            .NotEmpty()
            .MaximumLength(128);
    }
}
