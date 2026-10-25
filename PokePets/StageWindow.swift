import AppKit

/// A transparent window covering one whole screen. The Pokémon live on this "stage".
///
/// The stage sits at the **desktop level**: just above the desktop icons, below every app window.
/// So app windows, full-screen apps and Stage Manager thumbnails always cover the pets. They only
/// show where you can see the desktop. With "Walks over your apps" on (the default) it rises above
/// app windows instead, and only drops back behind them for full-screen windows and videos,
/// YouTube, and apps you list in Settings.
///
/// Clicks normally pass straight through. Only while the cursor is over a visible Pokémon does the
/// stage accept mouse events, so you can pick it up. It's a non-activating panel, so grabbing a pet
/// never steals focus from the app you're using.
final class StageWindow: NSPanel {
    private var pets: [Pet] = []
    private var held: (pet: Pet, grab: CGVector)?
    private var mouseMonitor: Any?
    private var ground: [Ground] = []          // floor + Dock
    private var icons: [Ground] = []           // tops of the files on your desktop
    private var iconsRead = Date.distantPast
    private var iconsAllowed = true            // false once you decline the Finder permission
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    /// Over app windows right now.
    private var raised = false { didSet { level = raised ? .floating : Self.desktopLevel } }
    private var raisedCheck: Timer?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false                           // allow see-through
        backgroundColor = .clear                   // fully transparent
        hasShadow = false
        ignoresMouseEvents = true                  // clicks go through to apps below
        hidesOnDeactivate = false                  // panels hide when the app is inactive by default
        acceptsMouseMovedEvents = true
        level = Self.desktopLevel                  // behind all apps
        collectionBehavior = [.canJoinAllSpaces,   // on every desktop/Space (never over full-screen apps)
                              .stationary,         // don't move during Mission Control
                              .ignoresCycle,       // skip in ⌘` window cycling
                              .auxiliary]          // not an app window: Stage Manager leaves it alone

        let view = StageView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true                     // GPU-backed, needed for Core Animation
        view.stage = self
        view.registerForDraggedTypes([.fileURL, Item.pasteboardType])
        contentView = view

        // Mouse moves over other apps. Needs no permission (only keyboard monitoring does).
        // The mouse-up can land on another app (menu bar, a hot corner…), so watch for it everywhere,
        // otherwise a dropped pet would stay hanging in the air.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]) { [weak self] e in
            if e.type == .leftMouseUp { self?.mouseUp() } else { self?.cursorMoved() }
        }
        // The Dock grows or shrinks as apps launch and quit, or when its size changes.
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.updateGround() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.updateGround() }
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.updateRaised() }
        }
        updateGround()
        updateRaised()
    }

    // MARK: Over your apps

    /// Above app windows, except while the app in front fills the screen (a full-screen window or video),
    /// is playing YouTube, or is one you listed. Checked on every app or Space switch, and every 2 s
    /// (going full screen, opening a video).
    private func updateRaised() {
        let front = NSWorkspace.shared.frontmostApplication, id = front?.bundleIdentifier ?? ""
        let up = Setting.overApps.isOn && !Setting.behindApps.contains(id)
            && !(front.map { fillsScreen($0.processIdentifier) } ?? false) && !(Onboarding.done && Self.watchingYouTube(in: id))   // (asking the browser prompts: after the guide)
        if up != raised { raised = up }
        if Setting.overApps.isOn, raisedCheck == nil {
            raisedCheck = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.updateRaised() }
        } else if !Setting.overApps.isOn, up == raised {
            raisedCheck?.invalidate()
            raisedCheck = nil
        }
    }

    /// Is the browser in front showing a YouTube video? Asks the browser for its tab's address (macOS
    /// asks you once per browser; if you say no, it counts as not YouTube).
    /// ponytail: one AppleScript call every 2 s while a browser is in front; a few ms.
    private static func watchingYouTube(in browser: String) -> Bool {
        let chromium = ["com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac", "company.thebrowser.Browser",
                        "com.vivaldi.Vivaldi", "com.operasoftware.Opera"]
        let tab = browser == "com.apple.Safari" ? "current tab" : chromium.contains(browser) ? "active tab" : nil
        guard let tab else { return false }
        var error: NSDictionary?
        let url = NSAppleScript(source: "tell application id \"\(browser)\" to return URL of \(tab) of front window")?
            .executeAndReturnError(&error).stringValue ?? ""
        return ["youtube.com/watch", "youtube.com/shorts", "youtube.com/live", "youtu.be/"].contains { url.contains($0) }
    }

    /// Does one of this app's windows cover the whole screen?
    private func fillsScreen(_ pid: pid_t) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        return list.contains { w in
            guard w[kCGWindowOwnerPID as String] as? pid_t == pid, w[kCGWindowLayer as String] as? Int == 0,
                  let b = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: b) else { return false }
            return r.width >= frame.width - 1 && r.height >= frame.height - 1
        }
    }

    func add(_ pet: Pet, x: CGFloat) {
        pet.ground = ground
        pet.walkArea = 20...(frame.width - 20)
        pet.ceiling = (screen?.visibleFrame.maxY ?? frame.maxY) - frame.minY - 60 * pet.scale
        pet.openSpots = { [weak self] in self?.openSpots() ?? [] }
        pet.isVisible = { [weak self] p in !(self?.appWindows().contains { $0.contains(p) } ?? true) }
        pet.frontWindow = { [weak self] in self?.frontWindow() }
        pet.showMenu = { [weak self, weak pet] in
            DispatchQueue.main.async {                 // not inside a drop: the menu runs its own loop
                guard let self, let pet, let menu = pet.onMenu?() else { return }
                menu.popUp(positioning: nil, at: CGPoint(x: pet.position.x, y: pet.frame.maxY), in: self.contentView)
            }
        }
        pet.iconCenter = { [weak self] url in self.flatMap { Self.desktopIconCenter(of: url, screenHeight: $0.frame.height) } }
        pet.node.position = CGPoint(x: x, y: pet.floorY(at: x))
        contentView?.layer?.addSublayer(pet.node)
        pets.append(pet)
    }

    // MARK: Ground

    /// The desktop's bottom edge, with the Dock as a raised step in the middle.
    private func updateGround() {
        guard let screen = screen ?? NSScreen.main else { return }
        let width = frame.width
        if let dock = Self.dockSpan(screen: screen) {
            let top = screen.visibleFrame.minY - screen.frame.minY
            ground = [Ground(span: 0...dock.lowerBound, y: 0),
                      Ground(span: dock, y: top),
                      Ground(span: dock.upperBound...width, y: 0)]
        } else {
            ground = [Ground(span: 0...width, y: 0)]
        }
        pets.forEach { $0.ground = ground + icons }
    }

    /// Re-read where the desktop files are if it's been 20 s (only when a pet is choosing where to go).
    private func refreshIcons() {
        guard iconsAllowed, Date().timeIntervalSince(iconsRead) > 20 else { return }
        iconsRead = Date()
        guard let found = Self.desktopIcons(screenHeight: frame.height) else { iconsAllowed = false; return }
        icons = found
        pets.forEach { $0.ground = ground + icons }
    }

    /// The top edge of every file icon on the desktop, asked from Finder (macOS asks you once whether
    /// PokePets may talk to Finder). Returns nil if that's not allowed.
    /// ponytail: polled every 20 s while pets roam; FSEvents on ~/Desktop if that ever feels laggy.
    static func desktopIcons(screenHeight: CGFloat) -> [Ground]? {
        // Finder gives the icon's center, measured from the top of the screen. The artwork is a bit
        // narrower than its cell, and screenshot/video thumbnails are landscape, so their top edge
        // sits ~1/3 of the cell above the center (square icons like folders reach 1/2).
        func top(x: CGFloat, y: CGFloat, size: CGFloat) -> Ground {
            Ground(span: (x - size * 0.42)...(x + size * 0.42), y: screenHeight - y + size * 0.32, solid: false)
        }
        if let drawn = drawnDesktopIcons() { return drawn.map { top(x: $0.frame.midX, y: $0.frame.midY, size: $0.frame.width) } }
        let source = """
            tell application "Finder" to return {icon size of icon view options of window of desktop, \
            desktop position of every item of desktop}
            """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil,
              let positions = result.atIndex(2) else { return nil }
        let size = CGFloat(result.atIndex(1)?.int32Value ?? 64)
        guard positions.numberOfItems > 0 else { return [] }
        return (1...positions.numberOfItems).compactMap { i in
            guard let p = positions.atIndex(i), let x = p.atIndex(1)?.doubleValue,
                  let y = p.atIndex(2)?.doubleValue else { return nil }
            return top(x: x, y: y, size: size)
        }
    }

    /// Where the Dock sits along the bottom edge, or nil if it's hidden or on the side.
    ///
    /// macOS doesn't expose the Dock's width, so we count its icons the way the Dock lays them out:
    /// Finder + pinned apps | recent and running unpinned apps | folders/stacks + Trash. Each icon and
    /// each divider (and the end padding) takes one tile, the Dock's icon size setting.
    /// ponytail: estimate (±1 tile if the Dock's prefs file lags); read the exact frame through
    /// Accessibility once we ask for that permission.
    static func dockSpan(screen: NSScreen) -> ClosedRange<CGFloat>? {
        let height = screen.visibleFrame.minY - screen.frame.minY
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"
        guard height > 0, let prefs = NSDictionary(contentsOfFile: path) as? [String: Any],
              (prefs["orientation"] as? String ?? "bottom") == "bottom" else { return nil }

        func ids(_ key: String) -> [String] {
            (prefs[key] as? [[String: Any]] ?? []).compactMap { ($0["tile-data"] as? [String: Any])?["bundle-identifier"] as? String }
        }
        let pinned = Set(ids("persistent-apps"))
        let recents = (prefs["show-recents"] as? Bool ?? true) ? Set(ids("recent-apps")) : []
        let running = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier))
        let middle = recents.union(running).subtracting(pinned).subtracting(["com.apple.finder"])
        let others = (prefs["persistent-others"] as? [Any])?.count ?? 0

        let icons = 1 + pinned.count + middle.count + others + 1          // Finder … Trash
        let dividers = 1 + (middle.isEmpty ? 0 : 1)
        let tile = prefs["tilesize"] as? CGFloat ?? 48              // macOS default icon size
        let width = CGFloat(icons + dividers) * tile
        let mid = screen.frame.width / 2
        return (mid - width / 2)...(mid + width / 2)
    }

    /// Where Finder shows `url` on the desktop (centre of its icon), or nil if it isn't a desktop file.
    static func desktopIconCenter(of url: URL, screenHeight: CGFloat) -> CGPoint? {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        guard url.deletingLastPathComponent().standardizedFileURL == desktop.standardizedFileURL else { return nil }
        if let drawn = drawnDesktopIcons() {
            // Matched by the name Finder shows, which may hide the extension. Two files that differ only
            // in extension ("photo.png", "photo.jpg"): the one drawn nearest to where Finder means it to be.
            let exact = drawn.filter { $0.name == url.lastPathComponent }
            let found = exact.isEmpty ? drawn.filter { $0.name == url.deletingPathExtension().lastPathComponent } : exact
            let best = found.count < 2 ? found.first : scriptedIconCenter(of: url, screenHeight: screenHeight).flatMap { meant in
                found.min { hypot($0.frame.midX - meant.x, screenHeight - $0.frame.midY - meant.y)
                          < hypot($1.frame.midX - meant.x, screenHeight - $1.frame.midY - meant.y) }
            }
            if let best { return CGPoint(x: best.frame.midX, y: screenHeight - best.frame.midY) }
        }
        return scriptedIconCenter(of: url, screenHeight: screenHeight)
    }

    /// Desktop icons as Finder actually draws them: the name shown and the icon's frame (from the top
    /// of the screen), read through Accessibility. Finder's AppleScript `desktop position` is only where
    /// an icon is meant to go: macOS slides icons aside to make room for desktop widgets, so next to a
    /// widget it can be hundreds of points off. Nil without Accessibility permission.
    static func drawnDesktopIcons() -> [(name: String, frame: CGRect)]? {
        guard AXIsProcessTrusted(),
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { return nil }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        // Finder's only top-level scroll area is the desktop; the icons sit in a group inside it.
        guard let desktop = (AX.value(app, kAXChildrenAttribute) as [AXUIElement]?)?
                .first(where: { (AX.value($0, kAXRoleAttribute) as String?) == kAXScrollAreaRole }) else { return nil }
        let groups: [AXUIElement] = AX.value(desktop, kAXChildrenAttribute) ?? []
        return groups.flatMap { (AX.value($0, kAXChildrenAttribute) as [AXUIElement]?) ?? [] }.compactMap { icon in
            guard let name: String = AX.value(icon, kAXTitleAttribute), let frame = AX.frame(icon) else { return nil }
            return (name, frame)
        }
    }

    /// Where Finder means the icon to be (AppleScript `desktop position`, stage coordinates).
    private static func scriptedIconCenter(of url: URL, screenHeight: CGFloat) -> CGPoint? {
        let name = url.lastPathComponent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        guard let p = NSAppleScript(source: "tell application \"Finder\" to return desktop position of item \"\(name)\" of desktop")?
                .executeAndReturnError(&error), error == nil,
              let x = p.atIndex(1)?.doubleValue, let y = p.atIndex(2)?.doubleValue else { return nil }
        return CGPoint(x: x, y: screenHeight - y)
    }

    // MARK: What's visible

    /// App windows on screen, in stage coordinates. Our own window and the desktop aren't included.
    private func appWindows() -> [CGRect] {
        guard !raised else { return [] }                                       // over the windows: nothing covers it
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return [] }
        let height = frame.height
        return list.compactMap { w in
            guard w[kCGWindowLayer as String] as? Int == 0,                     // normal app windows
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b) else { return nil }
            return CGRect(x: r.minX, y: height - r.maxY, width: r.width, height: r.height)  // flip to y-up
        }
    }

    /// The front app's top window, while the pets are allowed over it (only then: never over full-screen
    /// windows, YouTube or apps you listed). Big enough to play in.
    private func frontWindow() -> CGRect? {
        if let fake = UserDefaults.standard.string(forKey: "PokePhaseWindow")?.split(separator: ",").compactMap({ Double($0) }),
           fake.count == 4 { return CGRect(x: fake[0], y: fake[1], width: fake[2], height: fake[3]) }   // dev: a pretend window
        guard raised, let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid(),
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        for w in list where w[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier && w[kCGWindowLayer as String] as? Int == 0 {
            guard (w[kCGWindowAlpha as String] as? Double ?? 1) > 0, let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b) else { continue }
            guard r.width >= 300, r.height >= 200 else { return nil }
            return CGRect(x: r.minX, y: frame.height - r.maxY, width: r.width, height: r.height)   // flip to y-up
        }
        return nil
    }

    /// Surfaces (or the parts of them) where the desktop is visible, i.e. not behind any app window.
    /// Called a few times a minute (when the pet picks somewhere to go), never per frame.
    private func openSpots() -> [Ground] {
        refreshIcons()
        let windows = appWindows()
        var open: [Ground] = []
        for g in ground + (raised ? [] : icons) {                             // desktop files are hidden under the app
            let band = CGRect(x: g.span.lowerBound, y: g.y, width: g.width, height: 30)   // paws and body need to be visible
            var free = [g.span]
            for w in windows where w.intersects(band) {
                free = free.flatMap { s -> [ClosedRange<CGFloat>] in
                    var parts: [ClosedRange<CGFloat>] = []
                    if w.minX > s.lowerBound { parts.append(s.lowerBound...min(w.minX, s.upperBound)) }
                    if w.maxX < s.upperBound { parts.append(max(w.maxX, s.lowerBound)...s.upperBound) }
                    return parts
                }
            }
            open += free.filter { $0.upperBound - $0.lowerBound > (g.solid ? 60 : 20) }
                        .map { Ground(span: $0, y: g.y, solid: g.solid) }
        }
        return open
    }

    // MARK: Mouse

    /// The pet under `point`, if you can actually see it there (no app window on top).
    /// `margin`: extra room around it (berries get a generous target, so they're easy to give).
    private func visiblePet(at point: CGPoint, margin: CGFloat = 0) -> Pet? {
        guard let pet = pets.last(where: { !$0.node.isHidden && $0.interactive
                                              && $0.frame.insetBy(dx: 2 * $0.scale - margin, dy: 2 * $0.scale - margin).contains(point) })
        else { return nil }
        return appWindows().contains { $0.contains(point) } ? nil : pet
    }

    /// Cursor location in stage coordinates.
    private var cursor: CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x - frame.minX, y: p.y - frame.minY)
    }

    /// Called for every mouse move. A few rectangle checks; the window list is only read when
    /// the cursor is actually over a pet.
    fileprivate func cursorMoved() {
        if held != nil, NSEvent.pressedMouseButtons & 1 == 0 { mouseUp() }   // missed release: drop it now
        guard held == nil else { return }
        let p = cursor
        let hit = visiblePet(at: p)
        if ignoresMouseEvents != (hit == nil) { ignoresMouseEvents = hit == nil }   // each change is a WindowServer call
        if NSEvent.pressedMouseButtons == 0 { hit?.onHover?(p); pets.forEach { $0.onCursor?(p) } }   // (not while you're dragging something over it)
    }

    /// An item being dragged out of the dial (screen point), or nil when it's let go. Our own drags
    /// don't reach the global mouse monitor, so the dial reports them.
    func itemDragMoved(_ screenPoint: CGPoint?) {
        guard let screenPoint else { cursorMoved(); return }
        let p = CGPoint(x: screenPoint.x - frame.minX, y: screenPoint.y - frame.minY)
        let hit = visiblePet(at: p, margin: 40)
        if ignoresMouseEvents != (hit == nil) { ignoresMouseEvents = hit == nil }
        for pet in pets where hypot(pet.position.x - p.x, pet.position.y - p.y) < 250 { pet.onItemNear?(p) }
    }

    // MARK: Drops

    /// Which pet a drag is over, and whether we take it: items always, files only with ⌥ held
    /// (that's the Thunderbolt delete; a plain file drop is left alone).
    fileprivate func dropTarget(_ info: NSDraggingInfo) -> Pet? {
        if info.draggingPasteboard.availableType(from: [Item.pasteboardType]) != nil {
            return visiblePet(at: info.draggingLocation, margin: 40)
        }
        guard let pet = visiblePet(at: info.draggingLocation) else { return nil }
        return NSEvent.modifierFlags.contains(.option) && Setting.thunderbolt.isOn ? pet : nil
    }

    fileprivate func drop(_ info: NSDraggingInfo) -> Bool {
        guard let pet = dropTarget(info) else { return false }
        let board = info.draggingPasteboard
        if let raw = board.string(forType: Item.pasteboardType), let item = Item(rawValue: raw) {
            pet.onItem?(item)
        } else if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
                  !urls.isEmpty {
            pet.onZap?(urls)
        }
        return true
    }

    fileprivate func mouseDown() {
        let p = cursor
        guard let pet = visiblePet(at: p) else {
            ignoresMouseEvents = true              // pet moved away; let the next click through
            return
        }
        held = (pet, CGVector(dx: pet.position.x - p.x, dy: pet.position.y - p.y))
        pet.onPickUp?()
    }

    fileprivate func rightClicked(_ event: NSEvent) {
        guard let pet = visiblePet(at: cursor), let menu = pet.onMenu?(), let view = contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    fileprivate func mouseDragged() {
        guard let held else { return }
        guard NSEvent.pressedMouseButtons & 1 != 0 else { mouseUp(); return }
        let p = cursor
        let x = p.x + held.grab.dx
        held.pet.drag(to: CGPoint(x: x, y: max(p.y + held.grab.dy, held.pet.floorY(at: x))))
    }

    fileprivate func mouseUp() {
        guard let held else { return }
        self.held = nil
        held.pet.onDrop?()
        cursorMoved()
    }

    deinit {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }
}

/// Forwards mouse events on the stage to the window.
private final class StageView: NSView {
    weak var stage: StageWindow?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }   // first click grabs immediately

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) { stage?.cursorMoved() }
    override func mouseDown(with event: NSEvent) { stage?.mouseDown() }
    override func rightMouseDown(with event: NSEvent) { stage?.rightClicked(event) }
    override func mouseDragged(with event: NSEvent) { stage?.mouseDragged() }
    override func mouseUp(with event: NSEvent) { stage?.mouseUp() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { stage?.dropTarget(sender) == nil ? [] : .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { stage?.dropTarget(sender) == nil ? [] : .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { stage?.drop(sender) ?? false }
}
