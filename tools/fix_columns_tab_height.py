#!/usr/bin/env python3
"""Remove fixed-height scroll boxes from widget configurator modals."""
import os

# Fix 1 & 2: ScreenEditorPage.razor
razor_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(razor_path, "r", encoding="utf-8") as f:
    razor_text = f.read()

# Fix 1: columns-table-body height
old1 = '<div class="columns-table-body" style="height: 400px; overflow-y: scroll;" @onscroll="CloseMetricDropdown">'
new1 = '<div class="columns-table-body" @onscroll="CloseMetricDropdown">'
if old1 not in razor_text:
    print("ERROR: Fix 1 pattern not found")
    exit(1)
razor_text = razor_text.replace(old1, new1)

# Fix 2: score-formula-list max-height
old2 = '<div class="score-formula-list border rounded p-2" style="max-height: 300px; overflow-y: auto;">'
new2 = '<div class="score-formula-list border rounded p-2">'
if old2 not in razor_text:
    print("ERROR: Fix 2 pattern not found")
    exit(1)
razor_text = razor_text.replace(old2, new2)

with open(razor_path, "w", encoding="utf-8") as f:
    f.write(razor_text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed ScreenEditorPage.razor ({len(razor_text.splitlines())} lines)")

# Fix 3 & 4: app.css
css_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\wwwroot\app.css"
with open(css_path, "r", encoding="utf-8") as f:
    css_text = f.read()

# Fix 3: .columns-table-body - remove padding-bottom: 200px
old3 = '''.columns-table-body {
    border: 1px solid var(--clr-border);
    border-radius: var(--r-md);
    overflow-x: hidden;
    padding-bottom: 200px;
}'''
new3 = '''.columns-table-body {
    border: 1px solid var(--clr-border);
    border-radius: var(--r-md);
    overflow-x: hidden;
}'''
if old3 not in css_text:
    print("ERROR: Fix 3 pattern not found")
    exit(1)
css_text = css_text.replace(old3, new3)

# Fix 4: .columns-tab - remove min-height: 350px
old4 = '''.columns-tab {
    min-height: 350px;
    overflow-x: hidden;
}'''
new4 = '''.columns-tab {
    overflow-x: hidden;
}'''
if old4 not in css_text:
    print("ERROR: Fix 4 pattern not found")
    exit(1)
css_text = css_text.replace(old4, new4)

with open(css_path, "w", encoding="utf-8") as f:
    f.write(css_text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed app.css ({len(css_text.splitlines())} lines)")
