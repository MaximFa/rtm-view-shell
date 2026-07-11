using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public interface IPCConnection : IDisposable
    {
        Task Send(string message);
        event EventHandler Disconnected;
        event EventHandler<MessageReceivedEventArgs> MessageReceived;
    }

    public interface IServer : IPCConnection
    {
        Task Start();
        event EventHandler ServerStarted;
        event EventHandler ClientConnected;
    }

    public interface IClient : IPCConnection
    {
        Task Connect();
        event EventHandler ConnectedToServer;
        event EventHandler ClientStarted;
    }

    public class MessageReceivedEventArgs : EventArgs
    {
        public string Message { get; }

        public MessageReceivedEventArgs(string message)
        {
            Message = message;
        }
    }
}
