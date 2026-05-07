"""Convert INSTALL.md to INSTALL.docx with professional formatting."""

import re
from pathlib import Path
from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ROOT = Path(__file__).parent.parent
MD_FILE = ROOT / "INSTALL.md"
OUT_FILE = ROOT / "RTM_View_Shell_Installation_Guide.docx"

# ── colour palette ──────────────────────────────────────────────────
BLUE_DARK  = RGBColor(0x1F, 0x3A, 0x5F)   # headings
BLUE_MID   = RGBColor(0x2E, 0x75, 0xB6)   # h2
BLUE_LIGHT = RGBColor(0xBD, 0xD7, 0xEE)   # table header bg
GREY_CODE  = RGBColor(0xF2, 0xF2, 0xF2)   # code block bg
GREEN_OK   = RGBColor(0x37, 0x86, 0x44)   # checkboxes
RED_WARN   = RGBColor(0xC0, 0x39, 0x2B)   # warnings


def set_cell_bg(cell, hex_color: str):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_color)
    tcPr.append(shd)


def add_horizontal_rule(doc: Document):
    p = doc.add_paragraph()
    pPr = p._p.get_or_add_pPr()
    pb = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), "6")
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), "AAAAAA")
    pb.append(bottom)
    pPr.append(pb)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(6)


def configure_styles(doc: Document):
    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(10.5)

    for level, size, color, bold in [
        ("Heading 1", 18, BLUE_DARK, True),
        ("Heading 2", 14, BLUE_MID,  True),
        ("Heading 3", 11, BLUE_DARK, True),
    ]:
        s = doc.styles[level]
        s.font.name = "Calibri"
        s.font.size = Pt(size)
        s.font.color.rgb = color
        s.font.bold = bold
        s.paragraph_format.space_before = Pt(12)
        s.paragraph_format.space_after  = Pt(4)
        if level == "Heading 1":
            s.paragraph_format.space_before = Pt(18)

    # Code style
    if "Code Block" not in [s.name for s in doc.styles]:
        cs = doc.styles.add_style("Code Block", WD_STYLE_TYPE.PARAGRAPH)
    else:
        cs = doc.styles["Code Block"]
    cs.font.name = "Courier New"
    cs.font.size = Pt(9)
    cs.paragraph_format.left_indent  = Cm(0.5)
    cs.paragraph_format.right_indent = Cm(0.5)
    cs.paragraph_format.space_before = Pt(4)
    cs.paragraph_format.space_after  = Pt(4)

    # Inline code style
    if "Inline Code" not in [s.name for s in doc.styles]:
        ic = doc.styles.add_style("Inline Code", WD_STYLE_TYPE.CHARACTER)
    else:
        ic = doc.styles["Inline Code"]
    ic.font.name = "Courier New"
    ic.font.size = Pt(9.5)
    ic.font.color.rgb = RGBColor(0xC7, 0x25, 0x4E)


def add_title_page(doc: Document, title: str, subtitle: str):
    doc.add_paragraph()
    doc.add_paragraph()
    t = doc.add_paragraph(title)
    t.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = t.runs[0]
    run.font.size = Pt(28)
    run.font.bold = True
    run.font.color.rgb = BLUE_DARK

    s = doc.add_paragraph(subtitle)
    s.alignment = WD_ALIGN_PARAGRAPH.CENTER
    s.runs[0].font.size = Pt(13)
    s.runs[0].font.color.rgb = RGBColor(0x70, 0x70, 0x70)

    doc.add_paragraph()
    add_horizontal_rule(doc)
    doc.add_page_break()


def add_code_block(doc: Document, code: str, lang: str = ""):
    # Shaded paragraph simulating a code block
    p = doc.add_paragraph(style="Code Block")
    # shade background
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), "F2F2F2")
    pPr.append(shd)

    for line in code.split("\n"):
        if p.text == "":
            p.text = line
        else:
            p.add_run("\n" + line)
    p.paragraph_format.keep_together = True


def inline_code(run_text: str, para):
    """Add an inline code run to an existing paragraph."""
    run = para.add_run(run_text)
    run.style = "Inline Code"
    return run


def add_paragraph_with_inline_code(doc: Document, text: str, style: str = "Normal"):
    """Add a paragraph, converting `backtick` spans to Inline Code runs."""
    para = doc.add_paragraph(style=style)
    parts = re.split(r"`([^`]+)`", text)
    for i, part in enumerate(parts):
        if i % 2 == 0:
            # plain text — handle **bold** inside
            bold_parts = re.split(r"\*\*([^*]+)\*\*", part)
            for j, bp in enumerate(bold_parts):
                r = para.add_run(bp)
                r.bold = (j % 2 == 1)
        else:
            inline_code(part, para)
    return para


def parse_table(lines: list[str]) -> list[list[str]]:
    rows = []
    for line in lines:
        if re.match(r"\s*\|[-:| ]+\|\s*$", line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        rows.append(cells)
    return rows


def add_table_to_doc(doc: Document, rows: list[list[str]]):
    if not rows:
        return
    cols = max(len(r) for r in rows)
    table = doc.add_table(rows=len(rows), cols=cols)
    table.style = "Table Grid"
    for i, row_data in enumerate(rows):
        for j, cell_text in enumerate(row_data):
            if j >= cols:
                break
            cell = table.cell(i, j)
            cell.text = cell_text.replace("**", "")
            if i == 0:
                set_cell_bg(cell, "BDD7EE")
                for para in cell.paragraphs:
                    for run in para.runs:
                        run.bold = True
                        run.font.color.rgb = BLUE_DARK
    doc.add_paragraph()


def process_markdown(doc: Document, md_text: str):
    lines = md_text.split("\n")
    i = 0
    in_code = False
    code_lines: list[str] = []
    code_lang = ""
    table_lines: list[str] = []
    in_table = False

    while i < len(lines):
        line = lines[i]

        # ── Code fence ──────────────────────────────────────────────
        if line.startswith("```"):
            if not in_code:
                in_code = True
                code_lang = line[3:].strip()
                code_lines = []
            else:
                add_code_block(doc, "\n".join(code_lines), code_lang)
                in_code = False
                code_lines = []
            i += 1
            continue

        if in_code:
            code_lines.append(line)
            i += 1
            continue

        # ── Table ───────────────────────────────────────────────────
        if line.startswith("|"):
            if not in_table:
                in_table = True
                table_lines = []
            table_lines.append(line)
            i += 1
            continue
        elif in_table:
            add_table_to_doc(doc, parse_table(table_lines))
            in_table = False
            table_lines = []

        # ── Headings ────────────────────────────────────────────────
        m = re.match(r"^(#{1,3})\s+(.*)", line)
        if m:
            level = len(m.group(1))
            text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", m.group(2))  # strip links
            style = f"Heading {level}"
            if level == 1 and text != "RTM View Shell — Installation Guide":
                add_horizontal_rule(doc)
            doc.add_heading(text, level=level)
            i += 1
            continue

        # ── Horizontal rule ─────────────────────────────────────────
        if re.match(r"^---+\s*$", line):
            add_horizontal_rule(doc)
            i += 1
            continue

        # ── Blank line ──────────────────────────────────────────────
        if not line.strip():
            i += 1
            continue

        # ── Blockquote ──────────────────────────────────────────────
        if line.startswith("> "):
            text = line[2:]
            p = add_paragraph_with_inline_code(doc, text)
            p.paragraph_format.left_indent = Cm(1)
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after  = Pt(2)
            for run in p.runs:
                run.italic = True
                run.font.color.rgb = RGBColor(0x55, 0x55, 0x55)
            i += 1
            continue

        # ── Ordered list ────────────────────────────────────────────
        m = re.match(r"^(\d+)\.\s+(.*)", line)
        if m:
            text = m.group(2)
            p = add_paragraph_with_inline_code(doc, text, style="List Number")
            p.paragraph_format.left_indent  = Cm(1)
            p.paragraph_format.first_line_indent = Cm(-0.5)
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after  = Pt(1)
            i += 1
            continue

        # ── Unordered list / checkbox ────────────────────────────────
        m = re.match(r"^(\s*)[-*]\s+(.*)", line)
        if m:
            indent_level = len(m.group(1)) // 2
            text = m.group(2)
            is_check = text.startswith("[ ]") or text.startswith("[x]")
            if is_check:
                done = text.startswith("[x]")
                text = ("☑ " if done else "☐ ") + text[4:]
            p = add_paragraph_with_inline_code(doc, text, style="List Bullet")
            p.paragraph_format.left_indent  = Cm(0.8 + indent_level * 0.5)
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after  = Pt(1)
            if is_check and done:
                for run in p.runs:
                    run.font.color.rgb = GREEN_OK
            i += 1
            continue

        # ── Normal paragraph ─────────────────────────────────────────
        text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)  # strip links
        add_paragraph_with_inline_code(doc, text)
        i += 1

    # flush table at end
    if in_table:
        add_table_to_doc(doc, parse_table(table_lines))


def main():
    md_text = MD_FILE.read_text(encoding="utf-8")

    doc = Document()

    # Page margins
    for section in doc.sections:
        section.top_margin    = Cm(2.5)
        section.bottom_margin = Cm(2.5)
        section.left_margin   = Cm(2.5)
        section.right_margin  = Cm(2.5)

    configure_styles(doc)
    add_title_page(doc,
        "RTM View Shell",
        "Installation & Deployment Guide — Windows Server / IIS")

    # Skip the H1 title line from the markdown (already on title page)
    lines = md_text.split("\n")
    body_start = next(
        (i for i, l in enumerate(lines) if l.startswith("## ")), 0)
    body_md = "\n".join(lines[body_start:])

    process_markdown(doc, body_md)

    doc.save(OUT_FILE)
    print(f"Saved: {OUT_FILE}")


if __name__ == "__main__":
    main()
