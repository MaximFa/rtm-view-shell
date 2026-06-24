using System.Reflection;

namespace RTMMaintenance.ReadPlane.Tests;

/// <summary>
/// Architecture-level security tests for SF-MS-003.
/// Ensures anti-RCE patterns are followed across the codebase.
/// </summary>
public class ArchitectureSecurityTests
{
    private readonly Assembly _readPlaneAssembly;

    public ArchitectureSecurityTests()
    {
        _readPlaneAssembly = typeof(Program).Assembly;
    }

    [Fact]
    public void NoProcessStartInfoArgumentsStringUsage()
    {
        var sourceDir = FindSourceDirectory();
        if (sourceDir == null)
        {
            return;
        }

        var csFiles = Directory.GetFiles(sourceDir, "*.cs", SearchOption.AllDirectories)
            .Where(f => !f.Contains("\\bin\\") && !f.Contains("\\obj\\") && !f.Contains(".Tests\\"));

        var violations = new List<string>();

        foreach (var file in csFiles)
        {
            var lines = File.ReadAllLines(file);

            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i];

                if (IsInComment(line) || IsInXmlDoc(line))
                    continue;

                if (line.Contains(".Arguments =") || line.Contains(".Arguments="))
                {
                    if (!line.Contains("// SF-MS-003-EXEMPT:"))
                    {
                        violations.Add($"{Path.GetFileName(file)}:{i + 1}: Uses ProcessStartInfo.Arguments (string concat)");
                    }
                }
            }
        }

        violations.Should().BeEmpty(
            "SF-MS-003 requires ArgumentList (not Arguments string). " +
            "Found violations:\n" + string.Join("\n", violations));
    }

    [Fact]
    public void IScriptInvocationContractExists()
    {
        var invocationType = _readPlaneAssembly.GetType("RTMMaintenance.ReadPlane.Jobs.Contracts.IScriptInvocation");

        invocationType.Should().NotBeNull("IScriptInvocation contract should exist");
        invocationType!.IsInterface.Should().BeTrue("IScriptInvocation should be an interface");
    }

    [Fact]
    public void IScriptInvocationHasArgumentListParameter()
    {
        var invocationType = _readPlaneAssembly.GetType("RTMMaintenance.ReadPlane.Jobs.Contracts.IScriptInvocation");
        invocationType.Should().NotBeNull();

        var executeMethod = invocationType!.GetMethod("ExecuteAsync");
        executeMethod.Should().NotBeNull("IScriptInvocation should have ExecuteAsync method");

        var parameters = executeMethod!.GetParameters();
        var argumentsParam = parameters.FirstOrDefault(p => p.Name == "arguments");
        argumentsParam.Should().NotBeNull("ExecuteAsync should have 'arguments' parameter");

        var paramType = argumentsParam!.ParameterType;
        var isReadOnlyList = paramType.IsGenericType &&
            paramType.GetGenericTypeDefinition() == typeof(IReadOnlyList<>) &&
            paramType.GetGenericArguments()[0] == typeof(string);

        isReadOnlyList.Should().BeTrue(
            "arguments parameter should be IReadOnlyList<string> for ArgumentList compatibility");
    }

    [Fact]
    public void SignalScriptMapIsStaticAndImmutable()
    {
        var mapType = _readPlaneAssembly.GetType("RTMMaintenance.ReadPlane.Contracts.SignalScriptMap");
        mapType.Should().NotBeNull();

        mapType!.IsAbstract.Should().BeTrue("SignalScriptMap should be static (IsAbstract=true for static classes)");
        mapType.IsSealed.Should().BeTrue("SignalScriptMap should be static (IsSealed=true for static classes)");

        var fields = mapType.GetFields(BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);
        var mapField = fields.FirstOrDefault(f => f.Name == "Map");
        mapField.Should().NotBeNull("SignalScriptMap should have a Map field");
        mapField!.IsInitOnly.Should().BeTrue("Map field should be readonly");
    }

    [Fact]
    public void ArgumentArrayGuardIsStatic()
    {
        var guardType = _readPlaneAssembly.GetType("RTMMaintenance.ReadPlane.Validation.ArgumentArrayGuard");
        guardType.Should().NotBeNull();

        guardType!.IsAbstract.Should().BeTrue("ArgumentArrayGuard should be static (IsAbstract=true)");
        guardType.IsSealed.Should().BeTrue("ArgumentArrayGuard should be static (IsSealed=true)");
    }

    [Fact]
    public void ISingleCollectLockContractExists()
    {
        var lockType = _readPlaneAssembly.GetType("RTMMaintenance.ReadPlane.Jobs.Contracts.ISingleCollectLock");

        lockType.Should().NotBeNull("ISingleCollectLock contract should exist");
        lockType!.IsInterface.Should().BeTrue("ISingleCollectLock should be an interface");
    }

    private static string? FindSourceDirectory()
    {
        var currentDir = AppContext.BaseDirectory;

        while (currentDir != null)
        {
            var srcPath = Path.Combine(currentDir, "src", "Maintenance", "RTMMaintenance.ReadPlane");
            if (Directory.Exists(srcPath))
                return srcPath;

            var parent = Directory.GetParent(currentDir);
            currentDir = parent?.FullName;
        }

        var testAssemblyPath = typeof(ArchitectureSecurityTests).Assembly.Location;
        var projRoot = Path.GetDirectoryName(testAssemblyPath);

        for (int i = 0; i < 10 && projRoot != null; i++)
        {
            var tryPath = Path.Combine(projRoot, "src", "Maintenance", "RTMMaintenance.ReadPlane");
            if (Directory.Exists(tryPath))
                return tryPath;
            projRoot = Path.GetDirectoryName(projRoot);
        }

        return null;
    }

    private static bool IsInComment(string line)
    {
        var trimmed = line.TrimStart();
        return trimmed.StartsWith("//") || trimmed.StartsWith("/*") || trimmed.StartsWith("*");
    }

    private static bool IsInXmlDoc(string line)
    {
        var trimmed = line.TrimStart();
        return trimmed.StartsWith("///") || trimmed.StartsWith("<");
    }
}
