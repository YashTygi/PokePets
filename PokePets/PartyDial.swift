import AppKit

/// One party slot: who's in it and what clicking it does.
struct PartyMember {
    let stats: () -> PetStats
    let portrait: () -> Anim                     // the frame shown in the dial is its first frame
    let isOut: () -> Bool
    /// Send out / call back. `ballStart` is where the ball is thrown from (the menu bar icon), in screen points.
    let toggle: (_ ballStart: CGPoint) -> Void
}

/// The Poké Ball in the menu bar. Clicking it doesn't open a menu: a half-circle dial with the six
/// party slots drops down from it, with a stats card and an item tray below. Click a Pokémon to send it
/// out or call it back; drag a berry onto it to feed it. Right-click the icon for Settings and Quit.
final class PartyDial: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let party: [PartyMember]
    var onSettings: (() -> Void)?
    /// While an item is dragged out of the dial: where it is (screen points), then nil when it's let go.
    var onItemDrag: ((CGPoint?) -> Void)?
    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var hoverTimer: Timer?

    init(party: [PartyMember]) {
        self.party = party
        super.init()
        guard let button = statusItem.button else { return }
        let icon = NSImage(cgImage: Pixels.scaled(Pixels.pokeball, by: 3), size: NSSize(width: 18, height: 18))
        button.image = icon                       // 12 px art × 3 = crisp on Retina at 18 pt
        button.toolTip = "PokePets"
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Where a thrown Poké Ball starts: just under the menu bar icon (screen points).
    var ballStart: CGPoint {
        let f = statusItem.button?.window?.frame ?? .zero
        return CGPoint(x: f.midX, y: f.minY)
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        panel == nil ? open() : close()
    }

    @objc private func openSettings() { onSettings?() }

    private func showMenu() {
        close()
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PokePets", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu                    // attach just for this click, so left-click stays menu-free
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func open() {
        guard let buttonFrame = statusItem.button?.window?.frame else { return }
        let ballStart = CGPoint(x: buttonFrame.midX, y: buttonFrame.minY)
        let view = DialView(party: party)
        view.onPick = { [weak self] i in
            self?.close()
            self?.party[i].toggle(ballStart)
        }
        view.onDrag = { [weak self] point in
            self?.panel?.alphaValue = 0                    // out of the way while you drag the item
            self?.onItemDrag?(point)
            if point == nil { self?.close() }
        }
        let size = DialView.size
        let panel = NSPanel(contentRect: NSRect(x: buttonFrame.midX - size.width / 2, y: buttonFrame.minY - size.height - 4,
                                                width: size.width, height: size.height),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true                   // follows the ring's shape
        panel.level = .popUpMenu
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .auxiliary]
        panel.contentView = view
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        view.appear()
        self.panel = panel
        // Clicking anywhere else closes it (needs no permission).
        monitors = [NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.panel?.alphaValue != 0 { self?.close() }   // (not mid-drag)
        }].compactMap { $0 }
        // macOS doesn't send mouse moves to a window of an app that isn't active, so while the dial is
        // open (only then) we check where the cursor is, 30 times a second, for the hover highlight.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak view] _ in
            view?.track(NSEvent.mouseLocation)
        }
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        hoverTimer?.invalidate()
        hoverTimer = nil
    }
}

/// The dial itself: a frosted-glass arc hanging from the menu bar, six round slots along it, the
/// hovered Pokémon's name and status in the middle, and below it a card with the lead Pokémon's
/// stats and a tray of items to drag onto it.
private final class DialView: NSView, NSDraggingSource {
    static let size = NSSize(width: 316, height: 272)
    private static let radius: CGFloat = 114          // arc centre line
    private static let thickness: CGFloat = 64
    private static let slotSize: CGFloat = 46
    private static let arcStart = CGFloat.pi * 1.06, arcEnd = CGFloat.pi * 1.94
    private static let accent = NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1)   // Pikachu yellow

    var onPick: ((Int) -> Void)?
    var onDrag: ((CGPoint?) -> Void)?
    private let party: [PartyMember]
    private var items: [(item: Item, rect: CGRect)] = []
    private let content = CALayer()
    private var slots: [(container: CALayer, disc: CALayer)] = []
    private let name = CATextLayer()
    private let status = CATextLayer()
    private var hovered: Int? { didSet { if hovered != oldValue { refresh(animated: true) } } }

    init(party: [PartyMember]) {
        self.party = party
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.maxY) }    // top middle, under the icon

    /// The arc's outline: its centre line stroked to the ring's thickness, with round ends.
    private var ringPath: CGPath {
        let line = CGMutablePath()
        line.addArc(center: center, radius: Self.radius, startAngle: Self.arcStart, endAngle: Self.arcEnd, clockwise: false)
        return line.copy(strokingWithWidth: Self.thickness, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }

    /// The little pill in the middle that holds the name and status, so they stay readable.
    private var pillRect: CGRect { CGRect(x: center.x - 74, y: center.y - 86, width: 148, height: 48) }   // its bottom melts into the ring

    /// The stats card under the arc.
    private var cardRect: CGRect { CGRect(x: bounds.midX - 128, y: 6, width: 256, height: 102) }

    /// Slot centres, evenly spread along the arc, left to right.
    private func slotCenter(_ i: Int) -> CGPoint {
        let inset: CGFloat = 0.06 * .pi
        let angle = Self.arcStart + inset + (Self.arcEnd - Self.arcStart - 2 * inset) * CGFloat(i) / 5
        return CGPoint(x: center.x + Self.radius * cos(angle), y: center.y + Self.radius * sin(angle))
    }

    private func build() {
        // Frosted glass, cut to the arc's shape.
        let glass = NSVisualEffectView(frame: bounds)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .vibrantDark)
        let pill = CGPath(roundedRect: pillRect, cornerWidth: 20, cornerHeight: 20, transform: nil)
        let card = CGPath(roundedRect: cardRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
        let neck = CGPath(rect: CGRect(x: bounds.midX - 30, y: cardRect.maxY - 10,
                                       width: 60, height: center.y - Self.radius - cardRect.maxY + 30), transform: nil)
        let shape = ringPath.union(pill).union(card).union(neck)            // one glass shape
        glass.maskImage = NSImage(size: bounds.size, flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(cgPath: shape).fill()
            return true
        }
        addSubview(glass)

        let overlay = NSView(frame: bounds)
        overlay.wantsLayer = true
        addSubview(overlay)
        overlay.layer?.addSublayer(content)
        content.frame = bounds

        let tint = CAShapeLayer()                                            // a touch darker, for contrast on bright desktops
        tint.path = shape
        tint.fillColor = NSColor(white: 0, alpha: 0.22).cgColor
        tint.strokeColor = NSColor(white: 1, alpha: 0.14).cgColor          // hairline highlight around the glass
        tint.lineWidth = 1
        content.addSublayer(tint)

        for i in 0..<6 { slots.append(makeSlot(i)) }

        for (layer, size, weight, alpha) in [(name, 14.0, NSFont.Weight.semibold, 1.0), (status, 10.5, .medium, 0.62)] {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            layer.font = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? font
            layer.fontSize = size
            layer.alignmentMode = .center
            layer.foregroundColor = NSColor(white: 1, alpha: alpha).cgColor
            layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            content.addSublayer(layer)
        }
        name.frame = CGRect(x: pillRect.minX, y: pillRect.midY + 2, width: pillRect.width, height: 18)
        status.frame = CGRect(x: pillRect.minX, y: pillRect.midY - 13, width: pillRect.width, height: 14)
        // The card shows the first Pokémon that's out (else the first slot); the tray has every evolution item someone can use.
        if let lead = party.first(where: { $0.isOut() && !$0.stats().isEgg }) ?? party.first { buildCard(lead.stats()) }
        refresh(animated: false)
    }

    /// Portrait, level and three meters on top; the draggable items along the bottom.
    private func buildCard(_ s: PetStats) {
        let c = cardRect
        let face = CALayer()
        face.contents = s.portrait
        face.magnificationFilter = .nearest
        face.frame = CGRect(x: c.minX + 12, y: c.maxY - 58, width: 48, height: 48)
        face.cornerRadius = 9
        face.masksToBounds = true
        content.addSublayer(face)

        if s.isEgg {
            content.addSublayer(text("Egg", size: 13, weight: .semibold,
                                     frame: CGRect(x: c.minX + 70, y: c.maxY - 24, width: 180, height: 16)))
            content.addSublayer(text("Something is moving inside!\nClick it above to hatch it.", size: 10.5, weight: .medium,
                                     alpha: 0.65, frame: CGRect(x: c.minX + 70, y: c.maxY - 60, width: 180, height: 32)))
            return
        }
        content.addSublayer(text("\(s.name) \(s.gender)\(s.shiny ? " ★" : "")\(s.pokerus == .infected ? " · PKRS" : "")  ·  Lv \(s.level)  ·  \(Int(s.levelProgress * 100))%", size: 12.5, weight: .semibold,
                                 frame: CGRect(x: c.minX + 70, y: c.maxY - 24, width: 180, height: 16)))
        for (i, (label, value, color)) in [("Friendship", s.friendship / Growth.maxFriendship, NSColor.systemPink),
                                           ("Belly", 1 - s.hunger, NSColor.systemOrange),
                                           ("Energy", s.energy, NSColor.systemYellow)].enumerated() {
            let y = c.maxY - 38 - CGFloat(i) * 11
            content.addSublayer(text(label, size: 9, weight: .medium, alpha: 0.6,
                                     frame: CGRect(x: c.minX + 70, y: y - 4, width: 60, height: 11), align: .left))
            let track = CALayer(), bar = CALayer()
            track.frame = CGRect(x: c.minX + 132, y: y, width: 108, height: 4)
            track.cornerRadius = 2
            track.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor
            bar.frame = CGRect(x: 0, y: 0, width: 108 * max(0.04, min(1, value)), height: 4)
            bar.cornerRadius = 2
            bar.backgroundColor = color.cgColor
            track.addSublayer(bar)
            content.addSublayer(track)
        }

        let ready = party.map { $0.stats() }.filter(\.canEvolve).compactMap(\.evolveItem)
        let available = Item.allCases.filter { $0.isBerry || ready.contains($0) }
        for (i, item) in available.enumerated() {
            let rect = CGRect(x: c.minX + 12 + CGFloat(i) * 32, y: c.minY + 8, width: 26, height: 26)
            let chip = CALayer()
            chip.frame = rect
            chip.cornerRadius = 8
            chip.backgroundColor = NSColor(white: 1, alpha: 0.1).cgColor
            let art = CALayer()
            art.contents = item.image
            art.magnificationFilter = .nearest
            art.frame = chip.bounds.insetBy(dx: 4, dy: 4)
            chip.addSublayer(art)
            content.addSublayer(chip)
            items.append((item, rect))
        }

    }

    private func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1, frame: CGRect,
                      align: CATextLayerAlignmentMode = .left) -> CATextLayer {
        let t = CATextLayer()
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        t.font = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? font
        t.fontSize = size
        t.string = string
        t.alignmentMode = align
        t.foregroundColor = NSColor(white: 1, alpha: alpha).cgColor
        t.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        t.frame = frame
        return t
    }

    private func makeSlot(_ i: Int) -> (container: CALayer, disc: CALayer) {
        let c = slotCenter(i), d = Self.slotSize
        let container = CALayer()                                            // scales on hover
        container.bounds = CGRect(x: 0, y: 0, width: d, height: d)
        container.position = c

        let disc = CAGradientLayer()                                         // the round slot itself, clips the sprite
        disc.frame = container.bounds
        disc.cornerRadius = d / 2
        disc.masksToBounds = true
        container.addSublayer(disc)

        if i < party.count {
            disc.colors = [NSColor(white: 1, alpha: 0.2).cgColor, NSColor(white: 1, alpha: 0.06).cgColor]
            disc.borderWidth = 1
            let p = party[i].portrait()
            let sprite = CALayer()
            sprite.contents = p.image
            sprite.contentsRect = p.frames[0]
            sprite.magnificationFilter = .nearest
            let s: CGFloat = 1.3
            sprite.bounds = CGRect(x: 0, y: 0, width: p.frameSize.width * s, height: p.frameSize.height * s)
            sprite.position = CGPoint(x: d / 2 + 4, y: d / 2 - 8)            // centre the body, which sits high in PMD frames
            let egg = party[i].stats().isEgg
            sprite.opacity = party[i].isOut() || egg ? 1 : 0.45
            disc.addSublayer(sprite)
            if !party[i].isOut() && !egg {                                   // resting in its ball
                let ball = CALayer()
                ball.contents = Pixels.pokeball
                ball.magnificationFilter = .nearest
                ball.frame = CGRect(x: d - 15, y: -1, width: 16, height: 16)
                container.addSublayer(ball)
            }
        } else {                                                             // empty: a dashed ring
            disc.colors = [NSColor.clear.cgColor, NSColor.clear.cgColor]
            let dash = CAShapeLayer()
            dash.path = CGPath(ellipseIn: container.bounds.insetBy(dx: 1, dy: 1), transform: nil)
            dash.fillColor = nil
            dash.strokeColor = NSColor(white: 1, alpha: 0.22).cgColor
            dash.lineWidth = 1
            dash.lineDashPattern = [3, 4]
            container.addSublayer(dash)
        }
        content.addSublayer(container)
        return (container, disc)
    }

    private func refresh(animated: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.18 : 0)
        for (i, slot) in slots.enumerated() where i < party.count {
            let lit = i == hovered
            slot.disc.borderColor = (lit ? Self.accent : NSColor(white: 1, alpha: 0.16)).cgColor
            slot.disc.borderWidth = lit ? 2 : 1
        }
        CATransaction.commit()
        for (i, slot) in slots.enumerated() where i < party.count {          // springy grow on hover
            let target: CGFloat = i == hovered ? 1.16 : 1
            guard animated else { slot.container.transform = CATransform3DMakeScale(target, target, 1); continue }
            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = slot.container.presentation()?.value(forKeyPath: "transform.scale") ?? 1
            spring.toValue = target
            spring.damping = 14
            spring.initialVelocity = 6
            spring.duration = spring.settlingDuration
            slot.container.transform = CATransform3DMakeScale(target, target, 1)
            slot.container.add(spring, forKey: "hover")
        }

        if let h = hovered, h < party.count {
            let stats = party[h].stats()
            name.string = stats.name
            status.string = stats.isEgg ? "Something's moving · click to hatch"
                : party[h].isOut() ? "Out · click to return" : "In its ball · click to send out"
        } else if hovered != nil {
            name.string = "Empty slot"
            status.string = "More Pokémon soon"
        } else {
            name.string = "Party"
            status.string = party.first?.stats().isEgg == true ? "\(party.count) of 6" : "Drag a berry onto it"
        }
    }

    /// Springs open from the menu bar icon; the slots pop in one after another.
    func appear() {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.duration = 0.16
        layer?.add(fade, forKey: "appear")
        for (i, slot) in slots.enumerated() {
            let pop = CASpringAnimation(keyPath: "transform.scale")
            pop.fromValue = 0.4
            pop.toValue = 1
            pop.damping = 12
            pop.beginTime = CACurrentMediaTime() + 0.03 * Double(i)
            pop.duration = pop.settlingDuration
            pop.fillMode = .backwards
            slot.container.add(pop, forKey: "appear")
        }
    }

    // MARK: Mouse

    private func slot(at p: CGPoint) -> Int? {
        (0..<6).first { hypot(slotCenter($0).x - p.x, slotCenter($0).y - p.y) <= Self.slotSize / 2 + 4 }
    }

    /// Highlight whichever slot is under the cursor (`screenPoint` in screen coordinates).
    func track(_ screenPoint: CGPoint) {
        guard let window else { return }
        hovered = slot(at: convert(window.convertPoint(fromScreen: screenPoint), from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        if let i = slot(at: convert(event.locationInWindow, from: nil)), i < party.count { onPick?(i) }
    }

    // MARK: Dragging items out

    private var pressedAt: CGPoint?

    override func mouseDown(with event: NSEvent) { pressedAt = convert(event.locationInWindow, from: nil) }

    override func mouseDragged(with event: NSEvent) {
        // Hit-test where the press started: by the first drag event the cursor may already be off the chip.
        guard let start = pressedAt, let hit = items.first(where: { $0.rect.contains(start) }) else { return }
        pressedAt = nil
        let p = convert(event.locationInWindow, from: nil)
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(hit.item.rawValue, forType: Item.pasteboardType)
        let drag = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let image = NSImage(cgImage: Pixels.scaled(hit.item.image, by: 4), size: NSSize(width: 32, height: 32))
        drag.setDraggingFrame(NSRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32), contents: image)
        beginDraggingSession(with: [drag], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .copy : []                       // only onto our own Pokémon
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) { onDrag?(screenPoint) }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDrag?(nil)
    }
}
