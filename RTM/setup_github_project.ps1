# RTM PostgreSQL Migration - GitHub Project Setup
# No gh CLI required - uses Invoke-RestMethod with PAT from git remote
# Run from the RTM subfolder: .\setup_github_project.ps1

$ErrorActionPreference = "SilentlyContinue"

# ── Extract PAT from git remote URL ──────────────────────────────────────────
$repoRoot  = Split-Path $PSScriptRoot -Parent
$remoteUrl = & git -C $repoRoot remote get-url origin
$PAT       = [regex]::Match($remoteUrl, 'https://([^@]+)@github\.com').Groups[1].Value

if (-not $PAT) {
    Write-Error "Could not extract PAT from git remote URL. Aborting."
    exit 1
}

$OWNER   = "MaximFa"
$REPO    = "rtm-view-shell"
$BASE    = "https://api.github.com"
$HEADERS = @{
    Authorization          = "Bearer $PAT"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

function Invoke-GH {
    param($Uri, $Method = "GET", $Body = $null)
    $params = @{ Uri = $Uri; Method = $Method; Headers = $HEADERS; ContentType = "application/json" }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }
    Invoke-RestMethod @params
}

function Invoke-GQL {
    param($Query, $Variables = @{})
    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri "https://api.github.com/graphql" -Method POST `
        -Headers $HEADERS -Body $body -ContentType "application/json"
}

# ── 1. Labels ────────────────────────────────────────────────────────────────
Write-Host "`n=== Creating Labels ===" -ForegroundColor Cyan

$labels = @(
    @{ name="rtm-migration";     color="0075ca"; description="RTM PostgreSQL migration work" }
    @{ name="phase:ef-schema";   color="e4e669"; description="EF Core schema changes" }
    @{ name="phase:driver";      color="f9d0c4"; description="ADO.NET driver swap" }
    @{ name="phase:plpgsql";     color="c5def5"; description="PL/pgSQL function writing" }
    @{ name="phase:data-load";   color="bfd4f2"; description="pgloader / data migration" }
    @{ name="priority:critical"; color="b60205"; description="Blocks all other work" }
    @{ name="priority:high";     color="d93f0b"; description="Must complete before go-live" }
    @{ name="open-question";     color="ee0701"; description="Requires decision before implementation" }
)

foreach ($l in $labels) {
    try {
        Invoke-GH -Uri "$BASE/repos/$OWNER/$REPO/labels" -Method POST -Body $l | Out-Null
        Write-Host "  [+] $($l.name)"
    } catch {
        try {
            Invoke-GH -Uri "$BASE/repos/$OWNER/$REPO/labels/$([uri]::EscapeDataString($l.name))" -Method PATCH -Body $l | Out-Null
            Write-Host "  [~] $($l.name) (updated)"
        } catch { Write-Host "  [!] $($l.name) skipped" }
    }
}

# ── 2. Milestones ────────────────────────────────────────────────────────────
Write-Host "`n=== Creating Milestones ===" -ForegroundColor Cyan

$milestoneNames = @("RTM-Phase1-Schema","RTM-Phase2-Driver","RTM-Phase3-PgSQL","RTM-Phase4-Staging")
foreach ($m in $milestoneNames) {
    try {
        Invoke-GH -Uri "$BASE/repos/$OWNER/$REPO/milestones" -Method POST -Body @{ title=$m } | Out-Null
        Write-Host "  [+] $m"
    } catch { Write-Host "  [~] $m (may already exist)" }
}

$ms   = Invoke-GH -Uri "$BASE/repos/$OWNER/$REPO/milestones?per_page=20"
$msM  = @{}
foreach ($m in $ms) { $msM[$m.title] = $m.number }

$m1 = $msM["RTM-Phase1-Schema"]
$m2 = $msM["RTM-Phase2-Driver"]
$m3 = $msM["RTM-Phase3-PgSQL"]
$m4 = $msM["RTM-Phase4-Staging"]
Write-Host "  Phase1=$m1  Phase2=$m2  Phase3=$m3  Phase4=$m4"

# ── 3. Issues ────────────────────────────────────────────────────────────────
Write-Host "`n=== Creating Issues ===" -ForegroundColor Cyan

$issues = @(
    @{
        title     = "[RTM-M1] Add 4 missing EF Core entities + UNIQUE indexes"
        labels    = @("rtm-migration","phase:ef-schema","priority:critical")
        milestone = $m1
        body      = "Add RtsDataChatMessage, RtsGridStatistic, RtsGridTemplateCell, RtsGridUserStatus to BackendEmulationDbContext. Add UNIQUE indexes for UPSERT conflict keys. Generate EF migration. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M1."
    }
    @{
        title     = "[RTM-M2] Replace SqlClient with Npgsql in RTM projects"
        labels    = @("rtm-migration","phase:driver","priority:critical")
        milestone = $m2
        body      = "Swap Microsoft.Data.SqlClient for Npgsql in RTM.Tools and RTM.Configuration. Rewrite DBAdapter.cs and AppConfig.cs. Remove SqlDateTime dependency. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M2."
    }
    @{
        title     = "[RTM-M3] PL/pgSQL - NGC_* functions (18)"
        labels    = @("rtm-migration","phase:plpgsql","priority:high")
        milestone = $m3
        body      = "Port all 18 NGC_* stored procedures to PL/pgSQL. Output: RTM/sql/pgsql/01_ngc_functions.sql. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M3."
    }
    @{
        title     = "[RTM-M4] PL/pgSQL - RTSData_* functions (6 + 2 aliases)"
        labels    = @("rtm-migration","phase:plpgsql","priority:critical")
        milestone = $m3
        body      = "Port RTSData_* SPs including UPSERT, midnight clear (name mismatch fix), lowercase aliases. Output: RTM/sql/pgsql/02_rtsdata_functions.sql. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M4."
    }
    @{
        title     = "[RTM-M5] PL/pgSQL - RTSGrid read functions (8)"
        labels    = @("rtm-migration","phase:plpgsql","priority:high")
        milestone = $m3
        body      = "Port RTSGrid_* and RTSUserGrid_* read-only SPs. Output: RTM/sql/pgsql/03_rtsgrid_read_functions.sql. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M5."
    }
    @{
        title     = "[RTM-M6] PL/pgSQL - missing SPs from scratch + DNN stub"
        labels    = @("rtm-migration","phase:plpgsql","priority:critical")
        milestone = $m3
        body      = "Write NGC_GetDataGrid and NGC_GetCellsByDataGrid from scratch (absent from H_RTM.sql). Stub RTSUserView_GetHTMLSettings (DNN dependency). Output: RTM/sql/pgsql/04_missing_functions.sql. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M6."
    }
    @{
        title     = "[RTM-M7] pgloader staging + data migration + smoke test"
        labels    = @("rtm-migration","phase:data-load","priority:high")
        milestone = $m4
        body      = "Set up cc_rtm_staging PostgreSQL DB. Run pgloader from SQL Server. Smoke-test all 37 PL/pgSQL functions. Output: RTM/sql/pgloader/rtm_staging.load. See RTM/RTM_MIGRATION_CC_PROMPTS.md - RTM-M7."
    }
    @{
        title     = "[OQ-01] DECISION: RTSUserView_GetHTMLSettings DNN dependency"
        labels    = @("rtm-migration","open-question","priority:critical")
        milestone = $m3
        body      = "RTSUserView_GetHTMLSettings reads from DNN CMS table ModuleSettings. Options: (A) stub returning empty HTML, (B) replicate ModuleSettings to PostgreSQL, (C) REST endpoint from DNN side. Must decide before RTM-M6."
    }
    @{
        title     = "[OQ-03] VALIDATE: NGC_GetDataGrid / NGC_GetCellsByDataGrid spec"
        labels    = @("rtm-migration","open-question","priority:critical")
        milestone = $m3
        body      = "Both SPs called from RealtimeData.cs (lines 336, 372) but absent from H_RTM.sql. Must reconstruct from C# column-index access patterns and validate against production SQL Server before RTM-M6."
    }
)

$createdIssueIds = @()

foreach ($issue in $issues) {
    $payload = @{
        title     = $issue.title
        body      = $issue.body
        labels    = $issue.labels
        milestone = $issue.milestone
    }
    try {
        $result = Invoke-GH -Uri "$BASE/repos/$OWNER/$REPO/issues" -Method POST -Body $payload
        $createdIssueIds += $result.node_id
        Write-Host "  [+] #$($result.number) $($issue.title.Substring(0, [Math]::Min(55,$issue.title.Length)))"
    } catch {
        Write-Host "  [!] Failed: $($issue.title.Substring(0, [Math]::Min(55,$issue.title.Length)))"
        Write-Host "      $_"
    }
}

# ── 4. GitHub Project v2 (GraphQL) ───────────────────────────────────────────
Write-Host "`n=== Creating GitHub Project v2 ===" -ForegroundColor Cyan

# Get user node_id
$userQuery = 'query($login:String!){user(login:$login){id}}'
$userResult = Invoke-GQL -Query $userQuery -Variables @{ login=$OWNER }
$ownerId = $userResult.data.user.id

# Create project
$createQuery = 'mutation($ownerId:ID!,$title:String!){createProjectV2(input:{ownerId:$ownerId,title:$title}){projectV2{id number url}}}'
$projectResult = Invoke-GQL -Query $createQuery -Variables @{ ownerId=$ownerId; title="RTM PostgreSQL Migration" }
$projectId     = $projectResult.data.createProjectV2.projectV2.id
$projectNumber = $projectResult.data.createProjectV2.projectV2.number
$projectUrl    = $projectResult.data.createProjectV2.projectV2.url

if (-not $projectId) {
    Write-Host "  [!] Could not create project. Check PAT has 'project' scope." -ForegroundColor Yellow
    Write-Host "  You can create the project manually at: https://github.com/users/$OWNER/projects/new"
} else {
    Write-Host "  [+] Project #$projectNumber created: $projectUrl"

    # Add issues to project
    Write-Host "`n=== Adding issues to project ===" -ForegroundColor Cyan
    $addQuery = 'mutation($pid:ID!,$cid:ID!){addProjectV2ItemById(input:{projectId:$pid,contentId:$cid}){item{id}}}'
    foreach ($nodeId in $createdIssueIds) {
        try {
            Invoke-GQL -Query $addQuery -Variables @{ pid=$projectId; cid=$nodeId } | Out-Null
            Write-Host "  [+] added to project"
        } catch { Write-Host "  [!] Failed to add item" }
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Repo:    https://github.com/$OWNER/$REPO"
Write-Host "Issues:  https://github.com/$OWNER/$REPO/issues"
if ($projectUrl) { Write-Host "Project: $projectUrl" }
Write-Host ""
Write-Host "NOTE: If project scope is missing from PAT, create project at:" -ForegroundColor Yellow
Write-Host "      https://github.com/users/$OWNER/projects/new" -ForegroundColor Yellow
