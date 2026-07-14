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

        private async void WaitForConnectionCallBack(IAsyncResult result)
        {
            var connectedPipe = Pipe;   // capture this connection
            try
            {
                connectedPipe.EndWaitForConnection(result);
                OnClientConnected();
                await StartReading();    // returns only on disconnect (read loop drains via worker)
            }
            catch (ObjectDisposedException)
            {
                return; // server stopping
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }
            finally
            {
                try { connectedPipe?.Dispose(); } catch { }  // close THIS connection only
            }

            if (_stopping) return;

            try
            {
                Initialize(CreatePipe());   // fresh pipe for the NEXT client — only AFTER this one ended
                Pipe.BeginWaitForConnection(WaitForConnectionCallBack, null);
            }
            catch (ObjectDisposedException) { }
            catch (Exception ex) { Console.WriteLine(ex); }
        }

        public override void Dispose()
        {
            _stopping = true;
            try { Pipe?.Disconnect(); } catch { }
            try { Pipe?.Dispose(); } catch { }
        }
    }
}
