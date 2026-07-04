#Requires -Version 5.1
<#
.SYNOPSIS
    Single-source RTM table whitelist and version-independent schema dump helper.
    Used by Export-All.ps1 (baseline generation) and Compare-ToBaseline.ps1 (server dump).
    Avoids PS5.1 -t quote-stripping issue by doing full dump + post-filter.
.NOTES
    The whitelist must match exactly across both callers for symmetric comparison.
    24 RTM tables (NGC_/RTSData_/RTSGrid_/RTSUserGrid_) + 2 bookkeeping (db_patch_history/metric_deploy_log).
#>

# Single source of the RTM-canonical table whitelist
# 24 RTM + 2 bookkeeping = 26 total
$script:RtmTableNames = @(
    # NGC_ (9)
    'public."NGC_AgentGroups"',
    'public."NGC_BusinessUnit"',
    'public."NGC_BusinessUnitQueueClassification"',
    'public."NGC_BusinessUnitSupergroup"',
    'public."NGC_Queues"',
    'public."NGC_Site"',
    'public."NGC_Supergroup"',
    'public."NGC_SupergroupAgentgroup"',
    'public."NGC_UserAgentgroup"',
    # RTSData_ (4)
    'public."RTSData_ChatMessage"',
    'public."RTSData_Interaction"',
    'public."RTSData_UserStatus"',
    'public."RTSData_UserStatusLog"',
    # RTSGrid_ (8)
    'public."RTSGrid_Cell"',
    'public."RTSGrid_Column"',
    'public."RTSGrid_Grid"',
    'public."RTSGrid_Metric"',
    'public."RTSGrid_MetricTranslation"',
    'public."RTSGrid_Row"',
    'public."RTSGrid_Statistic"',
    'public."RTSGrid_UserStatus"',
    # RTSUserGrid_ (3)
    'public."RTSUserGrid_Column"',
    'public."RTSUserGrid_ColumnsSet"',
    'public."RTSUserGrid_Grid"',
    # Bookkeeping (2)
    'public.db_patch_history',
    'public.metric_deploy_log'
)

function Export-RtmSchema {
    <#
    .SYNOPSIS
        Exports RTM schema using full dump + filter (avoids PS5.1 -t quote-strip).
    .PARAMETER PgDump
        Path to pg_dump executable.
    .PARAMETER DBHost
        Database host.
    .PARAMETER DBPort
        Database port.
    .PARAMETER DBUser
        Database user.
    .PARAMETER Database
        Database name.
    .PARAMETER OutFile
        Output file path for the schema SQL.
    #>
    param(
        [Parameter(Mandatory)][string]$PgDump,
        [Parameter(Mandatory)][string]$DBHost,
        [Parameter(Mandatory)][string]$DBPort,
        [Parameter(Mandatory)][string]$DBUser,
        [Parameter(Mandatory)][string]$Database,
        [Parameter(Mandatory)][string]$OutFile
    )

    # FULL public schema-only dump (NO -t -> no PS quote-strip), then filter to whitelist
    $tmp = [System.IO.Path]::GetTempFileName() + ".sql"
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $dumpOutput = & $PgDump -h $DBHost -p $DBPort -U $DBUser -d $Database --schema-only --no-owner --no-acl -n public -f $tmp 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prev
    }

    if ($code -ne 0) {
        throw "pg_dump full schema failed (exit $code): $dumpOutput"
    }

    $raw = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8
    Remove-Item $tmp -ErrorAction SilentlyContinue

    # pg_dump separates each object with blank lines and "-- Name: ...; Type: ...;" headers.
    # Split on double newline boundary; KEEP a block iff it contains a full-quoted whitelist name.
    # Full-quoted match prevents "NGC_BusinessUnit" from substring-matching "NGC_BusinessUnitSupergroup".
    $blocks = $raw -split "(?m)\r?\n\r?\n"
    $keep = New-Object System.Collections.Generic.List[string]

    foreach ($b in $blocks) {
        foreach ($name in $script:RtmTableNames) {
            # Extract the quoted part (e.g., "NGC_Site" or db_patch_history)
            if ($name -match '^public\.(.+)$') {
                $quotedPart = $Matches[1]
            } else {
                $quotedPart = $name
            }
            # Check if block contains this exact table reference
            if ($b.Contains($quotedPart)) {
                [void]$keep.Add($b.TrimEnd())
                break
            }
        }
    }

    # Write without BOM for SQL baseline file
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $content = ($keep -join "`r`n`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($OutFile, $content, $utf8NoBom)

    Write-Host ("Export-RtmSchema: {0} object-blocks kept for {1} whitelist tables" -f @($keep).Count, @($script:RtmTableNames).Count)
}
