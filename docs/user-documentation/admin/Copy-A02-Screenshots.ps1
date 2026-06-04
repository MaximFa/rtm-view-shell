# Copy A-02 screenshots from Chrome Downloads to project screenshots folder
# Run from PowerShell after Claude captures all screenshots

$downloads = "$env:USERPROFILE\Downloads"
$dest = "C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\docs\user-documentation\admin\screenshots"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

$files = @(
  "a02_sc01_user_list.jpg",
  "a02_sc02_new_user_modal.jpg",
  "a02_sc03_edit_user_modal.jpg",
  "a02_sc04_pg_list.jpg",
  "a02_sc05_pg_menu_tab.jpg",
  "a02_sc06_pg_screens_tab.jpg",
  "a02_sc07_pg_queues_tab.jpg",
  "a02_sc08_pg_bu_tab.jpg",
  "a02_sc09_tenant_list.jpg",
  "a02_sc10_tenant_edit_general.jpg",
  "a02_sc11_tenant_settings_tab.jpg",
  "a02_sc12_tenant_agent_states.jpg",
  "a02_sc13_dashboard_list.jpg",
  "a02_sc14_audit_log.jpg"
)

foreach ($f in $files) {
  $src = Join-Path $downloads $f
  if (Test-Path $src) {
    Copy-Item $src (Join-Path $dest $f) -Force
    Write-Host "Copied: $f"
  } else {
    Write-Host "NOT FOUND: $f"
  }
}

Write-Host ""
Write-Host "Done. Screenshots in: $dest"
