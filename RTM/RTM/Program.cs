using Microsoft.Identity.Client;
using Newtonsoft.Json;
using RTM;
using RTM.Configuration;
using RTM.Services;
using RTM.Tools;
using RTM.Types;
using System.Xml.Serialization;


// CreateBuilder
WebApplicationOptions options = new()
{
    ContentRootPath = AppContext.BaseDirectory,
    Args = args
};
var builder = WebApplication.CreateBuilder(options);

// Configuration files
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile("app.dat", optional: false, reloadOnChange: true)
    .AddEnvironmentVariables();

string contentRootPath = builder.Environment.ContentRootPath;

// Set Log
var logConfigPath = Path.Combine(contentRootPath, "log4net.config");
AsyncLogger.InitializeLog4Net(logConfigPath);
AsyncLogger.Info("RTM Program Start");

// Determine the path to data.sys
string dataFilePath = Path.Combine(contentRootPath, "data.sys");
AsyncLogger.Info($"Root Path = {contentRootPath}");

AppConfig.Initialize(builder.Configuration, dataFilePath);


// Modify the configuration in-memory
var configurationBuilder = new ConfigurationBuilder()
    .SetBasePath(builder.Environment.ContentRootPath)
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile("app.dat", optional: false, reloadOnChange: true)
    .AddEnvironmentVariables();

var configuration = configurationBuilder.Build();


//  Kestrel configuration
var kestrelSection = builder.Configuration.GetSection("Kestrel");
if (kestrelSection.Exists())
{
    var endpoints = kestrelSection.GetSection("Endpoints").GetChildren();
    foreach (var endpoint in endpoints)
    {
        var url = endpoint.GetValue<string>("Url");
        if (url.StartsWith("https", StringComparison.OrdinalIgnoreCase))
        {
            configuration["Kestrel:Endpoints:Https:Certificate:Password"] = AppConfig.KestrelHttpsPassword;
        }
    }
}


builder.WebHost.ConfigureAppConfiguration((hostingContext, config) =>
{
    config.AddConfiguration(configuration);
});


builder.Services.AddControllers().AddXmlSerializerFormatters();



// APIAdapter
builder.Services.AddSingleton<RTMAdapter>();
builder.Services.AddHostedService<RTMAdapter>(provider => provider.GetService<RTMAdapter>());

builder.Host.UseWindowsService();
//builder.Host.UseSystemd();


builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();


builder.Services.AddSignalR()
    .AddNewtonsoftJsonProtocol(options =>
    {
        options.PayloadSerializerSettings.ContractResolver = new Newtonsoft.Json.Serialization.DefaultContractResolver();
    });

builder.Services.AddCors(options => options.AddPolicy("CorsPolicy",
        builder =>
        {
            builder.AllowAnyHeader()
                   .AllowAnyMethod()
                   .SetIsOriginAllowed((host) => true)                  
                   .AllowCredentials();
        }));

var app = builder.Build();

app.UseHttpsRedirection();

app.UseAuthorization();

app.UseCors("CorsPolicy");

//app.MapHub<RTMHub>("/RTMHub");

app.MapHub<RTMHub>("/signalr");



app.MapPost("/SetUsersStatusList", async (HttpContext context) =>
{
    try
    {
        // Read the request body and deserialize it to the List<Agent>
        string json = await new StreamReader(context.Request.Body).ReadToEndAsync();
        
        var apiAdapter = context.RequestServices.GetHostedService<RTMAdapter>();
        apiAdapter.setUsersStatusList(json);
    }
    catch (Exception ex)
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await context.Response.WriteAsJsonAsync(new { Success = false, Message = ex.Message });
    }
});



app.MapGet("/GetWorkgroups", (HttpContext context) =>
{
    var apiAdapter = context.RequestServices.GetRequiredService<RTMAdapter>();
    var workgroups = apiAdapter.getWorkgroups();

    context.Response.ContentType = "application/xml";
    using var stringWriter = new StringWriter();
    var xmlSerializer = new XmlSerializer(typeof(List<string>));
    xmlSerializer.Serialize(stringWriter, workgroups);
    return Results.Content(stringWriter.ToString(), "application/xml");
});




app.MapGet("/GetAgentgroups", (HttpContext context) =>
{
    var apiAdapter = context.RequestServices.GetRequiredService<RTMAdapter>();
    var workgroups = apiAdapter.getAgentgroups();

    context.Response.ContentType = "application/xml";
    using var stringWriter = new StringWriter();
    var xmlSerializer = new XmlSerializer(typeof(List<string>));
    xmlSerializer.Serialize(stringWriter, workgroups);
    return Results.Content(stringWriter.ToString(), "application/xml");
});



app.MapGet("/GetQueues", (HttpContext context) =>
{
    var apiAdapter = context.RequestServices.GetRequiredService<RTMAdapter>();
    var workgroups = apiAdapter.getQueues();

    context.Response.ContentType = "application/xml";
    using var stringWriter = new StringWriter();
    var xmlSerializer = new XmlSerializer(typeof(List<string>));
    xmlSerializer.Serialize(stringWriter, workgroups);
    return Results.Content(stringWriter.ToString(), "application/xml");
});





app.MapGet("/LoadData", async (HttpContext context) =>
{
    var apiAdapter = context.RequestServices.GetHostedService<RTMAdapter>();
    var res = apiAdapter.LoadData();

    context.Response.ContentType = "application/xml";
    using var stringWriter = new StringWriter();
    var xmlSerializer = new XmlSerializer(typeof(bool));
    xmlSerializer.Serialize(stringWriter, res);
    return Results.Content(stringWriter.ToString(), "application/xml");
});



app.MapGet("/UpdateCell", async (int cellId, int gridId, string metric, int statisticId, int unionId, HttpContext context) =>
{
    var apiAdapter = context.RequestServices.GetHostedService<RTMAdapter>();
    var res = apiAdapter.UpdateCell(cellId, gridId, metric, statisticId, unionId);

    context.Response.ContentType = "application/xml";
    using var stringWriter = new StringWriter();
    var xmlSerializer = new XmlSerializer(typeof(bool));
    xmlSerializer.Serialize(stringWriter, res);
    return Results.Content(stringWriter.ToString(), "application/xml");
});



app.MapGet("/GetCellData", async (int cellId, HttpContext context) =>
{
    var apiAdapter = context.RequestServices.GetHostedService<RTMAdapter>();
    var res = apiAdapter.GetCellData(cellId);
    return res;

    //context.Response.ContentType = "application/xml";
    //using var stringWriter = new StringWriter();
    //var xmlSerializer = new XmlSerializer(typeof(bool));
    //xmlSerializer.Serialize(stringWriter, res);
    //return Results.Content(stringWriter.ToString(), "application/xml");
});

app.Run();
