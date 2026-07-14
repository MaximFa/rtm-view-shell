using RTM.Tools;
using System;

namespace RTM.Twilio
{
    public sealed class RtmTarget
    {
        public string Url  { get; set; }              // REST base
        public string Pipe { get; set; } = "rtmpipe"; // NamedPipe name (default keeps single-target behavior)
        public IClient Client { get; set; }           // runtime-only per-target pipe; absent from config JSON

        // Supervisor reconnect backoff — reset to 1s on each successful connect
        internal TimeSpan Backoff { get; set; } = TimeSpan.FromSeconds(1);
    }
}
