# add_issues_to_project.ps1
# Adds issues #1-#9 from MaximFa/rtm-view-shell to GitHub Project #1
# Also creates labels and milestones using the existing PAT
# Run from anywhere inside the rtm-view-shell repo clone

param(
    [string]$Owner = "MaximFa",
    [string]$Repo  = "rtm-view-shell",
    [int]$ProjectNumber = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Extract PAT from git remote ────────────────────────────────────────────
$remoteUrl = & git remote get-url origin 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "git remote get-url failed. Run from inside the repo."; exit 1 }
$match = [regex]::Match($remoteUrl, 'https://([^@]+)@github\.com')
if (-not $match.Success) { Write-Error "PAT not found in remote URL. Expected https://<pat>@github.com/..."; exit 1 }
$PAT = $match.Groups[1].Value
Write-Host "PAT extracted (length=$($PAT.Length))"

$HEADERS = @{
    Authorization = "bearer $PAT"
    "Content-Type" = "application/json"
}

function Invoke-GQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10 -Compress
    $resp = Invoke-RestMethod -Uri "https://api.github.com/graphql" `
        -Method POST -Headers $HEADERS -Body $body
    if ($resp.PSObject.Properties.Item("errors")) {
        Write-Warning "GraphQL errors: $($resp.errors | ConvertTo-Json -Depth 5)"
    }
    return $resp
}

function Invoke-REST {
    param([string]$Method, [string]$Path, [hashtable]$Body = $null)
    $uri = "https://api.github.com$Path"
    $h = @{
        Authorization = "token $PAT"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    if ($Body) {
        $json = $Body | ConvertTo-Json -Compress
        return Invoke-RestMethod -Uri $uri -Method $Method -Headers $h -Body $json -ContentType "application/json"
    } else {
        return Invoke-RestMethod -Uri $uri -Method $Method -Headers $h
    }
}

# ── Step 1: Get project node ID ────────────────────────────────────────────
Write-Host "`n=== Step 1: Get project node ID ===" -ForegroundColor Cyan
$projectQuery = 'query($owner:String!,$num:Int!){user(login:$owner){projectV2(number:$num){id title}}}'
$pResult = Invoke-GQL -Query $projectQuery -Variables @{ owner = $Owner; num = $ProjectNumber }
$projectId = $pResult.data.user.projectV2.id
$projectTitle = $pResult.data.user.projectV2.title
if (-not $projectId) {
    Write-Error "Could not get project node ID. Check PAT has 'project' scope."
    exit 1
}
Write-Host "Project: $projectTitle  ID: $projectId" -ForegroundColor Green

# ── Step 2: Get issue node IDs ─────────────────────────────────────────────
Write-Host "`n=== Step 2: Get issue node IDs ===" -ForegroundColor Cyan
$issueQuery = 'query($owner:String!,$repo:String!){repository(owner:$owner,name:$repo){issues(first:20,orderBy:{field:CREATED_AT,direction:ASC}){nodes{id number title}}}}'
$iResult = Invoke-GQL -Query $issueQuery -Variables @{ owner = $Owner; repo = $Repo }
$issues = $iResult.data.repository.issues.nodes
Write-Host "Found $($issues.Count) issues:"
$issues | ForEach-Object { Write-Host "  #$($_.number) $($_.title)  [nodeId: $($_.id)]" }

# ── Step 3: Add each issue to the project ─────────────────────────────────
Write-Host "`n=== Step 3: Add issues to project ===" -ForegroundColor Cyan
$addMutation = 'mutation($pid:ID!,$cid:ID!){addProjectV2ItemById(input:{projectId:$pid,contentId:$cid}){item{id}}}'
$addedCount = 0
foreach ($issue in $issues) {
    try {
        $r = Invoke-GQL -Query $addMutation -Variables @{ pid = $projectId; cid = $issue.id }
        $itemId = $r.data.addProjectV2ItemById.item.id
        if ($itemId) {
            Write-Host "  Added #$($issue.number): $itemId" -ForegroundColor Green
            $addedCount++
        } else {
            Write-Warning "  #$($issue.number): no item ID returned (possibly already added)"
        }
    } catch {
        Write-Warning "  #$($issue.number) failed: $_"
    }
}
Write-Host "$addedCount/$($issues.Count) issues added to project." -ForegroundColor Cyan

# ── Step 4: Create labels ──────────────────────────────────────────────────
Write-Host "`n=== Step 4: Create labels ===" -ForegroundColor Cyan
$labels = @(
    @{ name="rtm-migration";          color="0075ca"; description="RTM PostgreSQL migration" },
    @{ name="phase:ef-schema";        color="e4e669"; description="RTM-M1 EF entities & schema" },
    @{ name="phase:driver";           color="e4e669"; description="RTM-M2 Npgsql driver" },
    @{ name="phase:plpgsql";          color="e4e669"; description="RTM-M3+M4+M5 PL/pgSQL functions" },
    @{ name="phase:data-load";        color="e4e669"; description="RTM-M7 pgloader staging" },
    @{ name="priority:critical";      color="d73a4a"; description="Must fix — blocks go-live" },
    @{ name="priority:high";          color="e99695"; description="Important, address this sprint" },
    @{ name="open-question";          color="cfd3d7"; description="Decision required before implementation" }
)
foreach ($label in $labels) {
    try {
        $r = Invoke-REST -Method POST -Path "/repos/$Owner/$Repo/labels" -Body $label
        Write-Host "  Created label: $($label.name)" -ForegroundColor Green
    } catch {
        $msg = $_.ToString()
        if ($msg -match "already_exists" -or $msg -match "422") {
            Write-Host "  Label exists: $($label.name)" -ForegroundColor Yellow
        } else {
            Write-Warning "  Label '$($label.name)' failed: $msg"
        }
    }
}

# ── Step 5: Create milestones ──────────────────────────────────────────────
Write-Host "`n=== Step 5: Create milestones ===" -ForegroundColor Cyan
$milestones = @(
    @{ title="RTM-Phase1-Schema";  description="EF entities + Npgsql driver" },
    @{ title="RTM-Phase2-Driver";  description="NGC* PL/pgSQL functions" },
    @{ title="RTM-Phase3-PgSQL";   description="RTSData* + RTSGrid* + missing SPs" },
    @{ title="RTM-Phase4-Staging"; description="pgloader migration & UAT" }
)
foreach ($ms in $milestones) {
    try {
        $r = Invoke-REST -Method POST -Path "/repos/$Owner/$Repo/milestones" -Body $ms
        Write-Host "  Created milestone: $($ms.title) (#$($r.number))" -ForegroundColor Green
    } catch {
        $msg = $_.ToString()
        if ($msg -match "already_exists" -or $msg -match "422") {
            Write-Host "  Milestone exists: $($ms.title)" -ForegroundColor Yellow
        } else {
            Write-Warning "  Milestone '$($ms.title)' failed: $msg"
        }
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Project board: https://github.com/users/$Owner/projects/$ProjectNumber"
Write-Host "Issues:        https://github.com/$Owner/$Repo/issues"
Write-Host "Labels:        https://github.com/$Owner/$Repo/labels"
Write-Host "Milestones:    https://github.com/$Owner/$Repo/milestones"
