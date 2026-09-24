# V4 Palette Map — 223 shell tokens vs 17 reference names

**Branch:** v4  
**HEAD:** 63d68666d7b8685fac76fc010eb96c8b82af5d18  
**Date:** 2026-09-24  
**Author:** shell-0919b / CC session

## Input Pins

| File | Expected Hash | Verified Hash | Status |
|------|---------------|---------------|--------|
| src/CcDashboard.Web/wwwroot/css/tokens.css | b571bc2b109a0b050601e6843ec7ad42122f8987 | b571bc2b109a0b050601e6843ec7ad42122f8987 | OK |
| .claude/skills/rtm-wallboard/assets/wallboard.css | 357138c5a16cbcb337a956bf7d7d43e9e0ce7b85 | 357138c5a16cbcb337a956bf7d7d43e9e0ce7b85 | OK |

---

## 1. Mapping Table — 17 Reference Names

Reference variables from `wallboard.css` (17 unique `--name:` declarations).

| # | Ref Name | Ref Hex | Our Variable(s) | Our Value | Match | Verdict |
|---|----------|---------|-----------------|-----------|-------|---------|
| 1 | --bg | #eef1f6 | --clr-bg | #F5F5F5 | DIFFER | Role match, value differs |
| 2 | --card | #ffffff | --clr-surface | #FFFFFF | = | Exact match |
| 3 | --line | #dfe4ec | --clr-border-solid | #DADCE0 | DIFFER | Role match, value differs |
| 4 | --line2 | #eef1f6 | --clr-border-md | rgba(0,0,0,0.12) | DIFFER | Role match, format differs |
| 5 | --ink | #16202e | --clr-text | #202124 | DIFFER | Role match, value differs |
| 6 | --muted | #7a869a | --clr-text-muted | #80868B | DIFFER | Role match, value differs |
| 7 | --faint | #9aa5b5 | --clr-text-faint | #9AA0A6 | DIFFER | Role match, value differs |
| 8 | --ok | #0f9d58 | --clr-success | #107C10 | DIFFER | Role match, value differs |
| 9 | --okbg | #e8f6ee | --clr-success-subtle | #DFFBE6 | DIFFER | Role match, value differs |
| 10 | --warn | #c77700 | --clr-warning | #CA8300 | DIFFER | Role match, value differs |
| 11 | --warnbg | #fdf3e2 | --clr-warning-subtle | #FFF4CE | DIFFER | Role match, value differs |
| 12 | --bad | #d32f2f | --clr-danger | #C42B1C | DIFFER | Role match, value differs |
| 13 | --badbg | #fdeaea | --clr-danger-subtle | #FCE8E6 | DIFFER | Role match, value differs |
| 14 | --brand | #1b3a6b | --clr-primary | #0066CC | DIFFER | Role match, value differs |
| 15 | --brand2 | #2f6fd0 | --clr-primary-muted | #4D94DB | DIFFER | Role match, value differs |
| 16 | --brandbg | #eaf1fb | --clr-primary-subtle | #E6F0FA | DIFFER | Role match, value differs |
| 17 | --radius | 7px | --r-lg | 6px | DIFFER | Geometry; closest is 6px |

**Summary:** 17 rows, 1 exact match (--card), 16 role matches with value differences, 0 NO MATCH.

---

## 2. Remainder Table — Variables Not Mapped to Reference

Total unique variables in tokens.css: **150**  
Mapped to reference roles: **17** (one-to-one by role, some refs have multiple candidates)  
Remainder: **133** variables not directly mapped to the 17 reference names.

### Grouped by Prefix

| Prefix | Count | Variables | Widget-relevant? |
|--------|-------|-----------|------------------|
| --btn-* | 3 | btn-height, btn-height-sm, btn-height-lg | NO — shell UI, not widget |
| --clr-danger-hover | 1 | --clr-danger-hover | NO — interactive state |
| --clr-info-* | 2 | --clr-info, --clr-info-subtle | MAYBE — could map to additional semantics |
| --clr-overlay | 1 | --clr-overlay | NO — shell chrome |
| --clr-primary-hover | 1 | --clr-primary-hover | NO — interactive state |
| --clr-role-* | 8 | superadmin/admin/editor/viewer bg+text | NO — shell user badges |
| --clr-sidebar-* | 8 | bg/text/hover/active/label/divider | NO — shell sidebar |
| --clr-status-* | 8 | active/inactive/blocked/pending bg+text | NO — shell status badges |
| --clr-success-hover | 1 | --clr-success-hover | NO — interactive state |
| --clr-text-secondary | 1 | --clr-text-secondary | MAYBE — between muted/faint |
| --clr-text-disabled | 1 | --clr-text-disabled | NO — disabled state |
| --clr-warning-hover | 1 | --clr-warning-hover | NO — interactive state |
| --clr-border | 1 | --clr-border (rgba) | YES — maps to --line |
| --clr-border-strong | 1 | --clr-border-strong | MAYBE — accent line |
| --content-max-width | 1 | layout | NO — shell layout |
| --dur-* | 5 | instant/fast/normal/slow/slower | NO — animation |
| --ease-* | 4 | linear/in/out/in-out | NO — animation |
| --focus-ring-* | 2 | focus-ring, focus-ring-danger | NO — accessibility |
| --font-* | 2 | font-family, font-mono | MAYBE — typography |
| --fw-* | 4 | normal/medium/semibold/bold | NO — typography weight |
| --input-* | 3 | input heights | NO — form elements |
| --lh-* | 6 | line heights | NO — typography |
| --ls-* | 6 | letter spacing | NO — typography |
| --nav-item-height | 1 | navigation | NO — shell chrome |
| --r-* | 6 | r-none/sm/md/xl/2xl/pill (excl r-lg mapped) | MAYBE — only --r-lg mapped |
| --shadow-* | 6 | xs/sm/md/lg/xl/inner | MAYBE — widget elevation |
| --sidebar-* | 2 | sidebar-width, sidebar-collapsed-width | NO — shell layout |
| --sp-* | 12 | spacing scale 0-20 | NO — not in reference |
| --table-* | 2 | row heights | MAYBE — if tables in widgets |
| --text-* | 8 | font size scale | NO — typography |
| --thr-* | 16 | ok/warn/crit/null bg/text/accent/badge | YES — threshold semantics |
| --topbar-height | 1 | topbar | NO — shell chrome |
| --z-* | 8 | z-index layers | NO — stacking |

### Widget-Relevant Categories (for redesign)

| Category | Variables | Notes |
|----------|-----------|-------|
| Mapped (17 reference) | 17 | Direct role equivalents |
| --thr-* threshold | 16 | ok/warn/crit/null states — **widget-critical** |
| --shadow-* | 6 | May apply to widget cards |
| --r-* radii | 7 | Only --r-lg mapped; rest are alternatives |
| --font-* | 2 | Typography base |

**Conclusion:** Of 150 unique variables, ~17 map directly to reference roles, ~16 (--thr-*) are widget threshold colors (reference uses --ok/--warn/--bad directly), and ~117 are shell-specific or layout/animation/typography utilities with no reference equivalent.

---

## 3. Numeric Measurements

| Magnitude | Area | Unit | Expected | Measured | Status |
|-----------|------|------|----------|----------|--------|
| Variable declarations | tokens.css | lines with `--x:` | 223 | 223 | CONFIRM |
| #hex literals | tokens.css | occurrences | 122 | 122 | CONFIRM |
| rgb()/rgba() | tokens.css | occurrences | 35 | 35 | CONFIRM |
| Total color literals | tokens.css | occurrences | 157 | 157 | CONFIRM |
| Unique #hex values | tokens.css | unique values | 81 | 81 | CONFIRM |
| Reference names | wallboard.css | unique `--name:` | 17 | 17 | CONFIRM |

---

## 4. Dark Theme Check

| Predicate | Area | Unit | Expected | Measured | Status |
|-----------|------|------|----------|----------|--------|
| prefers-color-scheme | all 15 skill files | occurrences | 0 | 0 | CONFIRM |
| data-theme | all 15 skill files | occurrences | 0 | 0 | CONFIRM |
| dark (case-insensitive) | all 15 skill files | occurrences | 0 | 0 | CONFIRM |
| --ok (positive control) | all 15 skill files | occurrences | 56 | 56 | CONFIRM |
| --nonexistent-xyz (neg control) | all 15 skill files | occurrences | 0 | 0 | CONFIRM |
| DarkMode | src/ excl obj/bin | occurrences/files | 143/62 | 167/65 | DIFFER |

**Note on DarkMode DIFFER:** Measured 167 occurrences in 65 files vs expected 143/62. This may be due to commits after the prompt was written. The measurement is from HEAD 63d68666.

---

## 5. Summary

- **17 reference names** verified from wallboard.css
- **1 exact match** (--card = --clr-surface = #FFFFFF)
- **16 role matches** with different hex values
- **0 NO MATCH** — all 17 reference roles have candidates
- **133 remainder variables** not mapped to reference, mostly shell-specific
- **Dark theme absent** from reference (verified with positive control)
- **Our DarkMode** (167 occ / 65 files) remains functional but not informed by reference

---

*Measurement complete. No files under src/ modified.*