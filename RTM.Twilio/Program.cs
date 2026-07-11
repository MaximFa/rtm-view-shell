using RTM.Tools;
using RTM.Twilio;
using RTM.Twilio.Services;

WebApplicationOptions options = new()
{
    ContentRootPath = AppContext.BaseDirectory,
    Args = args
};
var builder = WebApplication.CreateBuilder(options);


builder.Services.AddSingleton<TwilioAdapter>();
builder.Services.AddHostedService<TwilioAdapter>(provider => provider.GetService<TwilioAdapter>());

builder.Host.UseWindowsService();
//builder.Host.UseSystemd();


builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();


builder.Services.AddCors(options => options.AddPolicy("CorsPolicy",
        builder =>
        {
            builder.AllowAnyHeader()
                   .AllowAnyMethod()
                   .SetIsOriginAllowed((host) => true)
                   .AllowCredentials();
        }));

var app = builder.Build();



//app.MapPost("/RTData", async (HttpContext context) =>
//{
//    //NGCLog.Info("InsertMultipleNewCalls");

//    var jsonString = await new StreamReader(context.Request.Body).ReadToEndAsync();

//    var apiAdapter = context.RequestServices.GetHostedService<TwilioAdapter>();

//   bool result = await apiAdapter.setRTDataAsync(jsonString);

//    return result;
//});


app.MapPost("/RTData", async (HttpContext context) =>
{
    var requestId = Guid.NewGuid().ToString("N");
    var sw = System.Diagnostics.Stopwatch.StartNew();

    AsyncLogger.Info(
        $"RTData entry RequestId={requestId} RemoteIp={context.Connection.RemoteIpAddress} LocalIp={context.Connection.LocalIpAddress} LocalPort={context.Connection.LocalPort} ContentLength={context.Request.ContentLength}");

    try
    {
        using var reader = new StreamReader(context.Request.Body);
        var jsonString = await reader.ReadToEndAsync();


        if (string.IsNullOrWhiteSpace(jsonString))
        {
            sw.Stop();

            AsyncLogger.Error(
                $"RTData rejected RequestId={requestId} Reason=EmptyBody ElapsedMs={sw.ElapsedMilliseconds}");

            return Results.BadRequest("Empty body");
        }

        AsyncLogger.Info(
            $"RTData body received RequestId={requestId} BodyLength={jsonString?.Length ?? 0}");

        var apiAdapter = context.RequestServices.GetHostedService<TwilioAdapter>();

        if (apiAdapter == null)
        {
            sw.Stop();

            AsyncLogger.Error(
                $"RTData failed RequestId={requestId} Error=TwilioAdapter is null ElapsedMs={sw.ElapsedMilliseconds}");

            return Results.Problem("TwilioAdapter is null");
        }


        bool queued = apiAdapter.TryQueueRTData(jsonString, requestId);

        sw.Stop();

        if (!queued)
        {
            AsyncLogger.Error(
                $"RTData rejected RequestId={requestId} Reason=QueueFull ElapsedMs={sw.ElapsedMilliseconds}");

            return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
        }

        AsyncLogger.Info(
            $"RTData accepted RequestId={requestId} ElapsedMs={sw.ElapsedMilliseconds}");

        return Results.Ok(true);

        //bool result = await apiAdapter.setRTDataAsync(jsonString, requestId);

        //sw.Stop();

        //AsyncLogger.Info(
        //    $"RTData completed RequestId={requestId} Result={result} ElapsedMs={sw.ElapsedMilliseconds}");

        //return Results.Ok(result);
    }
    catch (Exception ex)
    {
        sw.Stop();

        AsyncLogger.Error(
            $"RTData failed RequestId={requestId} ElapsedMs={sw.ElapsedMilliseconds}",
            ex);

        return Results.Problem("RTData failed");
    }
});


app.Run();
