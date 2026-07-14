using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data;
using System.IO.Pipes;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public abstract class NamedPipeBase<T> : IPCConnection
          where T : PipeStream
    {
        protected readonly string _name;
        protected T Pipe;
        private StreamString _stream;

        public NamedPipeBase(string pipeName)
        {
            _name = pipeName;
        }

        public event EventHandler Disconnected;
        private void OnDisconnected()
        {
            Disconnected?.Invoke(this, EventArgs.Empty);
        }

        public event EventHandler<MessageReceivedEventArgs> MessageReceived;
        private void OnMessageReceived(string message)
        {
            MessageReceived?.Invoke(this, new MessageReceivedEventArgs(message));
        }

        protected void Initialize(T pipeStream)
        {
            Pipe = pipeStream;
            _stream = new StreamString(pipeStream);
        }

        protected async Task StartReading()
        {
            var queue = new BlockingCollection<string>();
            var worker = Task.Run(() =>
            {
                try
                {
                    foreach (var msg in queue.GetConsumingEnumerable())
                    {
                        try { OnMessageReceived(msg); }
                        catch (Exception ex) { Console.WriteLine("NamedPipe handler error: " + ex); }
                    }
                }
                catch { }
            });

            try
            {
                while (true)
                {
                    var message = await _stream.ReadString();
                    queue.Add(message);
                }
            }
            catch (Exception)
            {
                // pipe closed / broke — fall through to teardown
            }
            finally
            {
                queue.CompleteAdding();
                try { await worker; } catch { }
                OnDisconnected();
            }
        }

        public async Task Send(string message)
        {
            await _stream.WriteString(message);
        }

        public abstract void Dispose();
    }
}
