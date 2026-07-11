using RTM.Tools;

namespace RTM.Twilio
{
    public sealed class RtmTarget
    {
        public string Url  { get; set; }              // REST base
        public string Pipe { get; set; } = "rtmpipe"; // NamedPipe name (default keeps single-target behavior)
        public IClient Client { get; set; }           // runtime-only per-target pipe; absent from config JSON
    }
}
