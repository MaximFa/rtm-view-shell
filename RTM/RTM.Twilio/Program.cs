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



app.MapPost("/RTData", async (HttpContext context) =>
{
    //NGCLog.Info("InsertMultipleNewCalls");

    var jsonString = await new StreamReader(context.Request.Body).ReadToEndAsync();

    var apiAdapter = context.RequestServices.GetHostedService<TwilioAdapter>();

   bool result = await apiAdapter.setRTDataAsync(jsonString);

    return result;
});

app.Run();
