"""
Probe: userset-0924 — CSS cascade analysis for user settings fix
Tests that the skin layer does not override user-defined settings.

Measures presence of conflicting CSS rules in wallboard-skin.css,
QueueGridWidget.razor.css, and AgentGridWidget.razor.css.

Run twice: on HEAD (before) and on working tree (after).
"""

import subprocess
import re

def get_file_content(path, from_head=False):
    if from_head:
        result = subprocess.run(
            ['git', 'show', f'HEAD:{path}'],
            capture_output=True, text=True
        )
        return result.stdout
    else:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()

def analyze_css(content, name):
    results = {}
    
    # Check for problematic patterns
    patterns = {
        'wb-pill': r'\.wb-pill',
        'tr.alert': r'tr\.alert',
        'tr.warnrow': r'tr\.warnrow',
        'nth-child(even)': r'nth-child\(even\)',
        'white-space': r'white-space',
        'font-size on td': r'\.wb-skin\s+td\s*\{[^}]*font-size',
        'font-size on th': r'\.wb-skin\s+th\s*\{[^}]*font-size',
        'background on th': r'\.wb-skin\s+th\s*\{[^}]*background',
        'color on th': r'\.wb-skin\s+th\s*\{[^}]*color:',
        'thead background': r'queue-grid-thead\s*\{[^}]*background',
    }
    
    for key, pattern in patterns.items():
        matches = re.findall(pattern, content, re.DOTALL | re.IGNORECASE)
        results[key] = len(matches)
    
    return results

def main():
    files = [
        'src/CcDashboard.Web/wwwroot/css/widgets/wallboard-skin.css',
        'src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css',
        'src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor.css',
    ]
    
    print("=" * 60)
    print("PROBE: userset-0924 — Before (HEAD)")
    print("=" * 60)
    
    for path in files:
        content = get_file_content(path, from_head=True)
        results = analyze_css(content, path)
        print(f"\n{path}:")
        for key, count in results.items():
            if count > 0:
                print(f"  {key}: {count}")
    
    print("\n" + "=" * 60)
    print("PROBE: userset-0924 — After (working tree)")
    print("=" * 60)
    
    for path in files:
        content = get_file_content(path, from_head=False)
        results = analyze_css(content, path)
        print(f"\n{path}:")
        for key, count in results.items():
            if count > 0:
                print(f"  {key}: {count}")
        if all(v == 0 for v in results.values()):
            print("  (all problematic patterns removed)")

if __name__ == '__main__':
    main()