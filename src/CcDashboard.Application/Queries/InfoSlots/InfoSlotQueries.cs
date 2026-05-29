using CcDashboard.Contracts.DTOs.InfoSlots;
using MediatR;

namespace CcDashboard.Application.Queries.InfoSlots;

/// <summary>Admin list: all info slots for tenant</summary>
public record GetInfoSlotsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<InfoSlotListDto>>;

/// <summary>Viewer list: PG-gated, includes dashboard placements</summary>
public record GetInfoSlotsForViewerQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<InfoSlotViewerDto>>;

/// <summary>Widget: active messages for a slot</summary>
public record GetActiveMessagesQuery(Guid InfoSlotId) : IRequest<IReadOnlyList<InfoSlotMessageDto>>;

/// <summary>Widget config dropdown: summary list</summary>
public record GetInfoSlotsForWidgetConfigQuery : IRequest<IReadOnlyList<InfoSlotSummaryDto>>;
