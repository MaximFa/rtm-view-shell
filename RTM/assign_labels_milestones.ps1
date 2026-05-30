# assign_labels_milestones.ps1
# Assigns labels and milestones to all 9 RTM issues via GitHub REST API
# Requires: repo scope on PAT (no extra scopes needed)
# Run from inside the rtm-view-shell repo clone

param(
    [string]$Owner = "MaximFa",
    [string]$Repo  = "rtm-view-shell"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Extract PAT from git remote
$remoteUrl = & git remote get-url origin 2>&1
$PAT = [regex]::Match($remoteUrl, 'https://([^@]+)@github\.com').Groups[1].Value
Write-Host "PAT extracted (length=$($PAT.Length))"

$BASE = "https://api.github.com/repos/$Owner/$Repo"
$HEADERS = @{
    Authorization = "token $PAT"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

function Patch-Issue {
    param([int]$Number, [string[]]$Labels, [int]$Milestone = 0)
    $body = @{ labels = $Labels }
    if ($Milestone -gt 0) { $body.milestone = $Milestone }
    $json = $body | ConvertTo-Json -Compress
    try {
        $r = Invoke-RestMethod -Uri "$BASE/issues/$Number" -Method PATCH `
            -Headers $HEADERS -Body $json -ContentType "application/json"
        $milestoneStr = if ($r.milestone) { $r.milestone.title } else { "-" }
        $labelStr = ($r.labels | ForEach-Object { $_.name }) -join ", "
        Write-Host "  #$Number OK  labels=[$labelStr]  milestone=$milestoneStr" -ForegroundColor Green
    } catch {
        Write-Warning "  #$Number FAILED: $_"
    }
}

# Milestone numbers (created in previous step: #1..#4)
# RTM-Phase1-Schema=#1  RTM-Phase2-Driver=#2  RTM-Phase3-PgSQL=#3  RTM-Phase4-Staging=#4

Write-Host "`nAssigning labels and milestones..." -ForegroundColor Cyan

Patch-Issue -Number 1 -Labels @("rtm-migration","phase:ef-schema","priority:critical") -Milestone 1
Patch-Issue -Number 2 -Labels @("rtm-migration","phase:driver","priority:critical")    -Milestone 1
Patch-Issue -Number 3 -Labels @("rtm-migration","phase:plpgsql","priority:critical")   -Milestone 2
Patch-Issue -Number 4 -Labels @("rtm-migration","phase:plpgsql","priority:critical")   -Milestone 3
Patch-Issue -Number 5 -Labels @("rtm-migration","phase:plpgsql","priority:high")       -Milestone 3
Patch-Issue -Number 6 -Labels @("rtm-migration","phase:plpgsql","priority:high")       -Milestone 3
Patch-Issue -Number 7 -Labels @("rtm-migration","phase:data-load","priority:high")     -Milestone 4
Patch-Issue -Number 8 -Labels @("rtm-migration","open-question")
Patch-Issue -Number 9 -Labels @("rtm-migration","open-question")

Write-Host "`nDone! Check: https://github.com/$Owner/$Repo/issues" -ForegroundColor Green
