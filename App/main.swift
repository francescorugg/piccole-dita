import AppKit
import AVFoundation

let palette: [NSColor] = [.init(srgbRed: 0.98, green: 0.65, blue: 0.29, alpha: 1), .init(srgbRed: 0.43, green: 0.77, blue: 0.71, alpha: 1), .init(srgbRed: 0.69, green: 0.61, blue: 0.88, alpha: 1), .init(srgbRed: 0.96, green: 0.54, blue: 0.57, alpha: 1), .init(srgbRed: 0.48, green: 0.70, blue: 0.91, alpha: 1)]
let ink = NSColor(srgbRed: 0.15, green: 0.22, blue: 0.25, alpha: 1)
func label(_ text: String, _ rect: NSRect, size: CGFloat, color: NSColor = ink, weight: NSFont.Weight = .regular, align: NSTextAlignment = .center) {
    let p = NSMutableParagraphStyle(); p.alignment = align
    (text as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p])
}

struct Toy {
    var point: NSPoint
    let born: TimeInterval
    let color: NSColor
    let text: String
    let kind: Int
    let phase: Double
}

final class Music {
    var voices: [AVAudioPlayer] = []
    var cache: [Int: Data] = [:]
    func play(_ note: Int) {
        voices.removeAll { !$0.isPlaying }
        guard voices.count < 6 else { return }
        let n = abs(note) % 10
        if cache[n] == nil {
            let notes: [Double] = [261.63,293.66,329.63,392,440,523.25,587.33,659.25,783.99,880]
            let rate = 22050, count = 7938
            var data = Data()
            func word<T: FixedWidthInteger>(_ v: T) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            data.append(contentsOf: Array("RIFF".utf8)); word(UInt32(36 + count * 2)); data.append(contentsOf: Array("WAVEfmt ".utf8)); word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate * 2)); word(UInt16(2)); word(UInt16(16)); data.append(contentsOf: Array("data".utf8)); word(UInt32(count * 2))
            for i in 0..<count {
                let t = Double(i) / Double(rate)
                let env = min(1, t / 0.012) * exp(-t * 11) * min(1, Double(count - i) / 300)
                let sound = (sin(2 * .pi * notes[n] * t) + 0.18 * sin(4 * .pi * notes[n] * t)) * env * 0.16
                word(Int16(sound * 32767))
            }
            cache[n] = data
        }
        if let data = cache[n], let player = try? AVAudioPlayer(data: data) { voices.append(player); player.play() }
    }
    func stop() { voices.forEach { $0.stop() }; voices.removeAll() }
}

final class PlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let game = contentView as? Playground, game.playing { game.keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class Playground: NSView {
    var playing = false
    var sound = true
    var calm = false
    var theme = 0
    var count = 0
    var toys: [Toy] = []
    var music = Music()
    var ticker: Timer?
    var heldP = false
    var heldFlags: NSEvent.ModifierFlags = []
    var exitSince: TimeInterval?
    var savedOptions: NSApplication.PresentationOptions = []
    var savedFrame = NSRect.zero
    var lastSpawn: TimeInterval = 0
    var startTime: TimeInterval = 0
    var preview = false
    let animals = ["🐳", "🐥", "🐢", "🦋", "🐙", "🐱", "🐶", "🦊", "🐸", "🐼"]
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        setAccessibilityLabel("Piccole Dita: gioco della tastiera")
    }
    required init?(coder: NSCoder) { fatalError() }
    var startRect: NSRect { NSRect(x: bounds.midX - 150, y: 136, width: 300, height: 62) }
    var soundRect: NSRect { NSRect(x: bounds.midX - 280, y: 225, width: 170, height: 44) }
    var calmRect: NSRect { NSRect(x: bounds.midX - 85, y: 225, width: 170, height: 44) }
    var themeRect: NSRect { NSRect(x: bounds.midX + 110, y: 225, width: 170, height: 44) }
    func start() {
        guard let window, !playing else { return }
        savedFrame = window.frame; savedOptions = NSApp.presentationOptions
        heldP = false; exitSince = nil; toys.removeAll(); count = 0; startTime = ProcessInfo.processInfo.systemUptime
        playing = true
        window.styleMask = [.borderless]
        window.setFrame((window.screen ?? NSScreen.main)!.frame, display: true)
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(self)
        needsDisplay = true
    }
    func stop() {
        guard playing else { return }
        playing = false; heldP = false; exitSince = nil; music.stop()
        NSApp.presentationOptions = savedOptions
        window?.styleMask = [.titled, .closable, .miniaturizable]
        window?.setFrame(savedFrame, display: true)
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if playing && heldP && heldFlags.intersection([.command, .option, .shift, .control]) == [.command, .option, .shift] {
            if exitSince == nil { exitSince = now }
            if now - exitSince! >= 2 { stop() }
        } else { exitSince = nil }
        toys.removeAll { now - $0.born > (calm ? 6 : 4) }
        if playing || !toys.isEmpty || preview { needsDisplay = true }
    }
    func spawn(_ text: String, note: Int, at point: NSPoint? = nil) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSpawn >= 0.045 else { return }
        lastSpawn = now; count += 1
        let p = point ?? NSPoint(x: CGFloat.random(in: 100...max(101,bounds.width-100)), y: CGFloat.random(in: 160...max(161,bounds.height-180)))
        let shown = theme == 1 ? animals[abs(note) % animals.count] : text
        toys.append(Toy(point: p, born: now, color: palette[abs(note) % palette.count], text: shown, kind: abs(note) % 3, phase: Double.random(in: 0...6.28)))
        if toys.count > 55 { toys.removeFirst(toys.count - 55) }
        if sound { music.play(note) }
        needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        if !playing { if event.keyCode == 36 { start() }; return }
        heldFlags = event.modifierFlags
        if event.keyCode == 35 { heldP = true }
        if event.isARepeat { return }
        let chars = (event.charactersIgnoringModifiers ?? "").uppercased()
        let safe = chars.count == 1 && chars.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        spawn(safe ? chars : animals[Int(event.keyCode) % animals.count], note: Int(event.keyCode))
    }
    override func keyUp(with event: NSEvent) { if event.keyCode == 35 { heldP = false; exitSince = nil } }
    override func flagsChanged(with event: NSEvent) {
        heldFlags = event.modifierFlags
        if playing { spawn("✦", note: Int(event.keyCode)) }
    }
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if playing { spawn(animals.randomElement()!, note: Int.random(in: 0..<10), at: p); return }
        if startRect.contains(p) { start() }
        else if soundRect.contains(p) { sound.toggle() }
        else if calmRect.contains(p) { calm.toggle() }
        else if themeRect.contains(p) { theme = (theme + 1) % 2 }
        needsDisplay = true
    }
    override func rightMouseDown(with event: NSEvent) { if playing { mouseDown(with: event) } }
    override func otherMouseDown(with event: NSEvent) { if playing { mouseDown(with: event) } }
    override func scrollWheel(with event: NSEvent) { if playing { spawn("✿", note: 4) } }
    override func mouseDragged(with event: NSEvent) { if playing { mouseDown(with: event) } }
    func pill(_ text: String, rect: NSRect, fill: NSColor, size: CGFloat = 15) {
        fill.setFill(); NSBezierPath(roundedRect: rect, xRadius: rect.height/2, yRadius: rect.height/2).fill()
        label(text, NSRect(x: rect.minX, y: rect.midY-size*0.65, width: rect.width, height: size*1.7), size: size, weight: .medium)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.98, green: 0.96, blue: 0.91, alpha: 1).setFill(); bounds.fill()
        // Quiet dot-paper background.
        NSColor(srgbRed: 0.23, green: 0.36, blue: 0.35, alpha: 0.08).setFill()
        for x in stride(from: CGFloat(20), to: bounds.width, by: 32) { for y in stride(from: CGFloat(20), to: bounds.height, by: 32) { NSBezierPath(ovalIn: NSRect(x: x,y: y,width: 2,height: 2)).fill() } }
        if !playing && !preview { drawWelcome(); return }
        let now = ProcessInfo.processInfo.systemUptime
        label("PICCOLE DITA", NSRect(x: 35,y: bounds.height-63,width: 200,height: 23),size: 15,weight: .bold,align: .left)
        label("Per uscire: tieni premuti ⌘ + ⌥ + ⇧ + P per 2 secondi", NSRect(x: 35,y: bounds.height-94,width: bounds.width-180,height: 28),size: 17,color: ink,weight: .semibold,align: .left)
        pill("✦  \(count)",rect:NSRect(x: bounds.width-125,y: bounds.height-76,width: 90,height: 38),fill:.white.withAlphaComponent(0.8))
        if toys.isEmpty { label("Premi un tasto ✨", NSRect(x:0,y:bounds.midY-35,width:bounds.width,height:80),size:48,weight:.semibold) }
        for toy in toys {
            let age = max(0, now-toy.born), duration = calm ? 6.0 : 4.0
            let alpha = CGFloat(min(1, (duration-age)*1.3))
            let enter = calm ? 1 : min(1,age/0.2)
            let size = CGFloat(115 + 12*sin(age*2+toy.phase)) * CGFloat(0.7+0.3*enter)
            let y = toy.point.y + (calm ? 0 : CGFloat(age*16))
            let r = NSRect(x:toy.point.x-size/2,y:y-size/2,width:size,height:size)
            toy.color.withAlphaComponent(alpha*0.28).setFill()
            NSBezierPath(roundedRect:r.insetBy(dx:-12,dy:-12),xRadius:toy.kind == 0 ? size : 32,yRadius:toy.kind == 0 ? size : 32).fill()
            toy.color.withAlphaComponent(alpha).setFill(); NSBezierPath(roundedRect:r,xRadius:toy.kind == 0 ? size : 28,yRadius:toy.kind == 0 ? size : 28).fill()
            label(toy.text, NSRect(x:r.minX-12,y:r.midY-43,width:r.width+24,height:95),size:68,color:ink.withAlphaComponent(alpha),weight:.bold)
            if !calm {
                for j in 0..<4 { let angle = Double(j)*1.57+toy.phase; let radius = Double(size)*0.75+age*6
                    toy.color.withAlphaComponent(alpha*0.6).setFill()
                    NSBezierPath(ovalIn:NSRect(x:toy.point.x+cos(angle)*radius,y:y+sin(angle)*radius,width:8,height:8)).fill()
                }
            }
        }
        label("Per il genitore: tieni premuti ⌘ ⌥ ⇧ P per 2 secondi",NSRect(x:0,y:24,width:bounds.width,height:25),size:14,color:ink.withAlphaComponent(0.48))
        if let since = exitSince {
            let progress = min(1,(now-since)/2)
            let r = NSRect(x:bounds.midX-180,y:68,width:360,height:54)
            NSColor.white.setFill(); NSBezierPath(roundedRect:r,xRadius:20,yRadius:20).fill()
            label("Continua a tenere premuti…",NSRect(x:r.minX,y:r.minY+19,width:r.width,height:24),size:17,weight:.semibold)
            palette[1].setFill(); NSBezierPath(roundedRect:NSRect(x:r.minX+16,y:r.minY+9,width:328*progress,height:5),xRadius:2,yRadius:2).fill()
        }
    }
    func drawWelcome() {
        let w = bounds.width, h = bounds.height
        pill("PER USCIRE: ⌘ + ⌥ + ⇧ + P per 2 secondi",rect:NSRect(x:w/2-310,y:h-70,width:620,height:38),fill:palette[1].withAlphaComponent(0.25),size:16)
        label("Piccole Dita",NSRect(x:0,y:h-163,width:w,height:80),size:58,weight:.bold)
        label("La tastiera diventa un parco giochi.",NSRect(x:0,y:h-202,width:w,height:32),size:21,color:ink.withAlphaComponent(0.65))
        let symbols = ["A", "🐳", "✦", "🐥", "B"]
        for i in 0..<5 { let side: CGFloat = 76; let x = w/2 + CGFloat(i-2)*97 - side/2
            let r = NSRect(x:x,y:h-315+(i%2==0 ? 0:12),width:side,height:side)
            palette[i].withAlphaComponent(0.8).setFill(); NSBezierPath(roundedRect:r,xRadius:24,yRadius:24).fill()
            label(symbols[i],NSRect(x:x,y:r.minY+6,width:side,height:62),size:43,weight:.bold)
        }
        pill(sound ? "♫  Suoni accesi" : "♫  Senza suoni",rect:soundRect,fill:.white)
        pill(calm ? "☁  Movimento calmo" : "✦  Movimento vivace",rect:calmRect,fill:.white,size:13)
        pill(theme == 0 ? "ABC  Lettere e amici" : "🐳  Solo animaletti",rect:themeRect,fill:.white,size:13)
        pill("Inizia a giocare  ↗",rect:startRect,fill:palette[1],size:21)
        label("USCITA GENITORE   ⌘ + ⌥ + ⇧ + P   per 2 secondi",NSRect(x:0,y:88,width:w,height:26),size:14,weight:.semibold)
        label("Esc e le scorciatoie di chiusura diventano gioco.\nEmergenza: ⌘ + ⌥ + Esc. I tasti di sistema e i gesti del trackpad possono restare attivi.",NSRect(x:35,y:24,width:w-70,height:48),size:12,color:ink.withAlphaComponent(0.60))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: PlayWindow!
    var game: Playground!
    var monitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item)
        let submenu = NSMenu(); submenu.addItem(withTitle:"Esci da Piccole Dita",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); item.submenu = submenu; NSApp.mainMenu = menu
        window = PlayWindow(contentRect:NSRect(x:0,y:0,width:860,height:670),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Piccole Dita"; window.isReleasedWhenClosed = false; window.delegate = self
        game = Playground(frame:NSRect(x:0,y:0,width:860,height:670)); game.autoresizingMask = [.width,.height]; window.contentView = game
        monitor = NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.keyUp,.flagsChanged]) { [weak self] event in
            guard let self, self.game.playing else { return event }
            switch event.type { case .keyDown: self.game.keyDown(with:event); case .keyUp:self.game.keyUp(with:event); default:self.game.flagsChanged(with:event) }
            return nil
        }
        window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(game); NSApp.activate(ignoringOtherApps:true)
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline:.now()+0.3) {
                self.game.start()
                precondition(NSApp.presentationOptions.contains(.disableProcessSwitching))
                for key in [53,12,13,35,48,36] {
                    let event = NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.command],timestamp:0,windowNumber:self.window.windowNumber,context:nil,characters:"q",charactersIgnoringModifiers:"q",isARepeat:false,keyCode:UInt16(key))!
                    precondition(self.window.performKeyEquivalent(with:event))
                    precondition(self.game.playing)
                }
                precondition(self.applicationShouldTerminate(NSApp) == .terminateCancel)
                precondition(!self.windowShouldClose(self.window))
                self.game.heldP = true; self.game.heldFlags = [.command, .option]
                self.game.exitSince = ProcessInfo.processInfo.systemUptime-3
                self.game.tick(); precondition(self.game.playing && self.game.exitSince == nil)
                self.game.music.play(1); precondition(self.game.music.cache[1] != nil)
                self.game.heldP = true; self.game.heldFlags = [.command,.option,.shift]; self.game.exitSince = ProcessInfo.processInfo.systemUptime-2.1
                self.game.tick(); precondition(!self.game.playing); precondition(!NSApp.presentationOptions.contains(.disableProcessSwitching))
                print("PASS: protected mode, intercepted shortcuts, held exit, presentation restore")
                NSApp.terminate(nil)
            }
        }
        if CommandLine.arguments.contains("--preview") {
            game.preview = true
            for (i,s) in ["A","🐳","B","🐥","✦"].enumerated() { game.toys.append(Toy(point:NSPoint(x:140+i*145,y:310+(i%2)*75),born:ProcessInfo.processInfo.systemUptime+10,color:palette[i],text:s,kind:i%3,phase:Double(i))) }
            DispatchQueue.main.asyncAfter(deadline:.now()+0.3) {
                let image = self.game.bitmapImageRepForCachingDisplay(in:self.game.bounds)!
                self.game.cacheDisplay(in:self.game.bounds,to:image)
                if let data = image.representation(using:.png,properties:[:]) { try? data.write(to:URL(fileURLWithPath:CommandLine.arguments.last!)) }
                NSApp.terminate(nil)
            }
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { !game.playing }
    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { game.playing ? .terminateCancel : .terminateNow }
    func applicationWillResignActive(_ notification: Notification) { game.heldP = false; game.exitSince = nil; game.heldFlags = [] }
    func applicationWillTerminate(_ notification: Notification) { if game.playing { game.stop() }; if let monitor { NSEvent.removeMonitor(monitor) } }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
