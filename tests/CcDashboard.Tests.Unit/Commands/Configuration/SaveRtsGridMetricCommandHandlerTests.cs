using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class SaveRtsGridMetricCommandHandlerTests
{
    private readonly IRtsGridMetricRepository _repo = Substitute.For<IRtsGridMetricRepository>();
    private readonly IConfigurationApiHook _apiHook = Substitute.For<IConfigurationApiHook>();
    private readonly SaveRtsGridMetricCommandHandler _handler;

    public SaveRtsGridMetricCommandHandlerTests()
    {
        _handler = new SaveRtsGridMetricCommandHandler(_repo, _apiHook);
    }

    [Fact]
    public async Task Handle_CreateNewMetric_AddsToRepository()
    {
        _repo.GetByIdAsync("METRIC-001", Arg.Any<CancellationToken>()).Returns((RtsGridMetric?)null);
        RtsGridMetric? saved = null;
        await _repo.AddAsync(Arg.Do<RtsGridMetric>(m => saved = m), Arg.Any<CancellationToken>());

        var req = new SaveRtsGridMetricRequest(
            "METRIC-001", "Call count", "INT", "SUM", "calls", "0", "0", true);
        var result = await _handler.Handle(new SaveRtsGridMetricCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.MetricId.Should().Be("METRIC-001");
        saved.Description.Should().Be("Call count");
        saved.DataType.Should().Be("INT");
        saved.MetricFunction.Should().Be("SUM");
        saved.MetricParameter.Should().Be("calls");
        saved.MetricFormat.Should().Be("0");
        saved.DefaultValue.Should().Be("0");
    }

    [Fact]
    public async Task Handle_CreateDuplicate_ReturnsFailure()
    {
        var existing = new RtsGridMetric { MetricId = "METRIC-DUP" };
        _repo.GetByIdAsync("METRIC-DUP", Arg.Any<CancellationToken>()).Returns(existing);

        var req = new SaveRtsGridMetricRequest(
            "METRIC-DUP", null, "INT", "COUNT", "x", null, null, true);
        var result = await _handler.Handle(new SaveRtsGridMetricCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("already exists");
        await _repo.DidNotReceive().AddAsync(Arg.Any<RtsGridMetric>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_UpdateExisting_ModifiesFields()
    {
        var existing = new RtsGridMetric
        {
            MetricId = "METRIC-UPD",
            Description = "Old desc",
            DataType = "INT",
            MetricFunction = "OLD",
            MetricParameter = "old_param"
        };
        _repo.GetByIdAsync("METRIC-UPD", Arg.Any<CancellationToken>()).Returns(existing);

        var req = new SaveRtsGridMetricRequest(
            "METRIC-UPD", "New desc", "DECIMAL", "AVG", "new_param", "0.00", "0.0", false);
        var result = await _handler.Handle(new SaveRtsGridMetricCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        existing.Description.Should().Be("New desc");
        existing.DataType.Should().Be("DECIMAL");
        existing.MetricFunction.Should().Be("AVG");
        existing.MetricParameter.Should().Be("new_param");
        existing.MetricFormat.Should().Be("0.00");
        existing.DefaultValue.Should().Be("0.0");
        _repo.Received(1).Update(existing);
    }

    [Fact]
    public async Task Handle_UpdateNonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync("MISSING", Arg.Any<CancellationToken>()).Returns((RtsGridMetric?)null);

        var req = new SaveRtsGridMetricRequest(
            "MISSING", null, "INT", "SUM", "x", null, null, false);
        var result = await _handler.Handle(new SaveRtsGridMetricCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_TrimsAllFields()
    {
        _repo.GetByIdAsync("  TRIM  ", Arg.Any<CancellationToken>()).Returns((RtsGridMetric?)null);
        RtsGridMetric? saved = null;
        await _repo.AddAsync(Arg.Do<RtsGridMetric>(m => saved = m), Arg.Any<CancellationToken>());

        var req = new SaveRtsGridMetricRequest(
            "  TRIM  ", "  Desc  ", "  INT  ", "  SUM  ", "  param  ", "  fmt  ", "  def  ", true);
        await _handler.Handle(new SaveRtsGridMetricCommand(req), CancellationToken.None);

        saved!.MetricId.Should().Be("TRIM");
        saved.Description.Should().Be("Desc");
        saved.DataType.Should().Be("INT");
        saved.MetricFunction.Should().Be("SUM");
        saved.MetricParameter.Should().Be("param");
        saved.MetricFormat.Should().Be("fmt");
        saved.DefaultValue.Should().Be("def");
    }

    [Fact]
    public async Task Handle_NotifiesApiHook()
    {
        _repo.GetByIdAsync("M1", Arg.Any<CancellationToken>()).Returns((RtsGridMetric?)null);

        var req = new SaveRtsGridMetricRequest("M1", null, "INT", "SUM", "x", null, null, true);
        await _handler.Handle(new SaveRtsGridMetricCommand(req), CancellationToken.None);

        await _apiHook.Received(1).NotifyAsync("RtsGridMetric", Arg.Any<object>(), Arg.Any<CancellationToken>());
    }
}
