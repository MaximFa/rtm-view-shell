namespace CcDashboard.Domain.Interfaces;

public interface IBlobStorage
{
    Task<string> UploadAsync(Guid tenantId, string fileName, Stream content, string contentType, CancellationToken ct = default);
    Task<Stream> DownloadAsync(Guid tenantId, string fileName, CancellationToken ct = default);
    Task DeleteAsync(Guid tenantId, string fileName, CancellationToken ct = default);
}
