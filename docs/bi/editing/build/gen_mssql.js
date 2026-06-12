const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, TableOfContents, HeadingLevel,
  BorderStyle, WidthType, ShadingType, VerticalAlign, PageNumber, PageBreak, PageOrientation, ImageRun
} = require('docx');
const METRICS = require('/tmp/build/metrics_rows.js');
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
body.push(new Paragraph({ spacing:{before:900, after:120}, alignment:AlignmentType.CENTER,
  children:[ LOGO() ] }));
body.push(new Paragraph({ spacing:{before:160, after:120}, alignment:AlignmentType.CENTER,
  children:[new TextRun({text:"RTM View Shell Data Connector", bold:true, size:46, color:NAVY})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:80},
  children:[new TextRun({text:"Unified Reporting Guide", bold:true, size:40, color:BLUE})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:80},
  children:[new TextRun({text:"Real-time and historical reporting on one data model", italics:true, size:26})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:80},
  children:[new TextRun({text:"SQL Server edition · single-tenant (no TenantId)", bold:true, size:24, color:"2E5496"})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:600, after:40},
  children:[new TextRun({text:"For the Customer-Service business owner and the BI / data-warehouse team", size:24})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:40},
  children:[new TextRun({text:"Edition EN · SQL Server (single-tenant) · 2026-06-10 · RTM View Shell", size:22, color:"595959"})] }));
body.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:400},
  children:[new TextRun({text:"Column names, grain and units verified against the RTM schema; SQL is T-SQL for a single-tenant Microsoft SQL Server deployment.",
    italics:true, size:20, color:"808080"})] }));
body.push(new Paragraph({ children:[new PageBreak()] }));

body.push(H1("Document revision history"));
body.push(P("This table lists the revision history of this document."));
body.push(tbl(["Version","Date","Summary of changes","Product release ID","Shipped-with (commit/barrier)"],
  [["1.0","2026-06-10","Initial","RTM-REL-2026.06","(pending push)"]],
  [1100,1500,2260,2150,2350]));
body.push(new Paragraph({ children:[new PageBreak()] }));
// ---------- TOC ----------
body.push(new Paragraph({ heading:HeadingLevel.HEADING_1, children:[new TextRun("Contents")] }));
body.push(new TableOfContents("Contents", { hyperlink:true, headingStyleRange:"1-3" }));
body.push(new Paragraph({ children:[new PageBreak()] }));

// ---------- HOW TO READ ----------
body.push(H1("About RTM View Shell Data Connector"));
body.push(callout('note',"Scope of this document", [[{t:"This document describes the on-premises, system-per-user installation",b:true}," \u2014 direct access to the RTM Microsoft SQL Server database."]]));
body.push(P([{t:"RTM View Shell Data Connector",b:true}," is the licensed component that makes RTM\u2019s real-time and historical contact-centre data available to your BI / data-warehouse and Customer-Service teams."]));
body.push(P([{t:"Two delivery models:",b:true}]));
body.push(...bullets([
  [{t:"On-premises, system-per-user installation",b:true}," \u2014 the Connector runs inside your own environment and your BI tools query the RTM database ",{t:"directly",b:true},", using the tables and queries in this guide."],
  [{t:"Cloud (hosted) deployment",b:true}," \u2014 direct database access is not exposed. Instead the Connector provides an ",{t:"API Feed",b:true}," that delivers the same data into your client environment (your perimeter)."]
]));
body.push(callout('note',"Licensing", [[{t:"A RTM View Shell Data Connector license is required",b:true}," to use either delivery model."]]));
body.push(H1("How to read this guide"));
body.push(P([
  "This guide explains how to produce ", {t:"historical BI reports that match the RTM live picture to the second",b:true},
  ". It is written for two readers, in two parts you can read independently:"]));
body.push(tbl(["Reader","Read","What you get"],
  [["Customer-Service business owner","Part 1 (no SQL)","The concepts: the two lifecycles, status groups, how the wallboard and the report stay in agreement."],
   ["BI / data-warehouse engineer","Part 2 (SQL)","The data dictionary, the join model, units, and copy-paste worked queries you can reproduce."]],
  [2600,1700,5060], {zebra:true}));
body.push(SP());
body.push(callout('note',"This edition: single-tenant SQL Server", [
  [{t:"This guide targets a single-tenant Microsoft SQL Server database. ",b:true},
   "All queries are T-SQL: identifiers in [brackets], booleans as bit (compare with = 1 / = 0), schema dbo. ",
   {t:"There is no TenantId column",b:true}," — the database holds one tenant's data."]]));
body.push(callout('note',"One sentence to remember", [
  [{t:"RTM persists the same derived agent states that it shows live. ",b:true},
   "So a correctly written historical query returns the same numbers the real-time grid showed — that agreement is the whole point of this document."]]));
body.push(new Paragraph({ children:[new PageBreak()] }));

// =====================================================================
// PART 1
// =====================================================================
body.push(H1("Part 1 — The concepts (for the business owner)"));

body.push(H2("1.1  What RTM does with raw contact-centre events"));
body.push(P([
  "Your ACD (Twilio, or any other platform) emits a stream of low-level events — a call entered a queue, a worker became available, a reservation was accepted, a call was put on hold. On their own these events do not tell you ",
  {t:"what an agent is doing right now",i:true},
  " or ", {t:"how a queue is performing",i:true}, ". RTM turns that raw stream into ",
  {t:"two clean, business-meaningful models",b:true}, ":"]));
body.push(...bullets([
  [{t:"A call lifecycle",b:true}," — every interaction (call, callback, chat) and what happened to it: did it wait, was it answered, abandoned, transferred; how long it waited and talked."],
  [{t:"An agent-status lifecycle",b:true}," — a timeline of every agent's status through the day, where each status belongs to a ",{t:"status group",i:true}," (Available, On Phone, Break, …)."]
]));

body.push(H2("1.2  The Twilio gap — and how RTM closes it"));
body.push(P([
  "Legacy ACDs expose a categorised in-call agent status (Available → Ringing → Talk → Hold → Wrap → Available). ",
  {t:"Twilio does not.",b:true}, " In Twilio, ", {t:"Worker Activity is availability only",b:true},
  " — it says whether a worker is generally available, and it does ", {t:"not",i:true},
  " change while a call is in progress. The progress of the call itself lives in a separate stream of Voice and Reservation events."]));
body.push(P([
  "RTM bridges the two. While an agent is on a call, RTM ", {t:"derives the agent's in-call status from the bound call's state",b:true},
  " — Ringing when reserved, Talk when assigned, Hold when the call is held, Wrap Up during after-call work — and writes that derived status into the agent timeline. ",
  "That is why an RTM wallboard can show “Talk”, “Hold” and “Wrap Up” for a Twilio agent even though Twilio itself never sent those as a status."]));
body.push(tbl(["Raw Twilio signal","RTM derived agent status"],
  [["Reservation created","Ringing"],
   ["Reservation accepted / call assigned","Talk (On Phone)"],
   ["Call held (hold event)","Hold"],
   ["After-call work","Wrap Up"],
   ["Worker Activity = a break activity","Break (from the activity, not the call)"]],
  [4680,4680],{zebra:true}));

body.push(H2("1.3  The two lifecycles in plain language"));
body.push(P([{t:"The call lifecycle:",b:true},
  " In Queue → Answered → Talk (possibly with Hold and Wrap Up) → Completed. A call that leaves the queue before an agent answers is ",
  {t:"Abandoned",b:true}, "."]));
body.push(P([{t:"The agent-status lifecycle:",b:true},
  " a continuous timeline. Each entry is one status (e.g. Available, Lunch, Talk, Wrap Up, Offline) with a start and end time. Every status maps to exactly one ",
  {t:"status group",i:true}, ", which is how individual reasons roll up into shrinkage, occupancy and availability."]));

body.push(H2("1.4  Status groups — the model that must be exactly right"));
body.push(P("Every agent status belongs to one of these groups:"));
body.push(...bullets([
  [{t:"AVAILABLE",b:true}," — idle and ready to take work."],
  [{t:"ONPHONE",b:true}," — engaged on an interaction (the in-call states live here)."],
  [{t:"BREAK",b:true}," — lunch, short break, etc."],
  [{t:"PAPERWORK",b:true}," — after-call work / back-office."],
  [{t:"TRAINING",b:true}," — coaching, e-learning."],
  [{t:"SIGNOFF",b:true}," — logged out / Offline."],
  [{t:"UNAVAILABLE",b:true}," — logged in but not ready, for reasons not mapped elsewhere."]
]));
body.push(callout('note',"The grouping rule (important for honest reporting)", [
  [{t:"A status that is explicitly listed under a group ",b:false},"(ONPHONE / PAPERWORK / BREAK / TRAINING / SIGNOFF) ",{t:"belongs to that group.",b:true}],
  [{t:"Any status that is not mapped",b:true}," falls back to a default bucket: ",{t:"AVAILABLE",b:true}," if the worker is available, otherwise ",{t:"UNAVAILABLE",b:true},"."],
  ["So AVAILABLE and UNAVAILABLE are ",{t:"default buckets for unmapped statuses",i:true},", not hand-picked reason lists."],
  [{t:"SIGNOFF (logged out) is its own explicit group",b:true},". Do not fold sign-off into UNAVAILABLE — they answer different business questions (“not at the desk” vs “at the desk but not ready”)."]
]));
body.push(P([{t:"Handling time: ",b:true},"AHT = Talk + Hold + Wrap Up. ",
  "The exact state→group membership is ", {t:"per-tenant configuration",b:true},
  " — Part 2 shows the sample tenant's real configuration and the one trap it creates."]));

body.push(H2("1.5  Two ways things roll up to a Business Unit"));
body.push(P("RTM answers questions at the Business Unit (BU) level along two different paths, because calls and agent time reach a BU differently:"));
body.push(...bullets([
  [{t:"Calls",b:true}," roll up by queue: ", {t:"Queue → Business Unit",b:true}," (“how did the Sales queues perform?”)."],
  [{t:"Agent time",b:true}," rolls up by team: ", {t:"Agent → Agent Group → Super Group → Business Unit",b:true}," (“how much break time did the Sales team take?”)."]
]));

body.push(H2("1.6  Why real-time and historical agree"));
body.push(P([
  "The live grid and the nightly report read the ", {t:"same persisted, derived states",b:true},
  ". RTM does not compute one model for the screen and a different model for history — it stores what it shows. ",
  "Provided a historical query uses the same status-group rules and the same units, it reproduces the live numbers. Part 2, §Example C and §Example D, proves this on sample data."]));
body.push(new Paragraph({ children:[new PageBreak()] }));

// =====================================================================
// PART 2
// =====================================================================
body.push(H1("Part 2 — The practical guide (for the BI team)"));
body.push(callout('note',"The sample tenant used throughout Part 2", [
  ["Every worked example below uses one small, internally-consistent dataset so you can reproduce the numbers. The identifiers are:"],
  ["Single-tenant database (no TenantId). All examples filter ",{t:"OnDate = '2026-06-09'",code:true}," (yesterday)."],
  ["Business Units: ",{t:"Sales",b:true}," (BusinessUnitId 10), ",{t:"Support",b:true}," (20). Queues: ",
   {t:"SALES_VOICE, SALES_CB → Sales",code:true},"; ",{t:"SUP_VOICE → Support",code:true},"."],
  ["Team path: agents ",{t:"agent.dana, agent.omri",code:true}," → Agent Group ",{t:"AG_SALES_1",code:true},
   " → Super Group ",{t:"Sales Team A",code:true}," (100) → BU Sales (10)."]
]));

body.push(H2("2.0  Getting started in 10 minutes"));
body.push(...nums([
  [{t:"Connect",b:true}," to the RTM Microsoft SQL Server database. All reporting tables are in schema ",{t:"dbo",code:true},"; this guide writes identifiers in T-SQL [brackets]."],
  [{t:"Learn the three fact tables",b:true},": ",{t:"RTSData_Interaction",code:true}," (calls), ",
   {t:"RTSData_UserStatus",code:true}," (today's per-status totals per agent), ",
   {t:"RTSData_UserStatusLog",code:true}," (the agent status timeline — the parity backbone)."],
  [{t:"Always filter on",b:true}," ",{t:"[OnDate]",code:true},". This is a ",{t:"single-tenant",b:true}," database — there is no TenantId column. OnDate is a ",{t:"string",b:true}," date key (not a datetime); compare it as text: ",{t:"[OnDate] = '2026-06-09'",code:true},"."],
  [{t:"Run your first query",b:true}," — answered Sales calls yesterday:"]
]));
body.push(code([
  'SELECT count(*) AS answered_calls',
  'FROM [RTSData_Interaction] i',
  'JOIN [NGC_BusinessUnitQueueClassification] qc',
  '  ON qc.[QueueId] = i.[Workgroup]',
  " AND qc.[ClassificationId] = 'ALL'",
  'JOIN [NGC_BusinessUnit] bu',
  '  ON bu.[BusinessUnitId] = qc.[BusinessUnitId]',
  "WHERE i.[OnDate] = '2026-06-09'",
  "  AND bu.[BusinessUnitName] = 'Sales'",
  '  AND i.[IsAnswered] = 1;'
]));

body.push(H2("2.1  Data dictionary"));
body.push(P([{t:"Units are called out per column. ",b:true},
  "Two facts to internalise before reading: ", {t:"Workgroup = the queue's external id",b:true},
  ", and all NGC joins use ", {t:"string external keys, never the uniqueidentifier primary keys",b:true},". This is the single-tenant SQL Server schema — there is no TenantId column."]));
body.push(callout('note',"SQL Server data types", [[{t:"Types below are the standard SQL Server mapping",b:true}," (uuid \u2192 uniqueidentifier, timestamptz \u2192 datetimeoffset, text \u2192 nvarchar(max), varchar \u2192 nvarchar). ","This edition uses datetimeoffset for UTC-offset fidelity (datetime2 in UTC is an acceptable simpler alternative). Confirm types against your deployed MSSQL schema; the column names, grain and units are fixed."]]));

body.push(H3("RTSData_Interaction  — call fact (grain: one interaction segment)"));
body.push(dict([
  ["InteractionId","nvarchar(50)","PK","Interaction id. Part of the primary key with Segment + OnDate + ServerId."],
  ["Segment","int","PK","Segment number. One interaction can have several segments (e.g. after a transfer). Count DISTINCT InteractionId to avoid double-counting."],
  ["OnDate","nvarchar(50)","PK","Business date as a STRING (e.g. '2026-06-09'). The day key for all daily reporting."],
  ["ServerId","nvarchar(50)","PK","Source server / site id."],
  ["Workgroup","nvarchar(100)","FK","Queue external id. Join to NGC_Queues.ExternalId / NGC_BusinessUnitQueueClassification.QueueId."],
  ["UserId","nvarchar(50)","FK","Agent external id that handled the segment."],
  ["ClassificationCode","nvarchar(max)","","Optional call classification / disposition code."],
  ["InteractionType","nvarchar(50)","","'Call', 'Callback', 'Chat'."],
  ["CallType","nvarchar(50)","","e.g. 'External' / 'Internal'."],
  ["Direction","nvarchar(50)","","'Incoming' / 'Outgoing'."],
  ["IsAnswered","bit","","True if the segment was answered by an agent."],
  ["IsInQueue","bit","","True while waiting in queue (not yet answered)."],
  ["IsTalk","bit","","True while the agent is actively talking (in-progress flag)."],
  ["IsAbandoned","bit","","True if the caller left the queue before being answered."],
  ["IsTransferred","bit","","True if the segment ended in a transfer."],
  ["IsMessaging","bit","","True for messaging interactions."],
  ["IsCallbackRequest","bit","","True if the interaction is a callback request."],
  ["TimeInQueue","int","","Queue wait time in SECONDS."],
  ["TalkTime","int","","Talk time in SECONDS."],
  ["InQueueDateTime","datetimeoffset","","When the interaction entered the queue (UTC)."],
  ["AnsweredDateTime","datetimeoffset","","When the interaction was answered (UTC). Unanswered rows carry a sentinel far-past date."],
  ["UpdateTime","datetimeoffset","","Last update of the row (UTC)."],
  ["LastUserId","nvarchar(50)","","Last agent on the interaction (after transfers)."],
  ["LastWorkgroup","nvarchar(100)","","Last queue on the interaction."],
  ["RemoteAddress","nvarchar(50)","","Caller number / remote address."],
  ["TimeZone","nvarchar(10)","","Site time zone of OnDate."],
  ["CustomCallData, CustomCallData1..20","nvarchar(max)","","Tenant-defined extension fields (disposition, campaign, etc.)."]
]));
body.push(SP());

body.push(H3("RTSData_UserStatus  — today's status totals (grain: one agent × one status × day)"));
body.push(dict([
  ["UserId","nvarchar(100)","PK/FK","Agent external id. Join to NGC_UserAgentgroup.UserId."],
  ["StatusId","nvarchar(100)","PK","Status identifier."],
  ["ServerId","nvarchar(50)","PK","Source server / site."],
  ["OnDate","nvarchar(50)","PK","Business date STRING."],
  ["StatusName","nvarchar(100)","","Human status name (the state, e.g. 'Talk', 'Hold', 'Wrap Up', 'Lunch')."],
  ["StatusGroup","nvarchar(100)","","Denormalised group of this status (AVAILABLE / ONPHONE / BREAK / PAPERWORK / TRAINING / SIGNOFF / UNAVAILABLE)."],
  ["TotalDuration","int","","Cumulative time in this status today, in SECONDS."],
  ["MaxDuraction","int","","Longest single stay in this status today, SECONDS. NOTE: the column name is mis-spelled in the database (“MaxDuraction”) — quote it exactly."],
  ["TotalCount","int","","Number of times the agent entered this status today."],
  ["DisplayName","nvarchar(100)","","Agent display name."],
  ["UpdateTime","datetimeoffset","","Last update (UTC)."],
  ["TimeZone","nvarchar(10)","","Site time zone."]
]));
body.push(SP());

body.push(H3("RTSData_UserStatusLog  — the status timeline (grain: one status interval)"));
body.push(callout('warn',"Units trap on this table", [
  [{t:"RTSData_UserStatusLog.Duration is in MILLISECONDS",b:true}," — divide by 1000 to get seconds. ",
   "By contrast, ",{t:"RTSData_UserStatus.TotalDuration / MaxDuraction",b:true}," and ",
   {t:"RTSData_Interaction.TimeInQueue / TalkTime",b:true}," are in ",{t:"SECONDS",b:true},". Mixing them is the #1 reporting bug."]]));
body.push(dict([
  ["Id","int","PK","Surrogate identity key."],
  ["UserId","nvarchar(100)","FK","Agent external id."],
  ["StatusId","nvarchar(100)","","Status identifier (the state for this interval)."],
  ["ServerId","nvarchar(50)","","Source server / site."],
  ["OnDate","nvarchar(50)","","Business date STRING."],
  ["StartTime","datetimeoffset","","Interval start (UTC). Use for point-in-time reconstruction."],
  ["EndTime","datetimeoffset","","Interval end (UTC). NULL / open for the current ongoing status."],
  ["Duration","int","","Interval length in MILLISECONDS (see trap above)."],
  ["StatusGroup","nvarchar(50)","","Group of this status, denormalised onto the interval."],
  ["UpdateTime","datetimeoffset","","Last update (UTC)."],
  ["TimeZone","nvarchar(10)","","Site time zone."]
]));
body.push(SP());

body.push(H3("The NGC organisation graph (reference / dimension tables)"));
body.push(P([{t:"Join keys are the string external ids",b:true},
  " (Workgroup, AgentgroupId, UserId, QueueId, SiteId) and the integer BU / Super Group ids — ",
  {t:"not",i:true}," the uuid surrogate keys on NGC_Queues / NGC_AgentGroups."]));
body.push(H3("NGC_BusinessUnit"));
body.push(dict([
  ["BusinessUnitId","int","PK","BU id (identity). Join target for both roll-up paths."],
  ["BusinessUnitName","nvarchar(100)","","Display name (e.g. 'Sales')."],
  ["Description","nvarchar(max)","","Free text."],
  ["SiteId","nvarchar(50)","FK","Site (NGC_Site.SiteId)."],
  ["CreatedDatetime / CreatedBy","datetimeoffset / nvarchar","","Audit."]
]));
body.push(H3("NGC_Queues"));
body.push(dict([
  ["Id","uniqueidentifier","PK","Surrogate key (do NOT join on this)."],
  ["ExternalId","nvarchar(100)","KEY","Queue external id — equals RTSData_Interaction.Workgroup."],
  ["Name","nvarchar(200)","","Display name."],
  ["IsActive","bit","","Active flag."]
]));
body.push(H3("NGC_BusinessUnitQueueClassification  (queue → BU map)"));
body.push(dict([
  ["BusinessUnitId","int","FK","Target BU."],
  ["QueueId","nvarchar(100)","KEY","Queue external id (= Interaction.Workgroup)."],
  ["ClassificationId","nvarchar(100)","","Must be 'ALL' for a standard “all calls of this queue” mapping. Always include qc.\"ClassificationId\" = 'ALL' in the join."]
]));
body.push(H3("NGC_Supergroup"));
body.push(dict([
  ["SupergroupId","int","PK","Super Group id (identity)."],
  ["SupergroupName","nvarchar(200)","","Display name (e.g. 'Sales Team A')."],
  ["Description","nvarchar(500)","","Free text."]
]));
body.push(H3("NGC_AgentGroups"));
body.push(dict([
  ["Id","uniqueidentifier","PK","Surrogate key (do NOT join on this)."],
  ["ExternalId","nvarchar(100)","KEY","Agent-group external id (= SupergroupAgentgroup.AgentgroupId / UserAgentgroup.AgentgroupId)."],
  ["Name","nvarchar(200)","","Display name."],
  ["IsActive","bit","","Active flag."]
]));
body.push(H3("NGC_SupergroupAgentgroup  (agent-group → super-group map)"));
body.push(dict([
  ["Id","int","PK","Surrogate identity."],
  ["SupergroupId","int","FK","Super Group."],
  ["AgentgroupId","nvarchar(100)","KEY","Agent-group external id."],
]));
body.push(H3("NGC_BusinessUnitSupergroup  (super-group → BU map)"));
body.push(dict([
  ["BusinessUnitId","int","FK","Business Unit."],
  ["SupergroupId","int","FK","Super Group."],
]));
body.push(H3("NGC_UserAgentgroup  (agent → agent-group map)"));
body.push(dict([
  ["Id","int","PK","Surrogate identity."],
  ["UserId","nvarchar(100)","KEY","Agent external id (= RTSData_UserStatus.UserId)."],
  ["AgentgroupId","nvarchar(100)","KEY","Agent-group external id."],
]));
body.push(H3("NGC_Site"));
body.push(dict([
  ["SiteId","nvarchar(50)","PK","Site id (e.g. 'IL')."],
  ["SiteName","nvarchar(200)","","Display name."],
  ["TimeZone","nvarchar(10)","","Site time zone."],
  ["ClearTime","nvarchar(5)","","Daily midnight-clear time (HH:MM)."]
]));
body.push(P([{t:"Chat:",b:true}," messaging bodies live in ",{t:"RTSData_ChatMessage",code:true},
  " (MessageId, InteractionId, SegmentId, UserId, MsgDirection, DeliveryStatus, TimeStamp). Out of scope for voice-status reporting; join on InteractionId if you need transcripts."]));
body.push(new Paragraph({ children:[new PageBreak()] }));

// 2.2 join model
body.push(H2("2.2  The join model — the two roll-up paths"));
body.push(P([{t:"Path A — calls: Workgroup → Queue → BU.",b:true},
  " ClassificationId = 'ALL'. Single-tenant — no TenantId predicate."]));
body.push(code([
  'FROM [RTSData_Interaction] i',
  'JOIN [NGC_BusinessUnitQueueClassification] qc',
  '       ON qc.[QueueId] = i.[Workgroup]',
  "      AND qc.[ClassificationId] = 'ALL'",
  'JOIN [NGC_BusinessUnit] bu',
  '       ON bu.[BusinessUnitId] = qc.[BusinessUnitId]'
]));
body.push(P([{t:"Path B — agent status: UserId → AgentGroup → SuperGroup → BU.",b:true}]));
body.push(code([
  'FROM [RTSData_UserStatus] us',
  'JOIN [NGC_UserAgentgroup]       ua ON ua.[UserId]=us.[UserId]',
  'JOIN [NGC_SupergroupAgentgroup] sa ON sa.[AgentgroupId]=ua.[AgentgroupId]',
  'JOIN [NGC_Supergroup]           sg ON sg.[SupergroupId]=sa.[SupergroupId]',
  'JOIN [NGC_BusinessUnitSupergroup] bs ON bs.[SupergroupId]=sg.[SupergroupId]',
  'JOIN [NGC_BusinessUnit]         bu ON bu.[BusinessUnitId]=bs.[BusinessUnitId]'
]));

// 2.3 units & gotchas
body.push(H2("2.3  Units and gotchas (read before writing any query)"));
body.push(tbl(["Gotcha","What it means"],
  [["T-SQL syntax","Identifiers in [brackets]; booleans are bit \u2014 compare with = 1 / = 0, not = true/false; default schema dbo."],
   ["Milliseconds vs seconds","UserStatusLog.Duration = MILLISECONDS; UserStatus.TotalDuration/MaxDuraction and Interaction.TimeInQueue/TalkTime = SECONDS. Divide the log by 1000 before mixing."],
   ["“MaxDuraction” is mis-spelled","The UserStatus column is literally \"MaxDuraction\". Quote it exactly or the query errors."],
   ["OnDate is a string","nvarchar, not a datetime. Compare as text: [OnDate] = '2026-06-09'."],
   ["Workgroup = queue","Interaction.Workgroup is the queue EXTERNAL id, not a uuid. Join to NGC_Queues.ExternalId / QueueClassification.QueueId."],
   ["String keys, not PKs","All NGC joins use external string ids (UserId, AgentgroupId, QueueId) and integer BU/SG ids — never the uniqueidentifier surrogate keys."],
   ["ClassificationId = 'ALL'","Standard queue→BU mappings carry ClassificationId='ALL'. Omit it and you may match nothing or duplicate."],
   ["Segment grain","One interaction can have several segments. Count DISTINCT InteractionId for call volumes."]],
  [2300,7060],{zebra:true}));

// 2.4 status group config + double-count trap
body.push(H2("2.4  Worked status-group rollup (with the real config)"));
body.push(P([
  "Status→group membership is per-tenant. Here is the ", {t:"sample tenant's actual configuration",b:true},
  " (from the RTM Twilio config). State names are the raw ACD activity names — in this Israeli tenant they are in Hebrew; the English gloss is shown for readability."]));
body.push(tbl(["Group","Member states (raw)","Gloss"],
  [["ONPHONE","מצלצל; שיחה נכנסת; שיחה יוצאת; המתנה; תיעוד לאחר שיחה","Ringing; Incoming; Outgoing; Hold; Wrap Up"],
   ["BREAK","break; הפסקה ארוכה","Break; Long break"],
   ["PAPERWORK","הדרכה חאט; פעילות אישית חאט; אחר חאט …","Training-chat; Personal-chat; Other-chat …"],
   ["AVAILABLE (default)","(any unmapped status while available)","idle-ready"],
   ["UNAVAILABLE (default)","(any unmapped status while not available)","not ready"],
   ["SIGNOFF","(configure your logged-out / Offline states here)","logged out"]],
  [1500,5560,2300],{zebra:true}));
body.push(callout('warn',"The ONPHONE double-count trap (must read)", [
  ["In this sample tenant the ONPHONE group LIST already contains the ",{t:"Hold",b:true}," and ",{t:"Wrap Up",b:true},
   " states. So for such a tenant the ",{t:"ONPHONE group total = Talk + Hold + Wrap ≈ AHT",b:true},", NOT talk-only."],
  [{t:"Therefore: ",b:true},"compute Talk from the ",{t:"Talk state",b:true},", Hold from the ",{t:"'Hold' state",b:true},
   ", Wrap from the ",{t:"'Wrap Up' state",b:true},", and AHT = sum of those three states. ",
   {t:"Do not also add the ONPHONE GROUP total",b:true}," — that double-counts hold and wrap."],
  ["A live metric labelled “Talk” that is built on the ONPHONE ",{t:"group",i:true},
   " will, in such a tenant, actually equal talk+hold+wrap. Reconcile talk-only against the ",{t:"state",b:true},", not the group."]
]));

// 2.5 Example A
body.push(H2("2.5  Worked example A — “How many calls did BU Sales abandon yesterday?”"));
body.push(P([{t:"Sample rows",b:true}," from RTSData_Interaction (OnDate = '2026-06-09'). Only the relevant columns are shown; one row per segment:"]));
body.push(tbl(["Field","CALL-1001","CALL-1002","CALL-1003","CALL-1004"],
  [["Workgroup","SALES_VOICE","SALES_VOICE","SALES_CB","SUP_VOICE"],
   ["UserId","agent.dana","(none)","(none)","agent.eli"],
   ["IsAnswered","1","0","0","0"],
   ["IsAbandoned","0","1","1","1"],
   ["TimeInQueue (s)","12","45","30","20"],
   ["TalkTime (s)","180","0","0","0"]],
  [1760,1900,1900,1900,1900],{zebra:true, codeCols:[1,2,3,4], boldCol0:true}));
body.push(P([{t:"CALL-1004 is a Support queue",b:true},", so it is excluded by the BU filter. Two Sales calls abandoned: CALL-1002 and CALL-1003."]));
body.push(code([
  'SELECT count(DISTINCT i.[InteractionId]) AS sales_abandoned',
  'FROM [RTSData_Interaction] i',
  'JOIN [NGC_BusinessUnitQueueClassification] qc',
  '  ON qc.[QueueId]=i.[Workgroup]',
  "  AND qc.[ClassificationId]='ALL'",
  'JOIN [NGC_BusinessUnit] bu',
  '  ON bu.[BusinessUnitId]=qc.[BusinessUnitId]',
  "WHERE i.[OnDate] = '2026-06-09'",
  "  AND bu.[BusinessUnitName] = 'Sales'",
  '  AND i.[IsAbandoned] = 1;'
]));
body.push(callout('ok',"Result", [[{t:"sales_abandoned = 2",b:true}," (CALL-1002, CALL-1003). CALL-1004 excluded (Support); CALL-1001 excluded (answered)."]]));

// 2.6 Example B
body.push(H2("2.6  Worked example B — “Break-time share per Super Group”"));
body.push(P([{t:"Sample rows",b:true}," from RTSData_UserStatus (OnDate = '2026-06-09'; TotalDuration in SECONDS). Both agents are in Super Group ",{t:"Sales Team A",b:true},":"]));
body.push(tbl(["UserId","StatusGroup","TotalDuration (s)"],
  [["agent.dana","AVAILABLE","10800"],
   ["agent.dana","ONPHONE","14400"],
   ["agent.dana","BREAK","1800"],
   ["agent.omri","AVAILABLE","7200"],
   ["agent.omri","ONPHONE","18000"],
   ["agent.omri","BREAK","3600"]],
  [3120,3120,3120],{zebra:true, codeCols:[0,1]}));
body.push(P([{t:"Break share = Σ BREAK ÷ Σ all = (1800+3600) ÷ (10800+14400+1800+7200+18000+3600) = 5400 ÷ 55800 = 9.68%.",b:false}]));
body.push(code([
  'SELECT sg.[SupergroupName],',
  '       round(100.0 * sum(CASE WHEN us.[StatusGroup]=\'BREAK\'',
  '                               THEN us.[TotalDuration] ELSE 0 END)',
  '             / nullif(sum(us.[TotalDuration]),0), 2) AS break_share_pct',
  'FROM [RTSData_UserStatus] us',
  'JOIN [NGC_UserAgentgroup]       ua ON ua.[UserId]=us.[UserId]',
  'JOIN [NGC_SupergroupAgentgroup] sa ON sa.[AgentgroupId]=ua.[AgentgroupId]',
  'JOIN [NGC_Supergroup]           sg ON sg.[SupergroupId]=sa.[SupergroupId]',
  "WHERE us.[OnDate] = '2026-06-09'",
  'GROUP BY sg.[SupergroupName];'
]));
body.push(callout('ok',"Result", [[{t:"Sales Team A → break_share_pct = 9.68",b:true},"."]]));

// 2.7 Example C
body.push(H2("2.7  Worked example C — reproduce Talk / Hold / Wrap / AHT and match the live grid"));
body.push(P([{t:"Sample rows",b:true}," from RTSData_UserStatusLog for agent.dana (OnDate '2026-06-09'). ",
  {t:"Duration is in MILLISECONDS:",b:true}]));
body.push(tbl(["StatusId","StatusGroup","Duration (ms)"],
  [["Talk","ONPHONE","180000"],
   ["Talk","ONPHONE","240000"],
   ["Talk","ONPHONE","300000"],
   ["Hold","ONPHONE","30000"],
   ["Hold","ONPHONE","45000"],
   ["Wrap Up","ONPHONE","60000"],
   ["Wrap Up","ONPHONE","60000"],
   ["Wrap Up","ONPHONE","90000"]],
  [3120,3120,3120],{zebra:true, codeCols:[0,1]}));
body.push(P([{t:"By STATE (÷1000):",b:true}," Talk = (180+240+300)k ms = ",
  {t:"720 s",b:true},"; Hold = (30+45)k = ",{t:"75 s",b:true},
  "; Wrap = (60+60+90)k = ",{t:"210 s",b:true},". AHT = 720+75+210 = ",{t:"1005 s = 16:45",b:true}," over 3 calls = ",{t:"335 s (5:35) per call",b:true},"."]));
body.push(code([
  'SELECT l.[StatusId] AS state,',
  '       sum(l.[Duration])/1000.0 AS seconds   -- Duration is MILLISECONDS',
  'FROM [RTSData_UserStatusLog] l',
  "WHERE l.[OnDate] = '2026-06-09'",
  "  AND l.[UserId] = 'agent.dana'",
  "  AND l.[StatusId] IN ('Talk','Hold','Wrap Up')",
  'GROUP BY l.[StatusId];'
]));
body.push(callout('ok',"Parity with the live grid", [
  ["The same per-state seconds appear in RTSData_UserStatus.TotalDuration (Talk 720, Hold 75, Wrap 210) — the figures the wallboard showed live. ",
   {t:"They match because RTM persisted the same derived states it displayed.",b:true}],
  [{t:"Trap check:",b:true}," the ONPHONE ",{t:"group",i:true}," total here = 720+75+210 = ",{t:"1005 s",b:true},
   " (≈ AHT), NOT talk-only. For talk-only use the Talk ",{t:"state",b:true}," (720 s), as above."]
]));

// 2.8 Example D
body.push(H2("2.8  Worked example D — point-in-time wallboard reconciliation"));
body.push(P([{t:"Question:",b:true}," who was in what status at ",{t:"11:30 on 2026-06-09",b:true},
  "? Reconstruct it from the timeline (StartTime ≤ t < EndTime). Sample intervals:"]));
body.push(tbl(["UserId","StatusId","StatusGroup","StartTime","EndTime"],
  [["agent.dana","Talk","ONPHONE","2026-06-09 11:28","2026-06-09 11:33"],
   ["agent.omri","Break","BREAK","2026-06-09 11:15","2026-06-09 11:45"]],
  [1760,1500,1500,2300,2300],{zebra:true, codeCols:[0,1,2]}));
body.push(code([
  'SELECT l.[UserId], l.[StatusId], l.[StatusGroup]',
  'FROM [RTSData_UserStatusLog] l',
  "WHERE l.[OnDate] = '2026-06-09'",
  "  AND l.[StartTime] <= '2026-06-09T11:30:00'",
  "  AND (l.[EndTime] > '2026-06-09T11:30:00' OR l.[EndTime] IS NULL);"
]));
body.push(callout('ok',"Result", [["At 11:30 — ",{t:"agent.dana = Talk (ONPHONE)",b:true},", ",{t:"agent.omri = Break (BREAK)",b:true},
  ". This is exactly what the live wallboard showed at 11:30."]]));

// 2.9 live->historical map
body.push(H2("2.9  Live metric → historical query map"));
body.push(P("A starting map from common RTM live metrics to their historical source. The metric catalogue (docs/metrics-catalog.json) is the full reference."));
body.push(tbl(["RTM live metric","Source","Historical expression"],
  [["Cumulative Talk Duration (talk-only)","UserStatusLog / UserStatus","sum over Talk STATE; UserStatusLog.Duration/1000 (s)"],
   ["Cumulative Hold Duration","UserStatus (state 'Hold')","sum TotalDuration where StatusName='Hold' (s)"],
   ["Cumulative Wrap Up Duration","UserStatus (state 'Wrap Up')","sum TotalDuration where StatusName='Wrap Up' (s)"],
   ["Average Handling Duration (AHT)","UserStatusLog states","(Σ Talk+Hold+Wrap states) ÷ call count"],
   ["% Break of login","UserStatus","Σ BREAK TotalDuration ÷ Σ all TotalDuration"],
   ["Abandoned calls","Interaction","count DISTINCT InteractionId where IsAbandoned, via queue→BU"],
   ["Answered calls","Interaction","count where IsAnswered, via queue→BU"],
   ["Current status (point in time)","UserStatusLog","interval covering t (StartTime ≤ t < EndTime)"]],
  [3000,2560,3800],{zebra:true}));

// 2.10 common mistakes
body.push(H2("2.10  Common mistakes (tied to the gotchas)"));
body.push(...bullets([
  [{t:"Mixing ms and seconds",b:true}," — forgetting that UserStatusLog.Duration is milliseconds. Always /1000 before combining with UserStatus/Interaction seconds."],
  [{t:"Adding the ONPHONE group to talk-only",b:true}," — in a tenant whose ONPHONE group includes hold/wrap, the group total ≈ AHT. For talk-only, filter the Talk state."],
  [{t:"Folding SIGNOFF into UNAVAILABLE",b:true}," — sign-off is a distinct group. Confirm your tenant maps logged-out states to SIGNOFF; otherwise they fall to the UNAVAILABLE default and your shrinkage is wrong."],
  [{t:"Dropping ClassificationId = 'ALL'",b:true}," — the queue→BU join needs it; without it you can match nothing or duplicate."],
  [{t:"Joining on the uniqueidentifier PKs",b:true}," — join NGC tables on the string external ids (ExternalId / AgentgroupId / UserId / QueueId) and integer BU/SG ids, not on NGC_Queues.Id / NGC_AgentGroups.Id."],
  [{t:"Using = true / = false",b:true}," — SQL Server booleans are bit; compare with = 1 / = 0."],
  [{t:"Counting segments as calls",b:true}," — use count(DISTINCT InteractionId) for call volumes."],
  [{t:"Treating OnDate as a date",b:true}," — it is varchar; compare as a string."]
]));

// appendix / confirm checklist
body.push(H2("Appendix A — Confirm with your tenant before go-live"));
body.push(...bullets([
  [{t:"StatusGroups membership",b:true}," — which raw status names map to ONPHONE / BREAK / PAPERWORK / TRAINING / SIGNOFF, and whether ONPHONE includes Hold/Wrap (the double-count trap)."],
  [{t:"SIGNOFF mapping",b:true}," — confirm logged-out / Offline statuses are mapped to SIGNOFF rather than left to the UNAVAILABLE default."],
  [{t:"Talk / Hold / Wrap state names",b:true}," — the exact StatusName values your tenant uses (they may be localised, e.g. Hebrew)."],
  [{t:"Queue→BU and team mappings",b:true}," — that NGC_BusinessUnitQueueClassification (ClassificationId='ALL') and the agent→group→super-group→BU graph are populated for the BUs you report on."]
]));
body.push(P([{t:"Verification note: ",b:true,i:true},
  {t:"every column name, grain and unit in this guide was checked against the RTM schema and the RTM Twilio configuration on 2026-06-10; SQL Server data types are the standard mapping \u2014 confirm against your deployed schema.",i:true}]));

// =====================================================================
// ===== Real Time Metrics Table (appended) =====
body.push(H1("Real Time Metrics Table"));
body.push(P(["This is the ",{t:"RTSGrid_Metric",code:true}," catalogue \u2014 every metric RTM computes and streams in real time. ",{t:"To obtain historical data identical to the live figures, build your SQL filters as shown in the Metric Parameter column",b:true}," (the full table follows on the landscape pages)."]));
body.push(callout('note',"How to read the Metric Parameter column (the filter recipe)", [
  [{t:"Interaction metrics",b:true}," (Function = InteractionsCount, TalkDurationAvg, WaitDurationAvg, \u2026): the parameter is a boolean expression over ",{t:"RTSData_Interaction",code:true}," columns. Translate to SQL: ",{t:"== \u2192 =",code:true},", ",{t:"!= \u2192 <>",code:true},", ",{t:"&& \u2192 AND",code:true},", ",{t:"|| \u2192 OR",code:true},", ",{t:"!x \u2192 NOT x",code:true}," (booleans are bit — compare with = 1 / = 0)",". Apply it as the WHERE clause, plus your queue\u2192BU and OnDate filters."],
  [{t:"Agent-status metrics",b:true}," (Function = TotalStatusGroupDuration/Percent, TotalStatusDuration, UsersInStatusGroupCount, \u2026): the parameter is a ",{t:"StatusGroup",b:true}," value (e.g. ONPHONE, BREAK) or a ",{t:"StatusName",b:true}," value (e.g. Hold, Wrap Up). Filter ",{t:"RTSData_UserStatus",code:true},"/",{t:"UserStatusLog",code:true}," on StatusGroup (group-level) or StatusName (state-level)."],
  [{t:"Calc metrics",b:true}," (Function = Calc): the parameter is a formula over OTHER metrics in [brackets] \u2014 a ratio or percentage. Build each referenced metric with its own Metric Parameter, then apply the arithmetic."],
  [{t:"Empty Metric Parameter",b:true}," = an identity/text or fully-derived metric \u2014 no direct row filter."]
]));
body.push(H3("Example 1 \u2014 Abandoned calls (QueueNumAbandonedCalls)"));
body.push(P([{t:"Metric Parameter: ",b:true},{t:"(InteractionType==\"Call\") && (CallType==\"External\") && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest",code:true}]));
body.push(code(["-- QueueNumAbandonedCalls   (Function: InteractionsCount)", "SELECT count(DISTINCT i.[InteractionId]) AS abandoned_calls", "FROM [RTSData_Interaction] i", "WHERE i.[OnDate] = '2026-06-09'", "  AND i.[InteractionType]   = 'Call'", "  AND i.[CallType]          = 'External'", "  AND i.[Direction]         = 'Incoming'", "  AND i.[IsAbandoned]       = 1", "  AND i.[IsCallbackRequest] = 0;   -- !IsCallbackRequest", "-- scope to a BU with the queue->BU join from section 2.2"]));
body.push(H3("Example 2 \u2014 Break-group duration (MonAgentBreakDuration)"));
body.push(P([{t:"Metric Parameter: ",b:true},{t:"BREAK",code:true}," (a StatusGroup value; Function TotalStatusGroupDuration)."]));
body.push(code(["-- MonAgentBreakDuration   (Function: TotalStatusGroupDuration)", "-- Metric Parameter 'BREAK' = a StatusGroup value", "SELECT us.[UserId], sum(us.[TotalDuration]) AS break_seconds   -- SECONDS", "FROM [RTSData_UserStatus] us", "WHERE us.[OnDate] = '2026-06-09'", "  AND us.[StatusGroup] = 'BREAK'", "GROUP BY us.[UserId];"]));
body.push(H3("Example 3 \u2014 Short inbound calls < 15s (MonAgentNumberOfInboundCalls15sec)"));
body.push(P([{t:"Metric Parameter: ",b:true},{t:"CallType==\"External\" && Direction==\"Incoming\" && TalkTime<15 && (InteractionType==\"Call\" || InteractionType==\"Callback\")",code:true}]));
body.push(code(["-- MonAgentNumberOfInboundCalls15sec   (Function: InteractionsCount)", "SELECT count(DISTINCT i.[InteractionId]) AS short_inbound", "FROM [RTSData_Interaction] i", "WHERE i.[OnDate] = '2026-06-09'", "  AND i.[CallType]  = 'External'", "  AND i.[Direction] = 'Incoming'", "  AND i.[TalkTime]  < 15                       -- seconds", "  AND i.[InteractionType] IN ('Call','Callback');"]));
body.push(P([{t:"Note: ",b:true,i:true},{t:"the full catalogue (every active metric and its Metric Parameter) is on the landscape pages that follow.",i:true}]));

const CWL=12960;
function mcell(txt,w,opt){opt=opt||{};return new TableCell({borders:cellBorders,width:{size:w,type:WidthType.DXA},
  shading:opt.fill?{fill:opt.fill,type:ShadingType.CLEAR}:undefined,verticalAlign:VerticalAlign.CENTER,
  margins:{top:30,bottom:30,left:80,right:80},
  children:[new Paragraph({spacing:{after:0},children:[new TextRun({text:String(txt==null||txt===""?"\u2014":txt),
    bold:!!opt.bold,color:opt.color||undefined,font:opt.mono?"Courier New":"Arial",size:opt.size||15})]})]});}
function mtbl(rows){const W=[3400,2200,7360];
  const head=new TableRow({tableHeader:true,cantSplit:true,children:[
    mcell("Title",W[0],{bold:true,color:"FFFFFF",fill:NAVY,size:16}),
    mcell("Function",W[1],{bold:true,color:"FFFFFF",fill:NAVY,size:16}),
    mcell("Metric Parameter (historical filter recipe)",W[2],{bold:true,color:"FFFFFF",fill:NAVY,size:16})]});
  const rs=rows.map((r,i)=>new TableRow({cantSplit:true,children:[
    mcell(r[1],W[0],{fill:i%2?ZEBRA:undefined}),
    mcell(r[2],W[1],{fill:i%2?ZEBRA:undefined}),
    mcell(r[3],W[2],{mono:true,fill:i%2?ZEBRA:undefined})]}));
  return new Table({width:{size:CWL,type:WidthType.DXA},columnWidths:W,rows:[head,...rs]});}
const mbody=[
  new Paragraph({heading:HeadingLevel.HEADING_1,children:[new TextRun("Real Time Metrics Table \u2014 full catalogue")]}),
  P(["The complete RTSGrid_Metric catalogue ("+METRICS.length+" active metrics). The ",{t:"Metric Parameter",b:true}," column is the recipe to reproduce each metric historically."]),
  mtbl(METRICS)
];


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
      children:[ LOGOSM(), new TextRun({ text:"   RTM View Shell Data Connector — Unified Reporting Guide · SQL Server edition", size:16, color:"808080" }) ] }) ] }) },
    footers: { default: new Footer({ children:[ new Paragraph({
      tabStops:[{ type:"right", position:9360 }],
      children:[ new TextRun({ text:"Confidential — for the prospect BI & Customer-Service teams", size:16, color:"808080" }),
                 new TextRun({ text:"\tPage ", size:16, color:"808080" }),
                 new TextRun({ children:[PageNumber.CURRENT], size:16, color:"808080" }) ] }) ] }) },
    children: body
  },
  { properties:{ page:{ size:{ width:12240, height:15840, orientation:PageOrientation.LANDSCAPE },
      margin:{ top:1080, right:1080, bottom:1080, left:1080 } } },
    footers:{ default: new Footer({ children:[ new Paragraph({ tabStops:[{ type:"right", position:12960 }],
      children:[ new TextRun({ text:"RTM View Shell Data Connector \u2014 Real Time Metrics Table", size:16, color:"808080" }),
                 new TextRun({ text:"\tPage ", size:16, color:"808080" }),
                 new TextRun({ children:[PageNumber.CURRENT], size:16, color:"808080" }) ] }) ] }) },
    children: mbody }]
});

Packer.toBuffer(doc).then(buf=>{ fs.writeFileSync("/tmp/build/RTM_Unified_Reporting_Guide_EN_SQLServer.docx", buf);
  console.log("written", buf.length, "bytes"); });
