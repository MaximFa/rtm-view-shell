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
        private volatile bool _stopping;

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

        private NamedPipeServerStream CreatePipe()
        {
            return new NamedPipeServerStream(_name, PipeDirection.InOut,
                  NamedPipeServerStream.MaxAllowedServerInstances,
                  PipeTransmissionMode.Message, PipeOptions.Asynchronous);
        }

        public async Task Start()
        {
            _stopping = false;
            Initialize(CreatePipe());

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
            try
            {
                Pipe.EndWaitForConnection(result);
                OnClientConnected();
                StartReading().GetAwaiter().GetResult();
            }
            catch (ObjectDisposedException)
            {
                // Server stopping — exit silently
                return;
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }

            // RE-ACCEPT: create fresh pipe + wait for the next client (unless stopping)
            if (_stopping) return;

            try
            {
                // NamedPipeServerStream cannot be reused after Disconnect on .NET;
                // create a fresh instance with the same parameters
                Initialize(CreatePipe());
                Pipe.BeginWaitForConnection(WaitForConnectionCallBack, null);
            }
            catch (ObjectDisposedException)
            {
                // Server stopping — do not re-accept
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }
        }

        public override void Dispose()
        {
            _stopping = true;
            try { Pipe?.Disconnect(); } catch { }
            try { Pipe?.Dispose(); } catch { }
        }
    }
}
