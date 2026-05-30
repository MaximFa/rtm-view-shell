using System;
using System.Collections.Generic;
using System.IO.Pipes;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public class NamedPipeClient : NamedPipeBase<NamedPipeClientStream>, IClient
    {
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

        public async Task Connect()
        {
            Initialize(new NamedPipeClientStream(".", _name, PipeDirection.InOut, PipeOptions.Asynchronous));

            try
            {
                OnClientStarted();

                await Pipe.ConnectAsync();
                Pipe.ReadMode = PipeTransmissionMode.Message;

                OnConnectedToServer();

                await StartReading();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }
        }

        public override void Dispose()
        {
            Pipe?.Dispose();
        }
    }
}
