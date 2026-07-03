const pptxgen = require("pptxgenjs");
const TEAL="0F3D3B", DARK="0A2B29", ACCENT="2ECC71", CREAM="F5F2F2", INK="14302E", GREY="5A6A6A", WHITE="FFFFFF", WARN="B5651D";
const FT="Arial", W=13.33, H=7.5;
function newDeck(title){ const p=new pptxgen(); p.defineLayout({name:"W",width:W,height:H}); p.layout="W"; p.author="INSIGHTENSE"; p.title=title; return p; }
function rt(items){ return items.map(it=> (typeof it==="string")
  ? {text:it,options:{bullet:{indent:18},color:INK,fontSize:16,breakLine:true,paraSpaceAfter:10}}
  : {text:it.t,options:{bullet:{indent:18},color:it.c||INK,fontSize:it.sz||16,bold:!!it.b,breakLine:true,paraSpaceAfter:10,indentLevel:it.lvl||0}}); }
function mk(p, footerText){
  return {
    title(t,sub,ed){ const s=p.addSlide(); s.background={color:TEAL};
      s.addShape(p.shapes.RECTANGLE,{x:0,y:0,w:W,h:2.0,fill:{color:DARK}});
      s.addImage({path:"logo_white.png",x:0.6,y:0.55,w:3.6,h:0.85});
      s.addShape(p.shapes.RECTANGLE,{x:0.65,y:3.5,w:1.6,h:0.10,fill:{color:ACCENT}});
      s.addText(t,{x:0.6,y:3.7,w:11.8,h:1.4,fontFace:FT,fontSize:40,bold:true,color:WHITE});
      s.addText(sub,{x:0.65,y:5.1,w:11.8,h:0.9,fontFace:FT,fontSize:18,color:"BFE3D6"});
      s.addText(ed,{x:0.65,y:H-0.95,w:11,h:0.4,fontFace:FT,fontSize:11,color:"8FB8AC"}); return s; },
    content(t, items, opt){ opt=opt||{}; const s=p.addSlide(); s.background={color:CREAM};
      s.addShape(p.shapes.RECTANGLE,{x:0,y:0,w:W,h:1.15,fill:{color:TEAL}});
      s.addShape(p.shapes.RECTANGLE,{x:0,y:1.15,w:W,h:0.07,fill:{color:ACCENT}});
      s.addImage({path:"logo_white.png",x:W-3.05,y:0.34,w:2.45,h:0.58});
      s.addText(t,{x:0.55,y:0,w:9.3,h:1.15,fontFace:FT,fontSize:24,bold:true,color:WHITE,valign:"middle"});
      if(opt.intro) s.addText(opt.intro,{x:0.6,y:1.45,w:12.1,h:0.6,fontFace:FT,fontSize:14,italic:true,color:GREY});
      const y0=opt.intro?2.15:1.6;
      s.addText(rt(items),{x:0.7,y:y0,w:12.0,h:H-y0-0.5,fontFace:FT,valign:"top"});
      s.addShape(p.shapes.RECTANGLE,{x:0,y:H-0.32,w:W,h:0.32,fill:{color:TEAL}});
      s.addText(footerText,{x:0.4,y:H-0.32,w:9,h:0.32,fontFace:FT,fontSize:8.5,color:"CFE8DF",valign:"middle"});
      s.addText(`${p.slides.length}`,{x:W-0.9,y:H-0.32,w:0.5,h:0.32,fontFace:FT,fontSize:8.5,color:"CFE8DF",align:"right",valign:"middle"});
      return s; },
    closing(t,lines){ const s=p.addSlide(); s.background={color:TEAL};
      s.addShape(p.shapes.RECTANGLE,{x:0,y:0,w:W,h:2.0,fill:{color:DARK}});
      s.addImage({path:"logo_white.png",x:0.6,y:0.6,w:3.4,h:0.80});
      s.addShape(p.shapes.RECTANGLE,{x:0.65,y:3.2,w:1.6,h:0.10,fill:{color:ACCENT}});
      s.addText(t,{x:0.6,y:3.4,w:11.6,h:1,fontFace:FT,fontSize:34,bold:true,color:WHITE});
      s.addText(lines.map(l=>({text:l,options:{bullet:{indent:18},color:"CFE8DF",fontSize:16,breakLine:true,paraSpaceAfter:10}})),{x:0.75,y:4.6,w:11.5,h:2,fontFace:FT}); return s; }
  };
}
module.exports={newDeck,mk,COL:{TEAL,ACCENT,WARN,GREY}};
