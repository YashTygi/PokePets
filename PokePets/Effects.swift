import AppKit

/// Tiny hand-drawn pixel art for effects SpriteCollab doesn't have (hearts, sparks).
/// Drawn at 1 px per pixel and scaled up with the same nearest-neighbour filter as the sprites,
/// so every pixel is exactly as big as one of Pikachu's pixels. The outline colour and the
/// yellow/white of the sparks are taken from PMD's own Pikachu and Shock sheets.
enum Pixels {
    // ".": transparent. Colours sampled to match the PMD palette.
    private static let palette: [Character: UInt32] = [
        "k": 0x181010,   // PMD outline
        "r": 0xF83850,   // heart red
        "p": 0xF898B0,   // heart pink shade
        "w": 0xFFFFFF,
        "y": 0xF8E800,   // Pikachu/Shock yellow
        "l": 0xFFF8A8,   // pale spark yellow
        "d": 0xA81830,   // Poké Ball red, shaded
        "g": 0xC0C0C8,   // Poké Ball white, shaded
        "b": 0x4880F0,   // Oran berry blue
        "n": 0x2848A8,   // Oran berry blue, shaded
        "v": 0x58B840,   // leaf green
        "P": 0xF898C0,   // Pecha pink
        "Q": 0xD05888,   // Pecha pink, shaded
        "R": 0xF04030,   // Cheri red
        "S": 0xA82018,   // Cheri red, shaded
        "c": 0xFFF4D6,   // egg cream
        "C": 0xE0CC98,   // egg cream, shaded
        "U": 0x7058D0,   // Chesto purple
        "V": 0x483090,   // Chesto purple, shaded
        "T": 0x58C8D8,   // Rawst teal
        "W": 0x2C8898,   // Rawst teal, shaded
        "Y": 0xF8E070,   // Aspear yellow
        "Z": 0xC0A030,   // Aspear yellow, shaded
        "G": 0x50C058,   // Thunder Stone green
        "H": 0x2C7838,   // Thunder Stone green, shaded
        "L": 0x9070D8,   // Linking Cord purple
        "M": 0x5838A0,   // Linking Cord purple, shaded
        "N": 0xF8C838,   // Linking Cord gold clasp
        "D": 0x281038,   // Shadow Ball core
        "E": 0x6030A0,   // Shadow Ball purple
        "F": 0xB060F0,   // Shadow Ball glowing rim
        "I": 0xE8C8FF,   // Shadow Ball glint
        "A": 0x98CCF0,   // saliva, edge
        "B": 0xD8F0FF,   // saliva
    ]

    static let heart = image([
        ".kk.kk.",
        "kwrkrrk",
        "krrrrpk",
        ".krrpk.",
        "..kpk..",
        "...k...",
    ])

    /// Oran Berry, the classic Pokémon snack.
    static let oranBerry = image([
        "...kvk..",
        "..kvvk..",
        ".kkbbkk.",
        "kbwbbbbk",
        "kbbbbbbk",
        "kbbbbbnk",
        ".knbbnk.",
        "..kkkk..",
    ])

    static let pechaBerry = image([
        "....kv..",
        "...kvk..",
        ".kkPPkk.",
        "kPwPPPPk",
        "kPPPPPQk",
        "kPPPPPQk",
        ".kQPPQk.",
        "..kkkk..",
    ])

    static let cheriBerry = image([
        "...kvk..",
        "..kvvk..",
        ".kkRRkk.",
        "kRwRRRRk",
        "kRRRRRRk",
        "kRRRRRSk",
        ".kSRRSk.",
        "..kkkk..",
    ])

    static let chestoBerry = image([
        "...kvk..",
        "..kvvk..",
        ".kkUUkk.",
        "kUwUUUUk",
        "kUUUUUVk",
        "kUUUUUVk",
        ".kVUUVk.",
        "..kkkk..",
    ])

    static let rawstBerry = image([
        "..kvvk..",
        ".kvTTvk.",
        "kTwTTTTk",
        "kTTTTTWk",
        "kTTTTTWk",
        ".kTTTWk.",
        "..kWWk..",
        "...kk...",
    ])

    static let aspearBerry = image([
        "...kvk..",
        "...kYk..",
        "..kYYYk.",
        ".kYwYYYk",
        "kYYYYYZk",
        "kYYYYYZk",
        ".kZYYZk.",
        "..kkkk..",
    ])

    static let thunderStone = image([
        "...kk...",
        "..kGGk..",
        ".kGGyGk.",
        "kGGyyGGk",
        "kGyyGGHk",
        ".kGyGHk.",
        "..kGHk..",
        "...kk...",
    ])

    /// Linking Cord (Legends: Arceus): evolves Pokémon that evolve by trading, like Haunter.
    static let linkingCord = image([
        "..kkk...",
        ".kLLMk..",
        "kLk.kMk.",
        "kLk..kNk",
        ".kMk.kNk",
        "..kMkNk.",
        "...kNk..",
        "....k...",
    ])

    /// Shadow Ball: a dark orb with a glowing purple rim. 10×10.
    static let shadowBall = image([
        "...kkkk...",
        ".kkFEEFkk.",
        ".kFEIDEFk.",
        "kFEIDDDEFk",
        "kEDDDDDDEk",
        "kEDDDDDDEk",
        "kFEDDDDEFk",
        ".kFEDDEFk.",
        ".kkFEEFkk.",
        "...kkkk...",
    ])

    /// A wet lick mark on your screen, and the drips that run from it. Drawn semi-transparent.
    static let saliva = image([
        "....AAAAAAA.....",
        "..AABBBBBBBAAA..",
        ".ABBwwBBBBBBBBA.",
        "ABBwBBBBBBBBBBBA",
        "ABBBBBBBBBBBwBBA",
        ".ABBBBBBBBBBBBA.",
        "..AABBBAABBBAA..",
        "....AAA..AAA....",
    ])
    static let drip = image([
        ".A.",
        "ABA",
        "ABA",
        "AwA",
        ".A.",
    ])

    /// A ghostly purple handprint (Gengar's), left on your screen as a prank.
    static let handprint = image([
        "..k.k.k..",
        ".kLkLkLk.",
        ".kLkLkLk.",
        ".kLLLLLk.",
        "kkLLLLLk.",
        "kLLLLLMk.",
        ".kLLLLMk.",
        "..kLLMk..",
        "...kkk...",
    ])

    /// A Pokémon Egg: cream with yellow spots. 12×15.
    static let eggRows = [
        "....kkkk....",
        "..kkwccckk..",
        ".kwwccyycck.",
        ".kwcccyyyck.",
        "kwccccccyyck",
        "kccyycccccCk",
        "kcyyyccccCCk",
        "kccyccccccCk",
        "kcccccyyccCk",
        "kccccyyyycCk",
        "kCcccccccCCk",
        ".kCcccccCCk.",
        ".kCCccccCCk.",
        "..kkCCCCkk..",
        "....kkkk....",
    ]
    static let egg = image(eggRows)
    /// The same egg with a growing crack (as it's about to hatch).
    static let eggCracked = [cracked([(6, 4), (7, 5), (6, 6), (7, 7)]),
                             cracked([(6, 2), (7, 3), (6, 4), (7, 5), (6, 6), (7, 7), (6, 8), (7, 9)])]
    /// The two halves of the shell flying apart (split along the crack, rows 0–6 and 7–14).
    static let eggTop = image(Array(eggRows[0...6]))
    static let eggBottom = image(Array(eggRows[7...14]))

    /// The Egg on a canvas laid out like a PMD frame, so the dial centres it in its slot like a Pokémon.
    static let eggInSlot = canvas(width: 32, height: 44, egg: CGRect(x: 1, y: 13, width: 24, height: 30))
    /// The Egg centred on a square, for portraits (stats card, Settings).
    static let eggPortrait = canvas(width: 40, height: 40, egg: CGRect(x: 8, y: 5, width: 24, height: 30))

    private static func canvas(width: Int, height: Int, egg frame: CGRect) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.draw(egg, in: frame)
        return ctx.makeImage()!
    }

    private static func cracked(_ points: [(row: Int, col: Int)]) -> CGImage {
        var rows = eggRows.map(Array.init)
        for p in points { rows[p.row][p.col] = "k" }
        return image(rows.map { String($0) })
    }

    // Thought icons: what it's thinking about (shown on its portrait bubble).
    static let question = image([
        ".kkk.",
        "k...k",
        "....k",
        "..kk.",
        "..k..",
        ".....",
        "..k..",
    ])
    static let exclaim = image([
        "kk",
        "kk",
        "kk",
        "kk",
        "..",
        "kk",
    ])
    static let zzz = image([
        "kkkk...",
        "...k...",
        "..k.kkk",
        ".k....k",
        "kkkk.k.",
        "....kkk",
    ])
    static let note = image([
        "...kkk",
        "...k.k",
        "...k.k",
        ".kkk.k",
        "kkkk.k",
        ".kk.kk",
        "...kkk",
    ])
    static let file = image([
        "kkkkk..",
        "kwwwkk.",
        "kwkkwkk",
        "kwwwwwk",
        "kwkkkwk",
        "kwwwwwk",
        "kwkkkwk",
        "kwwwwwk",
        "kkkkkkk",
    ])

    /// Four-point twinkle, the same shape PMD uses around Shock.
    static let sparkle = image([
        "..y..",
        "..l..",
        "ylwly",
        "..l..",
        "..y..",
    ])

    static let bolt = image([
        "...ky",
        "..kyk",
        ".kyyk",
        "kyyyk",
        ".kyk.",
        "kyk..",
        "yk...",
    ])

    static func image(_ rows: [String]) -> CGImage {
        let h = rows.count, w = rows[0].count
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (r, line) in rows.enumerated() {
            for (c, ch) in line.enumerated() {
                guard let rgb = palette[ch] else { continue }
                ctx.setFillColor(red: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
                                 blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
                ctx.fill(CGRect(x: c, y: h - 1 - r, width: 1, height: 1))   // row 0 is the top
            }
        }
        return ctx.makeImage()!
    }
}

/// Things you can drag from the menu bar dial onto your Pokémon.
enum Item: String, CaseIterable {
    case oran, pecha, cheri, chesto, rawst, aspear, thunderStone, linkingCord

    static let pasteboardType = NSPasteboard.PasteboardType("com.pokepets.item")

    var image: CGImage {
        switch self {
        case .oran: Pixels.oranBerry
        case .pecha: Pixels.pechaBerry
        case .cheri: Pixels.cheriBerry
        case .chesto: Pixels.chestoBerry
        case .rawst: Pixels.rawstBerry
        case .aspear: Pixels.aspearBerry
        case .thunderStone: Pixels.thunderStone
        case .linkingCord: Pixels.linkingCord
        }
    }

    var name: String {
        switch self {
        case .oran: "Oran Berry"
        case .pecha: "Pecha Berry · sweet"
        case .cheri: "Cheri Berry · spicy"
        case .chesto: "Chesto Berry · dry"
        case .rawst: "Rawst Berry · bitter"
        case .aspear: "Aspear Berry · sour"
        case .thunderStone: "Thunder Stone"
        case .linkingCord: "Linking Cord"
        }
    }

    /// Each status berry's main flavour (Oran has a bit of everything, so no Pokémon minds it).
    var flavour: Flavour? {
        switch self {
        case .cheri: .spicy
        case .chesto: .dry
        case .pecha: .sweet
        case .rawst: .bitter
        case .aspear: .sour
        case .oran, .thunderStone, .linkingCord: nil
        }
    }

    var isBerry: Bool { ![.thunderStone, .linkingCord].contains(self) }
}

extension Pet {
    /// Particles (hearts, sparks) attached to the pet. Particles are simulated by Core Animation's
    /// render server, so they cost our app nothing per frame.
    /// - seconds: how long to keep emitting; `nil` = until `stopEmitting` is called.
    @discardableResult
    func emit(_ image: CGImage, height: CGFloat, rate: Float, for seconds: TimeInterval?,
              velocity: CGFloat, spread: CGFloat, lifetime: Float, gravity: CGFloat = 0,
              area: CGSize = .zero) -> CAEmitterLayer {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.magnificationFilter = CALayerContentsFilter.nearest.rawValue
        cell.scale = scale
        cell.birthRate = rate
        cell.lifetime = lifetime
        cell.lifetimeRange = lifetime * 0.3
        cell.velocity = velocity
        cell.velocityRange = velocity * 0.4
        cell.emissionLongitude = .pi / 2         // straight up
        cell.emissionRange = spread
        cell.yAcceleration = gravity
        cell.alphaSpeed = -1 / lifetime          // fade out

        let emitter = CAEmitterLayer()
        emitter.emitterCells = [cell]
        emitter.emitterPosition = CGPoint(x: 0, y: height)
        emitter.emitterShape = area == .zero ? .point : .rectangle
        emitter.emitterSize = area
        emitter.renderMode = .unordered
        node.addSublayer(emitter)
        if let seconds {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.stopEmitting(emitter)
            }
        }
        return emitter
    }

    /// Stop new particles and remove the emitter once the last ones have faded.
    func stopEmitting(_ emitter: CAEmitterLayer) {
        emitter.birthRate = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { emitter.removeFromSuperlayer() }
    }

    /// A shower of hearts floating up from the head.
    func hearts() {
        emit(Pixels.heart, height: 34 * scale, rate: 4, for: 0.7,
             velocity: 70, spread: .pi / 3, lifetime: 1.4, gravity: -10)
    }

    /// Pokémon Mystery Dungeon's look: navy panels with a bright blue border and a thin white line inside it.
    static let panelBlue = NSColor(calibratedRed: 0.29, green: 0.58, blue: 0.97, alpha: 1)
    static let panelNavy = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.2, alpha: 0.94)
    static let speakerCyan = NSColor(calibratedRed: 0.3, green: 0.85, blue: 1, alpha: 1)

    /// Show its emotion portrait above its head, PMD style (framed like the game's portraits), and, with a
    /// caption, a PMD dialogue box under it whose text types itself out. `speaker`: the name shown in cyan
    /// before the text ("Pikachu: …"), for things it says; none for announcements. A new face replaces the last.
    func showFace(_ portrait: CGImage, caption: String? = nil, speaker: String? = nil, thought: CGImage? = nil,
                  for seconds: TimeInterval = 2.5) {
        bubbleTurn += 1
        let turn = bubbleTurn
        let size = CGFloat(portrait.width) * 1.5                       // 40 px portrait → 60 pt
        let box = showDialog(caption, speaker: speaker, turn: turn)
        let typing = box?.typing ?? 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bubble.contents = portrait
        bubble.magnificationFilter = .nearest
        bubble.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        // With a dialogue box the portrait sits on top of it at the left, as in the game; alone, above the head.
        bubble.position = box.map { CGPoint(x: $0.frame.minX + size / 2, y: $0.frame.maxY + 2 + size / 2) }
            ?? CGPoint(x: 0, y: 26 * scale + size / 2)
        bubble.cornerRadius = 5
        bubble.masksToBounds = true
        bubble.borderWidth = 2.5
        bubble.borderColor = Self.panelBlue.cgColor
        bubbleLine.frame = bubble.bounds.insetBy(dx: 3, dy: 3)
        bubbleLine.cornerRadius = 3
        bubbleLine.borderWidth = 1
        bubbleLine.borderColor = NSColor(white: 1, alpha: 0.9).cgColor
        bubble.opacity = 1
        CATransaction.commit()
        showThought(thought, at: CGPoint(x: bubble.position.x + size / 2 - 2, y: bubble.position.y + size / 2 - 2))
        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.3
        pop.toValue = 1
        pop.damping = 11
        pop.duration = pop.settlingDuration
        bubble.add(pop, forKey: "pop")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + typing) { [weak self] in
            guard let self, bubbleTurn == turn else { return }
            bubble.opacity = 0                                         // fades (implicit animation)
            self.thought.opacity = 0
            dialog.opacity = 0
        }
    }

    /// The dialogue box: navy, double-bordered, white text with the speaker's name in cyan, and a blinking ▼.
    /// The text types out a letter at a time (about a second at most). Returns its frame and how long typing takes.
    private func showDialog(_ text: String?, speaker: String?, turn: Int) -> (frame: CGRect, typing: TimeInterval)? {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let text else { dialog.opacity = 0; return nil }
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let full = NSMutableAttributedString()
        if let speaker {
            full.append(NSAttributedString(string: speaker + ": ", attributes: [.font: font, .foregroundColor: Self.speakerCyan]))
        }
        full.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white]))
        let fits = full.boundingRect(with: CGSize(width: 230, height: 300), options: [.usesLineFragmentOrigin])
        let width = ceil(fits.width) + 28, height = ceil(fits.height) + 26
        let frame = CGRect(x: -width / 2, y: 26 * scale + 6, width: width, height: height)
        dialog.frame = frame
        dialog.backgroundColor = Self.panelNavy.cgColor
        dialog.cornerRadius = 7
        dialog.borderWidth = 2.5
        dialog.borderColor = Self.panelBlue.cgColor
        dialogLine.frame = dialog.bounds.insetBy(dx: 3.5, dy: 3.5)
        dialogLine.cornerRadius = 4
        dialogLine.borderWidth = 1
        dialogLine.borderColor = NSColor(white: 1, alpha: 0.85).cgColor
        caption.isWrapped = true
        caption.alignmentMode = .left
        caption.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        caption.frame = CGRect(x: 14, y: 14, width: ceil(fits.width) + 2, height: ceil(fits.height) + 2)
        caption.string = NSAttributedString()
        dialogArrow.string = NSAttributedString(string: "▼", attributes: [.font: NSFont.systemFont(ofSize: 7), .foregroundColor: NSColor.white])
        dialogArrow.contentsScale = caption.contentsScale
        dialogArrow.alignmentMode = .center
        dialogArrow.frame = CGRect(x: width / 2 - 6, y: 2, width: 12, height: 10)
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1
        blink.toValue = 0.15
        blink.duration = 0.5
        blink.autoreverses = true
        blink.repeatCount = .infinity
        dialogArrow.add(blink, forKey: "blink")
        dialog.opacity = 1
        // Types out like the game: the name appears at once, the words a letter at a time.
        let start = speaker.map { $0.count + 2 } ?? 0, count = full.length
        let step = min(0.03, 0.9 / Double(max(1, count - start)))
        for i in start...count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - start) * step) { [weak self] in
                guard let self, bubbleTurn == turn else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                caption.string = full.attributedSubstring(from: NSRange(location: 0, length: i))
                CATransaction.commit()
            }
        }
        return (frame, Double(count - start) * step)
    }

    /// A little white thought circle on the portrait's corner, with what it's thinking about.
    private func showThought(_ icon: CGImage?, at point: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        thought.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let icon else { thought.opacity = 0; return }
        let d: CGFloat = 30
        thought.bounds = CGRect(x: 0, y: 0, width: d, height: d)
        thought.cornerRadius = d / 2
        thought.backgroundColor = NSColor.white.cgColor
        thought.borderWidth = 1.5
        thought.borderColor = NSColor(white: 0.1, alpha: 1).cgColor
        thought.position = point                                        // top-right corner of the portrait
        let art = CALayer()
        art.contents = icon
        art.magnificationFilter = .nearest
        let k = floor(20 / CGFloat(max(icon.width, icon.height)))      // whole-pixel scale, ~20 pt
        art.bounds = CGRect(x: 0, y: 0, width: CGFloat(icon.width) * k, height: CGFloat(icon.height) * k)
        art.position = CGPoint(x: d / 2, y: d / 2)
        thought.addSublayer(art)
        thought.opacity = 1
    }

    /// Food held up to the mouth (for the Eat frames, which face you with paws at the mouth).
    /// It gets smaller with each bite and is gone after the last one; remove the layer when done.
    /// - height: where the paws are, in sprite pixels above the feet.
    func holdFood(_ image: CGImage, bites: Int, over seconds: CFTimeInterval, at height: CGFloat = 9) -> CALayer {
        let food = CALayer()
        food.contents = image
        food.magnificationFilter = .nearest
        food.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        food.position = CGPoint(x: 0, y: height * scale)               // in the paws, just under the mouth
        let shrink = CAKeyframeAnimation(keyPath: "transform.scale")
        shrink.values = (0...bites).map { 1 - Double($0) / Double(bites) }
        shrink.calculationMode = .discrete                             // one step per bite
        shrink.duration = seconds
        shrink.fillMode = .forwards
        shrink.isRemovedOnCompletion = false
        node.addSublayer(food)
        food.add(shrink, forKey: "bites")
        return food
    }

    /// The shiny sparkle: a ring of white stars bursting out from the body, as when a shiny appears.
    func stars() {
        let e = emit(Pixels.sparkle, height: 14 * scale, rate: 40, for: 0.5, velocity: 90, spread: .pi * 2, lifetime: 0.8)
        e.emitterCells?.first?.color = NSColor(white: 1, alpha: 1).cgColor
    }

    /// Eating from its paws (sets without an eating sprite). Each chew: the berry comes up to the mouth
    /// as the head dips to meet it (a bite), then back down while it chews; a few crumbs fall.
    func munch(_ food: CALayer, crumbs berry: CGImage, for seconds: TimeInterval, chew: TimeInterval) {
        let times: [NSNumber] = [0, 0.25, 0.45, 0.7, 1]
        let lift = CAKeyframeAnimation(keyPath: "position.y")
        lift.values = [0, 4 * scale, 4 * scale, 0, 0]
        lift.isAdditive = true                                           // on top of where it's held
        let dip = CAKeyframeAnimation(keyPath: "transform.scale.y")
        dip.values = [1, 0.95, 0.97, 1.01, 1]
        for (a, layer) in [(lift, food), (dip, node)] {
            a.keyTimes = times
            a.duration = chew
            a.repeatCount = Float(seconds / chew)
            layer.add(a, forKey: "munch")
        }
        let crumb = berry.cropping(to: CGRect(x: berry.width / 2 - 1, y: berry.height / 2 - 1, width: 2, height: 2)) ?? berry
        let e = emit(crumb, height: food.position.y + 5 * scale, rate: Float(2 / chew), for: seconds,
                     velocity: 25, spread: .pi / 2, lifetime: 0.7, gravity: -160)
        e.emitterCells?.first?.scale = scale * 0.8
    }

    /// Dizzy: sways on its feet and little stars circle its head for `seconds`.
    func dizzy(for seconds: TimeInterval) {
        let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        sway.values = [0, 0.14, -0.12, 0.1, -0.08, 0.05, 0]
        sway.duration = 0.9
        sway.repeatCount = Float(seconds / 0.9)
        node.add(sway, forKey: "dizzy")

        let orbit = CALayer(), spin = CALayer()                       // a flattened ring, so the circle reads as 3D
        orbit.position = CGPoint(x: 0, y: sprite.frame.maxY - 2 * scale)
        orbit.transform = CATransform3DMakeScale(1, 0.35, 1)
        for i in 0..<3 {
            let star = CALayer()
            star.contents = Pixels.sparkle
            star.magnificationFilter = .nearest
            star.bounds = CGRect(x: 0, y: 0, width: 5 * scale, height: 5 * scale)
            let angle = CGFloat(i) * 2 * .pi / 3
            star.position = CGPoint(x: cos(angle) * 9 * scale, y: sin(angle) * 9 * scale)
            spin.addSublayer(star)
        }
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = 2 * CGFloat.pi
        turn.duration = 0.8
        turn.repeatCount = .infinity
        spin.add(turn, forKey: "spin")
        orbit.addSublayer(spin)
        node.addSublayer(orbit)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { orbit.removeFromSuperlayer() }   // even if interrupted
    }

    /// Vanish in a shimmer and reappear at `point` (Psychic teleport).
    func blink(to point: CGPoint, done: @escaping () -> Void) {
        let out = CABasicAnimation(keyPath: "opacity")
        out.fromValue = 1
        out.toValue = 0
        out.duration = 0.25
        out.fillMode = .forwards
        out.isRemovedOnCompletion = false
        node.add(out, forKey: "blink")
        after(0.28) { [weak self] in
            guard let self else { return }
            drag(to: point)
            let back = CABasicAnimation(keyPath: "opacity")
            back.fromValue = 0
            back.toValue = 1
            back.duration = 0.25
            node.add(back, forKey: "blink")
            after(0.3, done)
        }
    }

    /// Sparks crackling all around the body. Returns the emitter so it can run until stopped.
    @discardableResult
    func sparks(for seconds: TimeInterval?, rate: Float = 14) -> CAEmitterLayer {
        let e = emit(Pixels.sparkle, height: 16 * scale, rate: rate, for: seconds,
                     velocity: 60, spread: .pi * 2, lifetime: 0.45, area: CGSize(width: 28 * scale, height: 26 * scale))
        let bolts = CAEmitterCell()
        bolts.contents = Pixels.bolt
        bolts.magnificationFilter = CALayerContentsFilter.nearest.rawValue
        bolts.scale = scale
        bolts.birthRate = rate / 3
        bolts.lifetime = 0.3
        bolts.alphaSpeed = -3
        e.emitterCells?.append(bolts)
        return e
    }
}
