using CcDashboard.Application.Commands.InfoSlots;
using FluentValidation;

namespace CcDashboard.Application.Validators.InfoSlots;

public class CreateInfoSlotCommandValidator : AbstractValidator<CreateInfoSlotCommand>
{
    public CreateInfoSlotCommandValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MaximumLength(200).WithMessage("Name must not exceed 200 characters");

        RuleFor(x => x.DisplayMode)
            .NotEmpty().WithMessage("Display mode is required")
            .Must(x => x == "Ticker" || x == "Sequential")
            .WithMessage("Display mode must be 'Ticker' or 'Sequential'");

        RuleFor(x => x.SecondsPerMessage)
            .InclusiveBetween(3, 3600)
            .WithMessage("Seconds per message must be between 3 and 3600");
    }
}

public class UpdateInfoSlotCommandValidator : AbstractValidator<UpdateInfoSlotCommand>
{
    public UpdateInfoSlotCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty().WithMessage("Id is required");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MaximumLength(200).WithMessage("Name must not exceed 200 characters");

        RuleFor(x => x.DisplayMode)
            .NotEmpty().WithMessage("Display mode is required")
            .Must(x => x == "Ticker" || x == "Sequential")
            .WithMessage("Display mode must be 'Ticker' or 'Sequential'");

        RuleFor(x => x.SecondsPerMessage)
            .InclusiveBetween(3, 3600)
            .WithMessage("Seconds per message must be between 3 and 3600");
    }
}

public class CreateInfoSlotMessageCommandValidator : AbstractValidator<CreateInfoSlotMessageCommand>
{
    public CreateInfoSlotMessageCommandValidator()
    {
        RuleFor(x => x.InfoSlotId).NotEmpty().WithMessage("Info Slot ID is required");

        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("Content is required")
            .MaximumLength(2000).WithMessage("Content must not exceed 2000 characters");

        RuleFor(x => x.Priority)
            .NotEmpty().WithMessage("Priority is required")
            .Must(x => x == "Normal" || x == "High")
            .WithMessage("Priority must be 'Normal' or 'High'");

        RuleFor(x => x.ExpiresAt)
            .GreaterThan(DateTime.UtcNow)
            .When(x => x.ExpiresAt.HasValue)
            .WithMessage("Expiration date must be in the future");
    }
}

public class DeactivateInfoSlotMessageCommandValidator : AbstractValidator<DeactivateInfoSlotMessageCommand>
{
    public DeactivateInfoSlotMessageCommandValidator()
    {
        RuleFor(x => x.MessageId).NotEmpty().WithMessage("Message ID is required");
    }
}

public class DeleteInfoSlotCommandValidator : AbstractValidator<DeleteInfoSlotCommand>
{
    public DeleteInfoSlotCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty().WithMessage("Id is required");
    }
}
