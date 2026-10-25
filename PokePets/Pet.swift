import AppKit

/// A menu item that runs a closure.
final class MenuAction: NSMenuItem {
    private let run: () -> Void
    init(_ title: String, _ run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { run() }
}

/// One animation, one direction: a row of a PMD SpriteCollab sheet. SpriteCollab sheets have a row per
/// direction (Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft); on the desktop we use Right
/// (row 2) and mirror it for left. Single-row sheets (Sleep and the like) use their only row.
struct Anim {
    let image: CGImage
    let frames: [CGRect]          // one entry per displayed step, in 0…1 unit coordinates of the row
    let frameSize: CGSize         // pixels
    let duration: CFTimeInterval  // one full cycle, in seconds
    /// Pixels from a frame's centre down to where the feet touch the ground. PMD sheets centre the
    /// character in each frame, but lying-down poses reach lower than standing ones, so it's measured
    /// from the art: the lowest opaque pixel in any frame.
    let feet: CGFloat
    /// Pixels from the feet up to the top of the art (its height, without the empty space PMD frames have).
    let height: CGFloat

    static let directions = 8
    static let right = 2

    /// - sheet: image file name in the app (without .png), SpriteCollab's sheet as published
    /// - ticks: how long each frame shows, in game ticks (1/60 s), from the species' AnimData.xml.
    ///   There is one entry per frame, so this also tells us how many columns the sheet has.
    /// - frameHeight: from AnimData.xml; the sheet's height over it is its number of rows.
    /// - firstFrame: just the first frame, held (looking up at your cursor: Idle's up-right row).
    /// - feet: override the measured feet (e.g. getting up from lying down: use the standing height).
    init(_ sheet: String, ticks: [Int], frameHeight: Int, row: Int = Anim.right, firstFrame: Bool = false, feet: CGFloat? = nil) {
        let whole = NSImage(named: sheet)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let rows = max(1, whole.height / max(1, frameHeight))
        let width = firstFrame ? whole.width / max(1, ticks.count) : whole.width
        let cut = CGRect(x: 0, y: (row < rows ? row : 0) * frameHeight, width: width, height: min(frameHeight, whole.height))
        self.init(row: whole.cropping(to: cut) ?? whole, ticks: firstFrame ? [ticks.first ?? 10] : ticks, feet: feet)
    }

    init(row image: CGImage, ticks: [Int], feet: CGFloat? = nil) {
        self.image = image
        let columns = max(1, ticks.count)
        frameSize = CGSize(width: image.width / columns, height: image.height)
        duration = CFTimeInterval(ticks.reduce(0, +)) / 60
        let rows = Self.opaqueRows(image)
        self.feet = feet ?? CGFloat(rows.lowest) + 1 - frameSize.height / 2
        height = CGFloat(rows.lowest - rows.highest + 1)

        let rects = (0..<columns).map { col in
            CGRect(x: CGFloat(col) / CGFloat(columns), y: 0, width: 1 / CGFloat(columns), height: 1)
        }
        // Frames can last different lengths (Idle holds frame 0 for 40 ticks, then 2–3 each).
        // Repeating each frame by its share of ticks keeps the timing exact with evenly spaced steps.
        let step = max(1, ticks.reduce(0) { gcd($0, $1) })
        frames = zip(rects, ticks).flatMap { rect, t in Array(repeating: rect, count: max(1, t / step)) }
    }
}

extension Anim {
    /// A single still image as a one-frame "animation" (e.g. the Egg in the dial).
    init(still image: CGImage) {
        self.image = image
        frames = [CGRect(x: 0, y: 0, width: 1, height: 1)]
        frameSize = CGSize(width: image.width, height: image.height)
        duration = 1
        feet = 0
        height = CGFloat(image.height)
    }

    /// Rows (from the top) of the highest and lowest pixels that aren't transparent, in any frame.
    private static func opaqueRows(_ image: CGImage) -> (highest: Int, lowest: Int) {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return (0, h - 1) }
        func opaque(_ row: Int) -> Bool { (0..<w).contains { pixels[(row * w + $0) * 4 + 3] > 25 } }
        let lowest = stride(from: h - 1, through: 0, by: -1).first(where: opaque) ?? h - 1   // bitmap rows run top to bottom
        let highest = (0..<h).first(where: opaque) ?? 0
        return (highest, lowest)
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

/// A flat surface at height `y` (stage coordinates, y up): a stretch of the desktop's bottom edge,
/// the Dock's top, or the top of a file icon. `solid` ones (floor, Dock) can't be dragged through;
/// icons are like ledges: you land on them when falling, but a held pet can pass through.
struct Ground {
    var span: ClosedRange<CGFloat>
    var y: CGFloat
    var solid = true
    var width: CGFloat { span.upperBound - span.lowerBound }
}

/// One creature on the stage.
///
/// `node` sits exactly at the pet's feet. Moving it moves the sprite and everything attached
/// (hearts, sparks). Only `sprite` gets flipped, so effects never mirror.
final class Pet {
    let node = CALayer()
    let sprite = CALayer()
    let bubble = CALayer()                      // emotion portrait above the head
    let caption = CATextLayer()                 // what it says, inside the dialogue box
    let dialog = CALayer()                      // Mystery Dungeon–style dialogue box above the head
    let dialogLine = CALayer()                  // the box's thin white inner border
    let dialogArrow = CATextLayer()             // the blinking ▼ at the bottom of the box
    let bubbleLine = CALayer()                  // the portrait frame's thin white inner border
    let thought = CALayer()                     // what it's thinking about, on the portrait's corner
    var bubbleTurn = 0                          // which showFace call the bubble currently belongs to
    let scale: CGFloat

    /// Everything the pet can stand on: desktop bottom edge, the Dock's top, file icons. Set by the stage.
    var ground: [Ground] = []
    var walkArea: ClosedRange<CGFloat> = 0...0  // x range the pet may roam
    var ceiling: CGFloat = 0                    // highest its feet may fly (below the menu bar). Set by the stage.
    /// The window you're working in (stage coordinates), if it's one the pets may be in front of right now
    /// (not full screen, not YouTube, not an app you listed). Set by the stage.
    var frontWindow: () -> CGRect? = { nil }
    /// Surfaces (or parts of them) you can see right now, i.e. not behind app windows. Set by the stage.
    var openSpots: () -> [Ground] = { [] }
    /// Can you see the desktop at this point (no app window over it)? Set by the stage.
    var isVisible: (CGPoint) -> Bool = { _ in true }
    private(set) var facingRight = true
    /// False while going into or coming out of its Poké Ball: no hovering or grabbing then.
    var interactive = true
    /// Can it leap big heights (Quick Attack)? Without it, it only hops up small steps like the Dock.
    var canLeap = true

    // Stage → pet events (the pet's brain fills these in).
    var onHover: ((CGPoint) -> Void)?
    var onCursor: ((CGPoint) -> Void)?          // every cursor move (stage coordinates), wherever it is
    var onPickUp: (() -> Void)?
    var onDrop: (() -> Void)?
    var onItem: ((Item) -> Void)?               // a berry or stone dragged onto it from the dial
    var onItemNear: ((CGPoint) -> Void)?        // an item is being dragged close to it
    var onZap: (([URL]) -> Void)?               // files ⌥-dropped onto it
    var onMenu: (() -> NSMenu?)?                // right-click menu (nil: none right now)
    /// Pops the right-click menu up above the pet without a click. Set by the stage.
    var showMenu: (() -> Void)?
    /// Centre of a desktop file's icon (stage coordinates), if the file is on the desktop. Set by the stage.
    var iconCenter: (URL) -> CGPoint? = { _ in nil }

    /// Bumped on every interruption. Callbacks scheduled before it changed are ignored,
    /// so a pet that is picked up mid-walk doesn't suddenly carry on walking.
    private(set) var token = 0

    init(scale: CGFloat) {
        self.scale = scale
        sprite.magnificationFilter = .nearest    // crisp pixels, no blur
        node.addSublayer(sprite)
        bubble.opacity = 0
        node.addSublayer(bubble)
        dialog.opacity = 0
        dialog.addSublayer(dialogLine)
        dialog.addSublayer(caption)
        dialog.addSublayer(dialogArrow)
        node.addSublayer(dialog)
        bubble.addSublayer(bubbleLine)
        thought.opacity = 0
        node.addSublayer(thought)
    }

    /// Where the feet are on screen right now (mid-animation too).
    var position: CGPoint { node.presentation()?.position ?? node.position }

    /// The rectangle the pet covers on screen right now (used for hover / click hit-testing).
    var frame: CGRect { sprite.frame.offsetBy(dx: position.x, dy: position.y) }

    // MARK: Drawing

    /// Show an animation. `repeats: .infinity` loops forever; a finite count stops on the last frame.
    func play(_ anim: Anim, repeats: Float = .infinity, speed: Float = 1) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.contents = anim.image
        sprite.contentsRect = anim.frames[0]
        sprite.bounds = CGRect(x: 0, y: 0, width: anim.frameSize.width * scale,
                               height: anim.frameSize.height * scale)
        // Sheets have different frame sizes; anchoring at each sheet's feet means the feet are always
        // at the node, so switching sheets never makes the pet jump or sink into the floor.
        sprite.anchorPoint = CGPoint(x: 0.5, y: (anim.frameSize.height / 2 - anim.feet) / anim.frameSize.height)
        sprite.position = .zero

        let flipBook = CAKeyframeAnimation(keyPath: "contentsRect")
        flipBook.values = anim.frames
        flipBook.calculationMode = .discrete    // jump between frames, don't blend them
        flipBook.duration = anim.duration
        flipBook.repeatCount = repeats
        flipBook.speed = speed
        if repeats != .infinity {               // hold the last frame when done
            flipBook.fillMode = .forwards
            flipBook.isRemovedOnCompletion = false
        }
        sprite.add(flipBook, forKey: "frames")  // same key replaces the previous loop
        CATransaction.commit()
    }

    /// Freeze on one frame of an animation (e.g. the crouch at the start of Charge).
    func hold(_ anim: Anim, frame: Int) {
        play(anim, repeats: 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.removeAnimation(forKey: "frames")
        sprite.contentsRect = anim.frames[min(frame, anim.frames.count - 1)]
        CATransaction.commit()
    }

    func face(right: Bool) {
        facingRight = right
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.transform = right ? CATransform3DIdentity : CATransform3DMakeScale(-1, 1, 1)
        CATransaction.commit()
    }

    /// Quick squash-and-stretch, like landing on soft paws.
    func squash() {
        let s = CAKeyframeAnimation(keyPath: "transform.scale.y")
        s.values = [1, 0.7, 1.1, 0.96, 1]
        s.keyTimes = [0, 0.25, 0.55, 0.8, 1]
        s.duration = 0.4
        // On `node`, not `sprite`: the sprite is mirrored with scale x = -1 when facing left, and
        // animating its scale.y would flip it upside down (below the floor) for the duration.
        node.add(s, forKey: "squash")
    }

    // MARK: Actions (all call `done` exactly once, unless interrupted)

    /// Called on every interruption (picked up, petted, a new routine…), so a species can put away
    /// anything its routine left on screen. Set by the species.
    var onInterrupt: (() -> Void)?

    /// Stop whatever the pet is doing, right where it is.
    func interrupt() {
        token += 1
        onInterrupt?()
        let p = position
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        node.removeAllAnimations()
        node.removeAnimation(forKey: "squash")
        node.position = p
        CATransaction.commit()
    }

    /// Run `f` after `seconds`, unless the pet got interrupted in the meantime.
    func after(_ seconds: TimeInterval, _ f: @escaping () -> Void) {
        let t = token
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.token == t { f() }
        }
    }

    /// Glide the feet to `to` (in a straight line, or along `path`). Core Animation plays it on the
    /// GPU; our code only wakes at the end.
    func move(to: CGPoint, duration: CFTimeInterval, timing: CAMediaTimingFunction? = nil,
              path: CGPath? = nil, done: @escaping () -> Void) {
        let t = token
        let anim = CAKeyframeAnimation(keyPath: "position")
        anim.values = [position, to]
        anim.path = path
        anim.duration = duration
        anim.timingFunction = timing
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in if self?.token == t { done() } }
        node.position = to
        node.add(anim, forKey: "move")
        CATransaction.commit()
    }

    /// Walk in a straight line to `x`, staying at the current height. `animSpeed` speeds up the legs.
    func walk(to x: CGFloat, with anim: Anim, speed: CGFloat, animSpeed: Float = 1,
              done: @escaping () -> Void) {
        let x = clamp(x)
        let distance = abs(x - position.x)
        guard distance > 1 else { done(); return }
        face(right: x > position.x)
        play(anim, speed: animSpeed)
        move(to: CGPoint(x: x, y: position.y), duration: distance / speed, done: done)
    }

    /// Go to `dest` (a point on some surface), walking along surfaces and jumping between them:
    /// up onto the Dock, from icon to icon, back down to the floor. Never walks through or behind
    /// anything. If there's no way there, it doesn't move.
    func travel(to dest: CGPoint, walk anim: Anim, jump: Anim, leap: Anim, speed: CGFloat,
                animSpeed: Float = 1, done: @escaping () -> Void) {
        guard let from = surfaceIndex(under: position), let to = surfaceIndex(under: dest),
              let legs = route(from: from, to: to) else { done(); return }
        var steps = legs.map { leg -> (@escaping () -> Void) -> Void in
            { [weak self] next in
                guard let self else { return }
                walk(to: leg.takeoff, with: anim, speed: speed, animSpeed: animSpeed) { [weak self] in
                    self?.jump(to: leg.landing, hop: jump, leap: leap, done: next)
                }
            }
        }
        steps.append { [weak self] next in
            self?.walk(to: dest.x, with: anim, speed: speed, animSpeed: animSpeed, done: next)
        }
        func run(_ i: Int) { if i < steps.count { steps[i]({ run(i + 1) }) } else { done() } }
        run(0)
    }

    /// Whether there's a way (walking and jumping) from here to `point`.
    func canReach(_ point: CGPoint) -> Bool {
        guard let from = surfaceIndex(under: position), let to = surfaceIndex(under: point) else { return false }
        return route(from: from, to: to) != nil
    }

    /// Fewest-jumps path between two surfaces (breadth-first search over the ~40 surfaces).
    private func route(from: Int, to: Int) -> [(takeoff: CGFloat, landing: CGPoint)]? {
        if from == to { return [] }
        var previous: [Int: (Int, CGFloat, CGPoint)] = [from: (from, 0, .zero)]
        var queue = [from]
        while !queue.isEmpty {
            let i = queue.removeFirst()
            for j in ground.indices where previous[j] == nil {
                guard let leg = jumpLeg(from: ground[i], to: ground[j]) else { continue }
                previous[j] = (i, leg.takeoff, leg.landing)
                if j == to {
                    var legs: [(takeoff: CGFloat, landing: CGPoint)] = []
                    var k = to
                    while k != from, let p = previous[k] { legs.insert((p.1, p.2), at: 0); k = p.0 }
                    return legs
                }
                queue.append(j)
            }
        }
        return nil
    }

    /// Where to take off from `a` and land on `b`, if Pikachu can make that jump at all:
    /// at most 30 px sideways across a gap, and up to 100 px up with a Quick Attack leap.
    private func jumpLeg(from a: Ground, to b: Ground) -> (takeoff: CGFloat, landing: CGPoint)? {
        let maxGap = 30 * scale, maxUp = (canLeap ? 100 : 30) * scale, inset = 6 * scale
        let rise = b.y - a.y
        guard rise <= maxUp, abs(rise) > 1 || a.span != b.span else { return nil }
        func inside(_ x: CGFloat, _ g: Ground) -> CGFloat {
            g.width > 2 * inset ? min(max(x, g.span.lowerBound + inset), g.span.upperBound - inset)
                                : (g.span.lowerBound + g.span.upperBound) / 2
        }
        let overlap = min(a.span.upperBound, b.span.upperBound) - max(a.span.lowerBound, b.span.lowerBound)
        if overlap <= 0 {                                   // side by side: hop across the gap
            guard -overlap <= maxGap else { return nil }
            let bIsRight = b.span.lowerBound >= a.span.upperBound
            let takeoff = inside(bIsRight ? a.span.upperBound : a.span.lowerBound, a)
            let landing = inside(bIsRight ? b.span.lowerBound : b.span.upperBound, b)
            return (takeoff, CGPoint(x: landing, y: b.y))
        }
        if rise > 0 {                                       // b is above a: jump up from beside it
            for side in [b.span.lowerBound - inset, b.span.upperBound + inset] where a.span.contains(side) {
                return (side, CGPoint(x: inside(side, b), y: b.y))
            }
            return (inside(b.span.lowerBound, a), CGPoint(x: inside(b.span.lowerBound, b), y: b.y))
        }
        // b is below a: step off one of a's edges and drop onto b
        for edge in [a.span.lowerBound - inset, a.span.upperBound + inset] where b.span.contains(edge) {
            return (inside(edge, a), CGPoint(x: edge, y: b.y))
        }
        return nil
    }

    /// Jump along an arc to `to`. Small hops use the Hop frames; big climbs are a Quick Attack
    /// leap (LeapForth frames, a trail of sparks).
    func jump(to: CGPoint, hop: Anim, leap: Anim, done: @escaping () -> Void) {
        let from = position
        let big = to.y - from.y > 35 * scale
        face(right: to.x >= from.x)
        play(big ? leap : hop, repeats: 1)
        if big { sparks(for: 0.35, rate: 20) }
        let peak = max(from.y, to.y) + (big ? 6 : 10) * scale
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: 2 * peak - (from.y + to.y) / 2))
        let distance = hypot(to.x - from.x, to.y - from.y)
        move(to: to, duration: max(0.45, Double(distance) / 600), path: path, done: done)
    }

    /// Loop an animation for a while.
    func stay(_ anim: Anim, for seconds: TimeInterval, done: @escaping () -> Void) {
        play(anim)
        after(seconds, done)
    }

    /// Play an animation `times` times, then hold its last frame and call `done`.
    func once(_ anim: Anim, times: Int = 1, speed: Float = 1, done: @escaping () -> Void) {
        play(anim, repeats: Float(times), speed: speed)
        after(anim.duration * Double(times) / Double(speed), done)
    }

    /// Fall straight down onto whatever is below (an icon, the Dock, the floor). Returns the drop height.
    @discardableResult
    func fall(float: Bool = false, done: @escaping () -> Void) -> CGFloat {
        let from = position
        let x = clamp(from.x)
        let floor = surface(under: CGPoint(x: x, y: from.y))?.y ?? 0
        let height = from.y - floor
        let landing = CGPoint(x: x, y: floor)
        guard height > 1 else { move(to: landing, duration: 0.1, done: done); return 0 }
        if float {                                                      // drifts down gently (psychic power)
            move(to: landing, duration: max(0.8, height / 220), timing: CAMediaTimingFunction(name: .easeInEaseOut), done: done)
            return height
        }
        let gravity: CGFloat = 2400                                     // points / s²
        move(to: landing, duration: sqrt(2 * height / gravity),
             timing: CAMediaTimingFunction(controlPoints: 0.55, 0.085, 0.68, 0.53), // ease-in ≈ falling
             done: done)
        return height
    }

    /// How hard it's been swung about while held: each reversal of a big move counts one.
    private(set) var swings = 0
    private var lastDrag: CGPoint?, lastSwing = CGVector.zero
    func resetSwings() { swings = 0; lastDrag = nil; lastSwing = .zero }

    /// Follow the cursor while held (no animation, instant).
    func drag(to point: CGPoint) {
        if let last = lastDrag {
            let d = CGVector(dx: point.x - last.x, dy: point.y - last.y)
            if hypot(d.dx, d.dy) > 8 {                               // ignore jitter
                if d.dx * lastSwing.dx + d.dy * lastSwing.dy < 0 { swings += 1 }   // turned back
                lastSwing = d
            }
        }
        lastDrag = point
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        node.position = point
        CATransaction.commit()
    }

    func clamp(_ x: CGFloat) -> CGFloat { min(max(x, walkArea.lowerBound), walkArea.upperBound) }

    /// The highest surface at or below `p` (what you'd land on falling from there).
    func surface(under p: CGPoint) -> Ground? { surfaceIndex(under: p).map { ground[$0] } }

    private func surfaceIndex(under p: CGPoint) -> Int? {
        ground.indices.filter { ground[$0].span.contains(p.x) && ground[$0].y <= p.y + 1 }
                      .max { ground[$0].y < ground[$1].y }
    }

    /// Height of the floor or Dock at `x`; a held pet can't be dragged below it.
    func floorY(at x: CGFloat) -> CGFloat {
        ground.filter { $0.solid && $0.span.contains(x) }.map(\.y).max() ?? 0
    }

    /// Above the surface it should be standing on (mid-jump, falling, or held).
    var isAirborne: Bool { position.y > (surface(under: position)?.y ?? 0) + 1 }
}
