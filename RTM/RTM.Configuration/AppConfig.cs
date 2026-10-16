using System.Net.Sockets;
using System.Net;
using System.Reflection;
using RTM.Tools;
using Microsoft.Extensions.Configuration;

namespace RTM.Configuration
{
   
    public static class AppConfig
    {
        private static IConfigurationRoot _configuration;

        // Kestrel properties
        //public static KestrelOptions Kestrel { get; private set; }

        // Other properties
        public static string RTMConnectionString { get; private set; }
       
        public static string DefaultTimeZone { get; private set; }

        public static string AgentWGPerfix { get; private set; }

        public static int CalcInterval { get; private set; }


        public static string AdapterServiceName { get; set; }

        public static string PipeName { get; private set; }


        public static string LicenseKey { get; private set; }
        public static string DatabaseUser { get; private set; }
        public static string DatabasePassword { get; private set; }
        public static string KestrelHttpsPassword { get; private set; }
        public static string LocalIPAddress { get; private set; }
        public static string Version { get; private set; }

        public static Guid TenantId { get; private set; }

        public static bool DiagPushLogging { get; private set; }

        // [SYNC-PORT 2026-10-15 src=2026-07-15] Consult/warm-transfer (Variant A): max lifetime of a retained consult leg
        // before the engine force-finalizes it. Default 1800 s; RTM:ConsultLegMaxDurationSeconds, non-positive/invalid => default.
        public static int ConsultLegMaxDurationSeconds { get; internal set; } = 1800;

        // [SYNC-PORT 2026-10-15 src=2026-07-30] Stuck-OnPhone reconcile kill-switch. FAIL-OPEN: on unless RTM:OnPhoneReconcileEnabled is a literal false.
        public static bool OnPhoneReconcileEnabled { get; internal set; } = true;

        // [SYNC-PORT 2026-10-15 src=2026-08-12] LastNoPhone must not overwrite a fresher real status. FAIL-OPEN:
        // on unless RTM:LastNoPhonePreserveRealStatusEnabled is a literal false.
        public static bool LastNoPhonePreserveRealStatusEnabled { get; internal set; } = true;

        // [SYNC-PORT 2026-10-15 src=2026-08-05] Orphaned-assigned-task reap (eviction + max-live backstop). FAIL-SAFE:
        // OFF unless RTM:OrphanReapEnabled is a literal true - the family stays OFF everywhere by the legacy deploy rule.
        public static bool OrphanReapEnabled { get; internal set; } = false;

        // [SYNC-PORT 2026-10-15 src=2026-08-05] Backstop silence threshold (seconds). Default 5400; non-positive/invalid => default.
        public static int OrphanCallMaxLiveSeconds { get; internal set; } = 5400;

        // [SYNC-PORT 2026-10-15 src=2026-08-06] Segment de-dup in queue metrics and per-agent day counts (one interaction
        // = one call across its segments). FAIL-OPEN: on unless RTM:SegmentDedupEnabled is a literal false.
        public static bool SegmentDedupEnabled { get; internal set; } = true;


        public static void Initialize(IConfiguration configuration, string dataFilePath)
        {
            try
            {
                _configuration = (IConfigurationRoot)configuration;

                // Load other values from appsettings.json and app.dat
                RTMConnectionString = configuration["ConnectionStrings:RTMConnectionString"];
                AgentWGPerfix = configuration["RTM:AgentWGPerfixList"];
                CalcInterval = int.Parse(configuration["RTM:CalcInterval"]);
                DefaultTimeZone = configuration["RTM:DefaultTimeZone"];

                TenantId = Guid.Parse(configuration["RTM:TenantId"]);
                AsyncLogger.Info($"AppConfig.TenantId = {TenantId}");

                DiagPushLogging = bool.TryParse(configuration["RTM:DiagPushLogging"], out var diagPush) && diagPush;

                AdapterServiceName = configuration["RTM:AdaptorServiceName"];

                PipeName = string.IsNullOrWhiteSpace(configuration["RTM:PipeName"]) ? "rtmpipe" : configuration["RTM:PipeName"];
                AsyncLogger.Info($"AppConfig.PipeName = {PipeName}");

                // [SYNC-PORT 2026-10-15 src=2026-07-15] Retained consult leg lifetime (seconds).
                ConsultLegMaxDurationSeconds = 1800;
                var consultLegMaxRaw = configuration["RTM:ConsultLegMaxDurationSeconds"];
                if (!string.IsNullOrWhiteSpace(consultLegMaxRaw) && int.TryParse(consultLegMaxRaw, out var consultLegMax) && consultLegMax > 0)
                {
                    ConsultLegMaxDurationSeconds = consultLegMax;
                }

                // [SYNC-PORT 2026-10-15 src=2026-07-30] FAIL-OPEN: only a literal "false" turns the reconcile off.
                OnPhoneReconcileEnabled = true;
                var reconcileRaw = configuration["RTM:OnPhoneReconcileEnabled"];
                if (!string.IsNullOrWhiteSpace(reconcileRaw) && bool.TryParse(reconcileRaw, out var reconcileEnabled))
                {
                    OnPhoneReconcileEnabled = reconcileEnabled;
                }

                // [SYNC-PORT 2026-10-15 src=2026-08-12] FAIL-OPEN: only a literal "false" restores the legacy LastNoPhone resolution.
                LastNoPhonePreserveRealStatusEnabled = true;
                var lastNoPhoneRaw = configuration["RTM:LastNoPhonePreserveRealStatusEnabled"];
                if (!string.IsNullOrWhiteSpace(lastNoPhoneRaw) && bool.TryParse(lastNoPhoneRaw, out var lastNoPhoneEnabled))
                {
                    LastNoPhonePreserveRealStatusEnabled = lastNoPhoneEnabled;
                }

                AsyncLogger.Info($"AppConfig.ConsultLegMaxDurationSeconds = {ConsultLegMaxDurationSeconds} OnPhoneReconcileEnabled = {OnPhoneReconcileEnabled} LastNoPhonePreserveRealStatusEnabled = {LastNoPhonePreserveRealStatusEnabled}");

                // [SYNC-PORT 2026-10-15 src=2026-08-05] FAIL-SAFE: only a literal "true" enables the orphan reap.
                OrphanReapEnabled = false;
                var orphanRaw = configuration["RTM:OrphanReapEnabled"];
                if (!string.IsNullOrWhiteSpace(orphanRaw) && bool.TryParse(orphanRaw, out var orphanEnabled))
                {
                    OrphanReapEnabled = orphanEnabled;
                }

                OrphanCallMaxLiveSeconds = 5400;
                var orphanMaxRaw = configuration["RTM:OrphanCallMaxLiveSeconds"];
                if (!string.IsNullOrWhiteSpace(orphanMaxRaw) && int.TryParse(orphanMaxRaw, out var orphanMax) && orphanMax > 0)
                {
                    OrphanCallMaxLiveSeconds = orphanMax;
                }

                // [SYNC-PORT 2026-10-15 src=2026-08-06] FAIL-OPEN: only a literal "false" restores the per-segment counting.
                SegmentDedupEnabled = true;
                var segDedupRaw = configuration["RTM:SegmentDedupEnabled"];
                if (!string.IsNullOrWhiteSpace(segDedupRaw) && bool.TryParse(segDedupRaw, out var segDedupEnabled))
                {
                    SegmentDedupEnabled = segDedupEnabled;
                }

                AsyncLogger.Info($"AppConfig.OrphanReapEnabled = {OrphanReapEnabled} OrphanCallMaxLiveSeconds = {OrphanCallMaxLiveSeconds} SegmentDedupEnabled = {SegmentDedupEnabled}");


                // Load and decrypt sensitive values from data.sys
                // encryptedData = File.ReadAllText("data.sys");
                string encryptedData = File.ReadAllText(dataFilePath);
                //EncryptConfig decryptedConfig = EncryptionHelper.DecryptConfiguration(encryptedData);
                EncryptConfig decryptedConfig = EncryptionHelper.DecryptConfiguration<EncryptConfig>(encryptedData);


                LicenseKey = decryptedConfig.LicenseKey;
                DatabaseUser = decryptedConfig.DatabaseUser;
                DatabasePassword = decryptedConfig.DatabasePassword;
                KestrelHttpsPassword = decryptedConfig.KestrelHttpsPassword;

                // Update the connection string with the decrypted database user and password
                var builder = new System.Data.Common.DbConnectionStringBuilder
                {
                    ConnectionString = RTMConnectionString
                };
                builder["Username"] = DatabaseUser;
                builder["Password"] = DatabasePassword;
                RTMConnectionString = builder.ConnectionString;


                // Load LocalIPAddress or find it programmatically
                LocalIPAddress = configuration["LocalIPAddress"] ?? GetLocalIPAddress();

                // Load version from the entry assembly
                Version = GetAssemblyVersion();

                // Validate critical configuration values
                ValidateConfiguration();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.Initialize", ex);
            }
        }


        public static void ReloadConfiguration(string dataFilePath)
        {
            try
            {
                _configuration.Reload();
                Initialize(_configuration, dataFilePath); // Re-initialize to refresh values
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.ReloadConfiguration", ex);
            }
        }


        private static void ValidateConfiguration()
        {
            try
            {
                if (string.IsNullOrEmpty(DatabaseUser))
                {
                    throw new InvalidOperationException("DatabaseUser configuration is missing or empty.");
                }

                if (string.IsNullOrEmpty(DatabasePassword))
                {
                    throw new InvalidOperationException("DatabasePassword configuration is missing or empty.");
                }

                if (string.IsNullOrEmpty(LicenseKey))
                {
                    throw new InvalidOperationException("LicenseKey configuration is missing or empty.");
                }

                if (TenantId == Guid.Empty)
                {
                    throw new InvalidOperationException("RTM:TenantId is not configured. Set a valid tenant UUID in appsettings.json.");
                }

                // Add additional validation as necessary
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.ValidateConfiguration", ex);
            }
        }



        private static string GetLocalIPAddress()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                foreach (var ip in host.AddressList)
                {
                    if (ip.AddressFamily == AddressFamily.InterNetwork)
                    {
                        return ip.ToString();
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.GetLocalIPAddress", ex);
            }
            return string.Empty;
        }



        private static string GetAssemblyVersion()
        {
            try
            {
                var entryAssembly = Assembly.GetEntryAssembly();
                return entryAssembly?.GetName().Version?.ToString() ?? "Version not found";
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.GetAssemblyVersion", ex);
            }
            return string.Empty;
        }
    }
}
