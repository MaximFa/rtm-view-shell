using System;
using System.Collections.Generic;
using System.IO.Pipes;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public class NamedPipeClient : NamedPipeBase<NamedPipeClientStream>, IClient
    {
        private const int ConnectTimeoutMs = 5000;

        public NamedPipeClient(string name) : base(name)
        {
        }

        public event EventHandler ConnectedToServer;
        private void OnConnectedToServer()
        {
            ConnectedToServer?.Invoke(this, EventArgs.Empty);
        }

        public event EventHandler ClientStarted;
        private void OnClientStarted()
        {
            ClientStarted?.Invoke(this, EventArgs.Empty);
        }

        public async Task Connect(CancellationToken ct = default)
        {
            Initialize(new NamedPipeClientStream(".", _name, PipeDirection.InOut, PipeOptions.Asynchronous));

            try
            {
                OnClientStarted();

                await Pipe.ConnectAsync(ConnectTimeoutMs, ct);
                Pipe.ReadMode = PipeTransmissionMode.Message;

                OnConnectedToServer();

                await StartReading();
            }
            catch (OperationCanceledException) { throw; }
            catch (TimeoutException) { AsyncLogger.Info($"CLIENT[{_name}] => connect timeout ({ConnectTimeoutMs}ms)"); }
            catch (Exception ex) { AsyncLogger.Error($"CLIENT[{_name}] => connect/read error", ex); }
        }

        public override void Dispose()
        {
            Pipe?.Dispose();
        }
    }
}
