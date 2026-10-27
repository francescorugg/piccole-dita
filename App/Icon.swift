import AppKit
let image = NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
NSColor(srgbRed:0.98,green:0.96,blue:0.91,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:24,y:24,width:976,height:976),xRadius:220,yRadius:220).fill()
NSColor(srgbRed:0.43,green:0.77,blue:0.71,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:140,y:185,width:580,height:615),xRadius:150,yRadius:150).fill()
("A" as NSString).draw(at:NSPoint(x:252,y:245),withAttributes:[.font:NSFont.systemFont(ofSize:430,weight:.bold),.foregroundColor:NSColor(srgbRed:0.15,green:0.22,blue:0.25,alpha:1)])
NSColor(srgbRed:0.98,green:0.65,blue:0.29,alpha:1).setFill()
NSBezierPath(ovalIn:NSRect(x:621,y:169,width:260,height:260)).fill()
("✦" as NSString).draw(at:NSPoint(x:662,y:195),withAttributes:[.font:NSFont.systemFont(ofSize:180,weight:.bold),.foregroundColor:NSColor.white])
image.unlockFocus()
let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
