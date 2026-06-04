const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, HeadingLevel, LevelFormat, BorderStyle,
  WidthType, ShadingType, VerticalAlign, PageNumber, PageBreak,
  TableOfContents
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── Screenshot file mapping ────────────────────────────────────────────────────
// Maps each placeholder label to { file, width, height } (width/height in px)
const SCREENSHOTS_DIR = "/sessions/tender-ecstatic-bardeen/mnt/RTM View Shell/docs/user-documentation/user/screenshots";
const screenshotMap = {
  // ── Original widget previews ──────────────────────────────────────────────
  "Sidebar navigation — Screens highlighted":                        { file: "sc01_sidebar.jpg",           width: 130,  height: 430  },
  "Screen Editor — header bar, widget palette, and canvas":          { file: "sc_editor.jpg",              width: 540,  height: 240  },
  "Agent Grid widget — live agent table with coloured thresholds":   { file: "sc03_agent_grid.jpg",        width: 540,  height: 360  },
  "Queue Grid widget — live queue metrics table":                    { file: "sc04_queue_grid.jpg",        width: 540,  height: 300  },
  "Data Slot widget — single KPI value with target indicator":       { file: "sc08_data_slot.jpg",         width: 260,  height: 180  },
  "Day Trend widget — intraday line chart with multiple metric series": { file: "sc05_day_trend.jpg",      width: 540,  height: 340  },
  "Call Metrics tab — list of metrics with enable toggles and colour pickers": { file: "sc_daytrend_callmetrics.jpg", width: 450, height: 470 },
  "Agent State Distribution — doughnut chart showing agent state breakdown": { file: "sc06_agent_state_dist.jpg", width: 460, height: 355 },
  "Info Slot widget — scrolling ticker with priority message":        { file: "sc07_info_slot.jpg",         width: 460,  height: 260  },
  // ── Section screenshots ─────────────────────────────────────────────────────
  "Screen list — all dashboards with columns and status badges":      { file: "sc_screen_list.jpg",         width: 540,  height: 255  },
  "Trash tab — soft-deleted screens with days-remaining badges":     { file: "sc_trash_tab.jpg",           width: 540,  height: 255  },
  "New Dashboard modal — name, description, category, IsPublic":     { file: "sc_new_dashboard.jpg",       width: 480,  height: 483  },
  "Screen Settings modal — edit fields and danger zone":             { file: "sc_settings_modal.jpg",      width: 300,  height: 325  },
  "Screen Editor header bar — status, publish and save controls":    { file: "sc_editor_header.jpg",       width: 550,  height: 16   },
  "Widget palette — available widgets grouped by category":          { file: "sc_widget_palette.jpg",      width: 150,  height: 446  },
  "Canvas area — live widgets in edit mode":                         { file: "sc_editor_canvas.jpg",       width: 540,  height: 242  },
  "Publishing — Publish / Unpublish button and status badge":        { file: "sc_publishing.jpg",          width: 550,  height: 40   },
  // ── Agent Grid tabs ──────────────────────────────────────────────────────────────
  "Agent Grid — General tab":                                        { file: "sc_agrid_general.jpg",       width: 400,  height: 421  },
  "Agent Grid — Appearance tab":                                     { file: "sc_agrid_appearance.jpg",    width: 400,  height: 421  },
  "Agent Grid — Thresholds tab":                                     { file: "sc_agrid_thresholds.jpg",    width: 400,  height: 421  },
  "Agent Grid — Filters tab":                                        { file: "sc_agrid_filters.jpg",       width: 400,  height: 421  },
  "Agent Grid — Columns tab":                                        { file: "sc_agrid_columns.jpg",       width: 400,  height: 421  },
  "Agent Grid — Score tab":                                          { file: "sc_agrid_score.jpg",         width: 400,  height: 421  },
  // ── Queue Grid tabs ──────────────────────────────────────────────────────────────
  "Queue Grid — General tab":                                        { file: "sc_qgrid_general.jpg",       width: 400,  height: 421  },
  "Queue Grid — Appearance tab":                                     { file: "sc_qgrid_appearance.jpg",    width: 400,  height: 421  },
  "Queue Grid — Thresholds tab":                                     { file: "sc_qgrid_thresholds.jpg",    width: 400,  height: 421  },
  "Queue Grid — Rows tab":                                           { file: "sc_qgrid_rows.jpg",          width: 400,  height: 421  },
  "Queue Grid — Queue Columns tab":                                  { file: "sc_qgrid_queue_columns.jpg", width: 400,  height: 421  },
  // ── Data Slot tabs ───────────────────────────────────────────────────────────────
  "Data Slot — General tab":                                         { file: "sc_dataslot_general.jpg",    width: 400,  height: 421  },
  "Data Slot — Appearance tab":                                      { file: "sc_dataslot_appearance.jpg", width: 400,  height: 421  },
  "Data Slot — Thresholds tab":                                      { file: "sc_dataslot_thresholds.jpg", width: 400,  height: 421  },
  // ── Day Trend tabs ───────────────────────────────────────────────────────────────
  "Day Trend — General tab":                                         { file: "sc_daytrend_general.jpg",    width: 400,  height: 421  },
  "Day Trend — Appearance tab":                                      { file: "sc_daytrend_appearance.jpg", width: 400,  height: 421  },
  "Day Trend — Call Metrics tab":                                    { file: "sc_daytrend_callmetrics.jpg", width: 400,  height: 421  },
  "Day Trend — Agent Metrics tab":                                   { file: "sc_daytrend_agentmetrics.jpg", width: 400,  height: 421  },
  // ── Agent State Distribution tabs ──────────────────────────────────────────────────────────────
  "Agent State Distribution — General tab":                          { file: "sc_agentstate_general.jpg",  width: 400,  height: 421  },
  "Agent State Distribution — Appearance tab":                       { file: "sc_agentstate_appearance.jpg", width: 400,  height: 421  },
  // ── Info Slot tabs ───────────────────────────────────────────────────────────────
  "Info Slot — General tab":                                         { file: "sc_infoslot_general.jpg",    width: 400,  height: 421  },
  "Info Slot — Appearance tab":                                      { file: "sc_infoslot_appearance.jpg", width: 400,  height: 421  },
};

// ── Colours ────────────────────────────────────────────────────────────────────
const C = {
  blue:       "1B3E6F",
  lightBlue:  "D0E4F7",
  teal:       "2980B9",
  headBg:     "1B3E6F",
  rowAlt:     "F2F7FC",
  border:     "C0CDD8",
  noteYellow: "FFF8DC",
  noteBlue:   "EBF5FB",
  white:      "FFFFFF",
  grey:       "888888",
  darkText:   "1A1A1A",
  orange:     "E67E22",
  green:      "1E8449",
};

// ── Borders ────────────────────────────────────────────────────────────────────
const bdr  = { style: BorderStyle.SINGLE, size: 1, color: C.border };
const bdrH = { style: BorderStyle.SINGLE, size: 2, color: C.blue };
const borders     = { top: bdr,  bottom: bdr,  left: bdr,  right: bdr  };
const bordersHead = { top: bdrH, bottom: bdrH, left: bdrH, right: bdrH };

// ── Helpers ────────────────────────────────────────────────────────────────────
function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    pageBreakBefore: true,
    children: [new TextRun({ text, font: "Arial", size: 36, bold: true, color: C.blue })],
    spacing: { before: 240, after: 200 },
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    children: [new TextRun({ text, font: "Arial", size: 28, bold: true, color: C.blue })],
    spacing: { before: 200, after: 120 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: C.lightBlue } },
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    children: [new TextRun({ text, font: "Arial", size: 24, bold: true, color: C.teal })],
    spacing: { before: 160, after: 80 },
  });
}
function h4(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_4,
    children: [new TextRun({ text, font: "Arial", size: 22, bold: true, color: C.darkText })],
    spacing: { before: 120, after: 60 },
  });
}
function p(text, opts = {}) {
  return new Paragraph({
    children: [new TextRun({ text, font: "Arial", size: 22, color: C.darkText, ...opts })],
    spacing: { before: 60, after: 80 },
  });
}
function note(text) {
  return new Table({
    width: { size: 9026, type: WidthType.DXA },
    columnWidths: [9026],
    rows: [new TableRow({ children: [new TableCell({
      shading: { fill: "EBF5FB", type: ShadingType.CLEAR },
      borders: { top: { style: BorderStyle.SINGLE, size: 3, color: C.teal },
                 bottom: bdr, left: { style: BorderStyle.SINGLE, size: 3, color: C.teal }, right: bdr },
      width: { size: 9026, type: WidthType.DXA },
      margins: { top: 100, bottom: 100, left: 160, right: 160 },
      children: [new Paragraph({ children: [
        new TextRun({ text: "ℹ  ", font: "Arial", size: 22, bold: true, color: C.teal }),
        new TextRun({ text, font: "Arial", size: 22, color: C.darkText }),
      ], spacing: { before: 40, after: 40 } })]
    })]})],
  });
}
function warning(text) {
  return new Table({
    width: { size: 9026, type: WidthType.DXA },
    columnWidths: [9026],
    rows: [new TableRow({ children: [new TableCell({
      shading: { fill: "FEF9E7", type: ShadingType.CLEAR },
      borders: { top: { style: BorderStyle.SINGLE, size: 3, color: C.orange },
                 bottom: bdr, left: { style: BorderStyle.SINGLE, size: 3, color: C.orange }, right: bdr },
      width: { size: 9026, type: WidthType.DXA },
      margins: { top: 100, bottom: 100, left: 160, right: 160 },
      children: [new Paragraph({ children: [
        new TextRun({ text: "⚠  ", font: "Arial", size: 22, bold: true, color: C.orange }),
        new TextRun({ text, font: "Arial", size: 22, color: C.darkText }),
      ], spacing: { before: 40, after: 40 } })]
    })]})],
  });
}
function screenshot(label) {
  const meta = screenshotMap[label];
  if (meta) {
    const imgPath = path.join(SCREENSHOTS_DIR, meta.file);
    if (fs.existsSync(imgPath)) {
      return new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 100, after: 100 },
        children: [new ImageRun({
          data: fs.readFileSync(imgPath),
          transformation: { width: meta.width, height: meta.height },
          type: "jpg",
        })],
      });
    }
  }
  // Fallback: grey placeholder box
  return new Table({
    width: { size: 9026, type: WidthType.DXA },
    columnWidths: [9026],
    rows: [new TableRow({ children: [new TableCell({
      shading: { fill: "F5F5F5", type: ShadingType.CLEAR },
      borders,
      width: { size: 9026, type: WidthType.DXA },
      margins: { top: 200, bottom: 200, left: 200, right: 200 },
      children: [new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: `[Screenshot: ${label}]`, font: "Arial", size: 20, italics: true, color: C.grey })],
      })]
    })]})],
  });
}
function bullet(text, level = 0) {
  return new Paragraph({
    numbering: { reference: "bullets", level },
    children: [new TextRun({ text, font: "Arial", size: 22, color: C.darkText })],
    spacing: { before: 40, after: 40 },
  });
}
function numbered(text, level = 0) {
  return new Paragraph({
    numbering: { reference: "numbers", level },
    children: [new TextRun({ text, font: "Arial", size: 22, color: C.darkText })],
    spacing: { before: 40, after: 40 },
  });
}
function spacer() {
  return new Paragraph({ children: [new TextRun("")], spacing: { before: 60, after: 60 } });
}

// ── Table builders ─────────────────────────────────────────────────────────────
function makeTable(colWidths, headers, rows) {
  function cell(text, isHead, colIdx, rowIdx) {
    const fill = isHead ? C.headBg : (rowIdx % 2 === 0 ? C.white : C.rowAlt);
    return new TableCell({
      shading: { fill, type: ShadingType.CLEAR },
      borders: isHead ? bordersHead : borders,
      width: { size: colWidths[colIdx], type: WidthType.DXA },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      verticalAlign: VerticalAlign.CENTER,
      children: [new Paragraph({
        children: [new TextRun({ text, font: "Arial", size: 20, bold: isHead, color: isHead ? C.white : C.darkText })],
        spacing: { before: 0, after: 0 },
      })],
    });
  }
  return new Table({
    width: { size: colWidths.reduce((a,b)=>a+b,0), type: WidthType.DXA },
    columnWidths: colWidths,
    rows: [
      new TableRow({ children: headers.map((h, i) => cell(h, true, i, 0)), tableHeader: true }),
      ...rows.map((row, ri) => new TableRow({ children: row.map((val, ci) => cell(val, false, ci, ri)) }))
    ],
  });
}

// Parameter table: 3 columns [Parameter, Description, Options / Example]
function paramTable(rows) {
  return makeTable([2200, 4200, 2626], ["Parameter", "Description", "Options / Example"], rows);
}

// Tab badge — a grey-ish highlighted label
function tabLabel(text) {
  return new Paragraph({
    children: [
      new TextRun({ text: "  Tab: ", font: "Arial", size: 20, bold: true, color: C.white }),
      new TextRun({ text: ` ${text} `, font: "Arial", size: 20, bold: true, color: C.white }),
    ],
    shading: { fill: C.teal, type: ShadingType.CLEAR },
    spacing: { before: 120, after: 80 },
    indent: { left: 0 },
  });
}

// ── Document sections content ──────────────────────────────────────────────────

const docContent = [

  // ── TITLE ──────────────────────────────────────────────────────────────────
  new Paragraph({
    children: [new TextRun({ text: "RTM View Shell", font: "Arial", size: 56, bold: true, color: C.blue })],
    alignment: AlignmentType.CENTER, spacing: { before: 600, after: 120 },
  }),
  new Paragraph({
    children: [new TextRun({ text: "B-02  |  Dashboard Management", font: "Arial", size: 36, color: C.teal })],
    alignment: AlignmentType.CENTER, spacing: { before: 0, after: 80 },
  }),
  new Paragraph({
    children: [new TextRun({ text: "User Guide", font: "Arial", size: 32, italics: true, color: C.grey })],
    alignment: AlignmentType.CENTER, spacing: { before: 0, after: 400 },
  }),
  makeTable([1800, 3600, 3626],
    ["Field", "Value", "Notes"],
    [
      ["Document ID",    "B-02",           "Dashboard Management User Guide"],
      ["Version",        "1.3",            "Added Widget Configuration Reference"],
      ["Date",           "2026-05-29",     ""],
      ["Prepared by",    "RTM View Shell", ""],
      ["Audience",       "All users",      "Editors, Administrators, Viewers"],
      ["Language",       "English",        ""],
    ]
  ),
  spacer(),

  // ── REVISION HISTORY ──────────────────────────────────────────────────────
  h1("1. Revision History"),
  makeTable([800, 1400, 2400, 4426],
    ["Ver.", "Date", "Author", "Change"],
    [
      ["1.0", "2026-05-28", "Documentation team", "Initial release"],
      ["1.1", "2026-05-29", "Documentation team", "Added Section 9: Widget Configuration Reference (all tabs, all parameters for all 6 widgets)"],
      ["1.3", "2026-05-30", "Documentation team", "Added screenshots for all sections and widget configuration tabs"],
    ]
  ),
  spacer(),

  // ── TOC ──────────────────────────────────────────────────────────────────
  h1("2. Contents"),
  new TableOfContents("Table of Contents", {
    hyperlink: true,
    headingStyleRange: "1-4",
    stylesWithLevels: [{ styleName: "Heading1", level: 1 }, { styleName: "Heading2", level: 2 }, { styleName: "Heading3", level: 3 }],
  }),
  spacer(),

  // ── 3. INTRODUCTION ──────────────────────────────────────────────────────
  h1("3. Introduction"),
  p("This guide explains how to use the RTM View Shell dashboard (screen) management system. Screens are real-time monitoring dashboards that display live contact centre data through configurable widgets. This document covers creating, editing, and managing screens as well as configuring each available widget type."),
  spacer(),
  h2("3.1 Who This Guide Is For"),
  makeTable([2400, 2400, 4226],
    ["Role", "Access Level", "Capabilities"],
    [
      ["Viewer",        "Read-only",       "View permitted screens and their live data"],
      ["Editor",        "Create / Edit",   "Create and configure screens within their Permission Group"],
      ["Administrator", "Full tenant",     "All Editor capabilities plus user and group management"],
      ["Superadmin",    "All tenants",     "Full system access across all tenants"],
    ]
  ),
  spacer(),

  // ── 4. ACCESSING SCREENS ─────────────────────────────────────────────────
  h1("4. Accessing Screens"),
  p("The main Screens page is accessible from the sidebar navigation. Click Screens in the Content section. The system displays only screens your Permission Group is allowed to view, plus any screen marked as Public."),
  screenshot("Sidebar navigation — Screens highlighted"),
  spacer(),

  // ── 5. SCREEN LIST ───────────────────────────────────────────────────────
  h1("5. Screen List"),
  screenshot("Screen list — all dashboards with columns and status badges"),
  spacer(),
  h2("5.1 List Columns"),
  makeTable([2600, 6426],
    ["Column", "Description"],
    [
      ["Name / Description",   "The screen name (bold) and optional description below it"],
      ["Tenant",               "The tenant that owns this screen (Superadmin view only)"],
      ["Category",             "Organisational category assigned at creation"],
      ["Status",               "Draft (orange) or Published (green) badge"],
      ["Widgets",              "Number of widgets placed on the screen"],
      ["Created",              "Creator name and creation date"],
      ["Updated",              "Last-modified-by name and date"],
      ["Actions",              "Edit settings (✎ pencil) and Delete (🗑 trash) buttons"],
    ]
  ),
  spacer(),
  h2("5.2 Search and Filters"),
  makeTable([2400, 6626],
    ["Control", "Behaviour"],
    [
      ["Search box",       "Full-text search on Name; press Enter to apply"],
      ["Status dropdown",  "Filter to Draft, Published, or All statuses"],
      ["Category dropdown","Filter by screen category"],
      ["Tenant dropdown",  "Superadmin only: filter by tenant"],
    ]
  ),
  note("Pagination is set to 25 rows per page. Use the page controls at the bottom to navigate."),
  spacer(),
  h2("5.3 Trash Tab"),
  p("When soft-delete is enabled (configured by Administrator), deleted screens appear in the Trash tab instead of being permanently removed. Each entry shows a days-remaining badge (red when ≤ 7 days). Use the ↩ Restore button to undelete a screen."),
  screenshot("Trash tab — soft-deleted screens with days-remaining badges"),
  spacer(),

  // ── 6. CREATING A SCREEN ─────────────────────────────────────────────────
  h1("6. Creating a Screen"),
  numbered("Click + New Screen in the top-right corner of the Screen List."),
  numbered("Complete the New Screen form:"),
  spacer(),
  makeTable([2400, 6626],
    ["Field", "Details"],
    [
      ["Name",         "Required. Unique within the tenant. Maximum 200 characters."],
      ["Description",  "Optional. Displayed below the name in the list."],
      ["Category",     "Select a category to organise screens (e.g. Inbound, Outbound, Quality)."],
      ["Is Public",    "If enabled, all authenticated tenant users can view this screen regardless of Permission Group. Editors and higher can toggle this."],
      ["Tenant",       "Superadmin only: choose which tenant to create the screen in."],
    ]
  ),
  screenshot("New Dashboard modal — name, description, category, IsPublic"),
  numbered("Click Create Screen. The editor opens immediately."),
  note("After creation, your Permission Group automatically receives Full access (View + Edit + Delete) to the new screen."),
  spacer(),

  // ── 7. SCREEN SETTINGS ──────────────────────────────────────────────────
  h1("7. Screen Settings"),
  p("Open Screen Settings by clicking the pencil icon on any screen card in the list."),
  makeTable([2400, 6626],
    ["Field", "Details"],
    [
      ["Name",         "Editable. Renaming takes effect immediately after Save."],
      ["Description",  "Editable."],
      ["Category",     "Editable."],
      ["Status",       "Draft ↔ Published. Draft screens are hidden from Viewers."],
      ["Is Public",    "Toggle to share the screen with all tenant users without explicit group assignment."],
      ["Danger Zone",  "Delete screen — requires inline confirmation. If soft-delete is enabled, the screen moves to Trash; otherwise it is permanently removed."],
    ]
  ),
  screenshot("Screen Settings modal — edit fields and danger zone"),
  spacer(),

  // ── 8. SCREEN EDITOR ────────────────────────────────────────────────────
  h1("8. Screen Editor"),
  p("The Screen Editor opens when you click a screen card or immediately after creating a new screen."),
  screenshot("Screen Editor — header bar, widget palette, and canvas"),
  spacer(),
  h2("8.1 Header Bar"),
  makeTable([2400, 6626],
    ["Element", "Description"],
    [
      ["Screen name",        "Displayed at top-left; click Edit Settings to rename"],
      ["Dark mode toggle",   "Switches the editor canvas between light and dark colour themes"],
      ["Add Widget button",  "Opens the widget palette panel on the left"],
      ["Templates button",   "Opens the template library to save or load pre-configured widget sets"],
      ["Save button",        "Saves all layout and configuration changes. Changes are NOT auto-saved."],
      ["Back to list",       "Returns to the Screen List. Unsaved changes are lost."],
    ]
  ),
  screenshot("Screen Editor header bar — status, publish and save controls"),
  spacer(),
  h2("8.2 Widget Palette"),
  p("The palette panel slides in from the left when you click Add Widget. Widgets are grouped by type. Click any widget to add it to the canvas."),
  makeTable([2400, 6626],
    ["Widget", "Category"],
    [
      ["Agent Grid",                 "Agent monitoring — tabular agent status"],
      ["Queue Grid",                 "Queue monitoring — tabular queue metrics"],
      ["Data Slot",                  "Single-metric KPI card"],
      ["Day Trend",                  "Intraday trend chart"],
      ["Agent State Distribution",   "Agent state breakdown chart"],
      ["Info Slot",                  "Scrolling text / ticker panel"],
    ]
  ),
  screenshot("Widget palette — available widgets grouped by category"),
  spacer(),
  h2("8.3 Canvas"),
  p("Widgets on the canvas can be moved, resized, and configured:"),
  bullet("Move — drag the widget header to reposition"),
  bullet("Resize — drag the bottom-right corner handle"),
  bullet("Configure — click the ⚙ gear icon on the widget header to open the configuration modal"),
  bullet("Delete — click the ✕ close button on the widget header; confirm in the dialog"),
  screenshot("Canvas area — live widgets in edit mode"),
  spacer(),

  // ── 9. WIDGET CONFIGURATION REFERENCE ────────────────────────────────────
  h1("9. Widget Configuration Reference"),
  p("Every widget has a configuration modal with multiple tabs. Open it by clicking the gear icon (⚙) on the widget. Click Save to apply changes; Cancel to discard. The tabs available depend on the widget type, as summarised below."),
  spacer(),
  makeTable([2800, 6226],
    ["Widget", "Available Tabs"],
    [
      ["Agent Grid",               "General, Appearance, Thresholds, Filters, Columns, Score"],
      ["Queue Grid",               "General, Appearance, Thresholds, Rows, Queue Columns"],
      ["Data Slot",                "General, Appearance, Thresholds"],
      ["Day Trend",                "General, Appearance, Call Metrics, Agent Metrics"],
      ["Agent State Distribution", "General, Appearance"],
      ["Info Slot",                "General, Appearance"],
    ]
  ),
  spacer(),
  note("All widgets share the same General and Appearance tabs, though some parameters within those tabs are widget-specific. The sections below document each widget's complete configuration."),
  spacer(),

  // ─── 9.1 AGENT GRID ───────────────────────────────────────────────────────
  h2("9.1 Agent Grid"),
  p("Displays a live table of agents with customisable columns, colour thresholds, row filters, and a performance score indicator. Suitable for supervisor wallboards and quality-monitoring screens."),
  screenshot("Agent Grid widget — live agent table with coloured thresholds"),
  spacer(),

  // General tab
  h3("General Tab"),
  screenshot("Agent Grid — General tab"),
  paramTable([
    ["Widget ID",       "Read-only system identifier for this widget instance.",                          "e.g. 42 (assigned automatically)"],
    ["Grid ID",         "Read-only identifier of the underlying real-time data grid.",                    "e.g. 7 (from RTSGrid)"],
    ["Display Name",    "Label shown in the widget header bar. Edit to override the default name.",       "e.g. \"Sales Team Agents\""],
    ["Business Unit",   "Filters data to agents belonging to the selected Business Unit only.",            "Select from list; leave blank for all BUs"],
  ]),
  spacer(),

  // Appearance tab
  h3("Appearance Tab"),
  screenshot("Agent Grid — Appearance tab"),
  h4("Typography"),
  paramTable([
    ["Font Size",       "Text size for cell content. Values come from the tenant's configured font-size list.", "e.g. 12, 14, 16 (px)"],
  ]),
  spacer(),
  h4("Display Options"),
  paramTable([
    ["Show Avatar",          "Displays a circular avatar with the agent's initials in the first column.",       "On / Off (default: On)"],
    ["Avatar BG Colour",     "Background colour of the avatar circle. Visible only when Show Avatar is On.",    "Colour swatch palette"],
    ["Avatar Text Colour",   "Initials text colour inside the avatar circle.",                                  "Colour swatch palette"],
    ["Show Pagination",      "Adds a pagination bar when the agent list exceeds the widget height.",            "On / Off (default: Off)"],
  ]),
  spacer(),
  h4("Colours — Light Mode and Dark Mode"),
  p("Each colour has a Light Mode and a Dark Mode variant. Dark mode colours apply when the screen editor's dark mode toggle is active."),
  paramTable([
    ["Widget Background",     "Canvas background of the entire widget.",                  "Light: White / Dark: Dark navy"],
    ["Text Colour",           "Default cell text colour.",                                "Light: Dark grey / Dark: White"],
    ["Header Background",     "Background of the column header row.",                     "Light: Steel blue / Dark: Dark blue"],
    ["Header Text Colour",    "Text colour of the column header row.",                    "Light: White / Dark: White"],
    ["Table Background",      "Alternating row background (even rows).",                  "Light: Light grey / Dark: Charcoal"],
  ]),
  spacer(),

  // Thresholds tab
  h3("Thresholds Tab"),
  screenshot("Agent Grid — Thresholds tab"),
  p("Thresholds apply conditional colour formatting to cells based on metric values. Rules are evaluated per column and per cell."),
  numbered("Select a column from the column selector on the left."),
  numbered("Click + Add Rule."),
  numbered("Set the condition and badge colours."),
  spacer(),
  p("Numeric column threshold rule parameters:"),
  paramTable([
    ["From",              "Lower bound of the range (inclusive). Leave blank for no lower bound.",    "e.g. 0"],
    ["To",                "Upper bound of the range (inclusive). Leave blank for no upper bound.",    "e.g. 300"],
    ["Badge Background",  "Cell background colour when the rule matches.",                            "Colour swatch palette"],
    ["Badge Font Colour", "Cell text colour when the rule matches.",                                  "Colour swatch palette"],
  ]),
  spacer(),
  p("Text column threshold rule parameters:"),
  paramTable([
    ["Match Type",        "How the cell value is compared to the match value.",                       "Equal / Not equal / Contains / Starts with / Ends with / Is empty / Is not empty"],
    ["Match Value",       "The string to compare against. Not shown for Is empty / Is not empty.",    "e.g. \"AVAILABLE\""],
    ["Badge Background",  "Cell background colour when the rule matches.",                            "Colour swatch palette"],
    ["Badge Font Colour", "Cell text colour when the rule matches.",                                  "Colour swatch palette"],
  ]),
  note("Multiple rules can be defined per column. Rules are evaluated top-to-bottom; the first matching rule wins."),
  spacer(),
  p("Example — highlight agents on a call in red:"),
  makeTable([2200, 6826],
    ["Setting", "Value"],
    [
      ["Column",          "Status"],
      ["Match Type",      "Equal"],
      ["Match Value",     "ONPHONE"],
      ["Badge Background","#D32F2F (red)"],
      ["Badge Font",      "#FFFFFF (white)"],
    ]
  ),
  spacer(),

  // Filters tab
  h3("Filters Tab"),
  screenshot("Agent Grid — Filters tab"),
  p("Row filters hide agents from the widget display before data is rendered. Filters are evaluated after data arrives from the real-time feed."),
  numbered("Click + Add condition."),
  numbered("Select a Column, an Operator, and enter a Value."),
  numbered("If adding multiple conditions, choose AND (all must match) or OR (any must match) between them."),
  spacer(),
  paramTable([
    ["Column",     "The column to filter on. Populated from the Columns tab.",                           "Select from defined columns"],
    ["Operator",   "Comparison operator for the filter condition.",                                      "Equals / Not equals / Contains / Starts with / Ends with / Is empty / Is not empty"],
    ["Value",      "The value to match against. Hidden when Operator is Is empty or Is not empty.",      "e.g. \"AVAILABLE\""],
    ["Connector",  "Logical connector between consecutive conditions.",                                  "AND / OR"],
  ]),
  note("Filters hide rows from the widget only — they do not affect the underlying data or other widgets. An agent filtered out of one widget will still appear in others."),
  spacer(),
  p("Example — show only Available agents:"),
  makeTable([2200, 6826],
    ["Setting", "Value"],
    [
      ["Column",    "Status"],
      ["Operator",  "Equals"],
      ["Value",     "AVAILABLE"],
    ]
  ),
  spacer(),

  // Columns tab
  h3("Columns Tab"),
  screenshot("Agent Grid — Columns tab"),
  p("Defines which data columns are displayed in the Agent Grid and in which order. The Columns tab also provides the list used by the Filters and Score tabs."),
  numbered("Click + Add Column to create a new column."),
  numbered("Enter a display Name for the column header."),
  numbered("Click the Metric field and search for the metric to bind to this column."),
  numbered("Use the ▲ / ▼ arrow buttons to reorder columns."),
  numbered("Click the trash icon to remove a column."),
  spacer(),
  paramTable([
    ["Name",    "Column header text shown to users.",                      "e.g. \"Status\", \"AHT\", \"Calls Handled\""],
    ["Metric",  "The RTSGrid metric ID that provides live data for this column. Searchable dropdown.", "e.g. AgentStateName, CallsHandled, AHT"],
  ]),
  note("The column list here is shared with the Filters and Score tabs. Columns must be defined before filter conditions or score rules can reference them."),
  spacer(),

  // Score tab
  h3("Score Tab"),
  screenshot("Agent Grid — Score tab"),
  p("Adds a 1–5 star performance score column to the Agent Grid. The score is calculated at the end of each data refresh cycle based on user-defined formula rules."),
  spacer(),
  h4("Enable / Disable"),
  paramTable([
    ["Show Score", "Master switch. When off, the score column is hidden and no calculation is performed.", "On / Off (default: Off)"],
  ]),
  spacer(),
  h4("Star Colour"),
  p("Choose the colour of the star icons from a palette of preset colours. The colour applies to all filled stars."),
  spacer(),
  h4("Score Formula"),
  p("The score formula consists of one or more rules. Each rule specifies a condition; the score equals (number of rules passed / total rules) \xD7 5, rounded to one decimal place."),
  numbered("Click + Add to add a rule."),
  numbered("Select a Column (from the Columns tab)."),
  numbered("Select an Operator."),
  numbered("Enter a Value."),
  numbered("Multiple rules are AND-joined."),
  spacer(),
  paramTable([
    ["Column",    "The metric column to evaluate.",                     "Select from defined columns"],
    ["Operator",  "Comparison operator.",                               "≥ (>=), ≤ (<=), > (>), < (<), == (equal), ≠ (not equal)"],
    ["Value",     "Numeric or text value to compare against.",          "e.g. 90 (for AHT < 90s)"],
  ]),
  spacer(),
  p("Example — score agents on three criteria:"),
  makeTable([2200, 3400, 3426],
    ["Rule", "Condition", "Meaning"],
    [
      ["Rule 1", "AHT ≤ 180",      "Average Handle Time within 3 minutes"],
      ["Rule 2", "CallsHandled ≥ 20", "At least 20 calls handled"],
      ["Rule 3", "Occupancy ≥ 85", "Occupancy rate at least 85%"],
    ]
  ),
  p("An agent who passes all three rules scores 5.0 ★. An agent who passes two out of three scores 3.3 ★."),
  spacer(),

  // ─── 9.2 QUEUE GRID ───────────────────────────────────────────────────────
  h2("9.2 Queue Grid"),
  p("Displays a tabular view of queue metrics, with rows representing Business Units or named queues and columns showing real-time metrics such as calls in queue, SLA percentage, and abandonment rate."),
  screenshot("Queue Grid widget — live queue metrics table"),
  spacer(),

  h3("General Tab"),
  screenshot("Queue Grid — General tab"),
  paramTable([
    ["Widget ID",    "Read-only system identifier for this widget instance.",       "e.g. 15"],
    ["Grid ID",      "Read-only identifier of the underlying real-time data grid.", "e.g. 3"],
    ["Display Name", "Widget header label.",                                        "e.g. \"Inbound Queues\""],
  ]),
  note("Queue Grid does not have a Business Unit selector in the General tab — queues are defined per-row in the Rows tab."),
  spacer(),

  h3("Appearance Tab"),
  screenshot("Queue Grid — Appearance tab"),
  h4("Typography"),
  paramTable([
    ["Font Size",    "Cell text size. Values from the tenant font-size list.",      "e.g. 12, 14, 16 (px)"],
  ]),
  spacer(),
  h4("Display Options"),
  paramTable([
    ["Show Pagination", "Adds a pagination bar when the row count exceeds the widget height.", "On / Off"],
  ]),
  spacer(),
  h4("Colours — Light Mode and Dark Mode"),
  paramTable([
    ["Widget Background",  "Canvas background of the entire widget.",                 "Colour swatch"],
    ["Text Colour",        "Default cell text colour.",                               "Colour swatch"],
    ["Header Background",  "Background of the column header row.",                    "Colour swatch"],
    ["Header Text Colour", "Text colour of the column header row.",                   "Colour swatch"],
    ["Table Background",   "Alternating row background (even rows).",                 "Colour swatch"],
  ]),
  spacer(),

  h3("Thresholds Tab"),
  screenshot("Queue Grid — Thresholds tab"),
  p("Same per-column threshold mechanism as Agent Grid (see Section 9.1, Thresholds Tab). Select a Queue Column, add rules with numeric From/To or text match conditions, and assign badge background and font colours."),
  spacer(),

  h3("Rows Tab"),
  screenshot("Queue Grid — Rows tab"),
  p("Each row in the Queue Grid represents one queue or Business Unit. Rows appear in the display in the order defined here."),
  numbered("Click + Add to create a new row."),
  numbered("Select a Business Unit from the searchable dropdown."),
  numbered("Optionally enter a Queue Name override."),
  numbered("Optionally set row-level Background and Font colours."),
  numbered("Use ▲ / ▼ to reorder rows."),
  spacer(),
  paramTable([
    ["Business Unit", "The Business Unit to display data for. Required.",             "Searchable dropdown — select from available BUs"],
    ["Queue Name",    "Display name for this row. Defaults to the Business Unit name.", "e.g. \"Sales\" (leave blank to use BU name)"],
    ["Background",    "Optional row background colour override.",                     "Colour swatch; leave blank for default"],
    ["Font Colour",   "Optional row text colour override.",                           "Colour swatch; leave blank for default"],
  ]),
  note("Row colours are applied at the row level and override the table alternating row colour for that specific row."),
  spacer(),
  p("Example — two rows with custom colours:"),
  makeTable([2200, 2400, 2200, 2226],
    ["Queue Name", "Business Unit", "Background", "Font"],
    [
      ["Sales",    "Sales BU",    "#E8F5E9 (light green)",  "Default"],
      ["Support",  "Support BU",  "#FFF3E0 (light amber)",  "Default"],
    ]
  ),
  spacer(),

  h3("Queue Columns Tab"),
  screenshot("Queue Grid — Queue Columns tab"),
  p("Defines which metrics appear as columns in the Queue Grid. These are QM (Queue Manager) or Agent Group metrics from the RTSGrid system."),
  numbered("Click + Add to create a new column."),
  numbered("Enter a display Name."),
  numbered("Search and select a Metric from the dropdown."),
  numbered("Use ▲ / ▼ to reorder."),
  spacer(),
  paramTable([
    ["Name",    "Column header text.",                                             "e.g. \"In Queue\", \"SLA %\", \"Abandoned\""],
    ["Metric",  "The QM/Agent Group metric ID. Searchable dropdown.",             "e.g. CallsWaiting, ServiceLevel, AbandonRate"],
  ]),
  spacer(),

  // ─── 9.3 DATA SLOT ────────────────────────────────────────────────────────
  h2("9.3 Data Slot"),
  p("A compact KPI card that displays a single real-time metric value with an optional target indicator and delta arrow. Ideal for prominent headline numbers on executive dashboards."),
  screenshot("Data Slot widget — single KPI value with target indicator"),
  spacer(),

  h3("General Tab"),
  screenshot("Data Slot — General tab"),
  paramTable([
    ["Widget ID",     "Read-only system identifier.",                                    "e.g. 8"],
    ["Grid ID",       "Read-only underlying grid identifier.",                           "e.g. 2"],
    ["Display Name",  "Widget header label.",                                            "e.g. \"Service Level\""],
    ["Business Unit", "Filters the metric to the selected BU.",                         "Select from list; blank = all"],
    ["Title",         "Large title text displayed above the metric value.",              "e.g. \"Today's SLA\""],
    ["Metric",        "The real-time metric to display. Full-text searchable dropdown.", "e.g. ServiceLevel, CallsHandled, AHT"],
    ["Target Value",  "A numeric target for the metric. Enables the target indicator.",  "e.g. 80 (for 80% SLA target)"],
    ["Target Mode",   "How the current value is evaluated against the target.",          "Less than: good when value < target\nGreater than: good when value > target"],
    ["Target Label",  "Text label shown next to the target value.",                      "e.g. \"Target: 80%\""],
  ]),
  note("Leave Target Value blank to disable the target indicator entirely."),
  spacer(),
  p("Example — SLA target widget:"),
  makeTable([2200, 6826],
    ["Setting", "Value"],
    [
      ["Title",        "Today’s Service Level"],
      ["Metric",       "ServiceLevel"],
      ["Target Value", "80"],
      ["Target Mode",  "Greater than (good when SLA ≥ 80%)"],
      ["Target Label", "Target: 80%"],
    ]
  ),
  spacer(),

  h3("Appearance Tab"),
  screenshot("Data Slot — Appearance tab"),
  h4("Typography"),
  paramTable([
    ["Font Size", "Text size for the metric value. Values from tenant font-size list.", "e.g. 32, 48 (px)"],
    ["Bold",      "Renders the metric value in bold.",                                  "On / Off (default: Off)"],
  ]),
  spacer(),
  h4("Display Options"),
  paramTable([
    ["Alignment",         "Horizontal alignment of the metric value and title.",                                     "Left / Centre / Right (default: Centre)"],
    ["Show Target Label", "Toggles the target label text below the value.",                                          "On / Off"],
    ["Show Delta Arrow",  "Displays an up/down arrow indicating whether the value improved since last update.",      "On / Off"],
    ["Hide Header",       "Hides the widget header bar (Display Name is not shown). Useful for large-value tiles.", "On / Off"],
  ]),
  spacer(),
  h4("Colours — Light Mode and Dark Mode"),
  paramTable([
    ["Widget Background",  "Canvas background.",            "Colour swatch"],
    ["Text Colour",        "Metric value and title colour.", "Colour swatch"],
    ["Header Background",  "Header bar background.",        "Colour swatch"],
    ["Header Text Colour", "Header bar text colour.",       "Colour swatch"],
  ]),
  spacer(),

  h3("Thresholds Tab"),
  screenshot("Data Slot — Thresholds tab"),
  p("Global thresholds applied to the metric value. Unlike Agent Grid and Queue Grid, Data Slot thresholds colour the entire widget background rather than a table cell."),
  numbered("Click + Add Rule."),
  numbered("Set From and To numeric bounds."),
  numbered("Set badge background and font colours."),
  spacer(),
  paramTable([
    ["From",              "Lower bound (inclusive). Leave blank for no lower bound.", "e.g. 0"],
    ["To",                "Upper bound (inclusive). Leave blank for no upper bound.", "e.g. 79"],
    ["Badge Background",  "Widget background colour when the rule matches.",          "e.g. #D32F2F (red — SLA < 80%)"],
    ["Badge Font Colour", "Text colour when the rule matches.",                       "e.g. #FFFFFF (white)"],
  ]),
  spacer(),

  // ─── 9.4 DAY TREND ─────────────────────────────────────────────────────────
  h2("9.4 Day Trend"),
  p("An intraday trend chart that plots call and agent metrics across time intervals throughout the day. Supports multiple series displayed simultaneously with configurable chart types."),
  screenshot("Day Trend widget — intraday line chart with multiple metric series"),
  spacer(),

  h3("General Tab"),
  screenshot("Day Trend — General tab"),
  paramTable([
    ["Widget ID",     "Read-only system identifier.",                                          "e.g. 3"],
    ["Grid ID",       "Read-only underlying grid identifier.",                                 "e.g. 1"],
    ["Display Name",  "Widget header label.",                                                  "e.g. \"Calls Today\""],
    ["Business Unit", "Restricts data to the selected BU.",                                   "Select from list; blank = all"],
    ["Interval",      "The time bucket size for each data point along the horizontal axis.",   "15 min / 30 min / 60 min"],
    ["Auto-refresh",  "How often the chart data is refreshed.",                               "1 min / 5 min / 10 min / Manual"],
  ]),
  note("A shorter interval gives more granular data points but may result in a more volatile chart. The default interval is 30 minutes."),
  spacer(),
  p("Example: for a high-traffic contact centre, use 15-minute intervals with 5-minute auto-refresh to track intraday patterns in near-real time."),
  spacer(),

  h3("Appearance Tab"),
  screenshot("Day Trend — Appearance tab"),
  h4("Chart Options"),
  paramTable([
    ["Chart Type",        "Visual style of the chart.",                                          "Line / Bar / Area / Step (default: Line)"],
    ["Show Data Labels",  "Displays numeric values above each data point.",                      "On / Off (default: Off)"],
    ["Show Legend",       "Displays the metric legend below the chart.",                         "On / Off (default: On)"],
  ]),
  spacer(),
  h4("Colours — Light Mode and Dark Mode"),
  paramTable([
    ["Widget Background",  "Canvas background.",            "Colour swatch"],
    ["Text Colour",        "Axis labels and legend text.",  "Colour swatch"],
    ["Header Background",  "Header bar background.",        "Colour swatch"],
    ["Header Text Colour", "Header bar text.",              "Colour swatch"],
  ]),
  spacer(),

  h3("Call Metrics Tab"),
  screenshot("Day Trend — Call Metrics tab"),
  p("Select which call-based metrics are plotted as series on the Day Trend chart. Each metric can be enabled/disabled, assigned a unique colour, and given a custom label."),
  screenshot("Call Metrics tab — list of metrics with enable toggles and colour pickers"),
  spacer(),
  paramTable([
    ["Enable toggle", "Shows or hides this metric series on the chart.",                                                         "On / Off"],
    ["Colour",        "Line/bar colour for this series. Uses a native colour picker.",                                           "Any hex colour, e.g. #2980B9"],
    ["Label",         "Custom display name for this series in the legend. Leave blank to use the default metric name.",          "e.g. \"Calls Offered\" instead of \"TotalCallsOffered\""],
  ]),
  note("At least one metric must be enabled for the chart to display data."),
  spacer(),

  h3("Agent Metrics Tab"),
  screenshot("Day Trend — Agent Metrics tab"),
  p("Select which agent-based metrics are overlaid on the Day Trend chart as secondary series. Configuration is identical to the Call Metrics tab."),
  paramTable([
    ["Enable toggle", "Shows or hides this agent metric series.",           "On / Off"],
    ["Colour",        "Series colour.",                                     "Any hex colour"],
    ["Label",         "Custom series label for the legend.",                "e.g. \"Available Agents\""],
  ]),
  note("Agent Metrics are plotted on the same chart as Call Metrics. Use contrasting colours to distinguish call-count series from agent-count series."),
  spacer(),
  p("Recommended colour scheme example:"),
  makeTable([2200, 2600, 4226],
    ["Metric", "Colour", "Rationale"],
    [
      ["Calls Offered",       "#2980B9 (blue)",   "Primary call volume — prominent colour"],
      ["Calls Handled",       "#27AE60 (green)",  "Positive outcome — green"],
      ["Calls Abandoned",     "#E74C3C (red)",     "Alert metric — red"],
      ["Available Agents",    "#F39C12 (amber)",  "Secondary metric — warm contrast"],
    ]
  ),
  spacer(),

  // ─── 9.5 AGENT STATE DISTRIBUTION ──────────────────────────────────────────
  h2("9.5 Agent State Distribution"),
  p("A pie, doughnut, or bar chart showing the breakdown of agents by their current state or state group. Useful for at-a-glance visibility of team availability."),
  screenshot("Agent State Distribution — doughnut chart showing agent state breakdown"),
  spacer(),

  h3("General Tab"),
  screenshot("Agent State Distribution — General tab"),
  paramTable([
    ["Widget ID",     "Read-only system identifier.",      "e.g. 9"],
    ["Grid ID",       "Read-only underlying grid ID.",     "e.g. 5"],
    ["Display Name",  "Widget header label.",              "e.g. \"Team Availability\""],
    ["Business Unit", "Filters to agents in the selected BU.", "Select from list; blank = all"],
  ]),
  spacer(),

  h3("Appearance Tab"),
  screenshot("Agent State Distribution — Appearance tab"),
  h4("Chart Configuration"),
  paramTable([
    ["Distribution Mode", "Controls the granularity of state grouping.",                             "Group: aggregate states into state groups (e.g. Available, Break)\nState: show individual raw states (e.g. AVAILABLE, LUNCH, TRAINING)"],
    ["Chart Type",        "Visual style of the chart.",                                              "Doughnut / Pie / Bar (vertical) / Horizontal Bar"],
    ["Value Display",     "What values are shown in the chart segments and tooltip.",                "Percentages (e.g. 45%) / Numbers (e.g. 12 agents)"],
    ["Show Legend",       "Displays the state/group name legend.",                                   "On / Off (default: On)"],
    ["Show Value Labels", "Renders the value directly on the chart segment.",                        "On / Off (default: On)"],
  ]),
  spacer(),
  h4("Colours — Light Mode and Dark Mode"),
  paramTable([
    ["Widget Background",  "Canvas background.",    "Colour swatch"],
    ["Text Colour",        "Legend and label text.", "Colour swatch"],
    ["Header Background",  "Header bar background.", "Colour swatch"],
    ["Header Text Colour", "Header bar text.",       "Colour swatch"],
  ]),
  note("Segment colours for each state/group are configured in the Tenant Settings > Agent States section by the Superadmin. These colours cannot be overridden per widget."),
  spacer(),
  p("Chart type selection guide:"),
  makeTable([2400, 6626],
    ["Chart Type", "Best Used For"],
    [
      ["Doughnut",       "Primary overview chart; space in the centre can show a headline number"],
      ["Pie",            "Compact proportion view without a centre gap"],
      ["Bar (vertical)", "Comparing absolute agent counts across states, especially when many states exist"],
      ["Horizontal Bar", "Same as Bar but works better in narrow widget widths"],
    ]
  ),
  spacer(),

  // ─── 9.6 INFO SLOT ─────────────────────────────────────────────────────────
  h2("9.6 Info Slot"),
  p("A scrolling text / ticker panel that displays configurable text content with priority-based colour highlighting. Used for announcements, alerts, and team notices on wallboards."),
  screenshot("Info Slot widget — scrolling ticker with priority message"),
  spacer(),

  h3("General Tab"),
  screenshot("Info Slot — General tab"),
  paramTable([
    ["Widget ID",     "Read-only system identifier.",                                            "e.g. 11"],
    ["Grid ID",       "Read-only underlying grid ID.",                                           "e.g. 4"],
    ["Display Name",  "Widget header label.",                                                    "e.g. \"Team Notices\""],
    ["Slot",          "The configured Info Slot data source to display. Defined in Admin > Info Slots.", "Select from available slots"],
  ]),
  note("Info Slot does not have a Business Unit selector — content is managed at the slot level by Administrators."),
  spacer(),

  h3("Appearance Tab"),
  screenshot("Info Slot — Appearance tab"),
  h4("Typography"),
  paramTable([
    ["Font Size",      "Text size for the scrolling content.",           "e.g. 14, 18, 24 (px)"],
  ]),
  spacer(),
  h4("Scroll Behaviour"),
  paramTable([
    ["Scroll Direction", "Direction the text moves across or up/down the widget area.",                                       "Left to Right / Right to Left / Top to Bottom / Bottom to Top"],
    ["Scroll Speed",     "Speed of the scroll animation. Only applies when a scrolling direction is selected (Ticker mode).", "Slow / Medium / Fast"],
  ]),
  note("Right to Left is the appropriate scroll direction for RTL languages (Arabic, Hebrew). Set the direction to match the screen’s language."),
  spacer(),
  h4("Colours — Light Mode and Dark Mode"),
  paramTable([
    ["Widget Background",  "Default canvas background.",                                        "Colour swatch"],
    ["Text Colour",        "Default scrolling text colour.",                                    "Colour swatch"],
    ["Header Background",  "Header bar background.",                                            "Colour swatch"],
    ["Header Text Colour", "Header bar text.",                                                  "Colour swatch"],
  ]),
  spacer(),
  h4("Priority High Colours"),
  p("Messages marked as Priority High in the slot data source are displayed with distinct colours to attract attention."),
  paramTable([
    ["Priority High Background (Light)",  "Background for priority messages in light mode.",   "e.g. #FFEB3B (yellow)"],
    ["Priority High Text (Light)",        "Text colour for priority messages in light mode.",  "e.g. #212121 (dark)"],
    ["Priority High Background (Dark)",   "Background for priority messages in dark mode.",    "e.g. #F57F17 (amber)"],
    ["Priority High Text (Dark)",         "Text colour for priority messages in dark mode.",   "e.g. #FFFFFF (white)"],
  ]),
  spacer(),

  // ── 10. PUBLISHING MANAGEMENT ──────────────────────────────────────────────
  h1("10. Publishing Management"),
  screenshot("Publishing — Publish / Unpublish button and status badge"),
  p("Screens have two statuses: Draft and Published. The status is set in Screen Settings."),
  makeTable([1800, 7226],
    ["Status", "Behaviour"],
    [
      ["Draft",     "Visible only to Editors and Administrators. Hidden from Viewers. Use Draft for screens under construction or requiring review."],
      ["Published", "Visible to all users with view permission (or all users if IsPublic is set). Suitable for live wallboards and shared screens."],
    ]
  ),
  note("Changing a screen from Published to Draft immediately hides it from Viewers. Viewers currently viewing the screen will see it disappear on their next page load."),
  spacer(),

  // ── 11. TRASH ──────────────────────────────────────────────────────────────
  h1("11. Trash (Soft Delete)"),
  screenshot("Trash tab — soft-deleted screens with days-remaining badges"),
  p("When the Administrator has enabled Soft Delete in Tenant Settings, deleted screens are moved to the Trash tab on the Screen List page rather than being permanently removed."),
  h2("11.1 Trash Tab Columns"),
  makeTable([2600, 6426],
    ["Column", "Description"],
    [
      ["Name",            "Screen name"],
      ["Deleted by",      "User who deleted the screen"],
      ["Deleted at",      "Deletion timestamp"],
      ["Days remaining",  "Days until permanent deletion. Shown as a red badge when ≤ 7 days"],
    ]
  ),
  spacer(),
  h2("11.2 Restoring a Screen"),
  numbered("Click the Trash tab."),
  numbered("Find the screen to restore."),
  numbered("Click the ↩ Restore button."),
  numbered("The screen reappears in the main Screen List in its original status."),
  note("The retention period before permanent deletion is configured by your Administrator (default: 90 days)."),
  spacer(),

  // ── 12. TIPS ───────────────────────────────────────────────────────────────
  h1("12. Tips and Best Practices"),
  bullet("Always click Save in the editor header before closing the browser tab. Changes are not auto-saved."),
  bullet("Use Categories to organise screens by team or function (e.g. Inbound, Outbound, Quality)."),
  bullet("Use Templates to share pre-configured widget layouts across multiple screens."),
  bullet("Set dark mode colours in widget Appearance if screens will be displayed on wall monitors in low-light areas."),
  bullet("Use IsPublic for shared overview screens that all staff should see, avoiding repeated Permission Group assignments."),
  bullet("On Agent Grid, define Score rules to give supervisors an instant performance snapshot without reading individual metrics."),
  bullet("On Data Slot, enable Show Delta Arrow to show whether the metric is trending up or down since the last refresh."),
  bullet("On Day Trend, use contrasting colours for call metrics vs. agent metrics to keep dual-axis data readable."),
  bullet("On Info Slot, test Priority High colours against your actual screen background — they should be clearly distinct from standard messages."),
  bullet("On Queue Grid, assign custom row background colours to differentiate queues at a glance (e.g. green for met SLA, amber for at-risk)."),
  spacer(),

  // ── 13. GLOSSARY ────────────────────────────────────────────────────────────
  h1("13. Glossary"),
  makeTable([2600, 6426],
    ["Term", "Definition"],
    [
      ["Agent Grid",              "Widget displaying a live table of agents with configurable columns, thresholds, filters, and score."],
      ["Agent State Distribution","Widget showing agent state/group breakdown as a pie, doughnut, or bar chart."],
      ["Business Unit (BU)",      "A data segmentation level used to filter widget data to a specific organisational unit."],
      ["Canvas",                  "The editing area in the Screen Editor where widgets are placed and arranged."],
      ["Category",                "An organisational label assigned to a screen (e.g. Inbound, Quality)."],
      ["Data Slot",               "Widget displaying a single real-time KPI metric with optional target and delta."],
      ["Day Trend",               "Widget plotting intraday call and agent metrics on a time-series chart."],
      ["Draft",                   "Screen status — visible only to Editors and Administrators."],
      ["Info Slot",               "Widget displaying a scrolling text/ticker feed with priority colour coding."],
      ["IsPublic",                "A screen flag that makes it visible to all authenticated tenant users without explicit group assignment."],
      ["Metric",                  "A specific real-time data value (e.g. ServiceLevel, AHT, CallsWaiting) sourced from RTSGrid."],
      ["Palette",                 "The slide-out panel in the Screen Editor listing available widget types and templates."],
      ["Permission Group",        "A set of permissions controlling which screens, queues, and features a user can access."],
      ["Published",               "Screen status — visible to all users with view permission."],
      ["Queue Grid",              "Widget displaying a live table of queue metrics with configurable rows and columns."],
      ["RTSGrid",                 "The underlying real-time data grid system that supplies live metrics to all widgets."],
      ["Screen",                  "A named dashboard containing one or more widgets. Also referred to as a Dashboard."],
      ["Score",                   "An optional 1–5 star indicator on Agent Grid calculated from user-defined formula rules."],
      ["SignalR",                 "The real-time communication technology used to stream live data to widgets."],
      ["Soft Delete",             "Deletion mode where screens move to Trash with a retention period before permanent removal."],
      ["Template",                "A saved widget configuration reusable across screens."],
      ["Threshold",               "A colour rule applied to a metric value when it crosses a defined boundary."],
      ["Widget",                  "A real-time data display component placed on a screen."],
    ]
  ),
  spacer(),
];

// ── Numbering definitions ──────────────────────────────────────────────────────
const numbering = {
  config: [
    { reference: "bullets", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 400, hanging: 200 } } } },
                                     { level: 1, format: LevelFormat.BULLET, text: "◦", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 800, hanging: 200 } } } }] },
    { reference: "numbers", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 400, hanging: 200 } } } },
                                     { level: 1, format: LevelFormat.DECIMAL, text: "%1.%2.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 800, hanging: 200 } } } }] },
  ]
};

const doc = new Document({
  numbering,
  sections: [{
    properties: {
      page: { margin: { top: 720, bottom: 720, left: 1000, right: 1000 } },
    },
    headers: {
      default: new Header({ children: [
        new Paragraph({
          children: [
            new TextRun({ text: "RTM View Shell  |  B-02  Dashboard Management User Guide", font: "Arial", size: 18, color: C.grey }),
            new TextRun({ text: "  v1.3", font: "Arial", size: 18, color: C.teal }),
          ],
          border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: C.border } },
          spacing: { after: 120 },
        }),
      ]}),
    },
    footers: {
      default: new Footer({ children: [
        new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [
            new TextRun({ text: "Page ", font: "Arial", size: 18, color: C.grey }),
            new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 18, color: C.grey }),
            new TextRun({ text: " of ", font: "Arial", size: 18, color: C.grey }),
            new TextRun({ children: [PageNumber.TOTAL_PAGES], font: "Arial", size: 18, color: C.grey }),
            new TextRun({ text: "  |  Confidential — For internal use only", font: "Arial", size: 18, color: C.grey }),
          ],
          border: { top: { style: BorderStyle.SINGLE, size: 1, color: C.border } },
          spacing: { before: 120 },
        }),
      ]}),
    },
    children: docContent,
  }],
});

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync("/tmp/docgen/B-02_DashboardUserGuide_v1.3_EN.docx", buffer);
  console.log("Done: B-02_DashboardUserGuide_v1.2_EN.docx");
}).catch(e => { console.error(e); process.exit(1); });
