import AppKit

/// The Gastly line's real data (Scarlet/Violet, via PokeAPI): Medium Slow, 50 % ♂ / 50 % ♀, Gastly →
/// Haunter at Lv 25, Haunter → Gengar by trade (here: a Linking Cord, as in Legends: Arceus).
enum GengarLine {
    static let haunterLevel = 25
    /// The line's ability. Gastly and Haunter have Levitate; Gengar had it in Gen 3–6 (Cursed Body since),
    /// and in PokePets keeps it, because flying anywhere is the whole point of a Gengar.
    static let ability = "Levitate"
    static let abilityEffect = "Floats instead of walking: it flies anywhere on your screen, not just along the floor, and never falls when you drop it."

    private static let effects: [String: String] = [
        "Lick": "Licks things now and then (and your screen, once it's a Haunter).",
        "Hypnosis": "Its stare can make another Pokémon doze off.",
        "Shadow Punch": "Haunter's evolution move.",
        "Shadow Ball": "Its file delete becomes a full Shadow Ball.",
        "Dream Eater": "Eats a sleeping Pokémon's dreams (a little EXP for it).",
    ]

    private static let learnsets: [(Stage, [(Int, String)])] = [
        (.gastly, [(1, "Confuse Ray"), (1, "Lick"), (4, "Hypnosis"), (8, "Mean Look"), (12, "Payback"), (16, "Spite"),
                   (20, "Curse"), (24, "Hex"), (28, "Night Shade"), (32, "Sucker Punch"), (36, "Dark Pulse"), (40, "Shadow Ball"),
                   (44, "Destiny Bond"), (48, "Dream Eater")]),
        (.haunter, [(1, "Shadow Punch"), (1, "Confuse Ray"), (1, "Hypnosis"), (1, "Lick"), (1, "Mean Look"), (12, "Payback"),
                    (16, "Spite"), (20, "Curse"), (24, "Hex"), (30, "Night Shade"), (36, "Sucker Punch"), (42, "Dark Pulse"),
                    (48, "Shadow Ball"), (54, "Destiny Bond"), (60, "Dream Eater")]),
        (.gengar, [(1, "Perish Song"), (1, "Reflect Type")]),         // plus everything Haunter learns, at Haunter's levels
    ]

    static let moves: [Move] = learnsets.flatMap { stage, list in
        list.map { Move(name: $0.1, level: $0.0, stage: stage, effect: effects[$0.1]) }
    }

    /// Moves known at `stage` and `level`. Like the games, Haunter and Gengar learn at Haunter's levels,
    /// and keep what they learned as a Gastly before evolving (Lv 24 and below).
    static func known(stage: Stage, level: Int) -> Set<String> {
        func learned(_ s: Stage, upTo lv: Int) -> [String] { moves.filter { $0.stage == s && $0.level <= lv }.map(\.name) }
        switch stage {
        case .gastly: return Set(learned(.gastly, upTo: level))
        case .haunter: return Set(learned(.haunter, upTo: level) + learned(.gastly, upTo: min(level, haunterLevel - 1)))
        case .gengar: return known(stage: .haunter, level: level).union(learned(.gengar, upTo: level))
        default: return []
        }
    }

    static func pokedex(_ stage: Stage) -> (genus: String, type: String, entries: [(game: String, text: String)]) {
        switch stage {
        case .gastly: ("Gas Pokémon", "Ghost / Poison", [
            ("Sun", "Should a strange light be seen flickering in an abandoned building, Gastly is lurking there."),
            ("Moon", "Although Gastly is barely visible, when it’s near, a faint sweet smell lingers."),
            ("Ultra Sun", "It’s said that gas emanating from a graveyard was possessed by the grievances of the deceased and thus became a Pokémon.")])
        case .haunter: ("Gas Pokémon", "Ghost / Poison", [
            ("Sun", "It strikes at humans from total darkness. Those licked by its cold tongue grow weaker with each passing day until they die."),
            ("Moon", "It fears the light and revels in the dark. It may be on the verge of extinction in cities that stay brightly lit at night."),
            ("Ultra Sun", "On moonless nights, Haunter searches for someone to curse, so it’s best not to go out walking around.")])
        default: ("Shadow Pokémon", "Ghost / Poison", [
            ("Sun", "Should you feel yourself attacked by a sudden chill, it is evidence of an approaching Gengar. There is no escaping it. Give up."),
            ("Moon", "It apparently wishes for a traveling companion. Since it was once human itself, it tries to create one by taking the lives of other humans."),
            ("Ultra Sun", "You can hear tales told all over the world about how Gengar will pay a visit to children who are naughty.")])
        }
    }

    /// Self-check: `swift PokePets/Growth.swift PokePets/Gengar.swift …` with `GengarLine.check()`.
    static func check() {
        assert(known(stage: .gastly, level: 1) == ["Confuse Ray", "Lick"])
        assert(known(stage: .gastly, level: 40).contains("Shadow Ball") && !known(stage: .gastly, level: 39).contains("Shadow Ball"))
        assert(known(stage: .haunter, level: 25).contains("Shadow Punch") && known(stage: .haunter, level: 25).contains("Hex"))
        assert(!known(stage: .haunter, level: 40).contains("Shadow Ball") && known(stage: .haunter, level: 48).contains("Shadow Ball"))
        assert(known(stage: .gengar, level: 30).contains("Perish Song") && !known(stage: .haunter, level: 30).contains("Perish Song"))
        assert(known(stage: .gengar, level: 48).contains("Shadow Ball") && !known(stage: .gengar, level: 47).contains("Shadow Ball"))
        assert(Stage.gengar.growthRate == .mediumSlow && Stage.haunter.next == .gengar && Stage.gastly.line.first == .egg)
    }
}

/// The Gastly line: Gastly → Haunter → Gengar. A naughty, playful ghost. With Levitate it isn't stuck to
/// the floor like Pikachu: it flies from anywhere to anywhere on your screen in hopping arcs, hovers with its
/// tongue out, and drifts down when it's done. Saves under "gengar.*".
final class Gengar: Companion {
    init(power: Power, senses: Senses) {
        super.init(store: "gengar", power: power, senses: senses)
        // However its routine gets cut short (picked up, petted, your cursor, the charger…), nothing it
        // was showing stays behind: shadows, the lick's lean-in, a half-sunk peek. (The stolen cursor
        // comes back on its own: any mouse move returns it.)
        pet.onInterrupt = { [weak self] in
            guard let self else { return }
            clearShades()
            endZoom()
            endPhase()
        }
    }

    override func sheetName(_ stage: Stage, form: String?, shiny: Bool) -> String {
        (stage == .egg ? "gastly" : stage.rawValue) + (shiny && stage != .egg ? "-shiny" : "")
    }
    override var firstStage: Stage { .gastly }
    override var ability: (name: String, effect: String) { (GengarLine.ability, GengarLine.abilityEffect) }
    override var known: Set<String> { GengarLine.known(stage: stage, level: level) }
    override var learnset: [Move] { GengarLine.moves }
    override var signatureMoves: Set<String> { ["Shadow Punch"] }
    override var canEvolve: Bool { stage == .haunter }
    override var evolveItem: Item? { stage == .haunter ? .linkingCord : nil }
    override var floats: Bool { true }

    /// Gastly and Haunter have no Eat animation: they lick their berries up (where their tongue reaches in
    /// their Lick, measured from the sprites). Gengar has its own Eat.
    override var nibble: (anim: String, at: CGPoint, bite: Double)? {
        switch stage {
        case .gastly: ("Lick", CGPoint(x: 26, y: 4), 0.35)          // its tongue tip, out by frame 6 (21 of 33 ticks)
        case .haunter: ("Lick", CGPoint(x: 23, y: 6), 0.29)         // its tongue tip, out by frame 7 (17 of 29 ticks)
        default: nil
        }
    }

    override var cry: String { stage == .gastly ? "Gas…" : stage == .haunter ? "Hehehe" : "Kekeke" }

    /// Naughty and playful: teases you, jokes about haunting your Mac, and loves a good scare.
    override var voice: [Moment: [String]] {
        [.curious: ["Hm? What's that? What's that?", "{cry}… who goes there?"],
         .recognized: ["Oh, it's you! {cry} ♥", "{cry}! My favourite human!"],
         .startled: ["Gah! Don't sneak up on a ghost!", "Hey! Scaring people is MY job!"],
         .petted: ["{cry}… that tickles!", "Hehe, your hand went right through me!", "Pet me more and I won't haunt you… much."],
         .pettedSleepy: ["Mm… even ghosts get sleepy…"],
         .pickedUp: ["Hey! You can't hold a ghost! …Wheee!", "{cry}! I'm flying!"],
         .pickedUpWorried: ["Careful! Ghosts bruise too, you know."],
         .droppedHard: ["Ow… wait, ghosts don't feel pain. …Ow anyway."],
         .dizzy: ["My head's spinning faster than my shadow…"],
         .askBerry: ["My tummy's haunted… got a berry?", "Feed me, or I lick your screen."],
         .ateFavourite: ["{cry}!! My favourite! ♥"],
         .ate: ["Mmm! Berries taste better in the dark."],
         .ateDisliked: ["Blech! You eat it!"],
         .full: ["I'm stuffed… no more!"],
         .woke: ["*yawn* Time to haunt!"],
         .userBack: ["{cry}… you're back. I hid all your stuff. Just kidding!"],
         .itemNear: ["Ooh, is that for me?", "Is that a berry? Gimme gimme!"],
         .offline: ["The internet vanished… it wasn't me!"],
         .online: ["It's back! Okay… maybe it WAS me."],
         .hot: ["Too hot… I'm a cold-blooded ghost!"],
         .deleted: ["Gone! Into the shadows!", "{cry}… swallowed whole!"],
         .celebrate: ["{cry}! We did it!"],
         .failed: ["{cry}… cursed. Definitely cursed."],
         .done: ["Done! Now let's go prank someone."],
         .hello: ["{cry}! Boo!"],
         .playing: ["{cry}! Watch this!", "Can't catch me!"]]
    }

    /// Which of its own SpriteCollab animations it uses where the engine has a default. Gengar's sheet has
    /// them all; Gastly and Haunter keep the defaults for the ones they don't have.
    override var animRoles: [String: [String]] {
        ["bask": ["Laying"], "nap": ["EventSleep"], "flinch": ["Cringe"], "wobble": ["LostBalance"], "glide": ["Float"],
         "peek": ["Head"], "breathe": ["DeepBreath"], "throw": ["MultiStrike", "Attack"]]
    }

    /// Its own playful animations from SpriteCollab (Gengar: Twirl, Rotate, Double, Tumble; Gastly and
    /// Haunter: Rotate and Double).
    override var playful: [String] { ["Twirl", "Rotate", "Double", "Tumble", "TumbleBack", "Trip"].filter { a.anim($0) != nil } }

    override func fill(_ mind: inout Mind) {
        mind.ghost = true
        mind.windowToHaunt = Self.isOn(Self.phaseKey) && pet.frontWindow() != nil
        mind.canLick = Self.isOn(Self.lickKey) && knows("Lick")
        let idle = Cursor.secondsUntouched
        mind.cursorLeftAlone = Self.isOn(Self.snatchKey) && stage == .gengar && a.anim("Pull") != nil
            && (90...280).contains(idle) && pet.isVisible(cursor())       // still at the Mac (away is 5 min), and it can get there
        mind.shadowTricks = Self.isOn(Self.shadowKey)
        mind.canPrank = Self.isOn(Self.prankKey)
        mind.ghostHour = Self.isOn(Self.nightKey) && Self.isGhostHour
        nightGlow(mind.ghostHour)
    }

    /// Evening and night (7 pm – 6 am), or any time your Mac is in dark mode. Dev: `-PokeGhostHour YES`.
    static var isGhostHour: Bool {
        if let forced = UserDefaults.standard.object(forKey: "PokeGhostHour") as? Bool { return forced }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 19 || hour < 6 || NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Its own switches in Settings (Gengar's page). All on unless you switch them off.
    static let phaseKey = "gengar.phaseThroughWindows", lickKey = "gengar.licksScreen", snatchKey = "gengar.stealsCursor",
               shadowKey = "gengar.shadowTricks", prankKey = "gengar.pranks", nightKey = "gengar.nightOwl"
    static func isOn(_ key: String) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    static var phasing: Bool { isOn(phaseKey) }

    /// Gastly levels up to 25: it offers to evolve (asked again each level until you say yes).
    override func didLevelUp() {
        if stage == .gastly, level >= GengarLine.haunterLevel { offerEvolution(to: .haunter) }
    }

    /// The Linking Cord: Haunter evolves (in the games, by trading).
    override func use(_ item: Item) -> Bool {
        guard item == .linkingCord else { return false }
        canEvolve ? offerEvolution(to: .gengar, askNow: true) : feel(.surprised)
        return true
    }

    override func startDemo(_ name: String) -> Bool {
        switch name {
        case "fly":                                                   // flies about on repeat
            func loop() { fly { [weak self] in self?.pet.after(1) { loop() } } }
            pet.after(1) { loop() }
            return true
        case "evolve":                                                // Gastly Lv 24 levels up → offers Haunter
            if stage == .gastly { exp = stage.growthRate.exp(forLevel: GengarLine.haunterLevel) - 0.1; gainEXP(0.1) }
        case "cord": pet.after(2) { [weak self] in self?.received(.linkingCord) }   // Haunter: evolves into Gengar
        case "phase":                                                  // sinks into your window and peeks out, on repeat
            func loop() { phase { [weak self] in self?.pet.after(2) { loop() } } }
            pet.after(1) { loop() }
            return true
        case "lick":                                                   // licks your screen, on repeat
            func loop() { lick { [weak self] in self?.pet.after(2) { loop() } } }
            pet.after(1) { loop() }
            return true
        case "snatch":                                                 // steals your cursor right away (move the mouse to get it back)
            pet.after(1) { [weak self] in self?.snatch { [weak self] in self?.think() } }
            return true
        case "clone", "shadow", "prank":                               // one trick on repeat
            func loop() {
                let then: () -> Void = { [weak self] in self?.pet.after(2) { loop() } }
                name == "clone" ? clone(then) : name == "shadow" ? shadowGag(then) : prank(then)
            }
            pet.after(1) { loop() }
            return true
        case "boo":                                                    // its head pops out of the screen near your cursor, on repeat
            func loop() {
                let c = cursor()
                phasing = true
                pet.interactive = false
                boo(at: CGPoint(x: c.x + 120, y: c.y - 60)) { [weak self] in self?.endPhase(); self?.pet.after(1.5) { loop() } }
            }
            pet.after(1) { loop() }
            return true
        case "shadowball":                                             // throws from mid-air at a spot near your cursor; no file is touched
            pet.drag(to: CGPoint(x: pet.position.x, y: max(300, pet.ceiling * 0.6)))
            func loop() {
                let c = cursor()
                halt { [weak self] in
                    self?.shadowBall(at: CGPoint(x: c.x, y: c.y), icon: NSWorkspace.shared.icon(for: .plainText), url: nil) { [weak self] in
                        self?.pet.after(3) { loop() }
                    }
                }
            }
            pet.after(1) { loop() }
            return true
        default: break
        }
        return false
    }

    // MARK: Flight

    /// Gastly and Haunter have no feet to speak of: they always float there. Gengar walks short distances
    /// along the floor it's on, and flies everywhere else.
    override func go(to point: CGPoint, speed: CGFloat, animSpeed: Float = 1, _ done: @escaping () -> Void) {
        let here = pet.position
        if stage == .gengar, abs(point.y - here.y) < 2, abs(point.x - here.x) < 220,
           pet.surface(under: here)?.span.contains(point.x) == true {
            super.go(to: point, speed: speed, animSpeed: animSpeed, done)
            return
        }
        glide(to: point, speed: max(speed * 2, 140) * nature.walkSpeed, done)
    }

    /// One hop through the air: a Mario-style arc from here to `point`, bobbing as it goes.
    private func glide(to point: CGPoint, speed: CGFloat, _ done: @escaping () -> Void) {
        let from = pet.position, d = hypot(point.x - from.x, point.y - from.y)
        guard d > 2 else { done(); return }
        if abs(point.x - from.x) > 4 { pet.face(right: point.x > from.x) }
        pet.play(a.role("glide") ?? a.walk, speed: 1.4)           // Gengar curls up and floats; Gastly's gas trails
        pet.sprite.add(hoverBob(), forKey: "bob")
        let lift = min(140, max(30, d * 0.35))                    // the higher the hop, the longer it is
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: point, control: CGPoint(x: (from.x + point.x) / 2, y: max(from.y, point.y) + lift))
        let duration = max(0.6, Double(d / speed))
        pet.move(to: point, duration: duration, timing: CAMediaTimingFunction(name: .easeInEaseOut), path: path) { [weak self] in
            self?.stopHovering()
            done()
        }
        // Gengar's shadow clones trail behind it on long flights.
        if stage == .gengar, Self.isOn(Self.shadowKey), d > 160 {
            let anim = a.role("glide") ?? a.walk
            for k in 1...4 {
                pet.after(duration * Double(k) / 5) { [weak self] in
                    guard let self else { return }
                    let trail = pet.shade(anim, at: pet.position, right: pet.facingRight, opacity: 0.4)
                    vanish(trail, after: 0, over: 0.5, shrink: false)
                }
            }
        }
    }

    /// Levitate: flies off across the screen, from anywhere to anywhere, in two to four hopping arcs,
    /// hovering a moment with its tongue out between them, then drifts back down. It prefers air you can
    /// see (not behind an app window), so you can actually watch it.
    override func fly(_ done: @escaping () -> Void) {
        let top = max(pet.ceiling, 200), area = pet.walkArea
        func spot() -> CGPoint {
            let candidates = (0..<8).map { _ in CGPoint(x: .random(in: area), y: .random(in: 40...top)) }
            return candidates.first { pet.isVisible($0) && pet.isVisible(CGPoint(x: $0.x, y: $0.y + 30 * pet.scale)) } ?? candidates[0]
        }
        energy -= 0.06
        gainEXP(Growth.Bonus.play)
        var steps: [Step] = []
        for _ in 0..<Int.random(in: 2...4) {
            let p = spot()
            steps.append { [weak self] next in self?.glide(to: p, speed: .random(in: 220...340) * (self?.nature.walkSpeed ?? 1), next) }
            steps.append { [weak self] next in self?.hover(for: .random(in: 0.8...2.5), next) }
        }
        steps.append { [weak self] next in
            guard let self else { return }
            pet.play(a.role("glide") ?? a.walk)
            pet.fall(float: true) { [weak self] in self?.stopHovering(); next() }        // drifts back down
        }
        run(steps) { [weak self] in self?.sit(for: .random(in: 2...4), done) }
    }

    /// Hangs in the air, bobbing. Gengar faces you and sticks its tongue out; the others just idle.
    private func hover(for seconds: TimeInterval, _ done: @escaping () -> Void) {
        pet.play(a.front("Idle") ?? a.idle)
        pet.sprite.add(hoverBob(), forKey: "bob")
        pet.after(seconds) { [weak self] in self?.stopHovering(); done() }
    }

    // MARK: Shadow Ball

    /// Its file delete: for each file, it charges a Shadow Ball in its hands, throws it at the file's icon
    /// (in its Finder window or on the desktop; for a file shown nowhere, just in front of it), the file is
    /// sucked into the shadow (and goes to the Trash), and the little wisp left over floats back for it to eat.
    override func attack(_ urls: [URL], at spots: [URL: CGPoint]) {
        halt { [weak self] in                               // throws from right where it is, even mid-air
            guard let self else { return }
            let steps: [Step] = urls.map { url in { [weak self] next in
                guard let self else { return }
                let here = pet.position, dir: CGFloat = pet.facingRight ? 1 : -1
                let target = spots[url] ?? pet.iconCenter(url) ?? CGPoint(x: here.x + dir * 50 * pet.scale, y: here.y + 12 * pet.scale)
                shadowBall(at: target, icon: NSWorkspace.shared.icon(forFile: url.path), url: url, next)
            } }
            run(steps + [{ [weak self] next in self?.cackle(next, saying: .deleted) }]) { [weak self] in self?.think() }
        }
    }

    private func shadowBall(at target: CGPoint, icon: NSImage, url: URL?, _ done: @escaping () -> Void) {
        guard let fx else { done(); return }
        let here = pet.position
        pet.face(right: target.x >= here.x)
        let dir: CGFloat = pet.facingRight ? 1 : -1, s = pet.scale
        feel(.determined, caption: "Shadow Ball!", for: 1.6)
        pet.play(a.charge)
        let eat = a.anim("Eat") ?? a.anim("Lick") ?? a.idle
        fx.shadowBall(at: CGPoint(x: here.x + dir * 13 * s, y: here.y + 14 * s), charge: 0.9, to: target,
                      icon: icon.cgImage(forProposedRect: nil, context: nil, hints: nil),
                      mouth: { [weak self] in
                          guard let self else { return target }
                          return CGPoint(x: pet.position.x + (pet.facingRight ? 6 : -6) * s, y: pet.position.y + 16 * s)
                      },
                      throwing: { [weak self] in
                          guard let self else { return }
                          pet.once(a.role("throw") ?? a.shock) { [weak self] in self?.pet.play(self!.a.idle) }   // Haunter: MultiStrike
                      },
                      impact: { [weak self] in
                          guard let url else { return }
                          do { try FileManager.default.trashItem(at: url, resultingItemURL: nil); self?.gainEXP(Growth.Bonus.zapFile) }
                          catch { self?.feel(.sigh) }                                      // couldn't (e.g. no permission)
                      },
                      eaten: { [weak self] in
                          guard let self else { return }
                          pet.hearts()
                          pet.once(eat, times: 2) { done() }                               // munch
                      })
    }

    /// After a delete or a prank: it turns to you and sticks its tongue out, very pleased with itself
    /// (and says so, if there's something to say).
    private func cackle(_ done: @escaping () -> Void, saying moment: Moment? = nil) {
        if let moment { chat(moment, .happy, for: 2.5) } else { feel(.happy, for: 2) }
        pet.once(a.front("Lick") ?? a.front("Idle") ?? a.pose, done: done)
    }

    // MARK: Phasing through windows

    private var phasing = false

    /// Ghost-type: it flies to the top edge of the window you're working in and sinks into it. A moment
    /// later its head pops up somewhere along the window's top or bottom edge, half out, tongue out at you,
    /// and ducks back in; once or twice more, then it climbs out over the top edge and drifts away.
    /// Only for windows it's allowed in front of (never full-screen apps, videos, YouTube or apps you listed).
    override func phase(_ done: @escaping () -> Void) {
        guard Self.phasing, let w = pet.frontWindow() else { fly(done); return }
        func along() -> CGFloat { .random(in: (w.minX + 40 * pet.scale)...max(w.minX + 40 * pet.scale, w.maxX - 40 * pet.scale)) }
        let entry = CGPoint(x: along(), y: w.maxY)
        feel(.happy, thought: Pixels.exclaim, for: 1.6)
        energy -= 0.05
        gainEXP(Growth.Bonus.play)
        var steps: [Step] = [
            { [weak self] next in self?.go(to: entry, speed: 160, next) },
            { [weak self] next in self?.sinkIn(next) },
        ]
        for _ in 0..<Int.random(in: 1...2) {
            steps.append { [weak self] next in self?.pet.after(.random(in: 1.5...4), next) }   // somewhere inside…
            let bottom = Bool.random()
            steps.append { [weak self] next in
                guard let self else { return }
                // Now and then, right where you're looking: just its head pops out of the screen under your cursor. Boo!
                let c = cursor()
                if a.roleName("peek") != nil, w.insetBy(dx: 30 * pet.scale, dy: 30 * pet.scale).contains(c), Bool.random() {
                    boo(at: CGPoint(x: c.x, y: c.y - 28 * pet.scale), next)
                } else {
                    peek(at: CGPoint(x: along(), y: bottom ? w.minY + 4 : w.maxY), next)
                }
            }
        }
        steps.append { [weak self] next in self?.pet.after(.random(in: 1...2.5), next) }
        steps.append { [weak self] next in self?.climbOut(at: CGPoint(x: along(), y: w.maxY), next) }
        run(steps) { [weak self] in self?.sit(for: 1, done) }
    }

    /// Sinks down into the edge it's standing on (Gengar's own Sink animation; Gastly and Haunter fade away).
    private func sinkIn(_ done: @escaping () -> Void) {
        phasing = true
        pet.interactive = false
        if let sink = a.anim("Sink") {
            pet.once(sink) { [weak self] in self?.pet.sprite.opacity = 0; done() }
        } else {
            fade(to: 0, 0.5)
            pet.after(0.5, done)
        }
    }

    /// Only what's above the line through its feet shows: the rest is "inside" the window.
    private func clipBelowFeet(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if on {
            let mask = CALayer()
            mask.backgroundColor = NSColor.black.cgColor
            mask.frame = CGRect(x: -2000, y: 0, width: 4000, height: 4000)
            pet.node.mask = mask
        } else {
            pet.node.mask = nil
        }
        CATransaction.commit()
    }

    /// Slides the sprite up or down within its node (the node stays on the window's edge).
    private func rise(from: CGFloat, to: CGFloat, _ seconds: CFTimeInterval) {
        let slide = CABasicAnimation(keyPath: "position.y")
        slide.fromValue = from
        slide.toValue = to
        slide.duration = seconds
        slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pet.sprite.position.y = to
        pet.sprite.add(slide, forKey: "rise")
        CATransaction.commit()
    }

    private func fade(to opacity: Float, _ seconds: CFTimeInterval) {
        let f = CABasicAnimation(keyPath: "opacity")
        f.fromValue = pet.sprite.presentation()?.opacity ?? pet.sprite.opacity
        f.toValue = opacity
        f.duration = seconds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pet.sprite.opacity = opacity
        pet.sprite.add(f, forKey: "fade")
        CATransaction.commit()
    }

    /// Half its body pops up out of the window's edge at `point`, facing you with its tongue out, then ducks back.
    private func peek(at point: CGPoint, _ done: @escaping () -> Void) {
        pet.drag(to: point)
        pet.resetSwings()
        let face = a.front("Idle") ?? a.idle
        pet.play(face)                                          // its tongue-out idle, facing you
        let depth = (face.height + 2) * pet.scale               // just under the edge: all of it hidden
        clipBelowFeet(true)
        pet.sprite.opacity = 1
        rise(from: -depth, to: -depth * 0.3, 0.6)               // head, grin and tongue pop up; the rest stays inside
        feel(.happy, for: 2.4)
        pet.after(.random(in: 2.5...4)) { [weak self] in
            guard let self else { return }
            rise(from: -depth * 0.3, to: -depth, 0.4)
            pet.after(0.45) { [weak self] in self?.pet.sprite.opacity = 0; done() }
        }
    }

    /// Just its head (its Head animation, facing you) rises out of the screen right below your cursor, with a
    /// "Boo!", grins at you a moment and sinks away again.
    private func boo(at point: CGPoint, _ done: @escaping () -> Void) {
        guard let name = a.roleName("peek"), let head = a.front(name) else { peek(at: point, done); return }
        pet.drag(to: point)
        pet.resetSwings()
        pet.play(head)
        let depth = (head.height + 2) * pet.scale
        clipBelowFeet(true)
        pet.sprite.opacity = 1
        rise(from: -depth, to: 0, 0.35)                         // fast: it's a surprise
        feel(.joyous, caption: "Boo!", for: 2)
        pet.after(.random(in: 1.8...2.6)) { [weak self] in
            guard let self else { return }
            rise(from: 0, to: -depth, 0.5)
            pet.after(0.55) { [weak self] in self?.pet.sprite.opacity = 0; done() }
        }
    }

    /// Climbs all the way out over the window's top edge, then carries on (it drifts down when it next thinks).
    private func climbOut(at point: CGPoint, _ done: @escaping () -> Void) {
        pet.drag(to: point)
        pet.resetSwings()
        pet.play(a.idle)
        let depth = (a.idle.height + 2) * pet.scale
        clipBelowFeet(true)
        pet.sprite.opacity = 1
        rise(from: -depth, to: 0, 0.8)
        pet.after(0.85) { [weak self] in self?.endPhase(); done() }
    }

    private func endPhase() {
        guard phasing else { return }
        phasing = false
        clipBelowFeet(false)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pet.sprite.removeAnimation(forKey: "rise")
        pet.sprite.removeAnimation(forKey: "fade")
        pet.sprite.position = .zero
        pet.sprite.opacity = 1
        CATransaction.commit()
        if !ballBusy { pet.interactive = true }
    }

    /// Stops whatever it's doing right where it is, in the air too: unlike `stop`, it doesn't drift down to the
    /// floor first (a ghost has no need to land to throw a Shadow Ball). It lands later, when it next thinks.
    private func halt(then next: @escaping () -> Void) {
        endPhase()
        giveCursorBack(laughing: false)
        endZoom()
        clearShades()
        stopHovering()
        stopChargeSparks()
        pet.interrupt()
        next()
    }

    /// Anything that interrupts it mid-phase or mid-prank (the charger, a Focus, your camera…) puts it back
    /// together first, and always gives your cursor back.
    override func stop(then next: @escaping () -> Void) {
        endPhase()
        giveCursorBack(laughing: false)
        endZoom()
        clearShades()
        super.stop(then: next)
    }

    // MARK: Licking your screen

    /// Lick: it comes right up to the glass (grows, as if leaning in towards you), licks it with its tongue
    /// a few times, facing you, and leaves a wet smear that drips and fades. Near your cursor if it can see it.
    override func lick(_ done: @escaping () -> Void) {
        guard let fx, let lick = a.front("Lick") else { sit(for: 3, done); return }
        let c = cursor(), s = pet.scale
        let here = pet.isVisible(c) ? CGPoint(x: c.x + .random(in: -160...160), y: max(40, c.y - 140)) : pet.position
        let spot = CGPoint(x: pet.clamp(here.x), y: min(max(40, here.y), max(pet.ceiling, 200)))
        energy -= 0.03
        gainEXP(Growth.Bonus.play)
        run([
            { [weak self] next in self?.go(to: spot, speed: 160, next) },
            { [weak self] next in
                guard let self else { return }
                feel(.joyous, caption: "*lick*", for: 2)
                pet.play(lick)
                zoom(to: 1.8, 0.35)                                   // leans in to the glass
                // The tongue touches the glass low on its face, where it hangs out (about a fifth of the way up).
                let mouth = { CGPoint(x: self.pet.position.x, y: self.pet.position.y + lick.height * 0.2 * s * 1.8) }
                pet.after(0.45) { fx.saliva(at: mouth()) }
                pet.after(0.45 + lick.duration) { if Bool.random() { fx.saliva(at: CGPoint(x: mouth().x + .random(in: -12...12) * s, y: mouth().y)) } }
                pet.after(lick.duration * 3) { [weak self] in
                    self?.zoom(to: 1, 0.35)
                    self?.pet.after(0.4) { [weak self] in self?.endZoom(); next() }
                }
            },
            { [weak self] next in                                      // floats back a little to admire its work
                guard let self else { return }
                feel(.happy, for: 1.5)
                let back = CGPoint(x: pet.clamp(pet.position.x + (Bool.random() ? 1 : -1) * 34 * s), y: pet.position.y)
                go(to: back, speed: 120) { [weak self] in self?.sit(for: 1.5, next) }
            },
        ], then: done)
    }

    private func zoom(to scale: CGFloat, _ seconds: CFTimeInterval) {
        let z = CABasicAnimation(keyPath: "transform.scale")
        z.fromValue = pet.node.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        z.toValue = scale
        z.duration = seconds
        z.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        z.fillMode = .forwards
        z.isRemovedOnCompletion = false
        pet.node.add(z, forKey: "zoom")
    }

    private func endZoom() { pet.node.removeAnimation(forKey: "zoom") }

    // MARK: Shadow tricks

    private var shades: [CALayer] = []

    /// Fades `layer` out (and shrinks it, a puff of shadow) and removes it, whatever happens to the pet meanwhile.
    private func vanish(_ layer: CALayer, after delay: TimeInterval, over seconds: CFTimeInterval, shrink: Bool = true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            CATransaction.begin()
            CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.toValue = 0
            let group = CAAnimationGroup()
            if shrink {
                let s = CABasicAnimation(keyPath: "transform.scale.y")
                s.toValue = 0.1
                group.animations = [fade, s]
            } else {
                group.animations = [fade]
            }
            group.duration = seconds
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            layer.add(group, forKey: "vanish")
            CATransaction.commit()
        }
    }

    private func clearShades() {
        shades.forEach { $0.removeFromSuperlayer() }
        shades = []
    }

    /// The longest any shadow may stay on screen. However a trick ends (or doesn't), each one fades away
    /// by itself after this.
    static let shadeLifetime: TimeInterval = 10

    /// Slides a shade to `to` over `seconds` (it stays there).
    private func slide(_ shade: CALayer, to: CGPoint, _ seconds: CFTimeInterval) {
        let m = CABasicAnimation(keyPath: "position")
        m.fromValue = NSValue(point: shade.presentation()?.position ?? shade.position)
        m.toValue = NSValue(point: to)
        m.duration = seconds
        m.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shade.position = to
        shade.add(m, forKey: "slide")
        CATransaction.commit()
    }

    /// Shadow clones: two or three dark copies of it burst out to either side, all grinning at you. "Which one's
    /// the real me?" Now and then the real one swaps places with a clone before they puff away.
    override func clone(_ done: @escaping () -> Void) {
        let here = pet.position, s = pet.scale, face = a.front("Idle") ?? a.idle
        let offsets: [CGFloat] = [-1, 1, Bool.random() ? -2 : 2].prefix(Int.random(in: 2...3)).map { $0 * 34 * s }
        let spots = offsets.map { CGPoint(x: pet.clamp(here.x + $0), y: here.y + .random(in: -6...6) * s) }
        pet.face(right: true)
        pet.play(face)
        feel(.joyous, caption: "Which one's the real me?", for: 3)
        energy -= 0.04
        gainEXP(Growth.Bonus.play)
        clearShades()
        for p in spots {
            let c = pet.shade(face, at: here, right: true, opacity: 0.8)
            shades.append(c)
            slide(c, to: p, 0.35)
        }
        let swap = Bool.random() ? spots.indices.randomElement() : nil
        pet.after(2.6) { [weak self] in
            guard let self else { return }
            if let i = swap {                                          // the switcheroo
                slide(shades[i], to: here, 0.4)
                pet.move(to: spots[i], duration: 0.4, timing: CAMediaTimingFunction(name: .easeInEaseOut)) {}
            }
            pet.after(1.4) { [weak self] in
                guard let self else { return }
                for (i, c) in shades.enumerated() { vanish(c, after: Double(i) * 0.15, over: 0.3) }
                shades = []
                feel(.happy, for: 1.5)
                pet.once(a.front("Lick") ?? face) { [weak self] in self?.sit(for: 1.5, done) }
            }
        }
    }

    /// Its own shadow gets up to mischief: it slips out from behind it and runs off, stops, turns and sticks its
    /// tongue out. Gengar startles and chases it, and they switch places on the way. Then the shadow melts
    /// into the floor. "…Wait. Which of us was the shadow?"
    override func shadowGag(_ done: @escaping () -> Void) {
        let here = pet.position, s = pet.scale
        let dir: CGFloat = here.x < (pet.walkArea.lowerBound + pet.walkArea.upperBound) / 2 ? 1 : -1   // towards the middle
        let away = CGPoint(x: pet.clamp(here.x + dir * 45 * s), y: here.y)
        clearShades()
        pet.face(right: dir < 0)                                           // looking the other way: it doesn't notice at first
        pet.hold(a.idle, frame: 0)
        var shadow = pet.shade(a.walk, at: here, right: dir > 0, opacity: 0.6)
        shades = [shadow]
        energy -= 0.04
        gainEXP(Growth.Bonus.play)
        func replace(_ anim: Anim, right: Bool) {
            let at = shadow.presentation()?.position ?? shadow.position
            shadow.removeFromSuperlayer()
            shadow = pet.shade(anim, at: at, right: right, opacity: 0.6)
            shades = [shadow]
        }
        run([
            { [weak self] next in self?.pet.after(0.8, next) },
            { [weak self] next in self?.slide(shadow, to: away, 1.4); self?.pet.after(1.5, next) },   // sneaks off
            { [weak self] next in
                guard let self else { return }
                replace(a.front("Lick") ?? a.idle, right: true)                   // turns and blows a raspberry
                pet.face(right: dir > 0)
                feel(.surprised, caption: "Hey! Come back!", thought: Pixels.exclaim, for: 2.2)
                if let cringe = a.role("flinch") { pet.once(cringe, done: next) } else { pet.squash(); pet.after(0.6, next) }
            },
            { [weak self] next in
                guard let self else { return }
                replace(a.walk, right: dir < 0)                                    // the chase: they cross over
                slide(shadow, to: here, 0.9)
                go(to: away, speed: 140) { next() }
            },
            { [weak self] next in
                guard let self else { return }
                vanish(shadow, after: 0.2, over: 0.6)                              // melts into the floor
                shades = []
                pet.face(right: dir < 0)
                feel(.dizzy, caption: "…Which of us was the shadow?", for: 3)
                pet.after(1, next)
            },
        ]) { [weak self] in self?.sit(for: 2, done) }
    }

    // MARK: Pranks

    /// Up to no good: tickles your Dock, tries to drag your window away by its corner, or pats ghostly
    /// handprints across your screen. Picks whichever it can play right now.
    override func prank(_ done: @escaping () -> Void) {
        var pranks: [(@escaping () -> Void) -> Void] = [{ [weak self] in self?.handprints($0) }]
        if pet.ground.count == 3, pet.isVisible(CGPoint(x: (pet.ground[1].span.lowerBound + pet.ground[1].span.upperBound) / 2, y: pet.ground[1].y + 20)) {
            let dock = pet.ground[1]
            pranks.append { [weak self] in self?.tickleDock(dock, $0) }
        }
        if let w = pet.frontWindow() { pranks.append { [weak self] in self?.tugWindow(w, $0) } }
        energy -= 0.04
        gainEXP(Growth.Bonus.play)
        pranks.randomElement()!(done)
    }

    /// Floats down to your Dock and tickles the icons with both hands. They don't laugh; it does.
    private func tickleDock(_ dock: Ground, _ done: @escaping () -> Void) {
        let s = pet.scale
        let spot = CGPoint(x: .random(in: (dock.span.lowerBound + 30 * s)...(dock.span.upperBound - 30 * s)), y: dock.y + 4 * s)
        run([
            { [weak self] next in self?.go(to: spot, speed: 160, next) },
            { [weak self] next in
                guard let self else { return }
                feel(.joyous, caption: "Tickle tickle!", for: 2.5)
                pet.stars()
                pet.once(a.anim("Swing") ?? a.anim("Strike") ?? a.shock, times: 3, done: next)
            },
            { [weak self] next in self?.cackle(next) },
        ], then: done)
    }

    /// Grabs your window by a top corner and pulls with all its might (its Pull) to drag it off. It won't
    /// budge, and it tumbles over backwards.
    private func tugWindow(_ w: CGRect, _ done: @escaping () -> Void) {
        let s = pet.scale, right = Bool.random()
        let corner = CGPoint(x: right ? w.maxX - 6 * s : w.minX + 6 * s, y: w.maxY - 2 * s)
        run([
            { [weak self] next in self?.go(to: corner, speed: 170, next) },
            { [weak self] next in
                guard let self else { return }
                pet.face(right: right)                                          // pulling outwards
                feel(.determined, caption: "Nngh… come… here…!", for: 3)
                pet.once(a.anim("Pull") ?? a.anim("Attack") ?? a.shock, times: 3, done: next)
            },
            { [weak self] next in
                guard let self else { return }
                feel(.dizzy, caption: "Oof! Too heavy.", for: 2.5)
                pet.once(a.anim("TumbleBack") ?? a.anim("Trip") ?? a.hurt, done: next)
            },
        ], then: done)
    }

    /// Pats ghostly purple handprints across your screen, left, right, left…, which fade a few seconds later.
    private func handprints(_ done: @escaping () -> Void) {
        let s = pet.scale, c = cursor()
        let start = pet.isVisible(c) ? CGPoint(x: pet.clamp(c.x - 80 * s), y: max(60, c.y - 40 * s)) : pet.position
        let dir: CGFloat = start.x < (pet.walkArea.lowerBound + pet.walkArea.upperBound) / 2 ? 1 : -1
        let count = Int.random(in: 4...6)
        let hands = (0..<count).map { i in CGPoint(x: start.x + dir * CGFloat(i) * 16 * s, y: start.y + 18 * s + (i % 2 == 0 ? 4 : -4) * s) }
        let end = CGPoint(x: pet.clamp(start.x + dir * CGFloat(count) * 16 * s), y: start.y)
        run([
            { [weak self] next in self?.go(to: start, speed: 170, next) },
            { [weak self] next in
                guard let self, let fx else { next(); return }
                feel(.joyous, caption: "Pat pat pat!", for: 2.5)
                fx.stamp(Pixels.handprint, at: hands, every: 0.35)
                pet.face(right: dir > 0)
                pet.play(a.anim("Strike") ?? a.anim("Attack") ?? a.walk)
                pet.move(to: end, duration: 0.35 * Double(count), timing: nil) { next() }
            },
            { [weak self] next in self?.cackle(next) },
        ], then: done)
    }

    // MARK: Ghost hour

    private var glowing = false

    /// After dark (or in dark mode) it glows a faint ghostly purple, and says so the first time each evening.
    private func nightGlow(_ on: Bool) {
        guard on != glowing else { return }
        glowing = on
        CATransaction.begin()
        CATransaction.setAnimationDuration(1.5)                            // fades in / out
        pet.sprite.shadowColor = NSColor(calibratedRed: 0.78, green: 0.3, blue: 1, alpha: 1).cgColor
        pet.sprite.shadowOffset = .zero
        pet.sprite.shadowRadius = 2.5 * pet.scale
        pet.sprite.shadowOpacity = on ? 0.95 : 0
        CATransaction.commit()
        let last = UserDefaults.standard.object(forKey: key("ghostHourGreeted")) as? Date ?? .distantPast
        if on, Date().timeIntervalSince(last) > 10 * 3600 {
            UserDefaults.standard.set(Date(), forKey: key("ghostHourGreeted"))
            feel(.joyous, caption: "The night is mine… 👻", for: 3.5)
        }
    }

    // MARK: Stealing your cursor

    private var fakeCursor: CALayer?
    private var mouseWatch: Any?

    /// Your mouse has sat untouched a while (you're reading, or typing): Gengar flies over, grabs your cursor
    /// and tugs at it (its Pull), then flies off with it and hovers, grinning. It's a fake: your real cursor
    /// is only hidden, never moved. The moment you touch the mouse or trackpad (or after 30 s), it's yours
    /// again: "Peek-a-boo!"
    override func snatch(_ done: @escaping () -> Void) {
        guard stage == .gengar, let pull = a.anim("Pull") else { lick(done); return }
        let c = cursor(), s = pet.scale
        let side: CGFloat = c.x > pet.position.x ? -1 : 1               // comes at it from its own side
        let reach = CGPoint(x: pet.clamp(c.x + side * 12 * s), y: max(0, c.y - 24 * s))   // hand at the cursor's tip
        feel(.happy, thought: Pixels.exclaim, for: 1.5)
        go(to: reach, speed: 180) { [weak self] in
            guard let self else { return }
            let now = cursor()
            guard hypot(now.x - c.x, now.y - c.y) < 15, Cursor.hide() else { sit(for: 2, done); return }   // you moved: never mind
            grab(at: c)
            pet.face(right: c.x > pet.position.x)
            run([
                { [weak self] next in self?.pet.once(pull, times: 2, done: next) },          // tug, tug
                { [weak self] next in
                    guard let self else { return }
                    let away = CGPoint(x: .random(in: pet.walkArea), y: .random(in: 60...max(120, pet.ceiling * 0.8)))
                    go(to: away, speed: 220, next)
                },
                { [weak self] next in
                    guard let self else { return }
                    feel(.joyous, caption: "Hehe! Mine now.", for: 3)
                    pet.play(a.front("Idle") ?? a.idle)
                    pet.sprite.add(hoverBob(), forKey: "bob")
                    var over = false                                    // whichever comes first: your mouse, or 30 s
                    let finish = { [weak self] in
                        guard !over else { return }
                        over = true
                        self?.stopHovering()
                        next()
                    }
                    pet.after(30) { [weak self] in self?.giveCursorBack(laughing: true); finish() }   // it gets bored of it
                    self.onCursorBack = finish                          // your mouse moved: given back right away
                },
            ], then: done)
        }
    }

    private var onCursorBack: (() -> Void)?

    /// Puts a copy of the arrow cursor in its hand (where the real one was) and starts watching for your mouse.
    private func grab(at point: CGPoint) {
        let arrow = NSCursor.arrow, image = arrow.image
        let layer = CALayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer.bounds = CGRect(origin: .zero, size: image.size)
        layer.anchorPoint = CGPoint(x: arrow.hotSpot.x / image.size.width, y: 1 - arrow.hotSpot.y / image.size.height)
        let here = pet.position
        layer.position = CGPoint(x: point.x - here.x, y: point.y - here.y)   // the node carries it from here
        pet.node.addSublayer(layer)
        CATransaction.commit()
        fakeCursor = layer
        mouseWatch = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
                                                                   .scrollWheel, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            guard let self else { return }
            let back = onCursorBack
            giveCursorBack(laughing: true)
            back?()
        }
    }

    /// Shows your real cursor again and drops the fake. `laughing`: "Peek-a-boo!" with its tongue out.
    private func giveCursorBack(laughing: Bool) {
        guard fakeCursor != nil || mouseWatch != nil else { return }
        if let mouseWatch { NSEvent.removeMonitor(mouseWatch) }
        mouseWatch = nil
        onCursorBack = nil
        Cursor.show()
        fakeCursor?.removeFromSuperlayer()
        fakeCursor = nil
        if laughing {
            feel(.joyous, caption: "Peek-a-boo! 👻", for: 2.5)
            if let tongue = a.front("Lick") { pet.once(tongue) { [weak self] in self?.pet.play(self!.a.idle) } }
        }
    }
}

private extension Pet {
    /// A dark, see-through copy of the Pokémon standing on the stage at `point` (where its feet go), playing
    /// `anim` on its own: shadow clones and its runaway shadow. Remove it when done.
    func shade(_ anim: Anim, at point: CGPoint, right: Bool, opacity: Float) -> CALayer {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let body = CALayer()
        body.bounds = CGRect(x: 0, y: 0, width: anim.frameSize.width * scale, height: anim.frameSize.height * scale)
        body.anchorPoint = CGPoint(x: 0.5, y: (anim.frameSize.height / 2 - anim.feet) / anim.frameSize.height)
        body.position = point
        body.backgroundColor = NSColor(calibratedRed: 0.17, green: 0.06, blue: 0.27, alpha: 1).cgColor
        body.opacity = opacity
        if !right { body.transform = CATransform3DMakeScale(-1, 1, 1) }
        let mask = CALayer()
        mask.frame = body.bounds
        mask.contents = anim.image
        mask.contentsRect = anim.frames[0]
        mask.magnificationFilter = .nearest
        let flipBook = CAKeyframeAnimation(keyPath: "contentsRect")
        flipBook.values = anim.frames
        flipBook.calculationMode = .discrete
        flipBook.duration = anim.duration
        flipBook.repeatCount = .infinity
        mask.add(flipBook, forKey: "frames")
        body.mask = mask
        node.superlayer?.insertSublayer(body, below: node)
        CATransaction.commit()
        // Its time to live: fades out and goes, even if nothing else ever removes it.
        DispatchQueue.main.asyncAfter(deadline: .now() + Gengar.shadeLifetime) { [weak body] in
            guard let body, body.superlayer != nil else { return }
            CATransaction.begin()
            CATransaction.setCompletionBlock { body.removeFromSuperlayer() }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.toValue = 0
            fade.duration = 0.6
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            body.add(fade, forKey: "ttl")
            CATransaction.commit()
        }
        return body
    }
}

/// Hiding the real cursor while Gengar "holds" it.
///
/// macOS only lets the front app hide the cursor; a menu bar app has to ask the window server to let it
/// do so in the background (the "SetsCursorInBackground" connection property: private, but what cursor
/// hiders use). If that isn't there, `hide()` says no and the prank is skipped: the cursor is never left
/// hidden. Hiding is per app, so if PokePets quits or crashes, macOS shows it again by itself.
/// ponytail: private CoreGraphics call; drop the prank (or draw a decoy next to the real cursor) if it goes away.
enum Cursor {
    private static var hidden = false

    /// Seconds since you last moved, clicked or scrolled the mouse (keyboard doesn't count).
    static var secondsUntouched: TimeInterval {
        [CGEventType.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .leftMouseDragged]
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }

    static func hide() -> Bool {
        guard !hidden else { return true }
        typealias Connection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let main = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_CGSDefaultConnection"),       // RTLD_DEFAULT
              let set = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetConnectionProperty") else { return false }
        let cid = unsafeBitCast(main, to: Connection.self)()
        guard unsafeBitCast(set, to: SetProperty.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue) == 0,
              CGDisplayHideCursor(CGMainDisplayID()) == .success else { return false }
        hidden = true
        return true
    }

    static func show() {
        guard hidden else { return }
        hidden = false
        CGDisplayShowCursor(CGMainDisplayID())
    }
}
