using System;
using System.Collections.Generic;
using System.IO.Pipes;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public class NamedPipeServer : NamedPipeBase<NamedPipeServerStream>, IServer
    {
        public NamedPipeServer(string name)
           : base(name)
        {
        }

        public event EventHandler ClientConnected;
        private void OnClientConnected()
        {
            ClientConnected?.Invoke(this, EventArgs.Empty);
        }

        public event EventHandler ServerStarted;
        private void OnServerStarted()
        {
            ServerStarted?.Invoke(this, EventArgs.Empty);
        }

        public async Task Start()
        {
            Initialize(new NamedPipeServerStream(_name, PipeDirection.InOut,
                  NamedPipeServerStream.MaxAllowedServerInstances,
                  PipeTransmissionMode.Message, PipeOptions.Asynchronous));

            try
            {
                Pipe.BeginWaitForConnection(WaitForConnectionCallBack, null);

                OnServerStarted();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }
        }

        private void WaitForConnectionCallBack(IAsyncResult result)
        {
            Pipe.EndWaitForConnection(result);
            OnClientConnected();

            // Start a new listener for the next client (multi-service support)
            _ = Start();

            StartReading().GetAwaiter().GetResult();
        }

        public override void Dispose()
        {
            Pipe?.Disconnect();
            Pipe?.Dispose();
        }
    }
}
