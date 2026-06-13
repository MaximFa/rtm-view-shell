#!/usr/bin/env python3
"""Insert Phase 5b NTFS ACL section into Apply-Server45Upgrade.ps1"""
import os

script_path = r"D:\Claude\Projects\RTM View Shell\deploy\Apply-Server45Upgrade.ps1"

# Read current content
with open(script_path, "r", encoding="utf-8-sig") as f:
    content = f.read()

# The marker where we insert Phase 5b (before Phase 6)
marker = """# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6 — START SERVICES"""

# Phase 5b section to insert
phase5b = r'''
# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5b — NTFS ACL LOCK (F-4 integrity anchor)
# ══════════════════════════════════════════════════════════════════════════════
Banner "5b" "NTFS ACL LOCK (F-4 integrity anchor)"

# F-4 defense-in-depth: lock PackageMigrationsDir + ManifestPath so tampering requires admin.
# Combined with F-4 hash-check in ApplyService = real migration integrity.

if ($ApplyServicePublish) {
    $applyDir = Join-Path $InstallRoot "ApplyService"
    $applyAppSettings = Join-Path $applyDir "appsettings.json"

    # Read configured paths from appsettings.json
    $pkgMigDir = $null
    $manifestPath = $null
    if (Test-Path $applyAppSettings) {
        try {
            $applyJson = Get-Content $applyAppSettings -Raw | ConvertFrom-Json
            $pkgMigDir = $applyJson.PackageMigrationsDir
            $manifestPath = $applyJson.ManifestPath
        } catch {
            Log "[WARN] Could not parse ApplyService appsettings.json for paths"
        }
    }

    # Default paths if not configured
    if (-not $pkgMigDir) { $pkgMigDir = Join-Path $InstallRoot "Packages\migrations" }
    if (-not $manifestPath) { $manifestPath = Join-Path $InstallRoot "Packages\manifest.json" }

    Log "Locking paths for F-4 integrity:"
    Log "  PackageMigrationsDir: $pkgMigDir"
    Log "  ManifestPath: $manifestPath"

    # Ensure the target directories exist
    if (-not (Test-Path $pkgMigDir)) {
        New-Item -ItemType Directory -Path $pkgMigDir -Force | Out-Null
        Log "  Created directory: $pkgMigDir"
    }
    $manifestDir = Split-Path $manifestPath -Parent
    if ($manifestDir -and -not (Test-Path $manifestDir)) {
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        Log "  Created directory: $manifestDir"
    }

    # icacls command pattern:
    # - Remove inheritance: /inheritance:r
    # - Grant SYSTEM full: /grant:r "SYSTEM:(OI)(CI)F"
    # - Grant Administrators full: /grant:r "Administrators:(OI)(CI)F"
    # - Grant service account read+execute: /grant:r "$ApplySvcName:(OI)(CI)RX"
    # - Remove Users and Authenticated Users (no write for non-admins)

    # Apply ACL to PackageMigrationsDir
    Log "  Applying ACL to PackageMigrationsDir..."
    $aclOutput = & icacls $pkgMigDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F" /grant:r "${ApplySvcName}:(OI)(CI)RX" 2>&1
    $aclOutput | ForEach-Object { Log "    $_" }
    & icacls $pkgMigDir /remove:g "Users" 2>&1 | Out-Null
    & icacls $pkgMigDir /remove:g "Authenticated Users" 2>&1 | Out-Null
    Log "  ACL applied to PackageMigrationsDir."

    # Apply ACL to ManifestPath (file or parent dir if file doesn't exist yet)
    if (Test-Path $manifestPath) {
        Log "  Applying ACL to ManifestPath (file)..."
        $aclOutput = & icacls $manifestPath /inheritance:r /grant:r "SYSTEM:F" /grant:r "Administrators:F" /grant:r "${ApplySvcName}:RX" 2>&1
        $aclOutput | ForEach-Object { Log "    $_" }
        & icacls $manifestPath /remove:g "Users" 2>&1 | Out-Null
        & icacls $manifestPath /remove:g "Authenticated Users" 2>&1 | Out-Null
        Log "  ACL applied to ManifestPath."
    } else {
        Log "  ManifestPath file does not exist yet - applying ACL to parent directory..."
        if ($manifestDir -and (Test-Path $manifestDir)) {
            $aclOutput = & icacls $manifestDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" /grant:r "Administrators:(OI)(CI)F" /grant:r "${ApplySvcName}:(OI)(CI)RX" 2>&1
            $aclOutput | ForEach-Object { Log "    $_" }
            & icacls $manifestDir /remove:g "Users" 2>&1 | Out-Null
            & icacls $manifestDir /remove:g "Authenticated Users" 2>&1 | Out-Null
            Log "  ACL applied to manifest directory (files inherit)."
        }
    }

    # Log final ACLs for audit
    Log "  Final ACL verification:"
    Log "    PackageMigrationsDir:"
    & icacls $pkgMigDir 2>&1 | ForEach-Object { Log "      $_" }
    if (Test-Path $manifestPath) {
        Log "    ManifestPath:"
        & icacls $manifestPath 2>&1 | ForEach-Object { Log "      $_" }
    } elseif ($manifestDir -and (Test-Path $manifestDir)) {
        Log "    ManifestDir (parent):"
        & icacls $manifestDir 2>&1 | ForEach-Object { Log "      $_" }
    }

    Ledger "NTFS_ACL_LOCK" "OK"
    Log "F-4 NTFS ACL lock complete - tampering requires Administrator."
} else {
    Log "ApplyServicePublish not specified - skipping NTFS ACL lock."
}


'''

# Insert Phase 5b before Phase 6
if marker not in content:
    print("ERROR: Phase 6 marker not found")
    exit(1)

new_content = content.replace(marker, phase5b + marker)

# Write with fsync
with open(script_path, "w", encoding="utf-8-sig", newline="\r\n") as f:
    f.write(new_content)
    f.flush()
    os.fsync(f.fileno())

print(f"Written {len(new_content)} chars, {new_content.count(chr(10))+1} lines")
