#!/usr/bin/env python3
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


OUT = Path(__file__).parent / "docs" / "AI_PACKAGE_HALLUCINATION_BRIEF.pdf"
pdfmetrics.registerFont(TTFont("ReportSans", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("ReportSans-Bold", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"))
pdfmetrics.registerFontFamily("ReportSans", normal="ReportSans", bold="ReportSans-Bold", italic="ReportSans", boldItalic="ReportSans-Bold")

class EmbeddedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, initialFontName="ReportSans", **kwargs)

    def setFont(self, name, size, *args, **kwargs):
        name = {"Helvetica": "ReportSans", "Helvetica-Bold": "ReportSans-Bold"}.get(name, name)
        return super().setFont(name, size, *args, **kwargs)
PAGE = landscape(A4)
W, H = PAGE

NAVY = HexColor("#081522")
PANEL = HexColor("#102638")
PANEL_2 = HexColor("#17364B")
CYAN = HexColor("#31D6D2")
BLUE = HexColor("#4F8CFF")
VIOLET = HexColor("#A88BFF")
LIME = HexColor("#A7E06D")
AMBER = HexColor("#FFBF69")
RED = HexColor("#FF6B6B")
MUTED = HexColor("#9FB5C5")
TEXT = HexColor("#EAF4F8")
INK = HexColor("#14202A")
LIGHT_BG = HexColor("#F4F7F9")
LIGHT_PANEL = white
LIGHT_MUTED = HexColor("#526876")
GRID = HexColor("#D9E2E7")


def rect(c, x, y, w, h, fill, radius=4, stroke=None, sw=1):
    c.setLineWidth(sw)
    if stroke:
        c.setStrokeColor(stroke)
    else:
        c.setStrokeColor(fill)
    c.setFillColor(fill)
    c.roundRect(x, y, w, h, radius, fill=1, stroke=1 if stroke else 0)


def ptext(c, text, x, y, w, h, size=10, color=TEXT, leading=None, bold=False, align=TA_LEFT):
    font = "ReportSans-Bold" if bold else "ReportSans"
    style = ParagraphStyle(
        "p",
        fontName=font,
        fontSize=size,
        leading=leading or size * 1.25,
        textColor=color,
        alignment=align,
        spaceAfter=0,
    )
    p = Paragraph(text, style)
    _, ph = p.wrap(w, h)
    if ph > h + 0.2:
        raise ValueError(f"Text exceeds layout height: {text[:80]} ({ph:.1f} > {h:.1f})")
    p.drawOn(c, x, y + h - ph)
    return ph


def label(c, text, x, y, color=CYAN):
    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(color)
    c.drawString(x, y, text.upper())


def footer(c, page_no):
    c.setFont("Helvetica-Bold", 7)
    c.setFillColor(MUTED if page_no == 1 else LIGHT_MUTED)
    c.drawRightString(W - 14 * mm, 5.2 * mm, f"0{page_no} / 02")


def stat_card(c, x, y, w, number, caption, accent):
    rect(c, x, y, w, 30 * mm, PANEL, radius=5, stroke=HexColor("#24465A"), sw=0.7)
    c.setFillColor(accent)
    c.setFont("Helvetica-Bold", 21)
    c.drawString(x + 5 * mm, y + 18 * mm, number)
    ptext(c, caption, x + 5 * mm, y + 3 * mm, w - 10 * mm, 12 * mm, size=8, color=MUTED, leading=10.5)


def flow_box(c, x, y, w, h, n, title, body, accent):
    rect(c, x, y, w, h, PANEL_2, radius=5, stroke=accent, sw=1.1)
    c.setFillColor(accent)
    c.circle(x + 6.5 * mm, y + h - 6.5 * mm, 3.7 * mm, fill=1, stroke=0)
    c.setFillColor(NAVY)
    c.setFont("Helvetica-Bold", 8)
    c.drawCentredString(x + 6.5 * mm, y + h - 7.5 * mm, str(n))
    ptext(c, title, x + 12 * mm, y + h - 11 * mm, w - 15 * mm, 8 * mm, size=8.1, color=white, bold=True)
    ptext(c, body, x + 5 * mm, y + 4 * mm, w - 10 * mm, h - 17 * mm, size=8.3, color=MUTED, leading=11)


def event_card(c, x, y, w, title, meaning, accent):
    rect(c, x, y, w, 27 * mm, HexColor("#0C1D2A"), radius=4, stroke=accent, sw=0.8)
    c.setFillColor(accent)
    c.setFont("Helvetica-Bold", 8.5)
    c.drawString(x + 4 * mm, y + 18 * mm, title)
    ptext(c, meaning, x + 4 * mm, y + 4 * mm, w - 8 * mm, 10 * mm, size=8.3, color=MUTED, leading=11)


def page_one(c):
    c.setFillColor(NAVY)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(CYAN)
    c.rect(0, H - 4 * mm, W, 4 * mm, fill=1, stroke=0)

    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 23)
    c.drawString(14 * mm, H - 29 * mm, "AI PACKAGE HALLUCINATION TO ROOT")
    rect(c, W - 82 * mm, H - 38 * mm, 68 * mm, 22 * mm, PANEL, radius=6, stroke=CYAN, sw=1)
    label(c, "Validated lab baseline", W - 77 * mm, H - 22 * mm, color=LIME)
    ptext(c, "react-codeshift 1.3.1<br/>Ubuntu 22.04 + needrestart 3.5-5ubuntu2.1", W - 77 * mm, H - 36 * mm, 58 * mm, 12 * mm, size=8.5, color=white, leading=10.5, bold=True)

    gap = 4 * mm
    sx = 14 * mm
    sw = (W - 28 * mm - 3 * gap) / 4
    sy = H - 83 * mm
    stat_card(c, sx, sy, sw, "237", "GitHub repositories referenced react-codeshift before the package existed.", CYAN)
    stat_card(c, sx + sw + gap, sy, sw, "576K", "Code samples studied across 16 LLMs at USENIX Security 2025.", BLUE)
    stat_card(c, sx + 2 * (sw + gap), sy, sw, "5.2% / 21.7%", "At least average hallucination rates reported for commercial / open-source models.", VIOLET)
    stat_card(c, sx + 3 * (sw + gap), sy, sw, "7.8 HIGH", "Ubuntu CVSS for CVE-2024-48990 local privilege escalation.", AMBER)

    label(c, "Attack chain", 14 * mm, sy - 9 * mm)
    fy = sy - 61 * mm
    fw = (W - 28 * mm - 5 * 3 * mm) / 6
    titles = [
        ("AI instruction", "Skill or generated guidance contains a plausible but unverified package name.", CYAN),
        ("Name claimed", "The prepared name is published to the isolated npm-compatible registry.", BLUE),
        ("npx execution", "The developer or agent resolves and executes the package as a normal user.", VIOLET),
        ("Fixture armed", "A visible developer Python process preserves the controlled import condition.", LIME),
        ("APT scans", "A later administrative package transaction starts vulnerable needrestart.", AMBER),
        ("Root proof", "The marker runs with EUID 0 and activates visible, bounded state telemetry.", RED),
    ]
    for i, (title, body, accent) in enumerate(titles):
        x = 14 * mm + i * (fw + 3 * mm)
        flow_box(c, x, fy, fw, 46 * mm, i + 1, title, body, accent)
        if i < 5:
            c.setStrokeColor(MUTED)
            c.setLineWidth(1)
            c.line(x + fw + 0.5 * mm, fy + 23 * mm, x + fw + 2.5 * mm, fy + 23 * mm)

    label(c, "What the receiver proves", 14 * mm, fy - 9 * mm)
    ey = fy - 41 * mm
    ew = (W - 28 * mm - 2 * 4 * mm) / 3
    event_card(c, 14 * mm, ey, ew, "armed-alive", "Package execution and resident state under the developer UID/EUID.", LIME)
    event_card(c, 14 * mm + ew + 4 * mm, ey, ew, "needrestart-root-execution", "The vulnerable scanner loaded the marker with UID/EUID 0.", RED)
    event_card(c, 14 * mm + 2 * (ew + 4 * mm), ey, ew, "root-persistence-alive", "The visible root-owned state service remains active after the transition.", AMBER)

    footer(c, 1)


def section_title(c, title, x, y, w, accent=CYAN):
    c.setFillColor(accent)
    c.rect(x, y - 1.5 * mm, 8 * mm, 1.5 * mm, fill=1, stroke=0)
    c.setFillColor(INK)
    c.setFont("Helvetica-Bold", 11.5)
    c.drawString(x, y - 7 * mm, title)
    c.setStrokeColor(GRID)
    c.line(x, y - 9.5 * mm, x + w, y - 9.5 * mm)


def evidence_row(c, x, y, w, title, items, accent):
    rect(c, x, y, w, 26 * mm, LIGHT_PANEL, radius=4, stroke=GRID, sw=0.7)
    c.setFillColor(accent)
    c.rect(x, y, 2.2 * mm, 26 * mm, fill=1, stroke=0)
    ptext(c, title, x + 5 * mm, y + 15.5 * mm, w - 9 * mm, 7 * mm, size=8.7, color=INK, bold=True)
    ptext(c, items, x + 5 * mm, y + 3 * mm, w - 9 * mm, 12 * mm, size=8, color=LIGHT_MUTED, leading=10.5)


def research_case(c, x, y, w, h, number, title, body, accent):
    c.setFillColor(accent)
    c.circle(x + 7 * mm, y + h - 7 * mm, 3.2 * mm, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 7.2)
    c.drawCentredString(x + 7 * mm, y + h - 8 * mm, str(number))
    ptext(c, title, x + 13 * mm, y + h - 12 * mm, w - 18 * mm, 8 * mm,
          size=8.2, color=INK, leading=9.8, bold=True)
    ptext(c, body, x + 13 * mm, y + 3 * mm, w - 18 * mm, h - 16 * mm,
          size=6.8, color=LIGHT_MUTED, leading=8.2)


def compact_reference(c, text, url, x, y, w):
    linked = f'<link href="{escape(url)}" color="#14202A"><b>{escape(text)}</b></link>'
    ptext(c, linked, x, y, w, 6.8 * mm, size=5.5, color=INK, leading=6.8)


def page_two(c):
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(NAVY)
    c.rect(0, H - 28 * mm, W, 28 * mm, fill=1, stroke=0)
    label(c, "DFIR and validation guide", 14 * mm, H - 10 * mm, color=CYAN)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 21)
    c.drawString(14 * mm, H - 21 * mm, "FROM CLAIM TO EVIDENCE")
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 8.5)
    c.drawRightString(W - 14 * mm, H - 19 * mm, "External research + vendor advisory + isolated lab observations")

    col_gap = 6 * mm
    left = 14 * mm
    col_w = (W - 28 * mm - 2 * col_gap) / 3
    mid = left + col_w + col_gap
    right = mid + col_w + col_gap
    top = H - 36 * mm

    section_title(c, "Real-world evidence", left, top, col_w, CYAN)
    evidence_y = top - 129 * mm
    evidence_h = 116 * mm
    rect(c, left, evidence_y, col_w, evidence_h, LIGHT_PANEL, radius=5, stroke=GRID, sw=0.7)

    inner_top = evidence_y + evidence_h - 3 * mm
    case_1_y = inner_top - 31 * mm
    research_case(
        c, left, case_1_y, col_w, 31 * mm, 1,
        "react-codeshift - exact precedent [1]",
        "Before the package existed, AI-generated skills referenced it across 237 repositories. After defensive registration, sustained downloads showed active resolution attempts. This lab reproduces the same package name and npx pattern.",
        CYAN,
    )

    case_2_y = case_1_y - 2 * mm - 28 * mm
    c.setStrokeColor(GRID)
    c.line(left + 13 * mm, case_1_y - 1 * mm, left + col_w - 5 * mm, case_1_y - 1 * mm)
    research_case(
        c, left, case_2_y, col_w, 28 * mm, 2,
        "huggingface-cli - independent validation [2]",
        "After models repeatedly hallucinated the name, Lasso registered an empty package. It drew 30,000+ authentic downloads in three months and appeared in Alibaba documentation.",
        BLUE,
    )

    case_3_y = case_2_y - 2 * mm - 28 * mm
    c.setStrokeColor(GRID)
    c.line(left + 13 * mm, case_2_y - 1 * mm, left + col_w - 5 * mm, case_2_y - 1 * mm)
    research_case(
        c, left, case_3_y, col_w, 28 * mm, 3,
        "unused-imports - malicious analogue [3]",
        "Confirmed malware occupied a plausible hallucinated npm name and still drew about 233 weekly downloads. AI-driven installation is plausible, not proven.",
        RED,
    )

    nx_y = case_3_y - 2 * mm - 17 * mm
    rect(c, left + 4 * mm, nx_y, col_w - 8 * mm, 17 * mm, HexColor("#EEF2F4"), radius=3)
    label(c, "Related DFIR reference", left + 8 * mm, nx_y + 11.7 * mm, color=LIGHT_MUTED)
    ptext(c, "Nx S1ngularity [4] is retained only as a post-install DFIR analogue for npm cache, shell-profile and credential artifacts.",
          left + 8 * mm, nx_y + 2 * mm, col_w - 16 * mm, 8.5 * mm,
          size=6.5, color=LIGHT_MUTED, leading=7.8)

    section_title(c, "CVE and lab proof", mid, top, col_w, VIOLET)
    rect(c, mid, top - 75 * mm, col_w, 62 * mm, LIGHT_PANEL, radius=5, stroke=GRID, sw=0.7)
    label(c, "Vendor fact", mid + 5 * mm, top - 20 * mm, color=HexColor("#BC3B46"))
    ptext(c, "Ubuntu describes CVE-2024-48990 as attacker-controlled PYTHONPATH leading needrestart to execute arbitrary code as root. Jammy is fixed in 3.5-5ubuntu2.2.", mid + 5 * mm, top - 43 * mm, col_w - 10 * mm, 20 * mm, size=8.2, color=INK, leading=10.2)
    label(c, "Researcher disclosure", mid + 5 * mm, top - 48 * mm, color=HexColor("#7053BA"))
    ptext(c, "Qualys documents that needrestart reads a local process environment and starts Python during interpreter scanning. The disclosure explains why an unprivileged process can influence a root scanner.", mid + 5 * mm, top - 70 * mm, col_w - 10 * mm, 19 * mm, size=8.2, color=INK, leading=10.2)

    rect(c, mid, top - 129 * mm, col_w, 48 * mm, HexColor("#EAF7F1"), radius=5, stroke=HexColor("#B8DED1"), sw=0.8)
    label(c, "Our isolated observation", mid + 5 * mm, top - 89 * mm, color=HexColor("#218C74"))
    ptext(c, "Version 1.3.1 produced a developer event, then an EUID 0 marker after an ordinary APT transaction. The implementation used fixed-destination telemetry and created no shell, user, key, credential collector, or command channel.", mid + 5 * mm, top - 124 * mm, col_w - 10 * mm, 31 * mm, size=8.2, color=INK, leading=10.3)

    section_title(c, "ATT&CK and defensive action", right, top, col_w, AMBER)
    rect(c, right, top - 63 * mm, col_w, 50 * mm, LIGHT_PANEL, radius=5, stroke=GRID, sw=0.7)
    ptext(c, "<b>T1195.002</b> - Compromise Software Supply Chain<br/><b>T1068</b> - Exploitation for Privilege Escalation<br/><b>T1543.002</b> - Systemd Service", right + 5 * mm, top - 55 * mm, col_w - 10 * mm, 38 * mm, size=8.5, color=INK, leading=13)

    rect(c, right, top - 129 * mm, col_w, 60 * mm, LIGHT_PANEL, radius=5, stroke=GRID, sw=0.7)
    label(c, "Priority controls", right + 5 * mm, top - 78 * mm, color=HexColor("#976011"))
    ptext(c, "1. Verify package existence, owner, age and provenance before execution.<br/>2. Treat agent skills and generated commands as code requiring review.<br/>3. Pin registries and dependencies; restrict package-manager egress.<br/>4. Patch needrestart or disable interpreter scanning per vendor guidance.<br/>5. Correlate package execution, unusual child processes, user services, APT and root network events.", right + 5 * mm, top - 124 * mm, col_w - 10 * mm, 41 * mm, size=7.8, color=INK, leading=9.8)

    ry = 17 * mm
    c.setStrokeColor(GRID)
    c.line(14 * mm, ry + 25 * mm, W - 14 * mm, ry + 25 * mm)
    label(c, "References", 14 * mm, ry + 21 * mm, color=BLUE)
    refs = [
        ("[1] Aikido: react-codeshift investigation (2026)", "https://www.aikido.dev/blog/agent-skills-spreading-hallucinated-npx-commands"),
        ("[2] Lasso: AI Package Hallucinations (2024)", "https://www.lasso.security/blog/ai-package-hallucinations"),
        ("[3] Aikido: Slopsquatting and unused-imports (2026)", "https://www.aikido.dev/blog/slopsquatting-ai-package-hallucination-attacks"),
        ("[4] Nx: S1ngularity postmortem (2025)", "https://nx.dev/blog/s1ngularity-postmortem"),
        ("[5] Spracklen et al.: USENIX Security 2025", "https://www.usenix.org/conference/usenixsecurity25/presentation/spracklen"),
        ("[6] Ubuntu: CVE-2024-48990 advisory", "https://ubuntu.com/security/CVE-2024-48990"),
        ("[7] Qualys: needrestart technical advisory (2024)", "https://www.qualys.com/2024/11/19/needrestart/needrestart.txt"),
        ("[8] MITRE ATT&CK: T1195.002, T1068, T1543.002", "https://attack.mitre.org"),
    ]
    chunks = [refs[0:3], refs[3:6], refs[6:8]]
    for x, items in zip([left, mid, right], chunks):
        for index, (ref_text, ref_url) in enumerate(items):
            ref_y = ry + 13 * mm - (index + 1) * 7.2 * mm
            compact_reference(c, ref_text, ref_url, x, ref_y, col_w)

    footer(c, 2)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    c = EmbeddedCanvas(str(OUT), pagesize=PAGE, pageCompression=1)
    c.setTitle("AI Package Hallucination Supply-Chain Lab Brief")
    c.setAuthor("Package Lab")
    c.setSubject("AI package hallucination, CVE-2024-48990, and DFIR evidence")
    page_one(c)
    c.showPage()
    page_two(c)
    c.showPage()
    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
