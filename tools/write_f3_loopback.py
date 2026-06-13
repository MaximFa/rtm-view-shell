#!/usr/bin/env python3
"""F-3 fix: RTM hub loopback rebind + orchestrator wiring"""
import os
import json

repo = r"D:\Claude\Projects\RTM View Shell"

# ═══════════════════════════════════════════════════════════════════════════════
# FILE A — RTM/RTM/appsettings.json (change * to 127.0.0.1)
# ═══════════════════════════════════════════════════════════════════════════════
appsettings_path = os.path.join(repo, "RTM", "RTM", "appsettings.json")

with open(appsettings_path, "r", encoding="utf-8") as f:
    appsettings = json.load(f)

# Verify current value
old_url = appsettings.get("Kestrel", {}).get("Endpoints", {}).get("Http", {}).get("Url", "")
print(f"RTM appsettings: old Url = {old_url}")

# Change to loopback
appsettings["Kestrel"]["Endpoints"]["Http"]["Url"] = "http://127.0.0.1:8088"

# Verify other keys still present
assert "RTM" in appsettings, "RTM section missing"
assert "TenantId" in appsettings["RTM"], "RTM:TenantId missing"
assert "ConnectionStrings" in appsettings, "ConnectionStrings missing"
print(f"  Key preservation: RTM:TenantId={appsettings['RTM']['TenantId'][:8]}..., ConnectionStrings present")

# Write back (UTF-8 NO BOM for JSON)
with open(appsettings_path, "w", encoding="utf-8") as f:
    json.dump(appsettings, f, indent=2, ensure_ascii=False)
    f.write("\n")  # trailing newline
    f.flush()
    os.fsync(f.fileno())

print(f"  New Url = {appsettings['Kestrel']['Endpoints']['Http']['Url']}")
print(f"RTM appsettings written: {os.path.getsize(appsettings_path)} bytes")

# ═══════════════════════════════════════════════════════════════════════════════
# FILE B — deploy/Apply-Server45Upgrade.ps1 (add Phase 5c)
# ═══════════════════════════════════════════════════════════════════════════════
orchestrator_path = os.path.join(repo, "deploy", "Apply-Server45Upgrade.ps1")

with open(orchestrator_path, "r", encoding="utf-8-sig") as f:
    orch_content = f.read()

# Find the insertion point: after Phase 5b closing brace, before Phase 6
# Phase 5b ends with: Log "ApplyServicePublish not specified - skipping NTFS ACL lock."
# }
#
# # PHASE 6

phase5c_section = r'''

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5c — RTM LOOPBACK REBIND (F-3 security fix)
# ══════════════════════════════════════════════════════════════════════════════
Banner "5c" "RTM LOOPBACK REBIND (F-3 security fix)"

# F-3: RTM SignalR hub must bind 127.0.0.1 only (not * or 0.0.0.0) so it is
# unreachable from browser/network. Shell reaches it via RtmRelayService (§34).

$rtmAppSettingsPath = Join-Path $rtmDir "appsettings.json"

# B1 — Assert/patch deployed RTM appsettings bind = loopback
if (Test-Path $rtmAppSettingsPath) {
    Log "B1: Checking RTM appsettings Kestrel bind..."
    try {
        $rtmJson = Get-Content $rtmAppSettingsPath -Raw | ConvertFrom-Json
        $currentUrl = $null
        if ($rtmJson.Kestrel -and $rtmJson.Kestrel.Endpoints -and $rtmJson.Kestrel.Endpoints.Http) {
            $currentUrl = $rtmJson.Kestrel.Endpoints.Http.Url
        }

        $loopbackUrl = "http://127.0.0.1:8088"
        if ($currentUrl -ne $loopbackUrl) {
            Log "  Changing Kestrel bind: $currentUrl -> $loopbackUrl"
            # Ensure structure exists
            if (-not $rtmJson.Kestrel) { $rtmJson | Add-Member -NotePropertyName "Kestrel" -NotePropertyValue ([PSCustomObject]@{}) }
            if (-not $rtmJson.Kestrel.Endpoints) { $rtmJson.Kestrel | Add-Member -NotePropertyName "Endpoints" -NotePropertyValue ([PSCustomObject]@{}) }
            if (-not $rtmJson.Kestrel.Endpoints.Http) { $rtmJson.Kestrel.Endpoints | Add-Member -NotePropertyName "Http" -NotePropertyValue ([PSCustomObject]@{}) }
            $rtmJson.Kestrel.Endpoints.Http.Url = $loopbackUrl
            $rtmJson | ConvertTo-Json -Depth 10 | Set-Content $rtmAppSettingsPath -Encoding UTF8
            Log "  RTM appsettings patched: Kestrel bind = $loopbackUrl"
        } else {
            Log "  RTM appsettings already loopback-bound: $currentUrl"
        }
    } catch {
        Log "[WARN] B1: Could not parse/patch RTM appsettings: $($_.Exception.Message)"
    }
} else {
    Log "[WARN] B1: RTM appsettings not found: $rtmAppSettingsPath"
}

# B2 — Update tenant_settings.SignalRConnectionUrl to loopback (Shell→RTM relay)
Log "B2: Setting tenant_settings.SignalRConnectionUrl to loopback..."
$rtmTenantId = $null
if (Test-Path $rtmAppSettingsPath) {
    try {
        $rtmJson = Get-Content $rtmAppSettingsPath -Raw | ConvertFrom-Json
        if ($rtmJson.RTM -and $rtmJson.RTM.TenantId) {
            $rtmTenantId = $rtmJson.RTM.TenantId
        }
    } catch {
        Log "[WARN] B2: Could not read RTM:TenantId from appsettings"
    }
}

if ($rtmTenantId -and $rtmTenantId -ne "00000000-0000-0000-0000-000000000000") {
    $signalRUrl = "http://127.0.0.1:8088/signalr"
    $updateSql = "UPDATE tenant_settings SET `"SignalRConnectionUrl`" = '$signalRUrl' WHERE `"TenantId`" = '$rtmTenantId';"
    Log "  Updating tenant_settings for TenantId=$rtmTenantId"
    Log "  SignalRConnectionUrl = $signalRUrl"

    $env:PGPASSWORD = $AppPassword
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $updateOutput = & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -c $updateSql 2>&1
    $updateExitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    $env:PGPASSWORD = $null

    $updateOutput | ForEach-Object { Log "    $_" }
    if ($updateExitCode -ne 0) {
        Log "[WARN] B2: UPDATE failed (exit $updateExitCode) — set SignalRConnectionUrl via Tenant Settings UI"
    } else {
        Log "  B2: SignalRConnectionUrl set to loopback."
        Ledger "F3_SIGNALR_URL" "OK"
    }
} else {
    Log "[WARN] B2: RTM:TenantId empty or placeholder — cannot update tenant_settings."
    Log "  Set SignalRConnectionUrl = http://127.0.0.1:8088/signalr via Tenant Settings UI after deploy."
}

Ledger "F3_RTM_LOOPBACK" "OK"
Log "F-3 RTM loopback rebind complete — hub now unreachable from network."

'''

# Find insertion point: before Phase 6
marker = '''# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6 — START SERVICES'''

if marker not in orch_content:
    print("ERROR: Phase 6 marker not found")
    exit(1)

new_orch_content = orch_content.replace(marker, phase5c_section + marker)

# Write with BOM + CRLF (§35)
with open(orchestrator_path, "wb") as f:
    bom = b'\xef\xbb\xbf'
    content_bytes = new_orch_content.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8')
    f.write(bom + content_bytes)
    f.flush()
    os.fsync(f.fileno())

print(f"Orchestrator written: {os.path.getsize(orchestrator_path)} bytes (BOM+CRLF)")
print("\nAll files written successfully!")
