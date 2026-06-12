const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, TableOfContents, HeadingLevel,
  BorderStyle, WidthType, ShadingType, VerticalAlign, PageNumber, PageBreak, PageOrientation, ImageRun
} = require('docx');
const _logo=()=>fs.readFileSync('/tmp/build/logo_color.png');
const LOGO=()=>new ImageRun({ type:'png', data:_logo(), transformation:{width:300,height:71}, altText:{title:'INSIGHTENSE',description:'INSIGHTENSE logo',name:'INSIGHTENSE'} });
const LOGOSM=()=>new ImageRun({ type:'png', data:_logo(), transformation:{width:72,height:17}, altText:{title:'INSIGHTENSE',description:'INSIGHTENSE logo',name:'INSIGHTENSE'} });

// ---------- palette ----------
const NAVY = "1F3864", BLUE = "2E5496", LITE = "D9E2F3", CODEBG = "F3F4F6",
      ZEBRA = "F6F9FC", HEADW = "FFFFFF", WARN = "FBE4D5", OKG = "E2EFDA";
const CW = 9360; // content width US Letter, 1" margins
const thin = { style: BorderStyle.SINGLE, size: 1, color: "BFBFBF" };
const cellBorders = { top: thin, bottom: thin, left: thin, right: thin };

// ---------- helpers ----------
const H1 = t => new Paragraph({ heading: HeadingLevel.HEADING_1, keepNext:true, children:[new TextRun(t)] });
const H2 = t => new Paragraph({ heading: HeadingLevel.HEADING_2, keepNext:true, children:[new TextRun(t)] });
const H3 = t => new Paragraph({ heading: HeadingLevel.HEADING_3, keepNext:true, children:[new TextRun(t)] });

function runs(parts){ // parts: string | {t,b,i,code,color}
  return parts.map(p=>{
    if (typeof p === 'string') return new TextRun(p);
    return new TextRun({ text:p.t, bold:!!p.b, italics:!!p.i, color:p.color||undefined,
      font: p.code? "Courier New": undefined, size: p.code? 19: undefined });
  });
}
const P = (parts, opt={}) => { const _arr = Array.isArray(parts)? parts : [parts];
  const _txt = _arr.map(p => typeof p==='string'? p : ((p&&p.t)||'')).join('').trim();
  return new Paragraph({ spacing:{after:120, ...(opt.spacing||{})}, keepNext: _txt.endsWith(':'),
    children: Array.isArray(parts)? runs(parts): [new TextRun(String(parts))], ...opt }); };

function bullets(items){ return items.map((it,ix) => new Paragraph({
  numbering:{reference:"b", level:0}, spacing:{after:60}, keepNext: ix < items.length-1,
  children: Array.isArray(it)? runs(it): [new TextRun(String(it))] })); }
function nums(items){ return items.map((it,ix) => new Paragraph({
  numbering:{reference:"n", level:0}, spacing:{after:60}, keepNext: ix < items.length-1,
  children: Array.isArray(it)? runs(it): [new TextRun(String(it))] })); }

// callout box (single cell) - kind: 'warn'|'ok'|'note'
function callout(kind, title, lines){
  const fill = kind==='warn'?WARN:kind==='ok'?OKG:LITE;
  const kids=[];
  if(title) kids.push(new Paragraph({spacing:{after:60}, children:[new TextRun({text:title,bold:true})]}));
  lines.forEach(l=>kids.push(new Paragraph({spacing:{after:40}, children: Array.isArray(l)?runs(l):[new TextRun(String(l))]})));
  return new Table({ width:{size:CW,type:WidthType.DXA}, columnWidths:[CW], rows:[
    new TableRow({cantSplit:true, children:[ new TableCell({ borders:cellBorders, width:{size:CW,type:WidthType.DXA},
      shading:{fill, type:ShadingType.CLEAR}, margins:{top:100,bottom:100,left:160,right:160}, children:kids }) ]}) ]});
}

// code block (monospace, shaded, one cell)
function code(lines){
  const kids = lines.map(l => new Paragraph({ spacing:{after:0},
    children:[new TextRun({ text: l===""? " ":l, font:"Courier New", size:18 })] }));
  return new Table({ width:{size:CW,type:WidthType.DXA}, columnWidths:[CW], rows:[
    new TableRow({cantSplit:true, children:[ new TableCell({ borders:cellBorders, width:{size:CW,type:WidthType.DXA},
      shading:{fill:CODEBG,type:ShadingType.CLEAR}, margins:{top:80,bottom:80,left:140,right:140}, children:kids }) ]}) ]});
}

// generic table. headers:[], rows:[[...]], widths:[], opts:{zebra, headFill}
function tbl(headers, rows, widths, opts={}){
  const headFill = opts.headFill||NAVY;
  const cell = (txt, w, o={}) => new TableCell({ borders:cellBorders, width:{size:w,type:WidthType.DXA},
    shading: o.fill? {fill:o.fill,type:ShadingType.CLEAR}:undefined, verticalAlign:VerticalAlign.CENTER,
    margins:{top:60,bottom:60,left:110,right:110},
    children:[ new Paragraph({ keepNext: !!o.keepNext, children:[ new TextRun({ text:String(txt),
      bold:!!o.bold, color:o.color||undefined, font:o.code?"Courier New":undefined,
      size:o.code?18:(o.small?18:undefined) }) ] }) ] });
  const headRow = new TableRow({ tableHeader:true, cantSplit:true, children: headers.map((h,i)=>
    cell(h, widths[i], {bold:true, color:HEADW, fill:headFill, keepNext:true})) });
  const dataRows = rows.map((r,ri)=> new TableRow({ cantSplit:true, children: r.map((c,i)=>{
    const o = { fill: (opts.zebra && ri%2===1)? ZEBRA: undefined, keepNext: ri < rows.length-1 };
    if(opts.codeCols && opts.codeCols.includes(i)) o.code=true;
    if(opts.boldCol0 && i===0) o.bold=true;
    return cell(c, widths[i], o);
  })}));
  return new Table({ width:{size:CW,type:WidthType.DXA}, columnWidths:widths, rows:[headRow,...dataRows] });
}

// data-dictionary table: Column|Type|Key|Meaning
function dict(rows){
  return tbl(["Column","Type","Key","Meaning"], rows, [2150,1450,820,4940],
    {zebra:true, codeCols:[0], boldCol0:false});
}

const SP = (h=80) => new Paragraph({spacing:{after:h}, children:[new TextRun("")]});

// =====================================================================
const body = [];

// ---------- TITLE PAGE ----------
body.push(new Paragraph({ spacing:{before:900, after:120}, alignment:AlignmentType.CENTER, children:[ LOGO() ] }));
body.push(new Paragraph({ spacing:{before:160, after:120}, alignment:AlignmentType.CENTER,
  children:[new TextRun({text:"Project Launch Runbook", bold:true, size:46, color:NAVY})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:80},
  children:[new TextRun({text:"Cowork multi-session project bootstrap", bold:true, size:32, color:BLUE})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:80},
  children:[new TextRun({text:"From “create a project” to the coordinator’s “team up & ready” report", italics:true, size:24})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:600, after:40},
  children:[new TextRun({text:"For the Operator, Coordinator, and Curator", size:24})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:40},
  children:[new TextRun({text:"Edition EN · 2026-06-11 · Reusable, product-agnostic methodology", size:22, color:"595959"})] }));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Document revision history"));
body.push(P("This table lists the revision history of this document."));
body.push(tbl(["Version","Date","Summary of changes","Product release ID","Shipped-with (commit/barrier)"],
  [["1.0","2026-06-11","initial runbook","RTM-REL-2026.06","(pending push)"]],
  [1100,1500,2260,2150,2350]));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(new Paragraph({ heading:HeadingLevel.HEADING_1, keepNext:true, children:[new TextRun("Contents")] }));
body.push(new TableOfContents("Contents", { hyperlink:true, headingStyleRange:"1-3" }));
body.push(new Paragraph({ children:[new PageBreak()] }));

// ---------- phase helper ----------
function phase(title, goal, who, actions, artifacts, gate, go){
  body.push(H2(title));
  body.push(P([{t:"Goal: ",b:true}, goal]));
  body.push(P([{t:"Who: ",b:true}, who]));
  body.push(P([{t:"Actions:",b:true}]));
  body.push(...bullets(actions));
  body.push(P([{t:"Artifacts: ",b:true}, artifacts]));
  body.push(callout("note","Verification gate", [gate]));
  body.push(P([{t:"Operator GO: ",b:true}, go]));
}

body.push(H1("Purpose & audience"));
body.push(P("This runbook captures the proven process for launching a new Cowork project as a multi-session team: one operator, one coordinator, an optional external curator, and a set of specialist sessions. It exists so a new project can reach a credible “team up & ready” state quickly and safely, with the same discipline that keeps a long-running project honest."));
body.push(P([{t:"Audience: ",b:true},"the Operator (directs the project), the Coordinator (owns the bus and the gates), the Curator (external source-of-truth / certifier, when present), and specialists being onboarded."]));

body.push(H1("How to use this runbook"));
body.push(...bullets([
  [{t:"Work the six phases P0 → P5 in order.",b:true}," Each phase has a Goal · Who · Actions · Artifacts · Verification gate · Operator GO."],
  [{t:"Every gate is verified against the object store / repo walk",b:true},", never from a chat claim."],
  ["Copy the Appendix templates (A–E) and fill the placeholders."],
  ["The cross-cutting invariants in section 5 are binding throughout."]
]));

body.push(H1("1. Roles & responsibilities"));
body.push(tbl(["Role","Mandate","Owns","Gate it holds"],[
 ["Operator","Directs the project; the only one who pushes and gives GO; schedules session turns.","Product intent, roster, GO/NO-GO, pushes.","Every phase GO."],
 ["Coordinator","Runs the bus and the process.","CLAUDE.md §0 + coordination + command-registry, .coord/ bus, claim-map, commit serialization, push barrier, work-done map, the ready report.","P1–P5 gates."],
 ["Curator","External SME / source capture; certifies “core raised” by an object-store walk.","Curation channel, certification.","P1 core-raised certification."],
 ["Specialists","Module owners (backend, frontend, DB, devops, …); do the work within their claims.","Their module paths.","Their READY/HOLD at barriers."],
 ["Security","Mandatory cross-cutting gate.","Security review.","Mandatory ACK before any prod release."],
 ["Tech Writer","Documentation gate and author.","docs/** authoring, DOCS inventory, approved/editing governance.","Doc-sync impact-triage ack in the push quorum."]
],[1400,2700,3360,1900],{zebra:true}));

body.push(H1("2. The six-phase model"));
body.push(P("Each arrow crosses a verification gate confirmed by walking the repo / object store."));
body.push(code([
 "P0 Universe  ->  P1 Core  ->  P2 Roster & Claims  ->  P3 Tree hygiene  ->  P4 Work-done map  ->  P5 Ready",
 "  (operator)     (coord)        (coord + operator)      (coord/CC)            (coord)              (coord)"
]));

body.push(H1("3. Phases"));
phase("P0 — Universe (the empty world)",
  "a mounted, version-controlled project folder with a seed spec.","Operator.",
  ["Create or connect one Cowork project folder; record its single absolute working path (the working-folder rule — all reads and writes use exactly that path).",
   "git init; create the working branch; pick a short session prefix (e.g. BY-AD) used by every session and chat.",
   "Seed CLAUDE.md with the product spec: product, stack, scope / out-of-scope, working-folder path, session prefix.",
   "Commit the baseline."],
  "repo (.git), branch, seed CLAUDE.md, the working-folder rule.",
  "git log shows the repo; the folder is mounted; CLAUDE.md is present (object-store check).",
  "→ build the core.");
phase("P1 — Core (discipline + bus)",
  "the binding §0 discipline, the coordination protocol, and the .coord/ bus exist.","Coordinator.",
  ["Extend CLAUDE.md §0 (BINDING) — see Appendix A: 0.1 verify; 0.2 resume-integrity; 0.3 Python + os.fsync writes, Edit tool BANNED on the mount; 0.4 pre-commit check; 0.5 mount .git/status UNRELIABLE → object-store verify; 0.6 NO auto-push and you cannot push from the mount [L-SC-20]; 0.7 post-commit re-sync from HEAD (PD-007).",
   "Add the multi-session coordination section + a command registry.",
   "Build the .coord/ bus (Appendix B).",
   "Write one init-prompt per planned specialist (Appendix C); tag not-yet-active roles FROZEN / NOT-YET-EXISTS."],
  "CLAUDE.md §0 + coordination + command-registry; .coord/ bus; init-prompts.",
  "The curator certifies by object store (not chat) — §0 anchors present, bus files exist, init-prompts carry the mandatory blocks.",
  "→ raise the roster.");
phase("P2 — Roster & Claims",
  "a validated, non-overlapping claim-map.","Coordinator (+ operator confirms the roster).",
  ["Operator confirms the initial roster.",
   "Build the claim-map (Appendix D): module → paths, seam rules, READ-ONLY / no-touch zones.",
   "Validate against the real tree: do the paths exist? nesting? overlaps?",
   "The roster is NOT frozen — the operator may split a role or activate one mid-bootstrap; re-validate on every change.",
   "Share a cross-cutting asset (e.g. DB migrations) by OWN / REVIEW / APPLY across three roles — never by carving a sub-path out of another owner’s claim."],
  "claim-map, seam rules.",
  "real paths, ZERO overlap, a single owner per seam.",
  "→ tree hygiene.");
phase("P3 — Tree hygiene",
  "a clean, intentional, committed tree.","Coordinator issues CC tasks; specialists run them (native CC, not the mount).",
  ["Commit .gitignore FIRST, then re-check status.",
   "Decide tracked vs ignored BEFORE any blanket add: legacy / large dirs → .gitignore (or LFS by owner call); logs → ignore; DB dumps → owner call; word-lock ~$ files → discard.",
   "De-duplicate documents ONLY by a verified subset proof (textual diff: drop X only if X is a subset of Y with zero unique lines).",
   "Commit existing work in labeled, module-grouped commits — native git / CC (the mount can’t commit), serialized by commit.lock, journaled, with a post-commit re-sync from HEAD."],
  ".gitignore, module-grouped commits, journal lines.",
  "git status clean; every commit journaled.",
  "→ work-done map.");
phase("P4 — Work-done map",
  "an honest map of what actually exists.","Coordinator.",
  ["Build the map by walking the committed tree, labeling each item Intended / Drafted / Delivered (verified) / Committed (hash).",
   "Delivered (verified) requires a green build/test — a commit is not “Delivered”.",
   "Distribute the first tasks per the claim-map (via the dispatch loop, section 4)."],
  "work-done map, first task assignments.",
  "the map is built from the repo, not chat; every “Delivered” is backed by a build/test.",
  "→ ready.");
phase("P5 — Ready",
  "the team is up and the first work is moving.","Coordinator.",
  ["Write the “team up & ready” report (Appendix E) — a Definition-of-Done checklist that includes the claim-map and confirms that each “Delivered” item was verified by the object store (git cat-file / git show / git hash-object), not chat."],
  "the “team up & ready” report.",
  "the report’s credibility is the object-store proof behind every “Delivered” claim, plus a defined push barrier + quorum (incl. the mandatory Security ack and the Tech-Writer doc-sync ack).",
  "→ the project is launched.");

body.push(H1("4. Operational loop — task dispatch (the heartbeat after launch)"));
body.push(P("Once the team is stood up (P5), this is how work actually moves. It is operator-mediated: the coordinator routes, the operator triggers, the specialist executes."));
body.push(...nums([
 [{t:"The coordinator drafts",b:true}," a full, self-contained directive (a compose-directive routing action — not a base session-coord §10 verb; a project may register its own): mandatory reads + the integrity block + the specialist’s claim + the task + acceptance criteria + commit.lock / journal / no-push. Code work points at a tasks/<file>.md (CC-only code rule)."],
 [{t:"The coordinator writes",b:true}," the directive into that specialist’s inbox .coord/inbox/<slug>.md (its router duty). It does not execute it and does not trigger the session."],
 [{t:"The coordinator hands the operator a trigger-list",b:true},": the session slugs to activate (e.g. backend-0611, security-0611)."],
 [{t:"The operator runs the intake command",b:true}," (коорд: входящие) in each named session. That session reads its own inbox inbox/<slug>.md and does the work via CC."],
 [{t:"The specialist reports back",b:true}," to the coordinator via inbox/coordinator-<slug>.md; it marks a message handled only as its recipient."],
 [{t:"The coordinator",b:true}," on its next intake reads its inbox, journals the outcome, and routes the next step."]
]));
body.push(P([{t:"Three roles in one line: ",b:true},"Coordinator = router (stages directives, reviews, journals — writes no feature code, never “sends” by triggering). Operator = the trigger (activates each session). Specialist = executor (reads its own inbox, does the CC work, reports)."]));
body.push(code([
 "coordinator --writes directive--> inbox/<slug>.md        coordinator --trigger-list--> OPERATOR",
 "OPERATOR --intake in session--> specialist --reads own inbox, CC work--> commit (commit.lock + journal, no push)",
 "specialist --report--> inbox/coordinator-<slug>.md --> coordinator (next intake) --journal--> next task"
]));
body.push(P([{t:"Verb precision. ",b:true},"The registry lists the intake verb as the coordinator reading an inbox; operationally the operator uses the same intake verb in every session to mean “read my inbox and act” (in a specialist session, “my inbox” = inbox/<that-slug>.md). Cite as canonical only the verbs in the session-coord §10 registry; describe project-specific verbs as patterns or add them to §10."]));
body.push(callout("note","Invariants of the loop",[
 "All code changes go out as CC prompts (CC-only rule); the coordinator analyses / plans / reviews / journals only. A handled-marker is written only by the recipient of a message. Commits run under commit.lock, are journaled, and never auto-push."]));

body.push(H1("5. Cross-cutting invariants (binding throughout)"));
body.push(...bullets([
 [{t:"Verify, not chat",b:true}," — tool success ≠ delivery; build status tables by walking the repo (§0.1)."],
 [{t:"Python + os.fsync for every write; the Edit tool is BANNED on the mount",b:true}," (§0.3)."],
 [{t:"Object-store verification",b:true}," — the mount’s .git / git status is unreliable; confirm with git hash-object vs git rev-parse HEAD:<file>; never escalate “corruption” from a mount read (§0.5)."],
 [{t:"No auto-push; you cannot push from the mount",b:true}," — every push is a conscious operator decision via the dedicated push prompt [L-SC-20] (§0.6)."],
 [{t:"Post-commit re-sync from HEAD",b:true}," — counteract the mount’s async cache write-back (PD-007, §0.7)."],
 [{t:"commit.lock covers the plumbing path too",b:true}," — the commit-tree + direct ref-write path has no git-level locking; never bypass commit.lock."],
 [{t:"Handled-markers are written only by the recipient",b:true}," of a message."],
 [{t:"The two-Cowork cross channel is deferred",b:true}," until a second Cowork instance actually exists."],
 [{t:"Documentation governance",b:true}," — a coordinator-assigned Product Release ID scheme RTM-REL-YYYY.MM[.patch] + a Shipped-with column; a doc-sync impact-triage gate in the push quorum; and the approved/{doc,pdf} + editing/ layout with a mandatory revision-history table."]
]));

body.push(H1("6. Case study & lessons — Agent Desktop bootstrap"));
body.push(P("Worked example. Project: Agent Desktop / Bynet — a Cisco UCCE/UCCX agent desktop via Finesse; .NET 8 backend, frontend added later. Captured by the curator; use it as the concrete illustration — the normative steps are sections 1–5 above."));
body.push(H2("Timeline"));
body.push(...bullets([
 [{t:"M0",b:true}," — the curation channel is established, separate from the active coordinator bus; curator and project inboxes are set up."],
 [{t:"M1",b:true}," — curator Q&A; the claim-map is corrected against the real tree (3 fixes) plus a tree-hygiene precondition."],
 [{t:"M2 (operator GO)",b:true}," — core raised, verified by a curator object-store walk: CLAUDE.md v1.8 (1054 lines) with §0.5/0.6/0.7, the multi-session protocol, and the command registry; the .coord/ bus (14 files); 5 init-prompts (frontend tagged FROZEN + NOT-YET-EXISTS). Boundary honored — only .coord/ touched, no commit/push."],
 [{t:"M3",b:true}," — pre-hygiene curator review; init-prompts certified; tree-hygiene labeling guidance issued."],
 [{t:"M4",b:true}," — full roster up (7 sessions). The operator changes the roster mid-bootstrap: DBA/Devops split into two roles; frontend un-frozen (first task = a React + Vite + MUI scaffold); the prefix is locked BY-AD. A Step-0 gate passes: a duplicate spec doc is resolved by a textual-diff subset proof (a is a subset of c, zero unique) before deletion. The coordinator chat migrates mounts; live state is kept in coordinator_handoff.md."],
 [{t:"M5 (in progress)",b:true}," — tree hygiene is a CC job (the mount physically cannot commit: a stuck .git/index.lock, and bindfs denies rm/rename inside .git → [L-SC-20] proven). It awaits native CC for three module-grouped, labeled commits; then the work-done map (build + test before any “Delivered” label)."]
]));
body.push(H2("Lessons (generalize for any project)"));
body.push(...nums([
 "The roster is not frozen at the roster phase — re-validate the claim-map for overlap on every operator change.",
 "Share a cross-cutting asset by OWN / REVIEW / APPLY across roles, never by carving a sub-path out of an owner’s claim.",
 "De-duplicate documents only by a verified subset proof (X subset of Y, zero unique), never by assumption.",
 "The mount cannot commit/push (stuck .git locks; bindfs denies rm/rename in .git) — all commits run native CC, serialized by commit.lock, journaled, with a post-commit re-sync. [L-SC-20].",
 "Certify “core raised” by walking the repo via the object store, never from a chat claim.",
 "A handled-marker is written only by the recipient of a message.",
 "A cross-project channel that depends on both mounts breaks on remount — route each direction through a file in the writer’s own bus, read by the party that holds both mounts (the curator)."
]));
body.push(H2("Tree-hygiene numbers (from the worked example)"));
body.push(P("Dirty tree at start: 3 modified + 23 untracked. Sequence: commit .gitignore first → re-check; decide tracked-vs-ignored before any blanket add (legacy ~750 MB → .gitignore, no LFS; production logs → ignore; root SQL dumps → DBA call; word-lock ~$ files → discard; spec docx → docs/); then module-grouped labeled commits; a build/test gate before labeling any feature “Delivered”."));

// ===== APPENDICES =====
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — CLAUDE.md skeleton"));
body.push(P("Copy and fill the placeholders. §0 is binding."));
body.push(code([
 "# <PROJECT> — CLAUDE.md",
 "> Single source of truth for autonomous work. Working folder: <ABSOLUTE WORKING PATH>. Session prefix: <PREFIX>.",
 "",
 "## 0. Environment rules — executor must read first (BINDING)",
 "### 0.1 Verification — tool success != delivery",
 "Verify via ls / git log / Read before claiming anything exists or is delivered. Build status by walking the repo.",
 "### 0.2 Session-resume integrity",
 "On resume: git status --short; for each M file check truncation; restore via: git show HEAD:<f> > <f>.",
 "### 0.3 Writes: Python + os.fsync ONLY; the Edit tool is BANNED on the mount",
 "Every write: read -> modify -> write with f.flush(); os.fsync(f.fileno()); then verify with tail -3 and wc -l.",
 "### 0.4 Pre-commit check",
 "Run the pre-commit verifier before every git add / commit; on FAIL restore from HEAD and retry.",
 "### 0.5 Mount .git / git status is UNRELIABLE -> object-store verify",
 "Confirm tracked-state and content via git hash-object <f> vs git rev-parse HEAD:<f>. Never escalate corruption from a mount read.",
 "### 0.6 No auto-push; you cannot push from the mount [L-SC-20]",
 "Never git push automatically; pushes are an operator decision via the dedicated push prompt.",
 "### 0.7 Post-commit re-sync from HEAD (PD-007)",
 "After every commit, re-sync committed files from HEAD as the last action (counteracts cache write-back).",
 "",
 "## <N>. Multi-session coordination",
 "State bus in .coord/; claims by module; commit.lock serializes commits (covers the plumbing path); journal every",
 "commit; push barrier with quorum (mandatory Security ack + Tech-Writer doc-sync ack). Handled-markers by recipient only.",
 "",
 "## <N+1>. Command registry",
 "<list each operator command verb and its exact semantics>"
]));

body.push(H1("Appendix B — .coord/ bus files"));
body.push(code([
 ".coord/",
 "  README.md              # what the bus is + quick reference",
 "  .gitignore             # ignore the runtime state below",
 "  sessions/<slug>.md     # one per active session (frontmatter below)",
 "  locks/commit.lock      # exclusive commit token (repo-wide)",
 "  journal.md             # append-only commit log",
 "  inbox/<slug>.md        # directed messages TO a session/role (coordinator-<slug>, curator, ...)",
 "  coordinator_handoff.md # live resume artifact for a fresh coordinator",
 "  push/",
 "    request.md           # active barrier (freeze); tombstone when cleared",
 "    acks/<slug>.md       # per-session READY / HOLD"
]));
body.push(P([{t:"Session file frontmatter:",b:true}]));
body.push(code([
 "---",
 "session: <Name>",
 "slug: <role>-<MMDD>",
 "role: <role>",
 "status: active          # active | pushing | done",
 "modules: [<module>]     # claimed modules",
 "files: []               # optional file-level claims",
 "heartbeat: <UTC>",
 "cc_task: none",
 "---",
 "<one-paragraph charter>"
]));
body.push(P([{t:"Inbox message block (handled-marker by the recipient only):",b:true}]));
body.push(code([
 "## <UTC> | from: <slug> | to: <slug>",
 "<body>",
 "---",
 "> handled <UTC> by <recipient-slug> — <what was done>"
]));

body.push(H1("Appendix C — Init-prompt template (per specialist)"));
body.push(code([
 "<PREFIX>: you are the standing <ROLE> specialist. Session name \"<Name>\".",
 "0. COMMS: your inbox = .coord/inbox/<slug>.md (read it whole; mark each block handled). Your outbox = the",
 "   COORDINATOR's SLUG inbox .coord/inbox/coordinator-<slug>.md. All .coord/ and work writes via Python + os.fsync.",
 "   Commands per the session-coord skill section 10 — never guess an unknown verb.",
 "1. INTEGRITY (0.2): git status; for M files hash-object vs HEAD; restore truncated.",
 "2. MATERIAL: read CLAUDE.md section 0 + coordination + your domain sections.",
 "3. TERRITORY: you OWN <paths> (claims); READ-ONLY elsewhere; shared seams via OWN / REVIEW / APPLY.",
 "4. REGISTER: write .coord/sessions/<slug>.md, status active.",
 "5. READ BUS: your inbox; sessions/*; journal tail; push/request (if FREEZE -> stop).",
 "6. PUSH QUORUM: give READY / HOLD on your paths at every barrier.",
 "7. CONFIRM: flush an ack to the coordinator's slug inbox + a short chat reply."
]));

body.push(H1("Appendix D — Claim-map template"));
body.push(code([
 "# Claim-map — <PROJECT>",
 "| Module | Owner (slug) | Paths (claims) | Seam rule | Read-only / no-touch |",
 "|---|---|---|---|---|",
 "| <module> | <role>-<MMDD> | <paths> | OWN / REVIEW / APPLY where shared | <paths others own> |",
 "",
 "Validation: every path exists in the real tree; ZERO overlap; one owner per seam. Re-validate on any roster change."
]));

body.push(H1("Appendix E — “Team up & ready” report template"));
body.push(code([
 "# Team up & ready — <PROJECT> (<date>)",
 "Definition of Done:",
 "- [ ] Core: CLAUDE.md section 0 (0.1-0.7) + coordination + command-registry — object-store verified.",
 "- [ ] Bus: .coord/ files present (README, sessions/, locks/, journal, inbox/, push/).",
 "- [ ] Roster holding: sessions registered; claim-map attached; ZERO overlap.",
 "- [ ] Tree clean: git status empty; commits journaled.",
 "- [ ] Work-done map attached; EACH “Delivered” verified by object store (cat-file / show / hash-object), not chat.",
 "- [ ] First tasks issued per the claim-map.",
 "- [ ] Push barrier + quorum defined, incl. MANDATORY Security ack (+ Tech-Writer doc-sync ack).",
 "- [ ] First CC task ran clean.",
 "Operator GO: ____"
]));

body.push(SP());
body.push(P([{t:"Sources: ",b:true,i:true},{t:"in-repo CLAUDE.md §0 / §42 / §44, the live .coord/ bus, and the session-coord skill (normative methodology); the Agent Desktop bootstrap capture by the curator (case study). EN canonical; a ru edition follows on request.",i:true}]));

const doc = new Document({
  features: { updateFields: true },
  styles: {
    default: { document: { run: { font:"Arial", size:21 } } },
    paragraphStyles: [
      { id:"Heading1", name:"Heading 1", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:30, bold:true, color:NAVY, font:"Arial" },
        paragraph:{ spacing:{before:280, after:140}, outlineLevel:0 } },
      { id:"Heading2", name:"Heading 2", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:25, bold:true, color:BLUE, font:"Arial" },
        paragraph:{ spacing:{before:220, after:100}, outlineLevel:1 } },
      { id:"Heading3", name:"Heading 3", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:22, bold:true, color:"333333", font:"Arial" },
        paragraph:{ spacing:{before:160, after:80}, outlineLevel:2 } },
    ]
  },
  numbering: { config: [
    { reference:"b", levels:[{ level:0, format:LevelFormat.BULLET, text:"•", alignment:AlignmentType.LEFT,
      style:{ paragraph:{ indent:{ left:540, hanging:280 } } } }] },
    { reference:"n", levels:[{ level:0, format:LevelFormat.DECIMAL, text:"%1.", alignment:AlignmentType.LEFT,
      style:{ paragraph:{ indent:{ left:540, hanging:280 } } } }] },
  ]},
  sections: [{
    properties: { page: { size:{ width:12240, height:15840 }, margin:{ top:1440, right:1440, bottom:1440, left:1440 } } },
    headers: { default: new Header({ children:[ new Paragraph({
      border:{ bottom:{ style:BorderStyle.SINGLE, size:4, color:NAVY, space:4 } },
      children:[ LOGOSM(), new TextRun({ text:"   Project Launch Runbook — Cowork multi-session bootstrap", size:16, color:"808080" }) ] }) ] }) },
    footers: { default: new Footer({ children:[ new Paragraph({
      tabStops:[{ type:"right", position:9360 }],
      children:[ new TextRun({ text:"Internal methodology — Operator / Coordinator / Curator", size:16, color:"808080" }),
                 new TextRun({ text:"\tPage ", size:16, color:"808080" }),
                 new TextRun({ children:[PageNumber.CURRENT], size:16, color:"808080" }) ] }) ] }) },
    children: body
  }]
});
Packer.toBuffer(doc).then(buf=>{ fs.writeFileSync("/tmp/build/Project-Launch-Runbook_EN.docx", buf); console.log("written", buf.length); });
