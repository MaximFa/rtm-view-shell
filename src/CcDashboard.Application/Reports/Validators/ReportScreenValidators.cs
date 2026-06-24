using CcDashboard.Application.Reports.Commands;
using CcDashboard.Application.Reports.DTOs;
using FluentValidation;

namespace CcDashboard.Application.Reports.Validators;

public class CreateReportScreenRequestValidator : AbstractValidator<CreateReportScreenRequest>
{
    public CreateReportScreenRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(x => x.Description)
            .MaximumLength(500)
            .When(x => x.Description != null);
    }
}

public class UpdateReportScreenRequestValidator : AbstractValidator<UpdateReportScreenRequest>
{
    public UpdateReportScreenRequestValidator()
    {
        RuleFor(x => x.Id)
            .NotEmpty();

        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(x => x.Description)
            .MaximumLength(500)
            .When(x => x.Description != null);
    }
}

public class CreateReportScreenCommandValidator : AbstractValidator<CreateReportScreenCommand>
{
    public CreateReportScreenCommandValidator()
    {
        RuleFor(x => x.Request).SetValidator(new CreateReportScreenRequestValidator());
    }
}

public class UpdateReportScreenCommandValidator : AbstractValidator<UpdateReportScreenCommand>
{
    public UpdateReportScreenCommandValidator()
    {
        RuleFor(x => x.Request).SetValidator(new UpdateReportScreenRequestValidator());
    }
}
