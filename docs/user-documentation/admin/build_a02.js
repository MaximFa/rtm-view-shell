/**
 * A-02_AdminGuide_v1.0_EN.docx — Build script
 * Insightense RTM View Shell — Administrator's Guide
 * Generated: 2026-05-30
 */

const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, HeadingLevel, LevelFormat, BorderStyle,
  WidthType, ShadingType, VerticalAlign, PageNumber, PageBreak,
  ExternalHyperlink, TableOfContents
} = require("docx");
const fs = require("fs");
const path = require("path");

// ─── Constants ──────────────────────────────────────────────────────────────
const OUT_DIR  = __dirname;
const OUT_FILE = path.join(OUT_DIR, "A-02_AdminGuide_v1.0_EN.docx");
const DOC_VERSION = "1.0";
const DOC_DATE    = "30 May 2026";
const PRODUCT     = "RTM View Shell";
const COMPANY     = "Insightense";

// A4 dimensions in DXA (1 inch = 1440 DXA)
const PAGE_W = 11906;   // A4 width
const PAGE_H = 16838;   // A4 height
const MARGIN = 1440;    // 1 inch margins
const CONTENT_W = PAGE_W - 2 * MARGIN;  // 9026 DXA

// ─── Screenshots ─────────────────────────────────────────────────────────────
const SCREENSHOTS_DIR = path.join(__dirname, "screenshots");
const screenshotMap = {
  "User Management list — user table with roles, groups, statuses":        { file: "a02_sc01_user_list.jpg",         w: 540, h: 215 },
  "New User modal — form with role and permission group selectors":         { file: "a02_sc02_new_user_modal.jpg",    w: 400, h: 290 },
  "Edit User modal — editable user fields with status and 2FA toggles":    { file: "a02_sc03_edit_user_modal.jpg",   w: 400, h: 370 },
  "Permission Groups list — groups with tenant, description, status":      { file: "a02_sc04_pg_list.jpg",           w: 540, h: 200 },
  "Permission Group editor — Menu tab with menu item checkboxes":          { file: "a02_sc05_pg_menu_tab.jpg",       w: 540, h: 350 },
  "Permission Group editor — Screens tab with View/Edit/Delete columns":   { file: "a02_sc06_pg_screens_tab.jpg",    w: 540, h: 300 },
  "Permission Group editor — Queues tab with dual-pane selector":          { file: "a02_sc07_pg_queues_tab.jpg",     w: 540, h: 300 },
  "Permission Group editor — Business Units tab":                          { file: "a02_sc08_pg_bu_tab.jpg",         w: 540, h: 300 },
  "Tenant Management list — tenants with slug and status":                 { file: "a02_sc09_tenant_list.jpg",       w: 540, h: 180 },
  "Edit Tenant modal — General tab with name, slug, status":               { file: "a02_sc10_tenant_edit_general.jpg", w: 480, h: 280 },
  "Edit Tenant modal — Settings tab with password policy and retention":   { file: "a02_sc11_tenant_settings_tab.jpg", w: 480, h: 370 },
  "Edit Tenant modal — Agent States tab with state-group mapping table":   { file: "a02_sc12_tenant_agent_states.jpg", w: 480, h: 350 },
  "Dashboard list — screen cards grid with status badges":                 { file: "a02_sc13_dashboard_list.jpg",    w: 540, h: 250 },
  "Audit Log — filter bar and event table with details":                   { file: "a02_sc14_audit_log.jpg",         w: 540, h: 270 },
};

function screenshot(label) {
  const meta = screenshotMap[label];
  if (meta) {
    const imgPath = path.join(SCREENSHOTS_DIR, meta.file);
    if (fs.existsSync(imgPath)) {
      return new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 120, after: 120 },
        children: [new ImageRun({
          data: fs.readFileSync(imgPath),
          transformation: { width: meta.w, height: meta.h },
          type: "jpg",
        })],
      });
    }
  }
  // Fallback: grey placeholder
  return screenshotPlaceholder(label);
}


// ─── Color palette ───────────────────────────────────────────────────────────
const C = {
  DARK_NAVY:  "1E3461",
  MID_BLUE:   "2D5497",
  LIGHT_BLUE: "D5E8F0",
  ACCENT:     "4F86C6",
  GREEN:      "2E8B57",
  RED:        "C0392B",
  GREY_BG:    "F5F5F5",
  GREY_TEXT:  "666666",
  WHITE:      "FFFFFF",
  ORANGE:     "E67E22",
  PLACEHOLDER:"E8E8E8",
  BORDER:     "CCCCCC",
};

// ─── Helpers ─────────────────────────────────────────────────────────────────
const border  = { style: BorderStyle.SINGLE, size: 1, color: C.BORDER };
const borders = { top: border, bottom: border, left: border, right: border };
const noBorder = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
const noBorders = { top: noBorder, bottom: noBorder, left: noBorder, right: noBorder };

function sp(before = 0, after = 0) { return { spacing: { before, after } }; }
function run(text, opts = {}) {
  return new TextRun({ text, font: "Arial", ...opts });
}
function para(children, opts = {}) {
  return new Paragraph({ children: Array.isArray(children) ? children : [children], ...opts });
}
function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    children: [new TextRun({ text, font: "Arial", size: 32, bold: true, color: C.DARK_NAVY })]
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    children: [new TextRun({ text, font: "Arial", size: 26, bold: true, color: C.MID_BLUE })]
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    children: [new TextRun({ text, font: "Arial", size: 24, bold: true, color: C.DARK_NAVY })]
  });
}
function body(text, opts = {}) {
  return new Paragraph({
    children: [new TextRun({ text, font: "Arial", size: 22 })],
    ...sp(60, 60), ...opts
  });
}
function note(text) {
  return new Paragraph({
    children: [
      new TextRun({ text: "NOTE: ", font: "Arial", size: 22, bold: true, color: C.MID_BLUE }),
      new TextRun({ text, font: "Arial", size: 22, italics: true }),
    ],
    ...sp(60, 60)
  });
}
function warning(text) {
  return new Paragraph({
    children: [
      new TextRun({ text: "⚠ ", font: "Arial", size: 22, bold: true, color: C.RED }),
      new TextRun({ text, font: "Arial", size: 22, italics: true, color: C.RED }),
    ],
    ...sp(60, 60)
  });
}
function pageBreak() { return new Paragraph({ children: [new PageBreak()] }); }
function spacer()    { return new Paragraph({ children: [run("")], ...sp(120, 0) }); }

function bullet(text, bold_prefix = null) {
  const children = [];
  if (bold_prefix) {
    children.push(new TextRun({ text: bold_prefix + " ", font: "Arial", size: 22, bold: true }));
  }
  children.push(new TextRun({ text, font: "Arial", size: 22 }));
  return new Paragraph({
    numbering: { reference: "bullets", level: 0 },
    children
  });
}
function numbered(text) {
  return new Paragraph({
    numbering: { reference: "numbers", level: 0 },
    children: [new TextRun({ text, font: "Arial", size: 22 })]
  });
}

// Placeholder box for screenshots
function screenshotPlaceholder(label, heightHint = 80) {
  const rows = [];
  // Top label row
  rows.push(new TableRow({ children: [new TableCell({
    borders: noBorders,
    width: { size: CONTENT_W, type: WidthType.DXA },
    shading: { fill: C.PLACEHOLDER, type: ShadingType.CLEAR },
    margins: { top: 120, bottom: 40, left: 240, right: 240 },
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: `[Screenshot: ${label}]`, font: "Arial", size: 20, color: C.GREY_TEXT, italics: true })]
    })]
  })] }));
  // Filler row for height
  for (let i = 0; i < Math.max(1, Math.floor(heightHint / 20)); i++) {
    rows.push(new TableRow({ children: [new TableCell({
      borders: noBorders,
      width: { size: CONTENT_W, type: WidthType.DXA },
      shading: { fill: C.PLACEHOLDER, type: ShadingType.CLEAR },
      margins: { top: 80, bottom: 80, left: 240, right: 240 },
      children: [para([])]
    })] }));
  }
  return new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [CONTENT_W],
    rows,
    margins: { top: 120, bottom: 120 }
  });
}

// Info box (blue-tinted callout)
function infoBox(title, items) {
  const children = [];
  if (title) children.push(new Paragraph({
    children: [new TextRun({ text: title, font: "Arial", size: 22, bold: true, color: C.MID_BLUE })]
  }));
  items.forEach(item => children.push(new Paragraph({
    children: [new TextRun({ text: item, font: "Arial", size: 20 })]
  })));
  return new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [CONTENT_W],
    rows: [new TableRow({ children: [new TableCell({
      borders,
      width: { size: CONTENT_W, type: WidthType.DXA },
      shading: { fill: C.LIGHT_BLUE, type: ShadingType.CLEAR },
      margins: { top: 120, bottom: 120, left: 180, right: 180 },
      children
    })] })],
    margins: { top: 120, bottom: 120 }
  });
}

// Two-column table row helper
function tRow(col1, col2, header = false) {
  const shade = header ? C.DARK_NAVY : C.WHITE;
  const textColor = header ? C.WHITE : undefined;
  const bold = header;
  const col1W = Math.round(CONTENT_W * 0.35);
  const col2W = CONTENT_W - col1W;
  return new TableRow({
    tableHeader: header,
    children: [
      new TableCell({
        borders, width: { size: col1W, type: WidthType.DXA },
        shading: { fill: shade, type: ShadingType.CLEAR },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: col1, font: "Arial", size: 20, bold, color: textColor })] })]
      }),
      new TableCell({
        borders, width: { size: col2W, type: WidthType.DXA },
        shading: { fill: header ? C.DARK_NAVY : C.WHITE, type: ShadingType.CLEAR },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: col2, font: "Arial", size: 20, bold, color: textColor })] })]
      }),
    ]
  });
}

function twoColTable(headers, rows) {
  return new Table({
    width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [Math.round(CONTENT_W * 0.35), CONTENT_W - Math.round(CONTENT_W * 0.35)],
    rows: [
      tRow(headers[0], headers[1], true),
      ...rows.map(r => tRow(r[0], r[1]))
    ],
    margins: { top: 120, bottom: 120 }
  });
}

// Five-column role matrix table
function roleMatrixRow(feature, sa, admin, editor, viewer, header = false) {
  const cols = [feature, sa, admin, editor, viewer];
  const widths = [
    Math.round(CONTENT_W * 0.40),
    Math.round(CONTENT_W * 0.15),
    Math.round(CONTENT_W * 0.15),
    Math.round(CONTENT_W * 0.15),
    CONTENT_W - Math.round(CONTENT_W * 0.40) - 3 * Math.round(CONTENT_W * 0.15),
  ];
  return new TableRow({
    tableHeader: header,
    children: cols.map((text, i) => {
      const isCheck = !header && (text === "✓" || text === "—");
      const color = header ? C.WHITE : (text === "✓" ? C.GREEN : (text === "—" ? C.GREY_TEXT : undefined));
      return new TableCell({
        borders,
        width: { size: widths[i], type: WidthType.DXA },
        shading: { fill: header ? C.DARK_NAVY : (i === 0 ? C.GREY_BG : C.WHITE), type: ShadingType.CLEAR },
        margins: { top: 60, bottom: 60, left: 100, right: 100 },
        children: [new Paragraph({
          alignment: (i > 0 && !header) ? AlignmentType.CENTER : AlignmentType.LEFT,
          children: [new TextRun({ text, font: "Arial", size: 20, bold: header, color })]
        })]
      });
    })
  });
}

// ─── Document sections ────────────────────────────────────────────────────────

function makeTitlePage() {
  return [
    spacer(), spacer(), spacer(),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: COMPANY, font: "Arial", size: 28, color: C.GREY_TEXT })]
    }),
    spacer(),
    new Table({
      width: { size: CONTENT_W, type: WidthType.DXA },
      columnWidths: [CONTENT_W],
      rows: [new TableRow({ children: [new TableCell({
        borders: noBorders,
        width: { size: CONTENT_W, type: WidthType.DXA },
        shading: { fill: C.DARK_NAVY, type: ShadingType.CLEAR },
        margins: { top: 480, bottom: 480, left: 720, right: 720 },
        children: [
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: PRODUCT, font: "Arial", size: 52, bold: true, color: C.WHITE })]
          }),
          new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({ text: "Administrator's Guide", font: "Arial", size: 36, color: C.LIGHT_BLUE })]
          }),
        ]
      })] })],
      margins: { top: 240, bottom: 240 }
    }),
    spacer(),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: `Version ${DOC_VERSION}  ·  ${DOC_DATE}`, font: "Arial", size: 22, color: C.GREY_TEXT })]
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: "Classification: Internal / Operational Use", font: "Arial", size: 20, color: C.GREY_TEXT, italics: true })]
    }),
    spacer(), spacer(), spacer(), spacer(),
    new Table({
      width: { size: CONTENT_W, type: WidthType.DXA },
      columnWidths: [CONTENT_W],
      rows: [new TableRow({ children: [new TableCell({
        borders: { top: border, bottom: noBorder, left: noBorder, right: noBorder },
        width: { size: CONTENT_W, type: WidthType.DXA },
        margins: { top: 120, bottom: 0, left: 0, right: 0 },
        children: [
          new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: `© ${new Date().getFullYear()} ${COMPANY}. All rights reserved.`, font: "Arial", size: 18, color: C.GREY_TEXT })] }),
          new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "This document is for internal use only and may not be distributed without authorization.", font: "Arial", size: 18, color: C.GREY_TEXT, italics: true })] }),
        ]
      })] })]
    }),
    pageBreak(),
  ];
}

function makeRevisionTable() {
  const colW = [Math.round(CONTENT_W/4), Math.round(CONTENT_W/4), Math.round(CONTENT_W/4), CONTENT_W - 3*Math.round(CONTENT_W/4)];
  const headerCells = ["Version", "Date", "Author", "Summary"].map((text, i) =>
    new TableCell({
      borders, width: { size: colW[i], type: WidthType.DXA },
      shading: { fill: C.DARK_NAVY, type: ShadingType.CLEAR },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      children: [new Paragraph({ children: [new TextRun({ text, font: "Arial", size: 20, bold: true, color: C.WHITE })] })]
    })
  );
  const dataCells = ["1.0", "30 May 2026", "Insightense", "Initial release"].map((text, i) =>
    new TableCell({
      borders, width: { size: colW[i], type: WidthType.DXA },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      children: [new Paragraph({ children: [new TextRun({ text, font: "Arial", size: 20 })] })]
    })
  );
  return [
    h1("Document Revision History"),
    spacer(),
    new Table({
      width: { size: CONTENT_W, type: WidthType.DXA },
      columnWidths: colW,
      rows: [
        new TableRow({ tableHeader: true, children: headerCells }),
        new TableRow({ children: dataCells }),
      ],
      margins: { top: 120, bottom: 120 }
    }),
    pageBreak(),
  ];
}

function makeTableOfContents() {
  return [
    h1("Table of Contents"),
    spacer(),
    infoBox(null, [
      "1. Introduction ........................................................................  3",
      "2. Navigation Overview .................................................................  4",
      "3. User Management .....................................................................  5",
      "   3.1  Viewing the User List ..........................................................  5",
      "   3.2  Creating a New User ............................................................  6",
      "   3.3  Editing a User .................................................................  7",
      "   3.4  Managing User Status ...........................................................  8",
      "   3.5  Resetting a User Password .....................................................  9",
      "   3.6  Force Logout ..................................................................  9",
      "4. Permission Groups ..................................................................  10",
      "   4.1  Viewing Permission Groups .....................................................  10",
      "   4.2  Creating a Permission Group ..................................................  11",
      "   4.3  Editing a Permission Group ...................................................  11",
      "   4.4  Menu Permissions .............................................................  12",
      "   4.5  Screen Permissions ...........................................................  13",
      "   4.6  Resource Permissions (Queues, Agent Groups, Business Units, Super Groups) ...  13",
      "   4.7  Deleting a Permission Group ..................................................  14",
      "5. Tenant Management (Superadmin) ....................................................  15",
      "   5.1  Viewing Tenants ..............................................................  15",
      "   5.2  Editing Tenant General Settings ..............................................  16",
      "   5.3  Tenant Settings (Password Policy, Security, Retention) ......................  16",
      "   5.4  Agent States .................................................................  17",
      "6. Dashboard Management ..............................................................  19",
      "7. Audit Log .........................................................................  20",
      "   7.1  Reading the Audit Log ........................................................  20",
      "   7.2  Filtering and Date Range ....................................................  21",
      "   7.3  Exporting Audit Records .....................................................  21",
      "8. Role Permissions Reference ........................................................  22",
      "9. Troubleshooting ...................................................................  23",
    ]),
    pageBreak(),
  ];
}

function makeIntroduction() {
  return [
    h1("1. Introduction"),
    spacer(),
    h2("1.1  Purpose of This Guide"),
    body("This guide is intended for Administrators and Superadmins of the Insightense RTM View Shell. It covers the day-to-day administration of users, permission groups, dashboards, tenant settings, and audit log review."),
    body("For end-user tasks such as creating dashboards and configuring widgets, refer to the Dashboard Management User Guide (B-02)."),
    spacer(),
    h2("1.2  Who Should Read This Guide"),
    bullet("System Administrators — responsible for user accounts and permission groups."),
    bullet("Superadmins — platform-wide administrators who manage multiple tenants, agent states, and widget catalogue."),
    spacer(),
    h2("1.3  Prerequisites"),
    bullet("RTM View Shell installed and accessible (see Installation Guide, A-01)."),
    bullet("An Administrator or Superadmin account with a verified email address."),
    bullet("Browser: Chrome, Firefox, or Edge (last two versions)."),
    spacer(),
    h2("1.4  Conventions"),
    twoColTable(["Notation", "Meaning"], [
      ["Bold text", "UI element — button, field, or menu item."],
      ["Monospace", "System value, URL, or permission key."],
      ["NOTE:", "Helpful information that supplements the main text."],
      ["⚠ WARNING:", "Action that may affect data or user access."],
    ]),
    spacer(),
    h2("1.5  Accessing the Application"),
    body("RTM View Shell is accessed at the tenant-specific URL provided by your system administrator, typically in the format:"),
    new Paragraph({
      children: [new TextRun({ text: "https://<tenant-slug>.cc-dashboard.local/", font: "Courier New", size: 22, color: C.MID_BLUE })],
      ...sp(60, 60),
    }),
    body("All communication uses HTTPS with TLS 1.3. Connections over plain HTTP are automatically redirected."),
    pageBreak(),
  ];
}

function makeNavigation() {
  return [
    h1("2. Navigation Overview"),
    spacer(),
    body("After logging in, the left sidebar provides access to all sections. The sections displayed depend on the user's role."),
    spacer(),
    screenshot("Left sidebar — Superadmin view showing all sections: CONTENT, CONFIGURATION, ADMINISTRATION, PLATFORM"),
    spacer(),
    h2("2.1  Sidebar Sections"),
    twoColTable(["Section", "Contents"], [
      ["CONTENT", "Dashboards, Widget Catalogue, Info Slots"],
      ["CONFIGURATION", "Business Units, Super Groups, Sites, Info Slots"],
      ["ADMINISTRATION", "Users, Categories, Permission Groups, Audit Log"],
      ["PLATFORM", "Tenants, Metrics (Superadmin only)"],
    ]),
    spacer(),
    note("Menu items visible to a user depend on the Menu permissions configured in the user's Permission Group (see Section 4.4)."),
    spacer(),
    h2("2.2  Role Summary"),
    body("RTM View Shell has four built-in roles. A user is assigned exactly one role."),
    new Table({
      width: { size: CONTENT_W, type: WidthType.DXA },
      columnWidths: [Math.round(CONTENT_W * 0.40), Math.round(CONTENT_W * 0.15), Math.round(CONTENT_W * 0.15), Math.round(CONTENT_W * 0.15), CONTENT_W - Math.round(CONTENT_W * 0.40) - 3 * Math.round(CONTENT_W * 0.15)],
      rows: [
        roleMatrixRow("Feature", "Superadmin", "Administrator", "Editor", "Viewer", true),
        roleMatrixRow("Tenant management", "✓", "—", "—", "—"),
        roleMatrixRow("User management", "✓", "✓", "—", "—"),
        roleMatrixRow("Permission Group management", "✓", "✓", "—", "—"),
        roleMatrixRow("Tenant settings / SSO", "✓", "✓", "—", "—"),
        roleMatrixRow("Create / edit dashboard", "✓", "✓", "✓ (PG)", "—"),
        roleMatrixRow("View dashboard", "✓", "✓", "✓ (PG)", "✓ (PG)"),
        roleMatrixRow("View widget catalogue", "✓", "✓", "✓", "—"),
        roleMatrixRow("Manage widget catalogue", "✓", "—", "—", "—"),
        roleMatrixRow("View audit log", "✓", "✓", "—", "—"),
        roleMatrixRow("Agent State Definitions", "✓", "—", "—", "—"),
      ],
      margins: { top: 120, bottom: 120 }
    }),
    para([run("(PG) = subject to Permission Group access restrictions.", { size: 18, italics: true, color: C.GREY_TEXT })], sp(60, 0)),
    pageBreak(),
  ];
}

function makeUserManagement() {
  return [
    h1("3. User Management"),
    body("User Management is available to Administrators and Superadmins. Access it from the sidebar under ADMINISTRATION → Users."),
    spacer(),
    h2("3.1  Viewing the User List"),
    body("The User Management page displays all users in a searchable, filterable table."),
    spacer(),
    screenshot("User Management list — user table with roles, groups, statuses"),
    spacer(),
    h3("Table Columns"),
    twoColTable(["Column", "Description"], [
      ["User", "Avatar initial, display name, and email address (two lines)."],
      ["Username", "Login username."],
      ["Role", "Coloured badge: Superadmin (purple), Administrator (blue), Editor (green), Viewer (grey)."],
      ["Group", "Assigned Permission Group name."],
      ["Tenant", "Tenant the user belongs to. Superadmin sees all tenants."],
      ["Status", "Active (green), Inactive (grey), or Blocked (red)."],
      ["Last Login", "Date and time of most recent successful login."],
      ["2FA", "Checkmark icon if email two-factor authentication is enabled."],
    ]),
    spacer(),
    h3("Filtering and Search"),
    bullet("Type in the Search box to filter by name or email address."),
    bullet("Use the Role dropdown to filter by Superadmin, Administrator, Editor, or Viewer."),
    bullet("Use the Group dropdown to filter by Permission Group."),
    bullet("Use the Status dropdown to show only Active, Inactive, or Blocked users."),
    bullet("Use the Tenant dropdown (Superadmin only) to filter by tenant."),
    spacer(),
    note("Server-side pagination keeps list performance consistent. Use the per-page selector (10 / 25 / 50 / 100) and Previous / Next controls at the bottom right."),
    spacer(),
    h2("3.2  Creating a New User"),
    body("Click the New User button (top right) to open the Create User dialog."),
    spacer(),
    screenshot("New User modal — form with role and permission group selectors"),
    spacer(),
    h3("Required Fields"),
    twoColTable(["Field", "Details"], [
      ["First Name", "Optional free text."],
      ["Last Name", "Optional free text."],
      ["Email *", "Must be unique within the tenant. Used for temporary password delivery and 2FA codes."],
      ["Username *", "Must be unique within the tenant. Used for login."],
      ["Role *", "Select one of: Superadmin, Administrator, Editor, Viewer."],
      ["Permission Group", "Required for all roles except Superadmin. Select from active groups."],
    ]),
    spacer(),
    infoBox("Password delivery", [
      "After clicking Create User →, the system generates a temporary password and sends it to the specified email address.",
      "The user must change this password on their first login.",
    ]),
    warning("An Administrator cannot create Superadmin accounts or users in a different tenant."),
    spacer(),
    h2("3.3  Editing a User"),
    body("Click the Edit button next to any user row to open the Edit User dialog."),
    spacer(),
    screenshot("Edit User modal — editable user fields with status and 2FA toggles"),
    spacer(),
    h3("Editable Fields"),
    twoColTable(["Field", "Details"], [
      ["First Name / Last Name", "Display name fields. Optional."],
      ["Email", "Must remain unique within the tenant. Changing email affects 2FA and password reset delivery."],
      ["Role", "Changes take effect immediately. An Administrator cannot change their own role."],
      ["Permission Group", "Reassigning a group updates the user's access on the next page interaction."],
      ["Preferred Locale", "Language for the UI and email notifications. Examples: en-US, ru-RU, ar-AE."],
      ["Active (checkbox)", "Uncheck to block the user immediately. Active sessions are terminated."],
      ["2FA (checkbox)", "Enable or disable email two-factor authentication for this user."],
    ]),
    spacer(),
    h2("3.4  Managing User Status"),
    body("A user's status can be Active, Inactive (never logged in), or Blocked (manually deactivated)."),
    bullet("To block a user: open Edit User and uncheck the Active checkbox, then click Save →."),
    bullet("Blocking terminates all active Blazor circuits and revokes all API refresh tokens immediately."),
    bullet("To reactivate: open Edit User, re-check Active, and click Save →."),
    warning("There is no grace period. A blocked user loses access the moment the change is saved."),
    spacer(),
    h2("3.5  Resetting a User Password"),
    body("Administrators can initiate a password reset for any user in their tenant."),
    numbered("Open the Edit User dialog for the target user."),
    numbered("Click Reset Password."),
    numbered("The system sends a one-time reset link to the user's email address. The link is valid for 24 hours."),
    numbered("The user follows the link, enters a new password, and logs in."),
    spacer(),
    note("The reset link is single-use. If the user does not receive the email, check the spam folder or verify the email address on the account."),
    spacer(),
    h2("3.6  Deleting a User"),
    body("Deleting a user is permanent and cannot be undone."),
    numbered("Open the Edit User dialog."),
    numbered("Click Delete User (displayed in red)."),
    numbered("Confirm the deletion in the confirmation prompt."),
    spacer(),
    warning("Deleting a user removes all associated data including session history. The audit log retains the user's historical activity entries."),
    spacer(),
    h2("3.7  Force Logout"),
    body("The Force Logout button immediately terminates all active sessions for a user without changing their account status."),
    bullet("All active Blazor Server SignalR circuits for the user are disconnected."),
    bullet("All API refresh tokens are revoked. Access tokens expire within 15 minutes."),
    bullet("The user is redirected to the login page on next interaction."),
    pageBreak(),
  ];
}

function makePermissionGroups() {
  return [
    h1("4. Permission Groups"),
    body("Permission Groups (PGs) define what each non-Superadmin user can see and do in RTM View Shell. Every user (except Superadmin) must belong to exactly one Permission Group."),
    body("Access Permission Groups from the sidebar: ADMINISTRATION → Permission Groups."),
    spacer(),
    h2("4.1  Viewing Permission Groups"),
    screenshot("Permission Groups list — groups with tenant, description, status"),
    spacer(),
    twoColTable(["Column", "Description"], [
      ["Group Name", "Unique name within the tenant."],
      ["Description", "Optional free-text description."],
      ["Tenant", "Tenant the group belongs to (Superadmin sees all tenants)."],
      ["Active", "Green Active badge if the group is enabled."],
    ]),
    spacer(),
    h2("4.2  Creating a Permission Group"),
    numbered("Click + New Group (top right)."),
    numbered("In the dialog that appears, enter a Group Name (required) and optional Description."),
    numbered("The Group active checkbox is selected by default."),
    numbered("Click Save → to create the group."),
    numbered("The group is created with no permissions. Configure permissions using the tabs described in sections 4.4–4.6."),
    spacer(),
    note("A newly created group grants access to nothing. Users assigned to it will not see any menus or dashboards until permissions are explicitly configured."),
    spacer(),
    h2("4.3  Editing a Permission Group"),
    body("Click the Edit button next to any group row. The Edit Group dialog opens with the following tabs:"),
    bullet("Menu — controls which sidebar items are visible."),
    bullet("Screens — controls which dashboards the group can access."),
    bullet("Queues — restricts which call queues are visible in widgets."),
    bullet("Agent Groups — restricts visible agent groups."),
    bullet("Business Units — restricts visible business units."),
    bullet("Super Groups — restricts visible agent super groups."),
    bullet("Info Slots — restricts which info slots the group can manage."),
    spacer(),
    screenshot("Permission Group editor — Menu tab with menu item checkboxes"),
    spacer(),
    h2("4.4  Menu Permissions"),
    body("The Menu tab controls which sidebar navigation items are visible to users in this group."),
    spacer(),
    screenshot("Permission Group editor — Menu tab with menu item checkboxes"),
    spacer(),
    twoColTable(["Menu Item (Permission Key)", "Accessible to Roles"], [
      ["Dashboards (menu.dashboards)", "All roles"],
      ["User Management (menu.users)", "Superadmin, Administrator"],
      ["Permission Groups (menu.permissiongroups)", "Superadmin, Administrator"],
      ["Widget Catalogue (menu.widgetCatalog)", "Superadmin, Administrator, Editor"],
      ["Audit Log (menu.audit)", "Superadmin, Administrator"],
      ["Tenant Settings (menu.tenantSettings)", "Superadmin, Administrator"],
      ["Tenant Management (menu.tenants)", "Superadmin only"],
      ["Info Slots (menu.infoSlots)", "All roles"],
    ]),
    spacer(),
    note("Role-restricted rows are greyed out for roles that are not permitted to see that menu item. Enabling a restricted row for an ineligible role has no effect."),
    warning("Hiding a menu item is cosmetic only. RTM View Shell also enforces permissions at the server side (API level). Users cannot bypass server-side checks by navigating directly to a URL."),
    spacer(),
    h2("4.5  Screen Permissions"),
    body("The Screens tab controls access to individual dashboards."),
    spacer(),
    screenshot("Permission Group editor — Screens tab with View/Edit/Delete columns"),
    spacer(),
    body("Use the dual-pane selector to assign dashboards to the group:"),
    bullet("Items in the Available (left) pane are not currently accessible to this group."),
    bullet("Click the arrow (→) next to a dashboard to move it to Selected (right), granting access."),
    bullet("Use the Search boxes to filter long lists."),
    body("Dashboards marked as Public (IsPublic = true) are accessible to all authenticated tenant users regardless of Permission Group assignment."),
    spacer(),
    note("When a new dashboard is created, its creator's Permission Group automatically receives Full access (View + Edit + Delete)."),
    spacer(),
    h2("4.6  Resource Permissions"),
    body("The Queues, Agent Groups, Business Units, and Super Groups tabs use the same dual-pane selector interface as Screens. They restrict which CC platform objects are visible in widgets for users in this group."),
    spacer(),
    screenshot("Permission Group editor — Queues tab with dual-pane selector"),
    spacer(),
    warning("An empty Selected list means access to all objects of that type is DENIED. To grant access to all queues, move at least one queue to the Selected pane, or leave both panes empty if no restriction is intended — contact your system administrator for the correct policy for your installation."),
    spacer(),
    h2("4.7  Deleting a Permission Group"),
    body("A Permission Group can only be deleted if it has no users assigned to it."),
    numbered("Reassign or remove all users from the group (see Section 3.3)."),
    numbered("Click the Edit button on the group row."),
    numbered("Click Delete in the Edit Group dialog."),
    numbered("Confirm the deletion."),
    spacer(),
    note("If users are still assigned, the Delete button is disabled and a tooltip shows the number of affected users."),
    spacer(),
    body("After a group is deleted, changes to permissions are propagated immediately. Active Blazor sessions are notified via SignalR and re-fetch permissions on the next interaction."),
    pageBreak(),
  ];
}

function makeTenantManagement() {
  return [
    h1("5. Tenant Management"),
    infoBox("Superadmin only", [
      "The Tenant Management section is visible only to Superadmin users.",
      "Access it from the sidebar: PLATFORM → Tenants.",
    ]),
    spacer(),
    h2("5.1  Viewing Tenants"),
    screenshot("Tenant Management list — tenants with slug and status"),
    spacer(),
    twoColTable(["Column", "Description"], [
      ["Name", "Display name of the tenant."],
      ["Slug", "Subdomain identifier used for URL routing. Cannot be changed after creation."],
      ["Status", "Active (green), Suspended (orange), or Deleted (grey)."],
      ["Created", "Date the tenant was provisioned."],
    ]),
    spacer(),
    h3("Creating a New Tenant"),
    numbered("Click + New Tenant (top right)."),
    numbered("Enter Name and Slug. The slug must be unique across the platform."),
    numbered("Click Save → to create the tenant."),
    numbered("The tenant is created with default settings. Configure using the tabs described below."),
    spacer(),
    warning("The Slug value is used for subdomain-based routing and cannot be changed after creation. Choose carefully."),
    spacer(),
    h2("5.2  Editing Tenant — General Tab"),
    body("Click Edit on any tenant row to open the Edit Tenant dialog."),
    spacer(),
    screenshot("Edit Tenant modal — General tab with name, slug, status"),
    spacer(),
    h3("Tenant Status"),
    twoColTable(["Status", "Effect"], [
      ["Active", "Normal operation. All users can log in."],
      ["Suspended", "All logins for this tenant are rejected immediately. Existing sessions are terminated. Data is preserved."],
      ["Deleted", "Tenant is invisible to authentication. Physical data deletion occurs ≥ 30 days after this transition."],
    ]),
    spacer(),
    warning("Suspending a tenant immediately blocks all users. Use this for emergency access revocation. Resuming re-enables all accounts simultaneously."),
    spacer(),
    h2("5.3  Editing Tenant — Settings Tab"),
    body("The Settings tab controls tenant-level policies for passwords, security, widget connectivity, and data retention."),
    spacer(),
    screenshot("Edit Tenant modal — Settings tab with password policy and retention"),
    spacer(),
    h3("Password Policy"),
    twoColTable(["Setting", "Default / Description"], [
      ["Minimum password length", "12 characters. Can be increased per tenant."],
      ["Password expiry (days)", "90 days. Users are prompted to change password after this period."],
    ]),
    spacer(),
    h3("Security"),
    twoColTable(["Setting", "Description"], [
      ["Require 2FA for all users", "When enabled, all users in this tenant must complete email OTP on every login, regardless of their individual 2FA setting."],
      ["Default locale", "BCP-47 locale applied to new users and system emails if no personal preference is set (e.g., en-US, ru-RU, ar-AE)."],
    ]),
    spacer(),
    h3("Data Retention"),
    twoColTable(["Setting", "Default / Description"], [
      ["Audit log retention (days)", "365 days. Older audit records are automatically purged."],
      ["Enable soft-delete for screens", "When enabled, deleted dashboards are moved to a Trash state and retained for the configured period before physical deletion."],
      ["Soft-delete retention (days)", "90 days. Dashboards in Trash are permanently deleted after this period."],
    ]),
    spacer(),
    h2("5.4  Editing Tenant — Agent States Tab"),
    body("The Agent States tab (Superadmin only) maps raw CC platform agent state names to logical display groups used in widgets."),
    spacer(),
    screenshot("Edit Tenant modal — Agent States tab with state-group mapping table"),
    spacer(),
    h3("State Groups"),
    body("State Groups are logical display categories (e.g., Available, Break, On Phone). They are used by widgets to aggregate and colour-code agent states."),
    twoColTable(["Action", "Steps"], [
      ["Add State Group", "Click + Add State Group. Enter a Group Name (unique per tenant). Click Save."],
      ["Edit Group Name", "Click Edit next to the group row. Change the name inline."],
      ["Deactivate Group", "Click Deactivate (Danger Zone). Choose to Reassign states to another active group, or Deactivate all states in this group. Confirm."],
    ]),
    spacer(),
    h3("Agent States"),
    body("Agent States are the raw state codes received from the CC platform (e.g., AVAILABLE, ONPHONE, BREAK). Each state must be mapped to exactly one State Group."),
    twoColTable(["Action", "Steps"], [
      ["Add Agent State", "Click + Add State. Enter the exact Agent State name (case-sensitive, must match CC platform output). Select a State Group. Click Save."],
      ["Edit Mapped Group", "Click Edit on the state row. Change the group via the dropdown."],
      ["Deactivate State", "Click Deactivate. The state and its group mapping are set to inactive."],
    ]),
    spacer(),
    infoBox("Seed data", [
      "Each new tenant is automatically seeded with five standard state definitions:",
      "AVAILABLE → Available  |  ONPHONE → On Phone  |  BREAK → Break",
      "PAPERWORK → Paperwork  |  TRAINING → Training",
      "You can edit or add to these defaults without affecting other tenants.",
    ]),
    pageBreak(),
  ];
}

function makeDashboardManagement() {
  return [
    h1("6. Dashboard Management"),
    body("Dashboard management — creating, editing, and deleting screens — is covered in detail in the Dashboard Management User Guide (B-02)."),
    body("This section provides a summary of the administrator-specific aspects."),
    spacer(),
    h2("6.1  Scope of Access"),
    bullet("Editors can create, edit, and delete dashboards within the permissions defined by their Permission Group."),
    bullet("Administrators can manage any dashboard in their tenant."),
    bullet("Superadmins can manage any dashboard across all tenants."),
    bullet("Viewers can only view dashboards they have been granted access to, or public dashboards."),
    spacer(),
    h2("6.2  Public Dashboards"),
    body("A dashboard marked as Public (IsPublic = true) is accessible to all authenticated users in the tenant, regardless of Permission Group assignment. This is useful for company-wide displays such as wallboards."),
    body("To set a dashboard as public: open Screen Settings from the dashboard list and check the Visible to all tenant users (IsPublic) checkbox."),
    spacer(),
    h2("6.3  Soft Delete"),
    body("When soft-delete is enabled for the tenant (Tenant Settings → Data Retention), deleted dashboards are moved to a Trash state and retained for the configured period (default 90 days). After this period, they are permanently deleted."),
    body("While in Trash, a dashboard is not visible in normal lists but can be restored by an Administrator."),
    spacer(),
    note("Refer to the Dashboard Management User Guide (B-02) for the complete workflow: creating, editing, adding widgets, publishing, and managing screens."),
    pageBreak(),
  ];
}

function makeAuditLog() {
  return [
    h1("7. Audit Log"),
    body("The Audit Log records every security-relevant action performed in RTM View Shell. It is available to Administrators and Superadmins under ADMINISTRATION → Audit Log."),
    warning("The audit log is append-only. Records cannot be edited or deleted through the application. Only the automated retention purge removes old records."),
    spacer(),
    h2("7.1  Reading the Audit Log"),
    screenshot("Audit Log — filter bar and event table with details"),
    spacer(),
    twoColTable(["Column", "Description"], [
      ["TIME", "UTC timestamp of the event (displayed in the user's local timezone)."],
      ["EVENT", "Event type in dot notation, e.g., Login.Success, User.Created, PermissionGroup.Updated."],
      ["RESULT", "Green Success badge, Red Failure badge, or Orange Warning badge."],
      ["USER", "Username of the actor. Empty for unauthenticated events."],
      ["TENANT", "Tenant context of the event. Platform for system-level events."],
      ["DETAILS", "Additional JSON details: subtype, affected object ID, old/new values."],
      ["IP", "Client IP address (extracted from X-Forwarded-For when behind a proxy)."],
    ]),
    spacer(),
    h2("7.2  Filtering and Date Range"),
    bullet("Use the Event type dropdown to filter by category (Login, User, PermissionGroup, Dashboard, Tenant, etc.)."),
    bullet("Use the Result dropdown to show only Success, Failure, or Warning events."),
    bullet("Use the date range pickers to restrict results to a specific period."),
    bullet("The Tenant filter (Superadmin only) restricts events to a specific tenant."),
    spacer(),
    h2("7.3  Key Event Types"),
    twoColTable(["Event", "When it fires"], [
      ["Login.Success", "Successful login (after 2FA if enabled)."],
      ["Login.Failure", "Failed login. Details field contains subtype: WrongPassword, TenantMismatch, AccountLocked, etc."],
      ["Login.Lockout", "Account locked after 5 consecutive failed attempts."],
      ["2FA.CodeSent", "OTP email dispatched to the user."],
      ["2FA.Failure", "Incorrect OTP entered."],
      ["Password.Changed", "User successfully changed their own password."],
      ["Password.Reset", "Administrator initiated a password reset."],
      ["User.Created / Updated / Deactivated", "User account lifecycle events."],
      ["PermissionGroup.PermissionChanged", "Any change to a group's menu, screen, or resource permissions."],
      ["Tenant.Suspended / Deleted", "Superadmin tenant lifecycle actions."],
      ["System.AuditPurged", "Automated retention purge completed."],
    ]),
    spacer(),
    h2("7.4  Exporting Audit Records"),
    body("To export audit records:"),
    numbered("Apply the desired filters and date range."),
    numbered("Click the Export CSV button (top right of the log table)."),
    numbered("Exports are limited to 50,000 records per request. For larger exports, narrow the date range."),
    numbered("Exports exceeding 50,000 records trigger an asynchronous job; a download link is sent to your email when ready."),
    pageBreak(),
  ];
}

function makeRoleReference() {
  return [
    h1("8. Role Permissions Reference"),
    body("Complete role-by-feature access matrix. (PG) = subject to Permission Group restrictions."),
    spacer(),
    new Table({
      width: { size: CONTENT_W, type: WidthType.DXA },
      columnWidths: [Math.round(CONTENT_W * 0.40), Math.round(CONTENT_W * 0.15), Math.round(CONTENT_W * 0.15), Math.round(CONTENT_W * 0.15), CONTENT_W - Math.round(CONTENT_W * 0.40) - 3 * Math.round(CONTENT_W * 0.15)],
      rows: [
        roleMatrixRow("Feature", "Superadmin", "Administrator", "Editor", "Viewer", true),
        roleMatrixRow("Tenant management", "✓", "—", "—", "—"),
        roleMatrixRow("Switch tenants", "✓", "—", "—", "—"),
        roleMatrixRow("User management (tenant)", "✓", "✓", "—", "—"),
        roleMatrixRow("Permission Groups management", "✓", "✓", "—", "—"),
        roleMatrixRow("Tenant settings / SSO config", "✓", "✓", "—", "—"),
        roleMatrixRow("Create / edit / delete dashboard", "✓", "✓", "✓ (PG)", "—"),
        roleMatrixRow("View dashboard", "✓", "✓", "✓ (PG)", "✓ (PG)"),
        roleMatrixRow("View widget catalogue", "✓", "✓", "✓", "—"),
        roleMatrixRow("Manage widget catalogue", "✓", "—", "—", "—"),
        roleMatrixRow("View audit log", "✓", "✓", "—", "—"),
        roleMatrixRow("Agent State Definitions", "✓", "—", "—", "—"),
        roleMatrixRow("Export audit log (CSV)", "✓", "✓", "—", "—"),
      ],
      margins: { top: 120, bottom: 120 }
    }),
    spacer(),
    h2("8.1  Password Policy Rules"),
    body("The following rules apply to all user passwords in RTM View Shell."),
    twoColTable(["Rule", "Requirement"], [
      ["Minimum length", "12 characters (configurable per tenant, can only be increased)."],
      ["Complexity", "Must contain: at least one uppercase letter, one lowercase letter, one digit, one special character."],
      ["History", "Cannot reuse any of the last 10 passwords."],
      ["Expiry", "Must be changed every 90 days (configurable). Users are prompted on login."],
      ["First login", "Temporary password must be changed on first login."],
    ]),
    pageBreak(),
  ];
}

function makeTroubleshooting() {
  return [
    h1("9. Troubleshooting"),
    spacer(),
    twoColTable(["Problem", "Resolution"], [
      ["User cannot log in — shows 'Invalid username or password'",
       "1. Check that the email/username exists. 2. Verify the account Status is Active (User Management → Edit). 3. Check audit log for Login.Failure events and the Details subtype."],
      ["User is locked out",
       "After 5 failed login attempts, the account is locked for 15 minutes. The lockout clears automatically. An Administrator can also unlock by opening Edit User and re-saving (this resets the lockout counter)."],
      ["User does not receive 2FA email",
       "1. Ask the user to check their spam folder. 2. Verify the email address in Edit User. 3. Check the Audit Log for 2FA.CodeSent events — if absent, the email provider may be misconfigured. 4. Verify SMTP settings in Tenant Settings."],
      ["User does not see a menu item they should",
       "Check the Permission Group assigned to the user (Edit User → Group). Open that group's Edit dialog → Menu tab and verify the required menu item is checked."],
      ["Dashboard is not visible to a user",
       "1. Verify the dashboard exists and is not in Trash (soft-deleted). 2. Check the user's Permission Group → Screens tab and verify the dashboard is in the Selected pane. 3. Alternatively, set the dashboard to IsPublic if all tenant users should see it."],
      ["Permission Group cannot be deleted",
       "At least one user is still assigned to the group. Open User Management, filter by that group, and reassign or deactivate those users first."],
      ["Audit log shows Login.Failure with subtype TenantMismatch",
       "The user's account exists in a different tenant than the one they are attempting to log into. This is blocked by design. Verify the user is accessing the correct tenant URL."],
      ["Page becomes unresponsive / Blazor circuit lost",
       "The browser will attempt to reconnect automatically. If reconnection fails, refresh the page. The Blazor Server status bar at the bottom of the page indicates 'Blazor Server · SignalR connected' when connected."],
    ]),
    pageBreak(),
  ];
}

// ─── Build document ──────────────────────────────────────────────────────────

const allChildren = [
  ...makeTitlePage(),
  ...makeRevisionTable(),
  ...makeTableOfContents(),
  ...makeIntroduction(),
  ...makeNavigation(),
  ...makeUserManagement(),
  ...makePermissionGroups(),
  ...makeTenantManagement(),
  ...makeDashboardManagement(),
  ...makeAuditLog(),
  ...makeRoleReference(),
  ...makeTroubleshooting(),
];

const doc = new Document({
  creator: COMPANY,
  title: `${PRODUCT} Administrator's Guide v${DOC_VERSION}`,
  description: "RTM View Shell Administrator's Guide — user management, permission groups, tenant settings, audit log",
  numbering: {
    config: [
      { reference: "bullets",
        levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } }, run: { font: "Arial" } } }] },
      { reference: "numbers",
        levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } }, run: { font: "Arial" } } }] },
    ]
  },
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, font: "Arial", color: C.DARK_NAVY },
        paragraph: { spacing: { before: 360, after: 180 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, font: "Arial", color: C.MID_BLUE },
        paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 24, bold: true, font: "Arial", color: C.DARK_NAVY },
        paragraph: { spacing: { before: 180, after: 60 }, outlineLevel: 2 } },
    ]
  },
  sections: [{
    properties: {
      page: {
        size: { width: PAGE_W, height: PAGE_H },
        margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN }
      }
    },
    headers: {
      default: new Header({
        children: [new Table({
          width: { size: CONTENT_W, type: WidthType.DXA },
          columnWidths: [CONTENT_W - 2880, 2880],
          rows: [new TableRow({ children: [
            new TableCell({
              borders: { ...noBorders, bottom: border },
              width: { size: CONTENT_W - 2880, type: WidthType.DXA },
              children: [new Paragraph({ children: [
                new TextRun({ text: `${PRODUCT} · Administrator's Guide`, font: "Arial", size: 18, color: C.GREY_TEXT })
              ]})]
            }),
            new TableCell({
              borders: { ...noBorders, bottom: border },
              width: { size: 2880, type: WidthType.DXA },
              children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [
                new TextRun({ text: COMPANY, font: "Arial", size: 18, color: C.GREY_TEXT })
              ]})]
            }),
          ]})]
        })]
      })
    },
    footers: {
      default: new Footer({
        children: [new Table({
          width: { size: CONTENT_W, type: WidthType.DXA },
          columnWidths: [CONTENT_W - 1440, 1440],
          rows: [new TableRow({ children: [
            new TableCell({
              borders: { ...noBorders, top: border },
              width: { size: CONTENT_W - 1440, type: WidthType.DXA },
              children: [new Paragraph({ children: [
                new TextRun({ text: `v${DOC_VERSION} · ${DOC_DATE} · Confidential`, font: "Arial", size: 16, color: C.GREY_TEXT })
              ]})]
            }),
            new TableCell({
              borders: { ...noBorders, top: border },
              width: { size: 1440, type: WidthType.DXA },
              children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [
                new TextRun({ children: ["Page ", PageNumber.CURRENT, " of ", PageNumber.TOTAL_PAGES], font: "Arial", size: 16, color: C.GREY_TEXT })
              ]})]
            }),
          ]})]
        })]
      })
    },
    children: allChildren,
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(OUT_FILE, buf);
  console.log(`✅ Written: ${OUT_FILE} (${Math.round(buf.length / 1024)} KB)`);
}).catch(err => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});
