import base64, markdown, re, os

MD="/sessions/inspiring-exciting-noether/mnt/Projects--RTM View Shell/docs/bi/data-connector-diataxis/"
BASE="/sessions/inspiring-exciting-noether/mnt/Projects--RTM View Shell/docs/assets/brand/Logo Files/png/"
LOGO_WHITE="data:image/png;base64,"+base64.b64encode(open(BASE+"White logo - no background.png","rb").read()).decode()
LOGO_COLOR="data:image/png;base64,"+base64.b64encode(open(BASE+"Color logo - no background.png","rb").read()).decode()

def md2html(name):
    src=open(MD+name,encoding="utf-8").read()
    return markdown.markdown(src, extensions=["tables","fenced_code","sane_lists","attr_list"])

CSS="""
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@600;700;800&family=Source+Sans+3:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
:root{ --primary:#0F3D3B; --primary-dark:#0A2B29; --accent:#2ECC71; --text:#23262b; --muted:#6b7280;
  --border:#dfe3e1; --bg:#fff; --cream:#F5F2F2; --gray-100:#f4f6f4; --note:#E6F1EC; --warn:#FBE4D5;
  --fh:'Poppins',Arial,sans-serif; --fb:'Source Sans 3',Arial,sans-serif; --fm:'JetBrains Mono',Consolas,monospace; }
*{box-sizing:border-box;}
@page{ size:8.5in 11in; margin:0; }
@media print{ body{ -webkit-print-color-adjust:exact!important; print-color-adjust:exact!important; } }
body{ margin:0; font-family:var(--fb); color:var(--text); font-size:10.5pt; line-height:1.55; background:#525866; }
.page{ width:8.5in; min-height:11in; padding:0.7in 0.8in 0.95in; background:var(--bg); position:relative; margin:0 auto 0.25in; box-shadow:0 2px 14px rgba(0,0,0,.35); overflow:hidden; }
.page-break{ page-break-before:always; }
/* cover */
.cover-page{ background:linear-gradient(160deg,#0F3D3B 0%,#0A2B29 100%); color:#EAF3EF; }
.cover{ display:flex; flex-direction:column; justify-content:space-between; min-height:9.6in; }
.cover-logo img{ height:0.6in; }
.eyebrow{ text-transform:uppercase; letter-spacing:.18em; font-size:9pt; font-weight:700; color:var(--accent); margin-bottom:.18in; }
.cover-title{ font-family:var(--fh); font-weight:800; font-size:38pt; line-height:1.05; color:#fff; margin:0 0 .12in; }
.cover-sub{ font-size:13.5pt; color:#BFD8CF; max-width:6in; }
.accent-rule{ width:1.1in; height:4px; background:var(--accent); margin:.22in 0; border-radius:2px; }
.stats{ display:flex; gap:.5in; margin-top:.3in; }
.stat .n{ font-family:var(--fh); font-weight:800; font-size:28pt; color:var(--accent); line-height:1; }
.stat .l{ font-size:8.5pt; text-transform:uppercase; letter-spacing:.05em; color:#9fc2b6; margin-top:3px; }
.cover-foot{ border-top:1px solid rgba(255,255,255,.22); padding-top:.14in; font-size:9pt; color:#9fc2b6; display:flex; justify-content:space-between; }
.tagline{ color:var(--accent); font-weight:600; }
/* quadrant badge */
.qbadge{ display:inline-block; font-family:var(--fh); font-weight:700; font-size:9pt; letter-spacing:.04em; text-transform:uppercase;
  color:#fff; padding:3px 12px; border-radius:12px; margin-bottom:.06in; }
.qbadge.tutorial{ background:#2E86AB; } .qbadge.howto{ background:#2ECC71; } .qbadge.reference{ background:#0F3D3B; } .qbadge.explanation{ background:#C9A24B; } .qbadge.compass{ background:#0F3D3B; }
/* rendered markdown */
.md h1{ font-family:var(--fh); font-weight:800; font-size:21pt; color:var(--primary); margin:.04in 0 .02in; }
.md h1::after{ content:''; display:block; width:.7in; height:3px; background:var(--accent); margin-top:8px; }
.md h2{ font-family:var(--fh); font-weight:700; font-size:14pt; color:#0F3D3B; margin:.2in 0 .05in; border-bottom:1px solid var(--border); padding-bottom:3px; }
.md h3{ font-weight:700; font-size:11.5pt; color:var(--primary-dark); margin:.14in 0 .03in; }
.md p{ margin:.05in 0 .08in; }
.md em{ color:#475467; }
.md ul,.md ol{ margin:.04in 0 .1in; padding-left:.26in; } .md li{ margin:.02in 0; }
.md code{ font-family:var(--fm); font-size:9pt; background:var(--gray-100); padding:1px 4px; border-radius:3px; color:var(--primary-dark); }
.md pre{ background:#0f1b2d; border-radius:6px; padding:.12in .16in; overflow:hidden; margin:.08in 0 .12in; }
.md pre code{ font-family:var(--fm); font-size:8.4pt; line-height:1.5; color:#dce6f4; background:none; padding:0; white-space:pre-wrap; word-break:break-word; }
.md blockquote{ border-left:4px solid var(--accent); background:var(--note); margin:.1in 0; padding:.1in .16in; border-radius:0 6px 6px 0; color:#1c3a30; }
.md blockquote p{ margin:.02in 0; }
.md table{ width:100%; border-collapse:collapse; margin:.08in 0 .12in; font-size:8.6pt; table-layout:fixed; }
.md th{ background:var(--primary); color:#fff; text-align:left; padding:5px 8px; font-weight:600; font-size:8.4pt; }
.md td{ padding:4px 8px; border-bottom:1px solid var(--border); vertical-align:top; word-break:break-word; }
.md tbody tr:nth-child(even){ background:var(--gray-100); }
.md a{ color:#1F7A5A; text-decoration:none; font-weight:600; }
.foot{ position:absolute; bottom:.42in; left:.8in; right:.8in; border-top:1px solid var(--border); padding-top:5px; font-size:8pt; color:var(--muted); display:flex; align-items:center; justify-content:space-between; }
.foot .fl img{ height:13px; vertical-align:middle; opacity:.92; }
"""

def foot(label): return f'<div class="foot"><span class="fl"><img src="{LOGO_COLOR}"></span><span>{label} · RTM View Shell Data Connector</span></div>'

H=[f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>RTM View Shell Data Connector — BI Documentation (Diátaxis)</title><style>{CSS}</style></head><body>']

# COVER
H.append('<section class="page cover-page"><div class="cover">')
H.append(f'<div class="cover-logo"><img src="{LOGO_WHITE}" alt="INSIGHTENSE"></div>')
H.append('<div>')
H.append('<div class="eyebrow">BI Documentation · Diátaxis edition · 2026-06-10</div>')
H.append('<h1 class="cover-title">RTM View Shell<br>Data Connector</h1>')
H.append('<div class="accent-rule"></div>')
H.append('<div class="cover-sub">Documentation organised by what you need to do — tutorial, how-to, reference, explanation.</div>')
H.append('<div class="stats">')
for n,l in [("4","Document types"),("5","How-to recipes"),("195","Real-time metrics"),("3","Fact tables")]:
    H.append(f'<div class="stat"><div class="n">{n}</div><div class="l">{l}</div></div>')
H.append('</div></div>')
H.append('<div class="cover-foot"><span>Confidential — prospect BI &amp; Customer-Service teams</span><span class="tagline">AI insights with a sense for excellence</span></div>')
H.append('</div></section>')

# sections: compass + 4 quadrants
secs=[("index.md","compass","Start here · the compass"),
      ("tutorial.md","tutorial","Tutorial · learning-oriented"),
      ("how-to.md","howto","How-to guides · problem-oriented"),
      ("reference.md","reference","Reference · information-oriented"),
      ("explanation.md","explanation","Explanation · understanding-oriented")]
for i,(fn,cls,label) in enumerate(secs):
    pb=" page-break" if i>0 else ""
    H.append(f'<section class="page md{pb}">')
    H.append(f'<div class="qbadge {cls}">{label}</div>')
    H.append(md2html(fn))
    H.append(foot(label.split(" · ")[0]))
    H.append('</section>')

H.append('</body></html>')
open("/tmp/build/RTM_Data_Connector_Diataxis_EN.html","w",encoding="utf-8").write("".join(H))
print("HTML written:", os.path.getsize("/tmp/build/RTM_Data_Connector_Diataxis_EN.html"), "bytes")
