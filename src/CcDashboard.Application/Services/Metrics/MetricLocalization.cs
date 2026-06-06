using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;

namespace CcDashboard.Application.Services.Metrics;

public static class MetricLocalization
{
    /// <summary>
    /// Returns a localized copy: for the 4 translatable fields, use translation value when non-empty,
    /// else fall back to the base (English). All other fields unchanged.
    /// </summary>
    public static RtsGridMetricDto Apply(RtsGridMetricDto base_, RtsGridMetricTranslation? tr)
    {
        if (tr is null)
            return base_;

        return base_ with
        {
            DisplayName = !string.IsNullOrWhiteSpace(tr.DisplayName) ? tr.DisplayName : base_.DisplayName,
            ShortDescription = !string.IsNullOrWhiteSpace(tr.ShortDescription) ? tr.ShortDescription : base_.ShortDescription,
            LongDescription = !string.IsNullOrWhiteSpace(tr.LongDescription) ? tr.LongDescription : base_.LongDescription,
            Comparison = !string.IsNullOrWhiteSpace(tr.Comparison) ? tr.Comparison : base_.Comparison
        };
    }
}