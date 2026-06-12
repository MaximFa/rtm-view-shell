import uno, sys, time
from com.sun.star.beans import PropertyValue
def mk(n,v):
    p=PropertyValue(); p.Name=n; p.Value=v; return p
inp,outp=sys.argv[1],sys.argv[2]
lc=uno.getComponentContext()
res=lc.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", lc)
ctx=None
for _ in range(40):
    try:
        ctx=res.resolve("uno:socket,host=127.0.0.1,port=2002;urp;StarOffice.ComponentContext"); break
    except Exception: time.sleep(1)
if ctx is None: print("NO CONNECT"); sys.exit(1)
smgr=ctx.ServiceManager
desktop=smgr.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)
doc=desktop.loadComponentFromURL(uno.systemPathToFileUrl(inp), "_blank", 0,
    (mk("Hidden",True), mk("ReadOnly",False), mk("UpdateDocMode",3)))
try: doc.refresh()
except Exception as e: print("refresh warn",e)
try:
    idx=doc.getDocumentIndexes()
    for i in range(idx.getCount()): idx.getByIndex(i).update()
    print("indexes updated:", idx.getCount())
except Exception as e: print("idx warn",e)
try: doc.getTextFields().refresh()
except Exception: pass
doc.storeToURL(uno.systemPathToFileUrl(outp), (mk("FilterName","writer_pdf_Export"),))
doc.close(False)
print("OK", outp)
