using CcDashboard.Application.DTOs;
using FluentValidation;

namespace CcDashboard.Application.Validators;

public class CreateScreenRequestValidator : AbstractValidator<CreateScreenRequest>
{
    public CreateScreenRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(256);
    }
}
