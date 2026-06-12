import json, sys

EX = {
 "pg": {
  "bool": " (booleans compare with = true / = false)",
  1:["-- QueueNumAbandonedCalls   (Function: InteractionsCount)",
     'SELECT count(DISTINCT i."InteractionId") AS abandoned_calls',
     'FROM "RTSData_Interaction" i',
     "WHERE i.\"TenantId\" = '...'            -- multi-tenant edition",
     "  AND i.\"OnDate\"   = '2026-06-09'",
     "  AND i.\"InteractionType\"   = 'Call'",
     "  AND i.\"CallType\"          = 'External'",
     "  AND i.\"Direction\"         = 'Incoming'",
     "  AND i.\"IsAbandoned\"       = true",
     "  AND i.\"IsCallbackRequest\" = false;   -- !IsCallbackRequest",
     "-- scope to a BU with the queue->BU join from section 2.2"],
  2:["-- MonAgentBreakDuration   (Function: TotalStatusGroupDuration)",
     "-- Metric Parameter 'BREAK' = a StatusGroup value",
     'SELECT us."UserId", sum(us."TotalDuration") AS break_seconds   -- SECONDS',
     'FROM "RTSData_UserStatus" us',
     "WHERE us.\"TenantId\" = '...'",
     "  AND us.\"OnDate\"   = '2026-06-09'",
     "  AND us.\"StatusGroup\" = 'BREAK'",
     'GROUP BY us."UserId";'],
  3:["-- MonAgentNumberOfInboundCalls15sec   (Function: InteractionsCount)",
     'SELECT count(DISTINCT i."InteractionId") AS short_inbound',
     'FROM "RTSData_Interaction" i',
     "WHERE i.\"TenantId\" = '...'",
     "  AND i.\"OnDate\"   = '2026-06-09'",
     "  AND i.\"CallType\"  = 'External'",
     "  AND i.\"Direction\" = 'Incoming'",
     "  AND i.\"TalkTime\"  < 15                       -- seconds",
     "  AND i.\"InteractionType\" IN ('Call','Callback');"],
 },
 "ms": {
  "bool": " (booleans are bit — compare with = 1 / = 0)",
  1:["-- QueueNumAbandonedCalls   (Function: InteractionsCount)",
     'SELECT count(DISTINCT i.[InteractionId]) AS abandoned_calls',
     'FROM [RTSData_Interaction] i',
     "WHERE i.[OnDate] = '2026-06-09'",
     "  AND i.[InteractionType]   = 'Call'",
     "  AND i.[CallType]          = 'External'",
     "  AND i.[Direction]         = 'Incoming'",
     "  AND i.[IsAbandoned]       = 1",
     "  AND i.[IsCallbackRequest] = 0;   -- !IsCallbackRequest",
     "-- scope to a BU with the queue->BU join from section 2.2"],
  2:["-- MonAgentBreakDuration   (Function: TotalStatusGroupDuration)",
     "-- Metric Parameter 'BREAK' = a StatusGroup value",
     'SELECT us.[UserId], sum(us.[TotalDuration]) AS break_seconds   -- SECONDS',
     'FROM [RTSData_UserStatus] us',
     "WHERE us.[OnDate] = '2026-06-09'",
     "  AND us.[StatusGroup] = 'BREAK'",
     'GROUP BY us.[UserId];'],
  3:["-- MonAgentNumberOfInboundCalls15sec   (Function: InteractionsCount)",
     'SELECT count(DISTINCT i.[InteractionId]) AS short_inbound',
     'FROM [RTSData_Interaction] i',
     "WHERE i.[OnDate] = '2026-06-09'",
     "  AND i.[CallType]  = 'External'",
     "  AND i.[Direction] = 'Incoming'",
     "  AND i.[TalkTime]  < 15                       -- seconds",
     "  AND i.[InteractionType] IN ('Call','Callback');"],
 },
}
P1='(InteractionType=="Call") && (CallType=="External") && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest'
P3='CallType=="External" && Direction=="Incoming" && TalkTime<15 && (InteractionType=="Call" || InteractionType=="Callback")'

def build_injection(dialect):
    e=EX[dialect]; J=lambda x:json.dumps(x,ensure_ascii=False)
    s=[]
    s.append('// ===== Real Time Metrics Table (appended) =====')
    s.append('body.push(H1("Real Time Metrics Table"));')
    s.append('body.push(P(["This is the ",{t:"RTSGrid_Metric",code:true}," catalogue \\u2014 every metric RTM computes and streams in real time. ",{t:"To obtain historical data identical to the live figures, build your SQL filters as shown in the Metric Parameter column",b:true}," (the full table follows on the landscape pages)."]));')
    s.append('body.push(callout(\'note\',"How to read the Metric Parameter column (the filter recipe)", [')
    s.append('  [{t:"Interaction metrics",b:true}," (Function = InteractionsCount, TalkDurationAvg, WaitDurationAvg, \\u2026): the parameter is a boolean expression over ",{t:"RTSData_Interaction",code:true}," columns. Translate to SQL: ",{t:"== \\u2192 =",code:true},", ",{t:"!= \\u2192 <>",code:true},", ",{t:"&& \\u2192 AND",code:true},", ",{t:"|| \\u2192 OR",code:true},", ",{t:"!x \\u2192 NOT x",code:true},'+J(e["bool"])+',". Apply it as the WHERE clause, plus your queue\\u2192BU and OnDate filters."],')
    s.append('  [{t:"Agent-status metrics",b:true}," (Function = TotalStatusGroupDuration/Percent, TotalStatusDuration, UsersInStatusGroupCount, \\u2026): the parameter is a ",{t:"StatusGroup",b:true}," value (e.g. ONPHONE, BREAK) or a ",{t:"StatusName",b:true}," value (e.g. Hold, Wrap Up). Filter ",{t:"RTSData_UserStatus",code:true},"/",{t:"UserStatusLog",code:true}," on StatusGroup (group-level) or StatusName (state-level)."],')
    s.append('  [{t:"Calc metrics",b:true}," (Function = Calc): the parameter is a formula over OTHER metrics in [brackets] \\u2014 a ratio or percentage. Build each referenced metric with its own Metric Parameter, then apply the arithmetic."],')
    s.append('  [{t:"Empty Metric Parameter",b:true}," = an identity/text or fully-derived metric \\u2014 no direct row filter."]')
    s.append(']));')
    # Example 1
    s.append('body.push(H3("Example 1 \\u2014 Abandoned calls (QueueNumAbandonedCalls)"));')
    s.append('body.push(P([{t:"Metric Parameter: ",b:true},{t:'+J(P1)+',code:true}]));')
    s.append('body.push(code('+J(e[1])+'));')
    # Example 2
    s.append('body.push(H3("Example 2 \\u2014 Break-group duration (MonAgentBreakDuration)"));')
    s.append('body.push(P([{t:"Metric Parameter: ",b:true},{t:"BREAK",code:true}," (a StatusGroup value; Function TotalStatusGroupDuration)."]));')
    s.append('body.push(code('+J(e[2])+'));')
    # Example 3
    s.append('body.push(H3("Example 3 \\u2014 Short inbound calls < 15s (MonAgentNumberOfInboundCalls15sec)"));')
    s.append('body.push(P([{t:"Metric Parameter: ",b:true},{t:'+J(P3)+',code:true}]));')
    s.append('body.push(code('+J(e[3])+'));')
    s.append('body.push(P([{t:"Note: ",b:true,i:true},{t:"the full catalogue (every active metric and its Metric Parameter) is on the landscape pages that follow.",i:true}]));')
    # mtbl helpers + mbody
    s.append('''
const CWL=12960;
function mcell(txt,w,opt){opt=opt||{};return new TableCell({borders:cellBorders,width:{size:w,type:WidthType.DXA},
  shading:opt.fill?{fill:opt.fill,type:ShadingType.CLEAR}:undefined,verticalAlign:VerticalAlign.CENTER,
  margins:{top:30,bottom:30,left:80,right:80},
  children:[new Paragraph({spacing:{after:0},children:[new TextRun({text:String(txt==null||txt===""?"\\u2014":txt),
    bold:!!opt.bold,color:opt.color||undefined,font:opt.mono?"Courier New":"Arial",size:opt.size||15})]})]});}
function mtbl(rows){const W=[2700,3000,2000,5260];
  const head=new TableRow({tableHeader:true,children:[
    mcell("MetricId",W[0],{bold:true,color:"FFFFFF",fill:NAVY,size:16}),
    mcell("Title",W[1],{bold:true,color:"FFFFFF",fill:NAVY,size:16}),
    mcell("Function",W[2],{bold:true,color:"FFFFFF",fill:NAVY,size:16}),
    mcell("Metric Parameter (historical filter recipe)",W[3],{bold:true,color:"FFFFFF",fill:NAVY,size:16})]});
  const rs=rows.map((r,i)=>new TableRow({children:[
    mcell(r[0],W[0],{mono:true,fill:i%2?ZEBRA:undefined}),
    mcell(r[1],W[1],{fill:i%2?ZEBRA:undefined}),
    mcell(r[2],W[2],{fill:i%2?ZEBRA:undefined}),
    mcell(r[3],W[3],{mono:true,fill:i%2?ZEBRA:undefined})]}));
  return new Table({width:{size:CWL,type:WidthType.DXA},columnWidths:W,rows:[head,...rs]});}
const mbody=[
  new Paragraph({heading:HeadingLevel.HEADING_1,children:[new TextRun("Real Time Metrics Table \\u2014 full catalogue")]}),
  P(["The complete RTSGrid_Metric catalogue ("+METRICS.length+" active metrics). The ",{t:"Metric Parameter",b:true}," column is the recipe to reproduce each metric historically."]),
  mtbl(METRICS)
];
''')
    return "\n".join(s)+"\n"

def inject(path, dialect):
    t=open(path).read()
    # 1) require PageOrientation + SectionType
    t=t.replace("VerticalAlign, PageNumber, PageBreak } = require('docx');",
                "VerticalAlign, PageNumber, PageBreak, PageOrientation } = require('docx');")
    # 2) METRICS require after the docx require line
    if "const METRICS" not in t:
        t=t.replace("} = require('docx');",
                    "} = require('docx');\nconst METRICS = require('/tmp/build/metrics_rows.js');",1)
    # 3) inject portrait block + mbody defs before const doc
    inj=build_injection(dialect)
    anchor="const doc = new Document({"
    assert anchor in t, "anchor missing"
    t=t.replace(anchor, inj+"\n"+anchor, 1)
    # 4) add landscape 2nd section
    old="    children: body\n  }]"
    assert old in t, "sections tail anchor missing"
    new=('    children: body\n  },\n'
         '  { properties:{ page:{ size:{ width:12240, height:15840, orientation:PageOrientation.LANDSCAPE },\n'
         '      margin:{ top:1080, right:1080, bottom:1080, left:1080 } } },\n'
         '    footers:{ default: new Footer({ children:[ new Paragraph({ tabStops:[{ type:"right", position:12960 }],\n'
         '      children:[ new TextRun({ text:"RTM View Shell Data Connector \\u2014 Real Time Metrics Table", size:16, color:"808080" }),\n'
         '                 new TextRun({ text:"\\tPage ", size:16, color:"808080" }),\n'
         '                 new TextRun({ children:[PageNumber.CURRENT], size:16, color:"808080" }) ] }) ] }) },\n'
         '    children: mbody }]')
    t=t.replace(old,new,1)
    open(path,"w").write(t)
    print("injected", dialect, "->", path)

inject("/tmp/build/gen.js","pg")
inject("/tmp/build/gen_mssql.js","ms")
