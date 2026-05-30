using System;
using System.ServiceProcess;
using TimeoutException = System.ServiceProcess.TimeoutException;

namespace RTM.Tools
{
    public static class WindowsServiceHelper
    {
        public static void RestartService(string serviceName, TimeSpan timeout, Action<string>? log = null)
        {
            using var service = new ServiceController(serviceName);

            log?.Invoke($"Checking service '{serviceName}'. Current status: {service.Status}");

            if (service.Status == ServiceControllerStatus.Running ||
                service.Status == ServiceControllerStatus.StartPending ||
                service.Status == ServiceControllerStatus.Paused ||
                service.Status == ServiceControllerStatus.PausePending ||
                service.Status == ServiceControllerStatus.ContinuePending)
            {
                StopService(service, timeout, log);
            }

            StartService(service, timeout, log);
        }

        private static void StopService(ServiceController service, TimeSpan timeout, Action<string>? log)
        {
            service.Refresh();

            if (service.Status == ServiceControllerStatus.Stopped)
            {
                log?.Invoke($"Service '{service.ServiceName}' is already stopped.");
                return;
            }

            if (!service.CanStop)
            {
                throw new InvalidOperationException($"Service '{service.ServiceName}' cannot be stopped.");
            }

            log?.Invoke($"Stopping service '{service.ServiceName}'...");

            service.Stop();
            service.WaitForStatus(ServiceControllerStatus.Stopped, timeout);

            service.Refresh();

            if (service.Status != ServiceControllerStatus.Stopped)
            {
                throw new TimeoutException($"Service '{service.ServiceName}' did not stop within {timeout.TotalSeconds} seconds.");
            }

            log?.Invoke($"Service '{service.ServiceName}' stopped.");
        }

        private static void StartService(ServiceController service, TimeSpan timeout, Action<string>? log)
        {
            service.Refresh();

            if (service.Status == ServiceControllerStatus.Running)
            {
                log?.Invoke($"Service '{service.ServiceName}' is already running.");
                return;
            }

            log?.Invoke($"Starting service '{service.ServiceName}'...");

            service.Start();
            service.WaitForStatus(ServiceControllerStatus.Running, timeout);

            service.Refresh();

            if (service.Status != ServiceControllerStatus.Running)
            {
                throw new TimeoutException($"Service '{service.ServiceName}' did not start within {timeout.TotalSeconds} seconds.");
            }

            log?.Invoke($"Service '{service.ServiceName}' started.");
        }


        public static void StopServiceIfRunning(string serviceName, TimeSpan timeout, Action<string>? log = null)
        {
            using var service = new ServiceController(serviceName);

            service.Refresh();

            log?.Invoke($"Checking service '{serviceName}'. Current status: {service.Status}");

            if (service.Status == ServiceControllerStatus.Stopped)
            {
                log?.Invoke($"Service '{serviceName}' is already stopped.");
                return;
            }

            if (service.Status == ServiceControllerStatus.StopPending)
            {
                log?.Invoke($"Service '{serviceName}' is already stopping.");
                service.WaitForStatus(ServiceControllerStatus.Stopped, timeout);
                return;
            }

            if (!service.CanStop)
            {
                throw new InvalidOperationException($"Service '{serviceName}' cannot be stopped.");
            }

            log?.Invoke($"Stopping service '{serviceName}'...");

            service.Stop();
            service.WaitForStatus(ServiceControllerStatus.Stopped, timeout);

            service.Refresh();

            if (service.Status != ServiceControllerStatus.Stopped)
            {
                throw new TimeoutException($"Service '{serviceName}' did not stop within {timeout.TotalSeconds} seconds.");
            }

            log?.Invoke($"Service '{serviceName}' stopped.");
        }
    }
}
