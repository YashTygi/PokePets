import AppKit
import UserNotifications

/// One species' animations: its PMD SpriteCollab sheets ("pikachu-walk", "gengar-sink", …) and their
/// frame timings from the species' AnimData.xml, exactly as the site publishes them, so evolving just
/// swaps the whole set. The engine's roles (walk, sleep, a jump…) map to SpriteCollab animations, with
/// the closest one the species has when an artist hasn't drawn that animation for it.
struct Sheets {
    let walk, idle, sleep, hop, charge, shock, pose, hurt, crash, eat, faint, wake, nod, leap,
        tumble, twirl, pain, stretch, dance, lookUp, lookDown: Anim
    /// Has its own eating sprite. Alolan Raichu doesn't: it eats in `eatHold` instead, facing you with
    /// the berry in both paws (its Shoot frame, holding an energy ball, with the berry over the ball).
    let canEat: Bool
    let eatHold: Anim?
    /// Every animation SpriteCollab has for this species, under the site's names, in the site's order.
    let all: [(name: String, anim: Anim)]
    private let species: String
    private let data: AnimData
    private let roles: [String: [String]]

    /// - roles: the species' own picks for some roles, by SpriteCollab name (first one it has wins):
    ///   "bask", "nap", "flinch", "wobble", "glide", "peek", "breathe", "throw". A role it doesn't name
    ///   keeps the engine's default, so a species only changes what it asks for.
    init(_ species: String, roles: [String: [String]] = [:]) {
        let data = AnimData(species)
        self.species = species
        self.data = data
        self.roles = roles
        func a(_ names: String..., feet: CGFloat? = nil) -> Anim {
            for n in names { if let s = Self.sheet(species, data, n, feet: feet) { return s } }
            return Self.sheet(species, data, "Idle")!
        }
        walk = a("Walk"); idle = a("Idle"); sleep = a("Sleep", "Idle"); hop = a("Hop", "Idle")
        charge = a("Charge", "Idle"); shock = a("Shock", "Shoot", "Attack"); pose = a("Pose", "Idle"); hurt = a("Hurt", "Idle")
        crash = a("HitGround", "Hurt", "Idle"); eat = a("Eat", "Pose", "Idle"); faint = a("Faint", "Sleep", "Idle")
        nod = a("Nod", "Pose", "Idle")
        wake = a("Wake", "Idle", feet: idle.feet)                       // starts lying down, ends standing
        leap = a("LeapForth", "Hop", "Idle"); tumble = a("Tumble", "Rotate", "Idle"); twirl = a("Rotate", "Idle")
        pain = a("Pain", "Hurt", "Idle"); stretch = a("DeepBreath", "Pose", "Idle"); dance = a("Double", "Idle")
        // Looking up / down at your cursor: the first frame of Idle's up-right and down-right rows.
        let still = data.anims["Idle"]!
        lookUp = Anim("\(species)-idle", ticks: still.durations, frameHeight: still.height, row: 3, firstFrame: true)
        lookDown = Anim("\(species)-idle", ticks: still.durations, frameHeight: still.height, row: 1, firstFrame: true)
        canEat = Self.sheet(species, data, "Eat") != nil
        eatHold = NSImage(named: "\(species)-eathold") == nil ? nil : Anim(row: NSImage(named: "\(species)-eathold")!
            .cgImage(forProposedRect: nil, context: nil, hints: nil)!, ticks: [10])
        all = data.order.compactMap { n in Self.sheet(species, data, n).map { (n, $0) } }
    }

    /// The animation the species picked for `role`, if it picked one it has.
    func role(_ role: String) -> Anim? { roleName(role).flatMap(anim) }
    /// Its SpriteCollab name.
    func roleName(_ role: String) -> String? { roles[role]?.first { anim($0) != nil } }

    /// One SpriteCollab animation (facing right), if this species has it.
    func anim(_ name: String) -> Anim? { all.first { $0.name == name }?.anim }
    /// The same, facing you (the Down row).
    func front(_ name: String) -> Anim? { Self.sheet(species, data, name, row: 0) }
    /// All eight directions, as the SpriteCollab site shows them (for the Settings gallery).
    func directions(_ name: String) -> [Anim] { (0..<Anim.directions).compactMap { Self.sheet(species, data, name, row: $0) } }

    private static func sheet(_ species: String, _ data: AnimData, _ name: String, row: Int = Anim.right, feet: CGFloat? = nil) -> Anim? {
        guard let info = data.anims[name] else { return nil }
        let source = info.copyOf ?? name                                 // Gengar's Lick is a copy of its Shoot
        guard let src = data.anims[source], NSImage(named: "\(species)-\(source.lowercased())") != nil else { return nil }
        return Anim("\(species)-\(source.lowercased())", ticks: src.durations, frameHeight: src.height, row: row, feet: feet)
    }
}

/// A species' AnimData.xml (SpriteCollab's, unchanged): each animation's frame height and frame timings
/// (in 1/60 s ticks), and which ones are copies of another.
private struct AnimData {
    struct Info { var height = 0; var durations: [Int] = []; var copyOf: String? }
    private(set) var anims: [String: Info] = [:]
    private(set) var order: [String] = []

    init(_ species: String) {
        guard let url = Bundle.main.url(forResource: "\(species)-anim", withExtension: "xml"),
              let parser = XMLParser(contentsOf: url) else { return }
        let reader = Reader()
        parser.delegate = reader
        parser.parse()
        anims = reader.anims
        order = reader.order
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var anims: [String: Info] = [:], order: [String] = []
        private var name = "", text = "", current = Info()
        func parser(_ p: XMLParser, didStartElement e: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) { text = ""; if e == "Anim" { current = Info() } }
        func parser(_ p: XMLParser, foundCharacters s: String) { text += s }
        func parser(_ p: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch e {
            case "Name": name = t
            case "FrameHeight": current.height = Int(t) ?? 0
            case "Duration": current.durations.append(Int(t) ?? 1)
            case "CopyOf": current.copyOf = t
            case "Anim": anims[name] = current; order.append(name)
            default: break
            }
        }
    }
}

/// Portraits (PMD SpriteCollab), shown in a bubble when it feels something.
enum Face: String {
    case happy, joyous, angry, crying, pain, dizzy, worried, surprised, sigh, determined, inspired
}

/// One step of a routine: do something, then call the continuation.
typealias Step = (@escaping () -> Void) -> Void

func run(_ steps: [Step], then done: @escaping () -> Void) {
    guard let first = steps.first else { done(); return }
    first { run(Array(steps.dropFirst()), then: done) }
}

/// The engine every Pokémon shares: its needs, growth, brain, everyday routines, cursor watching,
/// being picked up and fed, the Poké Ball, the Mac's events, notifications. It decides what to do from
/// its needs (see "Brain"), plays it with Core Animation, and only wakes up again when that ends or
/// something happens: cursor nearby, picked up, dropped, charger plugged or unplugged, battery changed.
///
/// A species subclasses it and overrides the hooks marked "Species" (sprites, moves, ability,
/// evolution, its delete move). Everything is saved under `store` ("pet.energy", "gengar.energy", …).
class Companion {
    let pet = Pet(scale: 3)
    /// UserDefaults prefix for everything this Pokémon saves.
    let store: String
    /// Where it is in its evolution line. A fresh install starts as an Egg.
    var stage: Stage
    var form: String?                            // a regional or other form ("alola" for Alolan Raichu)
    var shiny: Bool
    /// Its nature, rolled when it hatches (and given to a Pokémon from before natures existed).
    var nature: Nature
    // Pokérus: nil never had it; a future date: infected until then; a past date: cured (immune).
    var pokerusUntil: Date?
    var hasPokerus: Bool { pokerusUntil.map { $0 > Date() } ?? false }
    lazy var a = Sheets(species, roles: animRoles)
    /// The species' picks for the engine's animation roles (see `Sheets`). Default: none.
    var animRoles: [String: [String]] { [:] }
    /// ♂ or ♀, rolled when it hatches.
    var gender: String
    let power: Power
    let senses: Senses
    var fx: BallFX?                                  // throw / recall / bolt effects (set by the app)
    var ballStart: () -> CGPoint = { .zero }         // menu bar icon, in stage coordinates (set by the app)
    var cursor: () -> CGPoint = { .zero }             // cursor in stage coordinates (set by the app)

    // MARK: Species (override these)

    /// Sprite and portrait set for a stage: "pichu", "pikachu-shiny", "raichu-alola", …
    func sheetName(_ stage: Stage, form: String?, shiny: Bool) -> String { fatalError("species must override") }
    /// The stage an Egg hatches into.
    var firstStage: Stage { fatalError("species must override") }
    var name: String { stage.name }
    var ability: (name: String, effect: String) { ("", "") }
    /// Its ability does something while your Mac charges (announced when you plug in).
    var abilityOnCharge: Bool { false }
    /// Moves it knows right now.
    var known: Set<String> { [] }
    /// Every move its line learns (for "learned X!").
    var learnset: [Move] { [] }
    /// Moves announced first when it evolves (like the games' evolution moves).
    var signatureMoves: Set<String> { [] }
    var canEvolve: Bool { false }
    var isAlolan: Bool { false }
    /// Floats instead of falling: drifts down when dropped, rises into open air.
    var floats: Bool { false }
    /// Friendship from one petting (counted once per 15 min).
    var pettingFriendship: Double { 2 }
    /// Walking pace on top of its nature's.
    var paceBoost: Double { 1 }
    /// Plugged in: soak up the power instead of getting hungry? Return true if it did.
    func absorbsCharge(minutes: Double) -> Bool { false }
    /// Just levelled up (after the caption): evolution checks and the like.
    func didLevelUp() {}
    /// Its moves changed (hatched, levelled up, evolved): update what they unlock.
    func refreshMoves() {}
    /// Being petted: an extra flourish on top of the hearts.
    func petted() {}
    /// The charger was just plugged in.
    func chargerPlugged() {
        isFainted = false
        stop { [weak self] in self?.pet.once(self!.a.pose) { [weak self] in self?.think() } }
    }
    /// A non-berry item from the dial. Return true if it handled it.
    func use(_ item: Item) -> Bool { false }
    /// Its delete move: send these files to the Trash with a show. Only called when it can.
    func attack(_ urls: [URL], at spots: [URL: CGPoint]) {
        for url in urls { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
    }
    /// `pokepets celebrate`.
    func celebrateHook() {
        stop { [weak self] in
            guard let self else { return }
            chat(.celebrate, .joyous)
            gainEXP(Growth.Bonus.celebrate)
            pet.hearts()
            run([{ [weak self] next in self?.pet.once(self!.a.pose, done: next) }]) { [weak self] in self?.think() }
        }
    }
    /// A species with no Eat animation can eat with another of its own: which animation, where its mouth or
    /// tongue reaches (sprite pixels from its feet, facing right) and how far into each loop the bite lands.
    /// Gastly and Haunter lick their berries. Default: none (nibbles while holding it, as before).
    var nibble: (anim: String, at: CGPoint, bite: Double)? { nil }

    /// What it says in its own voice (see `Moment`); a moment it has no lines for uses the fallback.
    var voice: [Moment: [String]] { [:] }
    /// Its cry, for its lines ("Pika", "Kekeke").
    var cry: String { name }
    /// A launch demo of its own (`-PokeDemo <name>`). Return true if it took over (no `think()`).
    func startDemo(_ name: String) -> Bool { false }
    /// Add what only this species weighs to the brain's picture of how it feels.
    func fill(_ mind: inout Mind) {}
    /// The `.fly` intent (species with Levitate): fly about the screen, then carry on.
    func fly(_ done: @escaping () -> Void) { sit(for: 3, done) }
    /// The `.phase` intent (ghosts): sink into your window and peek out of it, then carry on.
    func phase(_ done: @escaping () -> Void) { sit(for: 3, done) }
    /// The `.lick` intent: lick your screen.
    func lick(_ done: @escaping () -> Void) { sit(for: 3, done) }
    /// The `.snatch` intent: steal your (idle) cursor.
    func snatch(_ done: @escaping () -> Void) { sit(for: 3, done) }
    /// Ghost tricks: shadow clones, chasing its own shadow, pranks.
    func clone(_ done: @escaping () -> Void) { sit(for: 3, done) }
    func shadowGag(_ done: @escaping () -> Void) { sit(for: 3, done) }
    func prank(_ done: @escaping () -> Void) { sit(for: 3, done) }
    /// The item that evolves it right now (shown in the dial's tray), if any.
    var evolveItem: Item? { nil }

    // MARK: Setup

    var species: String { sheetName(stage, form: form, shiny: shiny) }

    private enum Mood { case happy, charging, tired, fainted }
    private var mood: Mood {
        if Setting.heat.isOn, senses.thermal == .critical { return .fainted }     // overheated
        if Setting.heat.isOn, senses.thermal == .serious { return .tired }        // running hot: sluggish
        if power.charging { return .charging }
        if power.level <= 5 { return .fainted }
        if power.level <= 20 { return .tired }
        return .happy
    }
    var isTired: Bool { mood == .tired }
    private var wasCharging: Bool
    private var lastMood: Mood?
    var held = false
    var isFainted = false            // lying on the floor, waiting for power
    var lastCuddle = Date.distantPast
    private var chargeSparks: CAEmitterLayer?
    /// Out on the desktop (true) or resting in its Poké Ball (false).
    private(set) var isOut = true
    var ballBusy = false                     // mid throw or recall

    /// What the party dial shows: the Egg, or its first sitting frame.
    var portrait: Anim { stage == .egg ? Anim(still: Pixels.eggInSlot) : a.idle }

    func key(_ name: String) -> String { store + "." + name }

    init(store: String, power: Power, senses: Senses) {
        self.store = store
        self.power = power
        self.senses = senses
        let d = UserDefaults.standard
        func saved(_ name: String, or fallback: Double) -> Double { d.object(forKey: store + "." + name) as? Double ?? fallback }
        stage = Stage(rawValue: d.string(forKey: store + ".stage") ?? "") ?? .egg
        form = d.string(forKey: store + ".form")
        shiny = d.bool(forKey: store + ".shiny")
        nature = Nature.named(d.string(forKey: store + ".nature")) ?? Nature.all.randomElement()!
        pokerusUntil = d.object(forKey: store + ".pokerus") as? Date
        gender = d.string(forKey: store + ".gender") ?? (Double.random(in: 0..<1) < Growth.femaleChance ? "♀" : "♂")
        energy = saved("energy", or: 0.8)
        hunger = saved("hunger", or: 0.3)
        friendship = saved("friendship", or: Growth.hatchFriendship)
        exp = saved("exp", or: 0)
        hungryMinutes = saved("hungryMinutes", or: 0)
        focusQuiet = d.bool(forKey: "focus.on")
        wasCharging = power.charging

        pet.hold(a.idle, frame: 0)
        isOut = stage != .egg                       // an Egg waits in the dial until you hatch it
        pet.node.isHidden = !isOut
        refreshMoves()

        pet.onHover = { [weak self] point in self?.cursorNearby(point) }
        pet.onCursor = { [weak self] point in self?.watch(point) }
        pet.onPickUp = { [weak self] in self?.pickedUp() }
        pet.onDrop = { [weak self] in self?.dropped() }
        pet.onItem = { [weak self] item in self?.received(item) }
        pet.onItemNear = { [weak self] point in self?.itemNear(point) }
        pet.onZap = { [weak self] urls in self?.zap(urls) }
        pet.onMenu = { [weak self] in self?.menu() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] _ in self?.glance() }
    }

    func start() {
        lastMood = mood
        guard stage != .egg, isOut else { return }
        let demo = UserDefaults.standard.string(forKey: "PokeDemo") ?? ""
        if startDemo(demo) { return }
        switch demo {
        case "dock": dockDemo(); return
        case "files": filesDemo(); return
        case "drop": dropDemo(); return
        case "break": pet.after(1) { [weak self] in self?.suggestBreak() }; return   // its break routine right away
        case "feed": hunger = 1; pet.after(2) { [weak self] in self?.received(.pecha) }   // hungry, then a berry
        case "eat": hunger = 1; pet.drag(to: summonSpot())          // starts hungry, on visible floor
        case "levelup":                                              // levels up right away (caption + notification)
            exp = stage.growthRate.exp(forLevel: level + 1) - 0.1; gainEXP(0.1)
        case "play":                                                  // somersaults, twirls, stretches on repeat
            pet.drag(to: summonSpot())
            func loop() { play { loop() } }
            loop()
            return
        default: break
        }
        think()
    }

    /// Launch with `-PokeDemo dock`: start on the ground left of the Dock, walk up, jump on,
    /// cross the top, jump down on the far side. Then carry on as normal.
    private func dockDemo() {
        guard pet.ground.count == 3 else { think(); return }      // Dock hidden or on the side
        let dock = pet.ground[1].span
        demoRunning = true
        pet.drag(to: CGPoint(x: dock.lowerBound - 160, y: 0))
        run([
            { [weak self] next in self?.sit(for: 2, next) },
            { [weak self] next in self?.go(to: CGPoint(x: dock.lowerBound + 120, y: self!.pet.ground[1].y), speed: 60, next) },
            { [weak self] next in self?.sit(for: 1.5, next) },
            { [weak self] next in self?.go(to: CGPoint(x: dock.upperBound + 120, y: 0), speed: 90, next) },
            { [weak self] next in self?.sit(for: 2, next) },
        ]) { [weak self] in self?.demoRunning = false; self?.think() }
    }

    /// Launch with `-PokeDemo files`: climb onto the nearest file, then up to the highest file it can
    /// reach, look around, and come back down to the floor.
    private func filesDemo() {
        demoRunning = true
        _ = pet.openSpots()                                                         // reads the desktop files
        let files = pet.ground.filter { !$0.solid && pet.canReach(top(of: $0)) }   // demo: even ones behind windows
        let here = pet.position
        guard let first = files.min(by: { abs(top(of: $0).x - here.x) + $0.y < abs(top(of: $1).x - here.x) + $1.y }),
              let highest = files.filter({ abs(top(of: $0).x - top(of: first).x) < 300 }).max(by: { $0.y < $1.y })
        else { demoRunning = false; think(); return }
        run([
            { [weak self] next in self?.go(to: self!.top(of: first), speed: 70, next) },
            { [weak self] next in self?.sit(for: 2, next) },
            { [weak self] next in self?.go(to: self!.top(of: highest), speed: 70, next) },
            { [weak self] next in self?.sit(for: .random(in: 3...6), next) },
            { [weak self] next in self?.go(to: CGPoint(x: self!.pet.walkArea.upperBound - 200, y: 0), speed: 70, next) },
        ]) { [weak self] in self?.demoRunning = false; self?.think() }
    }

    /// Launch with `-PokeDemo drop`: on visible floor, picked up 150 pt and let go, every 5 s.
    private func dropDemo() {
        demoRunning = true
        let spot = summonSpot()
        pet.drag(to: spot)
        func cycle() {
            pickedUp()
            pet.drag(to: CGPoint(x: spot.x, y: spot.y + 150))
            pet.after(1) { [weak self] in
                self?.dropped()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { cycle() }
            }
        }
        cycle()
    }

    var demoRunning = false

    // MARK: Brain
    //
    // It has needs, not dice rolls:
    // • Energy. Walking and climbing tire it; standing around and lying down restore it. It only
    //   lies down when it's tired, and only sleeps when it's worn out (or late at night).
    // • Curiosity. A file that just appeared on the desktop gets inspected right away. Now and then
    //   it goes to explore files it hasn't visited for a while, climbing the icon grid like a ladder.
    // • After a nap it's full of beans: one quick trot, then back to normal.
    // It only ever jumps to get somewhere, never just for the sake of it.

    // Needs, friendship, EXP and stage survive relaunches (saved whenever it thinks).
    var energy: Double                               // 0 exhausted … 1 fresh
    var hunger: Double                               // 0 just ate … 1 starving
    var friendship: Double                           // 0…255, like the games
    var exp: Double                                  // total EXP (Medium Fast: Lv n at n³)
    var dozing = false                               // napping because you stepped away
    private var hiddenForCall = false                // went into its ball because your camera came on
    var caring: Bool { Setting.relationship.isOn }

    func save() {
        let d = UserDefaults.standard
        d.set(energy, forKey: key("energy")); d.set(hunger, forKey: key("hunger"))
        d.set(friendship, forKey: key("friendship")); d.set(exp, forKey: key("exp")); d.set(stage.rawValue, forKey: key("stage"))
        d.set(gender, forKey: key("gender")); d.set(nature.name, forKey: key("nature")); d.set(shiny, forKey: key("shiny"))
        d.set(form, forKey: key("form")); d.set(pokerusUntil, forKey: key("pokerus"))
    }

    var level: Int { stage.growthRate.level(forEXP: exp) }
    func knows(_ move: String) -> Bool { known.contains(move) }
    func befriend(_ amount: Double) {
        if caring { friendship = min(Growth.maxFriendship, max(0, friendship + amount)) }
    }

    /// Gain EXP worth `share` of the current level. Levelling up raises friendship a little and may teach
    /// a move (and the species may offer to evolve).
    func gainEXP(_ share: Double) {
        guard stage != .egg, level < 100 else { return }
        let before = level, knewBefore = known
        exp += (hasPokerus ? 2 : 1) * share * (stage.growthRate.exp(forLevel: level + 1) - stage.growthRate.exp(forLevel: level))
        guard level > before else { return }
        befriend(2)
        refreshMoves()
        let learned = learnset.first { known.contains($0.name) && !knewBefore.contains($0.name) }
        pet.sparks(for: 0.5, rate: 20)
        feel(learned == nil ? .joyous : .inspired,
             caption: learned.map { "\(name) learned \($0.name)!" } ?? "\(name) grew to Lv \(level)!", for: 3.5)
        notify("level", "\(name) grew to Lv \(level)!", learned.map { "It learned \($0.name)." } ?? "Keep it company to help it grow.")
        didLevelUp()
    }

    var stats: PetStats {
        let face: Face = friendship < 70 ? .sigh : friendship >= 200 ? .joyous : .happy
        let here = stage.growthRate.exp(forLevel: level), next = stage.growthRate.exp(forLevel: min(100, level + 1))
        return PetStats(name: name, gender: gender, nature: nature, ability: ability, shiny: shiny && stage != .egg,
                        alola: isAlolan, pokerus: pokerusUntil.map { $0 > Date() ? .infected : .cured } ?? .none,
                        stage: stage, level: level, exp: exp, nextLevelEXP: next,
                        levelProgress: level >= 100 ? 1 : (exp - here) / max(1, next - here),
                        friendship: friendship, hunger: hunger, energy: energy,
                        portrait: stage == .egg ? Pixels.eggPortrait : image(face), canEvolve: canEvolve,
                        evolveItem: evolveItem, known: known)
    }
    var lastPetted = Date()
    private var drops: [Date] = []                  // recent times it was dropped
    private var neglected: Bool { Date().timeIntervalSince(lastPetted) > 20 * 60 }
    var lastThought = Date()
    private var knownFiles: Set<String>?            // nil until its first look at the desktop
    private var lastExplored: [String: Date] = [:]

    var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 23 || hour < 6
    }

    func think() {
        guard !held, isOut, !ballBusy, !dozing else { return }
        if focusQuiet { quietDown(); return }
        greetTheDay()
        defer { save() }
        stopChargeSparks()
        if pet.isAirborne {                             // never stay floating: land first, then decide
            pet.fall(float: floats) { [weak self] in self?.think() }
            return
        }
        let next: () -> Void = { [weak self] in self?.think() }
        switch mood {
        case .fainted:
            faint()
            return
        case .tired:                                    // low battery: the brain weighs rest and naps much higher
            break
        case .charging:
            energy = min(1, energy + 0.05)              // (an ability like Lightning Rod adds more below)
        case .happy:
            break
        }

        let spots = pet.openSpots()
        let files = spots.filter { !$0.solid }
        let newFile = noticeNewFiles(files)

        // Time passes: it gets hungry (about every half hour) and slowly tired just being awake.
        let minutes = min(5, Date().timeIntervalSince(lastThought) / 60)   // (not the time spent in its ball)
        lastThought = Date()
        if pokerusUntil == nil, Double.random(in: 0..<Growth.pokerusOdds) < 1 || UserDefaults.standard.bool(forKey: "PokeRus") {
            catchPokerus()
        }
        if !absorbsCharge(minutes: minutes), Setting.hunger.isOn {
            hunger = min(1, hunger + minutes / 40)         // hungry about every half hour
        }
        energy = max(0, energy - minutes / 40)
        // Good company levels it up: up to 2 % of a level a minute, less when friendship is low.
        gainEXP(minutes * Growth.levelShare(perMinute: caring ? friendship : 180, tired: mood == .tired, rate: stage.growthRate))

        if minutes > 0 { boredom = min(1, boredom + minutes / 8) }   // nothing happening slowly gets boring
        // Left hungry a whole working day: only counts while it's out and you're at the Mac (this runs
        // only then), so a night away or time in its ball doesn't. Each 8 h: friendship −10.
        if Setting.hunger.isOn, 1 - hunger < 0.4 {
            hungryMinutes += minutes
            if hungryMinutes >= Growth.hungryMinutes {
                hungryMinutes = 0
                befriend(-Growth.hungryPenalty)
                if caring { feel(.crying, caption: "\(name) went hungry all day…", thought: Pixels.oranBerry, for: 4) }
            }
        }

        // The utility AI decides (see Brain.swift): every action scored from how it feels right now.
        let fileToVisit = Setting.exploreFiles.isOn ? fileToExplore(files) : nil
        let nearCursor = spotNearCursor(spots)
        var mind = Mind()
        mind.energy = energy; mind.hunger = hunger; mind.friendship = friendship / Growth.maxFriendship
        mind.boredom = boredom; mind.neglect = min(1, Date().timeIntervalSince(lastPetted) / 3600)
        mind.daytime = (9..<17).contains(Calendar.current.component(.hour, from: Date()))
        mind.night = isNight; mind.charging = power.charging; mind.lowBattery = mood == .tired
        mind.music = Setting.music.isOn && senses.musicPlaying
        mind.hungerOn = Setting.hunger.isOn; mind.caring = caring
        mind.newFile = newFile != nil; mind.filesToExplore = fileToVisit != nil; mind.cursorReachable = nearCursor != nil
        mind.openAir = floats && pet.isVisible(CGPoint(x: pet.position.x, y: pet.position.y + 150))
        mind.canPlay = !unlockedMoves.isEmpty; mind.knowsElectroBall = knows("Electro Ball")
        mind.knowsPsychic = knows("Psychic")
        mind.alolan = isAlolan; mind.nature = nature
        fill(&mind)
        let intent = brain.decide(mind)
        if intent.isActive { boredom = max(0, boredom - 0.3) }
        act(intent, newFile: newFile, file: fileToVisit, cursorSpot: nearCursor, spots: spots, next: next)
    }

    /// Carry out what the brain picked. Anything with a goal shows what it's thinking about (portrait +
    /// a little thought icon) the first time it sets out on it, so every move has a reason you can see.
    private func act(_ intent: Intent, newFile: Ground?, file: Ground?, cursorSpot: CGPoint?, spots: [Ground],
                     next: @escaping () -> Void) {
        let changed = intent != lastIntent
        lastIntent = intent
        func show(_ face: Face, _ icon: CGImage?) { if changed { feel(face, thought: icon, for: 2.2) } }
        switch intent {
        case .nap: show(.sigh, Pixels.zzz); nap(next)
        case .rest: show(.sigh, Pixels.zzz); rest(next)
        case .sit:                                       // a quiet breather: restful, but gets boring after a while
            energy = min(1, energy + 0.03)
            boredom = min(1, boredom + 0.12)
            sit(for: .random(in: 5...10), next)
        case .askForBerry: askForBerry(cursorSpot, next)
        case .daydream:                                  // sits and thinks about something it likes
            let likes = Item.allCases.first { $0.flavour != nil && $0.flavour == nature.likes }?.image
            feel(.happy, thought: [Pixels.heart, Pixels.note, Pixels.sparkle, Pixels.bolt, likes ?? Pixels.oranBerry].randomElement()!, for: 3)
            sit(for: .random(in: 6...10), next)
        case .yawn:                                      // getting sleepy: a big yawn and stretch, then a sit
            feel(.sigh, thought: Pixels.zzz, for: 2)
            energy = min(1, energy + 0.05)
            run([{ [weak self] n in self?.pet.once(self!.a.stretch, done: n) },
                 { [weak self] n in self?.sit(for: .random(in: 4...6), n) }], then: next)
        case .sniff:                                     // a few slow steps, nose to the floor
            let spot = strollTarget(spots, within: 90) ?? pet.position
            run([{ [weak self] n in self?.go(to: spot, speed: 35, animSpeed: 0.7, n) },
                 { [weak self] n in self?.pet.once(self!.a.nod, times: 3, done: n) },
                 { [weak self] n in self?.sit(for: 2, n) }], then: next)
        case .hum:                                       // happy with life: bobs its head to a tune of its own
            feel(.joyous, thought: Pixels.note, for: 2.5)
            run([{ [weak self] n in self?.pet.once(self!.a.nod, times: 4, done: n) },
                 { [weak self] n in self?.sit(for: 3, n) }], then: next)
        case .bask:                                      // a sunny afternoon: lies down in the warmth for a bit
            feel(.happy, thought: Pixels.sparkle, for: 2)
            run([{ [weak self] n in self?.pet.stay(self!.a.role("bask") ?? self!.a.sleep, for: .random(in: 15...30), done: n) },
                 { [weak self] n in self?.energy = min(1, (self?.energy ?? 0) + 0.1); self?.pet.once(self!.a.wake, done: n) }], then: next)
        case .inspect:
            guard let newFile else { sit(for: 3, next); return }
            inspect(newFile, next)                       // (shows its own surprised face + file)
        case .explore:
            guard let file else { sit(for: 3, next); return }
            show(.inspired, Pixels.file); explore(file, next)
        case .patrol:                                    // checking its territory, one purposeful walk
            show(.determined, Pixels.bolt)
            guard let spot = strollTarget(spots, within: 260) else { sit(for: 4, next); return }
            if mood == .tired { trudge(next) } else { stroll(to: spot, next) }
        case .visit:                                     // comes over to say hi
            show(.happy, Pixels.heart)
            guard let spot = cursorSpot else { sit(for: 3, next); return }
            go(to: spot, speed: 70) { [weak self] in
                guard let self else { return }
                pet.face(right: cursor().x > pet.position.x)
                sit(for: .random(in: 3...5), next)
            }
        case .play: if changed { chat(.playing, .joyous, thought: Pixels.sparkle, for: 2.2) }; play(next)
        case .dance: show(.joyous, Pixels.note); dance(next)
        case .chargeUp: show(.determined, Pixels.bolt); chargeUp(next)
        case .surfLaps: show(.joyous, Pixels.bolt); surfLaps(spots, next)
        case .levitate: show(.inspired, Pixels.sparkle); levitate(next)
        case .teleport:
            guard let spot = cursorSpot else { sit(for: 3, next); return }
            show(.inspired, Pixels.heart); teleport(to: spot, next)
        case .fly: show(.joyous, Pixels.sparkle); fly(next)
        case .phase: phase(next)
        case .lick: lick(next)
        case .snatch: snatch(next)
        case .clone: clone(next)
        case .shadowGag: shadowGag(next)
        case .prank: prank(next)
        }
    }

    /// Surge Surfer on the charge: a couple of fast surfing laps across the open floor.
    private func surfLaps(_ spots: [Ground], _ done: @escaping () -> Void) {
        guard let a = strollTarget(spots, within: 300), let b = strollTarget(spots, within: 300) else { sit(for: 3, done); return }
        run([{ [weak self] n in self?.go(to: a, speed: 160, animSpeed: 1.6, n) },
             { [weak self] n in self?.go(to: b, speed: 160, animSpeed: 1.6, n) }]) { [weak self] in self?.sit(for: 3, done) }
    }

    private var brain = Brain()
    private var lastIntent: Intent?
    private var boredom = 0.3                        // 0 just played … 1 nothing's happened for ages

    /// What the brain is thinking, for the Settings "Why?" panel.
    var why: (choice: Intent?, at: Date, options: [Option], needs: [(String, Double)]) {
        (brain.choice, brain.decidedAt, brain.options,
         [("Energy", energy), ("Belly", 1 - hunger), ("Friendship", friendship / Growth.maxFriendship), ("Boredom", boredom),
          ("Missing you", min(1, Date().timeIntervalSince(lastPetted) / 3600))])
    }

    private func key(_ file: Ground) -> String { "\(Int(file.span.lowerBound)),\(Int(file.y))" }
    private func top(of file: Ground) -> CGPoint { CGPoint(x: (file.span.lowerBound + file.span.upperBound) / 2, y: file.y) }

    /// The first newly appeared file it can see and reach, if any (files present at launch don't count).
    private func noticeNewFiles(_ visible: [Ground]) -> Ground? {
        let all = pet.ground.filter { !$0.solid }
        let keys = Set(all.map(key))
        defer { knownFiles = keys }
        guard let known = knownFiles else { return nil }
        return all.first { file in
            !known.contains(key(file)) && pet.canReach(top(of: file))
                && visible.contains { $0.y == file.y && $0.span.overlaps(file.span) }
        }
    }

    /// A reachable file it hasn't visited in the last 5 minutes, preferring ones nearby.
    private func fileToExplore(_ files: [Ground]) -> Ground? {
        let here = pet.position
        let candidates = files.filter {
            Date().timeIntervalSince(lastExplored[key($0)] ?? .distantPast) > 300 && pet.canReach(top(of: $0))
        }
        return candidates.sorted { hypot(top(of: $0).x - here.x, top(of: $0).y - here.y)
                                 < hypot(top(of: $1).x - here.x, top(of: $1).y - here.y) }
                         .prefix(3).randomElement()
    }

    /// Somewhere to amble to on the surface it's on (or the nearest visible stretch of floor).
    /// Sitting on a file, it's just as likely to hop back down to the floor.
    func strollTarget(_ spots: [Ground], within maxDistance: CGFloat) -> CGPoint? {
        let here = pet.position
        if pet.surface(under: here)?.solid == false, Bool.random(),
           let floor = spots.filter(\.solid).min(by: { abs(top(of: $0).x - here.x) < abs(top(of: $1).x - here.x) }) {
            return CGPoint(x: min(max(here.x, floor.span.lowerBound + 40), floor.span.upperBound - 40), y: floor.y)
        }
        let floors = spots.filter { $0.solid || ($0.y == pet.surface(under: here)?.y && $0.span.contains(here.x)) }
        guard let spot = floors.first(where: { $0.span.contains(here.x) && abs($0.y - here.y) < 2 })
                ?? floors.min(by: { abs(top(of: $0).x - here.x) < abs(top(of: $1).x - here.x) }) else { return nil }
        guard spot.span.contains(here.x), abs(spot.y - here.y) < 2 else {
            return CGPoint(x: min(max(here.x, spot.span.lowerBound + 40), spot.span.upperBound - 40), y: spot.y)
        }
        let lo = max(spot.span.lowerBound + 20, here.x - maxDistance), hi = min(spot.span.upperBound - 20, here.x + maxDistance)
        return lo < hi ? CGPoint(x: .random(in: lo...hi), y: spot.y) : nil
    }

    func go(to point: CGPoint, speed: CGFloat, animSpeed: Float = 1, _ done: @escaping () -> Void) {
        // Its nature makes it a quick or slow walker (and some abilities speed it up).
        let pace = nature.walkSpeed * paceBoost
        pet.travel(to: point, walk: a.walk, jump: a.hop, leap: a.leap, speed: speed * pace,
                   animSpeed: animSpeed * Float(pace), done: done)
    }

    /// A visible bit of floor right below your cursor, if there is one.
    private func spotNearCursor(_ spots: [Ground]) -> CGPoint? {
        let c = cursor()
        guard let floor = spots.first(where: { $0.solid && $0.span.contains(c.x) }),
              abs(c.x - pet.position.x) > 60 else { return nil }
        let x = min(max(c.x + (c.x > pet.position.x ? -40 : 40), floor.span.lowerBound + 20), floor.span.upperBound - 20)
        return CGPoint(x: x, y: floor.y)
    }

    /// Rises into open air (Alolan Raichu on its tail), drifts around for a while with a gentle hover
    /// bob, then floats back down on its own. Only through air you can see, unless `anywhere`.
    func levitate(anywhere: Bool = false, _ done: @escaping () -> Void) {
        let here = pet.position, altitude = CGFloat.random(in: 70...180), head = 40 * pet.scale
        func open(_ p: CGPoint) -> Bool { anywhere || (pet.isVisible(p) && pet.isVisible(CGPoint(x: p.x, y: p.y + head))) }
        var path = [CGPoint(x: here.x, y: here.y + altitude)]
        guard open(path[0]) else { sit(for: .random(in: 3...6), done); return }
        for _ in 0..<Int.random(in: 2...4) {
            let p = CGPoint(x: pet.clamp(path.last!.x + .random(in: -260...260)), y: here.y + altitude + .random(in: -40...40))
            if open(p) { path.append(p) }
        }
        energy -= 0.05
        gainEXP(Growth.Bonus.play)
        pet.play(a.walk)                                         // sitting on its tail, surfing the air
        pet.sprite.add(hoverBob(), forKey: "bob")
        var steps: [Step] = []
        for (i, p) in path.enumerated() {
            steps.append { [weak self] next in
                guard let self else { return }
                if i > 0 { pet.face(right: p.x > pet.position.x) }
                let d = hypot(p.x - pet.position.x, p.y - pet.position.y)
                pet.move(to: p, duration: max(1.2, Double(d) / 55), timing: CAMediaTimingFunction(name: .easeInEaseOut), done: next)
            }
            steps.append { [weak self] next in self?.pet.after(.random(in: 1.5...3.5), next) }   // hangs in the air a moment
        }
        steps.append { [weak self] next in
            guard let self else { return }
            pet.fall(float: true) { [weak self] in self?.stopHovering(); next() }        // drifts back down
        }
        run(steps) { [weak self] in self?.sit(for: .random(in: 2...4), done) }
    }

    func hoverBob() -> CAAnimation {
        let bob = CABasicAnimation(keyPath: "position.y")
        bob.fromValue = 0
        bob.toValue = 3 * pet.scale
        bob.duration = 0.9
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return bob
    }

    func stopHovering() { pet.sprite.removeAnimation(forKey: "bob") }

    /// Vanishes in a shimmer and reappears beside your cursor (Alolan Raichu's Psychic).
    private func teleport(to spot: CGPoint, _ done: @escaping () -> Void) {
        energy -= 0.03
        pet.sparks(for: 0.3, rate: 20)
        pet.blink(to: spot) { [weak self] in
            guard let self else { return }
            pet.sparks(for: 0.3, rate: 20)
            pet.face(right: cursor().x > pet.position.x)
            feel(.happy, for: 2)
            sit(for: .random(in: 3...5), done)
        }
    }

    // MARK: Routines

    /// Ambles somewhere nearby, then stops to look around.
    private func stroll(to spot: CGPoint, _ done: @escaping () -> Void) {
        energy -= Double(abs(spot.x - pet.position.x)) / 3000
        run([
            { [weak self] next in self?.go(to: spot, speed: 45, next) },
            { [weak self] next in self?.sit(for: .random(in: 3...6), next) },
        ], then: done)
    }


    /// A new file appeared: trots over, sniffs it, looks pleased, sits on it for a bit.
    private func inspect(_ file: Ground, _ done: @escaping () -> Void) {
        energy -= 0.1
        lastExplored[key(file)] = Date()
        run([
            { [weak self] next in self?.go(to: self!.top(of: file), speed: 90, animSpeed: 1.2, next) },
            { [weak self] next in self?.feel(.surprised, thought: Pixels.file); self?.pet.once(self!.a.nod, times: 2, done: next) },  // sniff sniff
            { [weak self] next in self?.sit(for: .random(in: 4...8), next) },
        ], then: done)
    }

    /// Goes to a file it hasn't visited in a while, takes in the view from the top, and if it still
    /// has the energy, climbs on to a higher one nearby.
    private func explore(_ file: Ground, _ done: @escaping () -> Void) {
        energy -= 0.15
        lastExplored[key(file)] = Date()
        run([
            { [weak self] next in self?.go(to: self!.top(of: file), speed: 70, next) },
            { [weak self] next in self?.sit(for: .random(in: 3...6), next) },
            { [weak self] next in
                guard let self, energy > 0.6, Bool.random(),
                      let higher = pet.openSpots().filter({ !$0.solid && $0.y > file.y + 1
                          && abs(self.top(of: $0).x - self.top(of: file).x) < 150 && self.pet.canReach(self.top(of: $0)) })
                          .min(by: { $0.y < $1.y }) else { next(); return }
                energy -= 0.1
                lastExplored[key(higher)] = Date()
                run([
                    { [weak self] n in self?.go(to: self!.top(of: higher), speed: 70, n) },
                    { [weak self] n in self?.sit(for: .random(in: 3...6), n) },
                ], then: next)
            },
        ], then: done)
    }

    /// Worn out: curls up and sleeps (longer at night), then wakes up refreshed.
    private func nap(_ done: @escaping () -> Void) {
        let length: ClosedRange<Double> = isNight ? 60...180 : 30...90
        run([
            { [weak self] next in self?.pet.stay(self!.a.role("nap") ?? self!.a.sleep, for: .random(in: length), done: next) },
            { [weak self] next in self?.pet.once(self!.a.wake, done: next) },
            { [weak self] next in self?.pet.once(self!.a.stretch, done: next) },              // big morning stretch
        ]) { [weak self] in
            self?.energy = 1; self?.chat(.woke, .happy)
            done()
        }
    }

    /// Tired: sits down for a while to catch its breath.
    private func rest(_ done: @escaping () -> Void) {
        energy = min(1, energy + 0.35)
        sit(for: .random(in: 10...18), done)
    }

    /// Still, sitting upright (the first Idle frame; the rest of that sheet is a pounce).
    func sit(for seconds: TimeInterval, _ done: @escaping () -> Void) {
        pet.hold(a.idle, frame: 0)
        seatedAt = pet.token
        gaze = .ahead
        let since = Date()
        func wait(_ s: TimeInterval) {
            pet.after(s) { [weak self] in
                guard let self else { return }
                // Still watching your cursor: stays a little longer (up to half a minute), curious what you'll do.
                if Date() < watchingUntil, Date().timeIntervalSince(since) < 30 { wait(2); return }
                seatedAt = nil
                done()
            }
        }
        wait(seconds)
    }

    // MARK: Watching the cursor

    private enum Gaze { case ahead, up, down }
    private var gaze = Gaze.ahead
    private var seatedAt: Int?                       // pet.token when it sat down (nil, or stale: busy doing something)
    private var watchingUntil = Date.distantPast
    private var lastNoticed = Date.distantPast
    private var approachedAt: Date?                   // when the cursor came within reach (nil: it's away)
    private var settledIn = false                     // already got comfortable with this visit
    private var lastCursor = (point: CGPoint.zero, time: Date.distantPast)

    /// What it feels about the cursor coming close, shown as a portrait with a thought:
    /// • darting in fast, or a shy one that doesn't trust you yet: startled ("!"), flinches;
    /// • otherwise: curious ("?");
    /// • it stays a few seconds: gets comfortable (happy, or a heart if you're friends).
    /// One reaction per visit, at most every 15 s, so it never chatters.
    private func react(to p: CGPoint) {
        let now = Date()
        let gap = now.timeIntervalSince(lastCursor.time)
        let speed = gap > 0 && gap < 0.2 ? hypot(p.x - lastCursor.point.x, p.y - lastCursor.point.y) / gap : 0
        lastCursor = (p, now)
        guard let since = approachedAt else {
            approachedAt = now
            settledIn = false
            guard now.timeIntervalSince(lastNoticed) > 15 else { return }
            lastNoticed = now
            if speed > 1800 || (nature.shy && friendship < 150) || (caring && friendship < 70) {
                chat(.startled, .worried, thought: Pixels.exclaim, for: 1.8)   // "Eek!"
                if let cringe = a.role("flinch") {                    // its own startled animation, then back to sitting
                    let seat = seatedAt
                    pet.once(cringe) { [weak self] in
                        guard let self, seatedAt == seat else { return }
                        pet.hold(a.idle, frame: 0)
                        gaze = .ahead
                    }
                } else {
                    pet.squash()
                }
            } else {
                chat(.curious, .surprised, thought: Pixels.question, for: 1.8)   // "Hm? What's that? What's that?"
            }
            return
        }
        if !settledIn, now.timeIntervalSince(since) > 6 {
            settledIn = true
            if caring, friendship < 70 { feel(.happy, thought: Pixels.question, for: 2) } else { chat(.recognized, .happy, thought: Pixels.heart, for: 2) }   // "Oh, it's you! ♥"
        }
    }

    /// Cursor moved. Sitting still and it comes within reach: turns to it and looks up or down at it.
    private func watch(_ p: CGPoint) {
        guard Setting.greetings.isOn, seatedAt == pet.token, calm, !isFainted, !eating, !pet.isAirborne, !demoRunning else { return }
        let dx = p.x - pet.position.x, dy = p.y - (pet.position.y + pet.frame.height * 0.6)   // from its eyes
        let near = hypot(dx, dy) < 260
        let want: Gaze = !near ? .ahead : dy > abs(dx) * 0.8 ? .up : -dy > abs(dx) * 0.8 ? .down : .ahead
        guard near || gaze != .ahead else { return }
        if near {
            watchingUntil = Date().addingTimeInterval(2)
            if abs(dx) > 12, (dx > 0) != pet.facingRight { pet.face(right: dx > 0) }
            react(to: p)
        } else {
            approachedAt = nil
        }
        guard want != gaze else { return }
        gaze = want
        pet.hold(want == .up ? a.lookUp : want == .down ? a.lookDown : a.idle, frame: 0)
    }

    /// Hungry: takes out an Oran berry, munches it in three bites, then sits back content.
    /// Likes and dislikes come from its nature, as in the games (Jolly likes sweet, dislikes dry, …).
    private func likes(_ food: Item) -> Bool { food.flavour != nil && food.flavour == nature.likes }
    private func dislikes(_ food: Item) -> Bool { food.flavour != nil && food.flavour == nature.dislikes }

    /// Busy with a berry until then: no petting reaction meanwhile. (A time, not a flag, so being picked
    /// up mid-meal can't leave it stuck.)
    private var eatingUntil = Date.distantPast
    var eating: Bool { Date() < eatingUntil }

    /// One number for hunger and fullness: the belly shown in the stats is 1 − hunger.
    private var isFull: Bool { 1 - hunger > Growth.fullBelly }

    private var hungerNotified = false
    /// Minutes spent hungry while you were around (saved, so it adds up across launches).
    private var hungryMinutes: Double {
        didSet { UserDefaults.standard.set(hungryMinutes, forKey: key("hungryMinutes")) }
    }

    private func eat(_ food: Item, _ done: @escaping () -> Void) {
        hunger = max(0, hunger - Growth.berryFill)
        hungryMinutes = 0
        if hunger < 0.6 {
            hungerNotified = false
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [key("hungry")])
        }
        if !a.canEat, let n = nibble, let lick = a.anim(n.anim) { lickUp(food, with: lick, at: n.at, bite: n.bite, done); return }
        let bites = 3, chew = a.canEat ? a.eat.duration : 0.6        // one chew, in seconds
        let hold = a.canEat ? nil : a.eatHold
        if let hold { pet.hold(hold, frame: 0) }                      // face you, berry in both paws
        let berry = pet.holdFood(food.image, bites: bites, over: chew * Double(2 * bites), at: hold == nil ? 9 : 15)
        eatingUntil = Date().addingTimeInterval(chew * Double(2 * bites) + 3.5)   // the meal and its "yum" face
        run([
            { [weak self] next in
                guard let self else { return }
                if a.canEat { pet.once(a.eat, times: 2 * bites, done: next); return }
                // No eating sprite: lifts the berry to its mouth and nibbles, crumbs falling.
                if hold == nil { pet.hold(a.idle, frame: 0) }
                pet.munch(berry, crumbs: food.image, for: chew * Double(2 * bites), chew: chew)
                pet.after(chew * Double(2 * bites), next)
            },
            { [weak self] next in
                berry.removeFromSuperlayer()
                guard let self else { return }
                if likes(food) {                                       // its favourite!
                    chat(.ateFavourite, .joyous); pet.hearts(); gainEXP(Growth.Bonus.favouriteBerry); befriend(4)
                } else if dislikes(food) {
                    chat(.ateDisliked, .sigh); gainEXP(Growth.Bonus.berry / 2); befriend(1)   // eats it anyway, not thrilled
                } else {
                    chat(isFull ? .full : .ate, .happy); gainEXP(Growth.Bonus.berry); befriend(2)     // yum
                }
                sit(for: .random(in: 4...7), next)
            },
        ], then: done)
    }

    /// Eating with its tongue (Gastly, Haunter): the berry floats where its tongue reaches, and each lick
    /// takes a bite as the tongue lands: the berry wobbles, shrinks, crumbs fly. Three licks and it's gone.
    private func lickUp(_ food: Item, with lick: Anim, at reach: CGPoint, bite: Double, _ done: @escaping () -> Void) {
        let bites = 3, s = pet.scale
        let dir: CGFloat = pet.facingRight ? 1 : -1
        let berry = pet.holdFood(food.image, bites: bites, over: lick.duration * Double(bites), at: reach.y)
        berry.removeAnimation(forKey: "bites")                       // the bites land with the tongue instead
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        berry.position.x = dir * reach.x * s
        CATransaction.commit()
        let bob = CABasicAnimation(keyPath: "position.y")              // hovers, waiting to be licked
        bob.byValue = 2 * s
        bob.duration = 0.4
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.isAdditive = true
        berry.add(bob, forKey: "bob")
        eatingUntil = Date().addingTimeInterval(lick.duration * Double(bites) + 3.5)
        let crumb = food.image.cropping(to: CGRect(x: food.image.width / 2 - 1, y: food.image.height / 2 - 1, width: 2, height: 2)) ?? food.image
        pet.play(lick, repeats: Float(bites))
        for k in 1...bites {
            pet.after(lick.duration * Double(k - 1) + bite) { [weak self] in
                guard let self else { return }
                let left = 1 - CGFloat(k) / CGFloat(bites)
                let squish = CAKeyframeAnimation(keyPath: "transform.scale")
                squish.values = [left + 1 / CGFloat(bites), (left + 0.1) * 1.25, left]
                squish.duration = 0.18
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                berry.transform = CATransform3DMakeScale(left, left, 1)
                berry.position.x -= dir * s                            // the tongue pulls what's left a little closer
                CATransaction.commit()
                berry.add(squish, forKey: "squish")
                let e = pet.emit(crumb, height: reach.y * s, rate: 30, for: 0.15, velocity: 40, spread: .pi / 2, lifetime: 0.6, gravity: -160)
                e.emitterPosition.x = berry.position.x
                e.emitterCells?.first?.scale = s * 0.8
            }
        }
        pet.after(lick.duration * Double(bites)) { [weak self] in
            berry.removeFromSuperlayer()
            guard let self else { return }
            if likes(food) {                                           // its favourite!
                chat(.ateFavourite, .joyous); pet.hearts(); gainEXP(Growth.Bonus.favouriteBerry); befriend(4)
            } else if dislikes(food) {
                chat(.ateDisliked, .sigh); gainEXP(Growth.Bonus.berry / 2); befriend(1)
            } else {
                chat(isFull ? .full : .ate, .happy); gainEXP(Growth.Bonus.berry); befriend(2)
            }
            pet.once(a.front("Lick") ?? lick) { [weak self] in self?.sit(for: .random(in: 4...7), done) }   // licks its lips at you
        }
    }

    /// Hungry: it never helps itself. It comes over to you, hops up and down and asks for a berry
    /// (hungry face, berry thought), then waits a moment for you to drag one over from the dial.
    private func askForBerry(_ cursorSpot: CGPoint?, _ done: @escaping () -> Void) {
        if !hungerNotified {                                  // once per hungry spell, not every time it asks
            hungerNotified = true
            notify("hungry", "\(name) is hungry", "Drag a berry onto it from the menu bar dial.")
        }
        let ask: Step = { [weak self] next in
            guard let self else { return }
            pet.face(right: cursor().x > pet.position.x)
            chat(.askBerry, .worried, thought: Pixels.oranBerry, otherwise: "\(name) is hungry!", for: 3.5)
            pet.once(a.hop, times: 2) { [weak self] in self?.sit(for: .random(in: 5...8), next) }
        }
        guard let spot = cursorSpot else { run([ask], then: done); return }
        go(to: spot, speed: 70) { run([ask], then: done) }
    }

    /// While plugged in, now and then: a quick ~1.3 s charge-up with a few sparks.
    private func chargeUp(_ done: @escaping () -> Void) {
        run([
            { [weak self] next in
                guard let self else { return }
                startChargeSparks(rate: 5)
                pet.stay(a.charge, for: 1.0, done: next)
            },
            { [weak self] next in
                guard let self else { return }
                stopChargeSparks()
                pet.once(a.shock, done: next)
            },
        ], then: done)
    }

    /// Low battery: slow, heavy steps along the floor.
    private func trudge(_ done: @escaping () -> Void) {
        guard let spot = strollTarget(pet.openSpots(), within: 120) else { rest(done); return }
        go(to: spot, speed: 25, animSpeed: 0.5, done)
    }

    /// Battery almost empty: collapses and stays down until the charger is plugged in.
    private func faint() {
        guard !isFainted else { return }
        isFainted = true
        stop { [weak self] in
            guard let self else { return }
            feel(.pain)
            pet.once(a.faint) {}
        }
    }

    /// Its playful animations (SpriteCollab names), each switchable in the Settings gallery.
    var playful: [String] { ["DeepBreath", "Rotate", "Tumble", "Double"].filter { a.anim($0) != nil } }
    /// The playful animations it may pick right now. Species can tie them to learned moves.
    var unlockedMoves: [String] { playful.filter(Setting.moveAllowed) }

    /// Happy and full of energy: one of its playful moves, then a short sit.
    private func play(_ done: @escaping () -> Void) {
        energy -= 0.05
        guard let name = unlockedMoves.randomElement() else { sit(for: .random(in: 3...6), done); return }
        gainEXP(Growth.Bonus.play)
        run([move(name), { [weak self] next in self?.sit(for: .random(in: 2...4), next) }], then: done)
    }

    /// Music's on: one of its playful moves (not the stretch), or it bops its head.
    private func dance(_ done: @escaping () -> Void) {
        let moves = unlockedMoves.filter { $0 != "DeepBreath" }
        guard let name = moves.randomElement() else {
            run([{ [weak self] next in self?.pet.once(self!.a.nod, times: 3, done: next) },   // just bops its head
                 { [weak self] next in self?.sit(for: .random(in: 2...4), next) }], then: done)
            return
        }
        run([move(name), { [weak self] next in self?.sit(for: .random(in: 1...3), next) }], then: done)
    }

    /// One named move, as a step (also used by the Settings gallery's Play buttons).
    func move(_ name: String) -> Step {
        switch name {
        case "Tumble":                                  // a somersault: rolls a short way along the surface it's on
            return { [weak self] next in
                guard let self else { return }
                let here = pet.position, dir: CGFloat = pet.facingRight ? 1 : -1
                let span = pet.surface(under: here)?.span ?? here.x...here.x
                let to = CGPoint(x: min(max(here.x + dir * 16 * pet.scale, span.lowerBound + 10), span.upperBound - 10), y: here.y)
                pet.play(a.tumble, repeats: 1)
                pet.move(to: to, duration: a.tumble.duration, done: next)
            }
        case "Rotate", "Double": return { [weak self] next in self?.pet.once(self!.a.anim(name)!, times: 2, done: next) }
        default:
            let anim = a.anim(name) ?? a.stretch
            return { [weak self] next in self?.pet.once(anim, done: next) }
        }
    }

    /// From the Settings gallery: do this animation now, then carry on.
    func perform(_ name: String) {
        guard isOut, !ballBusy, !held else { return }
        dozing = false
        stop { [weak self] in
            guard let self else { return }
            run([move(name), { [weak self] next in self?.sit(for: 1.5, next) }]) { [weak self] in self?.think() }
        }
    }

    var animations: [(name: String, anim: Anim)] { a.all }
    func directions(_ name: String) -> [Anim] { a.directions(name) }

    // MARK: Events

    /// Stop the current routine. If that leaves it in mid-air (halfway through a jump onto the Dock),
    /// it falls to the ground first, so it can never get stuck floating.
    func stop(then next: @escaping () -> Void) {
        pet.interrupt()
        stopChargeSparks()
        if pet.isAirborne { stopHovering(); pet.fall(float: floats, done: next) } else { next() }
    }

    func powerChanged() {
        let plugged = power.charging && !wasCharging
        let unplugged = !power.charging && wasCharging
        wasCharging = power.charging
        if plugged, abilityOnCharge { announceAbility() }
        let moodChanged = mood != lastMood
        lastMood = mood
        guard !held, isOut, !ballBusy, !focusQuiet else { return }     // in its ball, or a Focus is on: nothing to show

        if plugged {
            chargerPlugged()
        } else if unplugged {
            stop { [weak self] in
                guard let self else { return }
                pet.once(a.nod) { [weak self] in self?.think() }
            }
        } else if moodChanged {
            if mood == .fainted { faint() }
            else if isFainted { recover() }
            else { stop { [weak self] in self?.think() } }   // switch to the new mood's routines right away
        }
    }

    private func recover() {
        isFainted = false
        stop { [weak self] in
            guard let self else { return }
            pet.once(a.wake) { [weak self] in self?.think() }
        }
    }

    /// Cursor came close: turns to you and a few hearts float up. Then it calmly carries on.
    private func cursorNearby(_ point: CGPoint) {
        guard Setting.greetings.isOn, !held, isOut, !ballBusy, !dozing, !isFainted, !pet.isAirborne, !demoRunning,
              !eating,                                   // you're feeding it: it's focused on the berry
              Date().timeIntervalSince(lastCuddle) > 8 else { return }
        lastCuddle = Date()
        pet.interrupt()
        stopChargeSparks()
        let shyNow = nature.shy && friendship < 200 && Bool.random()
        // Petting makes it fonder of you; if it's been a while, it's especially grateful (never sad about it).
        if !shyNow { chat(mood == .tired ? .pettedSleepy : .petted, neglected || friendship >= 200 ? Face.joyous : .happy) }
        if Date().timeIntervalSince(lastPetted) > Growth.pettingMinutes * 60 {   // counts once per 15 min, so no hover-spamming
            befriend(pettingFriendship)
            gainEXP(Growth.Bonus.pet)
        }
        lastPetted = Date()
        if shyNow {                                                 // Timid / Bashful: backs away shyly until it trusts you
            feel(.worried, for: 2)
            pet.face(right: point.x < pet.position.x)
            let away = pet.position.x + (point.x < pet.position.x ? 50 : -50)
            go(to: CGPoint(x: away, y: pet.position.y), speed: 70) { [weak self] in self?.sit(for: 2) { [weak self] in self?.think() } }
            return
        }
        pet.face(right: point.x > pet.position.x)
        pet.hearts()
        petted()
        if pendingEvolution != nil { feel(.inspired, caption: "Ready to evolve! Right-click me to choose.", for: 3) }
        let tired = mood == .tired
        pet.stay(tired ? a.nod : a.pose, for: tired ? 1.0 : 1.3) { [weak self] in
            guard let self else { return }
            sit(for: 2) { [weak self] in self?.think() }
        }
    }

    private func pickedUp() {
        held = true
        pet.interrupt()
        stopChargeSparks()
        stopHovering()
        pet.play(a.hurt)                 // startled, legs dangling
        pet.resetSwings()
        drops.removeAll { Date().timeIntervalSince($0) > 120 }
        let face: Face = caring && drops.count >= 2 ? .worried : friendship >= 160 ? .joyous : .surprised
        chat(face == .worried ? .pickedUpWorried : .pickedUp, face)         // loves being held … or worried you'll drop it again
    }

    /// Let go: falls, lands on its paws (or crashes and gets back up from high drops).
    /// Set down near the ground, it's "placed": no fuss, not counted as a drop. A floating Pokémon
    /// (Alolan Raichu's psychic power) never falls at all: it drifts down.
    private func dropped() {
        held = false
        dizzyNext = pet.swings >= 6                      // swung back and forth a lot: the world's spinning
        let height = pet.position.y - (pet.surface(under: pet.position)?.y ?? 0)
        if floats || height < 50 {
            if floats { pet.hold(a.idle, frame: 0) }
            pet.fall(float: floats) { [weak self] in
                guard let self else { return }
                lastCuddle = Date().addingTimeInterval(-6)
                if dizzyNext { dizzySpell(); return }
                sit(for: 1.2) { [weak self] in self?.think() }
            }
            return
        }
        pet.fall { [weak self] in self?.landed(from: height) }
    }

    /// Set down after being swung about: dizzy portrait, it sways with stars round its head, shakes it
    /// off, then carries on. Not upset, just woozy.
    private var dizzyNext = false
    private func dizzySpell() {
        dizzyNext = false
        lastCuddle = Date()                              // no hover greeting while it's woozy
        pet.hold(a.idle, frame: 0)
        chat(.dizzy, .dizzy, otherwise: "\(name) is dizzy…", for: 3)
        pet.dizzy(for: 2.7)
        run([
            { [weak self] next in self?.pet.after(2.8, next) },
            { [weak self] next in                                                            // shakes it off (or wobbles)
                guard let self else { return }
                if let wobble = a.role("wobble") { pet.once(wobble, times: 3, done: next) } else { pet.once(a.nod, times: 2, done: next) }
            },
            { [weak self] next in self?.sit(for: 1, next) },
        ]) { [weak self] in self?.think() }
    }

    private func landed(from height: CGFloat) {
        lastCuddle = Date().addingTimeInterval(-6)      // no hover greeting for 2 s: let the landing play
        drops.append(Date())
        drops.removeAll { Date().timeIntervalSince($0) > 120 }
        if mood == .fainted {
            isFainted = false
            faint()
        } else if height > 350 || (caring && drops.count >= 3) {
            // Dropped hard, or once too often: it hurts, it cries, and it's a bit upset with you.
            befriend(-10)
            run([
                { [weak self] next in self?.pet.once(height > 350 ? self!.a.crash : self!.a.pain, done: next) },
                { [weak self] next in self?.chat(.droppedHard, self!.caring ? .crying : .dizzy, for: 3.5); self?.sit(for: 4, next) },
            ]) { [weak self] in self?.think() }
        } else if dizzyNext {
            pet.squash()
            dizzySpell()
        } else {
            if drops.count == 2 { feel(.dizzy) }
            // Lands on all fours: squashes on impact, stays crouched a moment, then stands up.
            pet.hold(a.charge, frame: 0)
            pet.squash()
            run([
                { [weak self] next in self?.pet.after(0.6, next) },
                { [weak self] next in self?.sit(for: 1.2, next) },
            ]) { [weak self] in self?.think() }
        }
    }

    // MARK: Poké Ball

    /// From the party dial: call it back into its ball, or throw the ball and send it out, thrown from /
    /// back to the menu bar icon.
    func toggleBall() {
        if let fx { toggleBall(from: ballStart(), fx: fx) }
    }

    /// `start` is where the ball is thrown from (the menu bar icon), in stage coordinates.
    func toggleBall(from start: CGPoint, fx: BallFX) {
        guard !held, !ballBusy else { return }
        if stage == .egg { hatch(from: start, fx: fx); return }
        ballBusy = true
        demoRunning = false
        pet.interactive = false
        stopChargeSparks()
        if isOut {
            stop { [weak self] in                       // lands first if it was mid-jump
                guard let self else { return }
                pet.hold(a.idle, frame: 0)
                fx.recall(pet) { [weak self] in
                    self?.isOut = false
                    self?.ballBusy = false
                }
            }
        } else {
            pet.interrupt()
            let spot = summonSpot()
            let side: CGFloat = spot.x > pet.walkArea.lowerBound + 40 * pet.scale ? -1 : 1   // ball lands beside it
            pet.face(right: side < 0)                                                        // faces away from the ball
            pet.hold(a.idle, frame: 0)
            fx.release(pet, from: start, ground: CGPoint(x: spot.x + side * 22 * pet.scale, y: spot.y), spot: spot) { [weak self] in
                guard let self else { return }
                isOut = true
                ballBusy = false
                pet.interactive = true
                isFainted = false
                lastMood = mood
                comeOutRoutine { [weak self] in self?.think() }
            }
        }
    }

    /// Just out of its Poké Ball: a big stretch, a half-second pause, then a high jump straight up.
    private func comeOutRoutine(_ done: @escaping () -> Void) {
        run([
            { [weak self] next in self?.pet.once(self!.a.stretch, done: next) },
            { [weak self] next in self?.pet.after(0.5, next) },
            { [weak self] next in
                guard let self else { return }
                let here = pet.position, top = CGPoint(x: here.x, y: here.y + 28 * pet.scale)
                let path = CGMutablePath()
                path.move(to: here)
                path.addQuadCurve(to: here, control: CGPoint(x: here.x, y: here.y + 2 * (top.y - here.y)))
                pet.play(a.hop, repeats: 1)
                pet.move(to: here, duration: 0.6, path: path) { [weak self] in
                    self?.pet.squash()
                    self?.feel(.joyous, for: 2)
                    next()
                }
            },
        ], then: done)
    }

    /// The Egg drops from the menu bar to the middle of the desktop, cracks, and it hatches.
    private func hatch(from start: CGPoint, fx: BallFX) {
        ballBusy = true
        pet.interactive = false
        stage = firstStage
        exp = 0
        friendship = Growth.hatchFriendship
        energy = 0.8
        hunger = 0.3
        gender = Double.random(in: 0..<1) < Growth.femaleChance ? "♀" : "♂"
        nature = Nature.all.randomElement()!
        shiny = Int.random(in: 0..<Growth.shinyOdds) == 0 || UserDefaults.standard.bool(forKey: "PokeShiny")   // 1 in 4,096
        form = nil
        pokerusUntil = nil
        a = Sheets(species, roles: animRoles)
        save()
        refreshMoves()
        pet.face(right: true)
        pet.hold(a.idle, frame: 0)
        let mid = (pet.walkArea.lowerBound + pet.walkArea.upperBound) / 2       // right in the middle of the screen
        fx.hatch(pet, from: start, spot: CGPoint(x: mid, y: pet.floorY(at: mid))) { [weak self] in
            guard let self else { return }
            isOut = true
            ballBusy = false
            pet.interactive = true
            lastThought = Date()
            lastPetted = Date()
            lastMood = mood
            pet.hearts()
            if shiny { pet.stars() }                               // the shiny sparkle, as in the games
            feel(.joyous, caption: shiny ? "A shiny \(name) \(gender) hatched! ✨" : "\(name) \(gender) hatched from the Egg!", for: 3.5)
            pet.after(3.7) { [weak self] in
                guard let self else { return }
                feel(.inspired, caption: "Its ability is \(ability.name)!", for: 3.5)
                pet.sparks(for: 0.5, rate: 14)
                pet.after(3.7) { [weak self] in
                    guard let self else { return }
                    feel(.happy, caption: "It has a \(nature.name) nature.", for: 3.5)
                    pet.after(3.7) { [weak self] in self?.think() }
                }
            }
        }
    }

    /// Resting in its ball from the start (another Pokémon is the one out). No animation.
    func keepInBall() {
        isOut = false
        pet.node.isHidden = true
    }

    /// Start over: back to an Egg in the dial (from Settings).
    func restart() {
        guard !ballBusy, !held else { return }
        pet.interrupt()
        stopChargeSparks()
        dozing = false
        pendingEvolution = nil
        stage = .egg
        form = nil
        shiny = false
        pokerusUntil = nil
        a = Sheets(species, roles: animRoles)
        exp = 0
        friendship = Growth.hatchFriendship
        save()
        isOut = false
        pet.node.isHidden = true
    }

    /// Where to send it out: the visible stretch of floor (or Dock) nearest the middle of the screen.
    func summonSpot() -> CGPoint {
        let mid = (pet.walkArea.lowerBound + pet.walkArea.upperBound) / 2
        let floors = pet.openSpots().filter { $0.solid && $0.width > 120 }
        guard let spot = floors.min(by: { distance(mid, $0.span) < distance(mid, $1.span) }) else {
            return CGPoint(x: mid, y: pet.floorY(at: mid))           // nothing visible: middle of the floor
        }
        let x = min(max(mid, spot.span.lowerBound + 60), spot.span.upperBound - 60)
        return CGPoint(x: x, y: spot.y)
    }

    private func distance(_ x: CGFloat, _ span: ClosedRange<CGFloat>) -> CGFloat {
        span.contains(x) ? 0 : min(abs(x - span.lowerBound), abs(x - span.upperBound))
    }

    /// Caught Pokérus: EXP doubles for 1–4 days (in the games it doubles effort values; PokePets has none).
    private func catchPokerus() {
        pokerusUntil = Date().addingTimeInterval(Double(Int.random(in: Growth.pokerusDays)) * 86_400)
        save()
        feel(.surprised, caption: "\(name) caught Pokérus! EXP gain is doubled for a while.", for: 4)
    }

    // MARK: The world around it

    var calm: Bool { isOut && !ballBusy && !held && !dozing }

    // MARK: Little lifestyle moments

    /// First time it sees you each day: "Good morning!" (or afternoon / evening).
    private func greetTheDay() {
        let last = UserDefaults.standard.object(forKey: key("greeted")) as? Date ?? .distantPast
        let hour = Calendar.current.component(.hour, from: Date())
        guard last < Calendar.current.startOfDay(for: Date()), hour >= 5 else { return }
        UserDefaults.standard.set(Date(), forKey: key("greeted"))
        feel(.joyous, caption: hour < 12 ? "Good morning!" : hour < 18 ? "Good afternoon!" : "Good evening!", for: 3)
        pet.hearts()
    }

    /// You switched apps: if it's sitting, it glances up at the screen for a moment (at most every 20 s).
    private var lastGlance = Date.distantPast
    private func glance() {
        guard seatedAt == pet.token, gaze == .ahead, calm, !isFainted, Date().timeIntervalSince(lastGlance) > 20 else { return }
        lastGlance = Date()
        pet.hold(a.lookUp, frame: 0)
        pet.after(1.2) { [weak self] in
            guard let self, seatedAt == pet.token, gaze == .ahead else { return }
            pet.hold(a.idle, frame: 0)
        }
    }

    // MARK: Focus

    /// A Focus is on (Do Not Disturb, Work, Fitness, …): it falls asleep and stays quiet until it ends.
    /// macOS only lets entitled apps read Focus, so a Shortcuts automation tells us: `pokepets://focus`
    /// when one turns on, `pokepets://unfocus` when it turns off (see Settings › Focus).
    private var focusQuiet: Bool {
        didSet { UserDefaults.standard.set(focusQuiet, forKey: "focus.on") }
    }
    var isQuiet: Bool { focusQuiet }

    private func quietDown() {
        guard isOut, !ballBusy, !held else { return }
        dozing = true
        stop { [weak self] in
            guard let self else { return }
            pet.play(a.sleep)
        }
    }

    /// You left the Mac: it curls up and naps until you're back.
    func userLeft() {
        guard Setting.awayNaps.isOn, calm, !isFainted else { return }
        dozing = true
        stop { [weak self] in
            guard let self else { return }
            pet.play(a.sleep)
        }
    }

    /// You're back: it wakes, stretches, and is glad to see you.
    func userReturned() {
        guard dozing, !focusQuiet else { return }
        dozing = false
        pet.interrupt()
        run([
            { [weak self] next in self?.pet.once(self!.a.wake, done: next) },
            { [weak self] next in self?.pet.once(self!.a.stretch, done: next) },
            { [weak self] next in
                guard let self else { return }
                chat(.userBack, .joyous)
                pet.hearts()
                befriend(1)
                sit(for: 2, next)
            },
        ]) { [weak self] in self?.think() }
    }

    /// You've been at it a long time: it stretches, sighs, and suggests a break. (One notification for
    /// the whole party: the same id replaces it.)
    func suggestBreak() {
        guard calm else { return }
        let breathe = a.role("breathe")
        let center = UNUserNotificationCenter.current(), body = breathe == nil
            ? "\(name) is stretching. Maybe you should too."
            : "\(name) wants you to take a few deep breaths with it."
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time for a break?"
            content.body = body
            center.add(UNNotificationRequest(identifier: "break", content: content, trigger: nil))
        }
        stop { [weak self] in
            guard let self else { return }
            guard let breathe else {
                feel(.sigh, for: 4)
                run([
                    { [weak self] next in self?.pet.once(self!.a.stretch, times: 2, done: next) },
                    { [weak self] next in self?.sit(for: 3, next) },
                ]) { [weak self] in self?.think() }
                return
            }
            // Its DeepBreath, facing you: three slow breaths, and it tells you when to breathe in and out.
            feel(.happy, caption: "Take a deep breath with me…", for: 3)
            var steps: [Step] = [{ [weak self] next in self?.pet.after(2, next) }]
            for _ in 0..<3 {
                steps.append { [weak self] next in
                    guard let self else { return }
                    feel(.happy, caption: "Breathe in…", for: breathe.duration * 0.9)
                    pet.after(breathe.duration * 0.45) { [weak self] in self?.feel(.happy, caption: "…and out.", for: breathe.duration * 0.9) }
                    pet.once(breathe, speed: 0.5, done: next)
                }
            }
            steps.append { [weak self] next in self?.feel(.joyous, caption: "Better? 👻", for: 2.5); self?.sit(for: 3, next) }
            run(steps) { [weak self] in self?.think() }
        }
    }

    /// Camera on: it hides in its Poké Ball for the call; camera off: back out it comes.
    func cameraChanged(_ on: Bool) {
        guard Setting.hideOnCamera.isOn, !held, !ballBusy else { return }
        if on, isOut {
            hiddenForCall = true
            dozing = false
            toggleBall()
        } else if !on, hiddenForCall, !isOut {
            hiddenForCall = false
            toggleBall()
        }
    }

    /// The Mac got hotter or cooled down: sluggish when hot, faints when overheating.
    func heatChanged() {
        guard Setting.heat.isOn else { return }
        if calm, senses.thermal == .serious { chat(.hot, .sigh, for: 3) }
        powerChanged()                                  // same mood switch as battery changes
    }

    /// Internet lost: worried; back: relieved.
    func internetChanged(_ online: Bool) {
        guard Setting.wifi.isOn, calm, !isFainted else { return }
        chat(online ? .online : .offline, online ? .happy : .worried, for: 3)
        if !online { stop { [weak self] in self?.sit(for: 3) { [weak self] in self?.think() } } }
    }

    // MARK: Things you give it

    /// You're bringing it something from the dial: it stops, turns to you and waits, so it's easy to feed.
    private func itemNear(_ point: CGPoint) {
        guard calm, !isFainted, !eating, !pet.isAirborne else { return }
        watchingUntil = Date().addingTimeInterval(2)      // keeps it sitting while the berry is close
        if seatedAt == pet.token { pet.face(right: point.x > pet.position.x); return }
        stop { [weak self] in
            guard let self else { return }
            pet.face(right: point.x > pet.position.x)
            chat(.itemNear, .happy, thought: Pixels.oranBerry, for: 1.5)
            sit(for: 2) { [weak self] in self?.think() }
        }
    }

    /// A berry (eats it) or an evolution item, dragged from the dial.
    func received(_ item: Item) {
        guard calm, !isFainted else { return }
        if !item.isBerry {
            if !use(item) { feel(.surprised) }
        } else if isFull {
            chat(.full, .sigh, otherwise: "\(name) is full.")       // too full for another, however tasty
        } else {
            eatingUntil = Date().addingTimeInterval(2)      // from the moment the berry lands (eat() extends it)
            stop { [weak self] in self?.eat(item) { [weak self] in self?.lastCuddle = Date(); self?.think() } }
        }
    }

    /// Evolution, like the games: it glows white and flickers between its old and new shape, faster and
    /// faster, then bursts into its new form (sprites and portraits swap over; moves are kept).
    private func evolve(to next: Stage, form newForm: String?) {
        guard calm, !isFainted else { pendingEvolution = (next, newForm); return }   // busy: still yours to start later
        ballBusy = true
        pet.interactive = false
        let before = name, knewBefore = known
        stop { [weak self] in
            guard let self else { return }
            let new = Sheets(sheetName(next, form: newForm, shiny: shiny), roles: animRoles), old = a
            pet.hold(old.idle, frame: 0)
            var glow = pet.silhouette(.white)
            var t = 0.8
            for (i, gap) in [0.5, 0.42, 0.36, 0.3, 0.24, 0.19, 0.15, 0.12, 0.09, 0.07, 0.06, 0.05].enumerated() {
                t += gap
                pet.after(t) { [weak self] in
                    guard let self else { return }
                    glow.removeFromSuperlayer()
                    pet.hold(i % 2 == 0 ? new.idle : old.idle, frame: 0)
                    glow = pet.silhouette(.white)
                }
            }
            pet.after(t + 0.6) { [weak self] in
                guard let self else { return }
                glow.removeFromSuperlayer()
                stage = next
                form = newForm
                a = new
                save()
                refreshMoves()
                pet.hold(a.idle, frame: 0)
                let shine = pet.silhouette(.white)
                shine.opacity = 0                       // fades out to reveal the new form (implicit animation)
                pet.sparks(for: 0.8, rate: 30)
                pet.hearts()
                feel(.joyous, caption: "\(before) evolved into \(name)!", for: 3.5)
                // Announce its evolution move first, like the games; otherwise a new move with a desktop effect.
                let new = learnset.filter { self.known.contains($0.name) && !knewBefore.contains($0.name) }
                let learned = new.first { self.signatureMoves.contains($0.name) } ?? new.first { $0.effect != nil }
                pet.after(3.8) { [weak self] in
                    guard let self else { return }
                    shine.removeFromSuperlayer()
                    if let learned { feel(.inspired, caption: "\(name) learned \(learned.name)!", for: 3.5) }
                    ballBusy = false
                    pet.interactive = true
                    think()
                }
            }
        }
    }

    // MARK: Deleting files

    /// ⌥⌘⌫ in Finder (or ⌥-drop, or the Downloads guard): its delete move sends the files to the Trash
    /// with a show. If it can't right now (in its ball, fainted, busy), they still go, just without the show.
    func strike(_ urls: [URL], at spots: [URL: CGPoint] = [:]) {
        if Setting.thunderbolt.isOn, calm, !isFainted, fx != nil { attack(urls, at: spots); return }
        for url in urls { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
    }

    /// Files ⌥-dropped onto it.
    private func zap(_ urls: [URL]) {
        guard Setting.thunderbolt.isOn, calm, !isFainted, fx != nil else { return }
        attack(urls, at: [:])
    }

    /// After a delete: thrilled with itself, it trots happily out and back with a little hop.
    func victoryLap(_ done: @escaping () -> Void) {
        chat(.deleted, .joyous, thought: Pixels.bolt, for: 2.5)
        pet.sparks(for: 0.4, rate: 16)
        let here = pet.position, dir: CGFloat = pet.facingRight ? 1 : -1
        let span = pet.surface(under: here)?.span ?? here.x...here.x
        let out = CGPoint(x: min(max(here.x + dir * 90, span.lowerBound + 20), span.upperBound - 20), y: here.y)
        run([{ [weak self] n in self?.pet.once(self!.a.pose, done: n) },
             { [weak self] n in self?.go(to: out, speed: 140, animSpeed: 1.6, n) },
             { [weak self] n in self?.go(to: here, speed: 140, animSpeed: 1.6, n) },
             { [weak self] n in self?.pet.once(self!.a.pose, done: n) }], then: done)
    }

    // MARK: Developer hooks

    /// `pokepets://<action>` (see bin/pokepets): celebrate · fail · done · hello.
    func hook(_ action: String) {
        switch action {
        case "focus": focusQuiet = true; quietDown(); return
        case "unfocus": focusQuiet = false; userReturned(); return
        default: break
        }
        guard isOut, !ballBusy, !held, !focusQuiet else { return }   // a Focus is on: don't disturb
        dozing = false
        switch action {
        case "celebrate", "pass", "success":           // build passed / tests green
            celebrateHook()
        case "fail", "failed", "error":                // build failed: faints for a bit
            guard !isFainted else { return }
            isFainted = true
            stop { [weak self] in
                guard let self else { return }
                chat(.failed, .pain)
                pet.once(a.faint) {}
                pet.after(8) { [weak self] in
                    guard let self, isFainted, mood != .fainted else { return }
                    recover()
                }
            }
        case "done", "finished":                        // an AI agent / long job finished
            stop { [weak self] in
                guard let self else { return }
                chat(.done, .joyous)
                pet.hearts()
                run([{ [weak self] next in self?.pet.once(self!.a.pose, done: next) },
                     { [weak self] next in self?.sit(for: 2, next) }]) { [weak self] in self?.think() }
            }
        default:                                        // hello / anything else: a friendly wave
            chat(.hello, .happy)
            pet.hearts()
        }
    }

    // MARK: Evolution is your choice

    private(set) var pendingEvolution: (to: Stage, form: String?)?

    /// What it would evolve into, for menus and notifications.
    func evolutionName(_ to: Stage, form: String?) -> String { to.name }

    /// Ready to evolve: it never just does it. It tells you (a notification, a caption, a hint when you
    /// hover) and evolves only when you pick Evolve, in the notification or its right-click menu.
    /// `askNow`: you're right here (you just gave it an item), so the choice pops up at once.
    func offerEvolution(to next: Stage, form: String? = nil, askNow: Bool = false) {
        guard pendingEvolution == nil || askNow else { return }
        pendingEvolution = (next, form)
        if askNow { pet.showMenu?(); return }
        feel(.inspired, caption: "\(name) is ready to evolve! Right-click it to choose.", for: 4)
        notify("evolve", "\(name) is ready to evolve!", "Evolve into \(evolutionName(next, form: form))?",
               category: "evolve", sound: true)
    }

    /// Evolve (or not) from the notification's buttons or the right-click menu. "Not now": it asks again
    /// later (the species decides when).
    func answerEvolution(_ yes: Bool) {
        guard let choice = pendingEvolution else { return }
        pendingEvolution = nil
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [key("evolve")])
        if yes { evolve(to: choice.to, form: choice.form) } else { feel(.happy, caption: "\(name) stays as it is, for now.", for: 3) }
    }

    /// Right-click menu: only while there's something to decide.
    private func menu() -> NSMenu? {
        guard let choice = pendingEvolution else { return nil }
        let menu = NSMenu()
        menu.addItem(MenuAction("Evolve into \(evolutionName(choice.to, form: choice.form))") { [weak self] in self?.answerEvolution(true) })
        menu.addItem(MenuAction("Not Now") { [weak self] in self?.answerEvolution(false) })
        return menu
    }

    /// A macOS notification, if they're on in Settings. The same id replaces the one before. Ids carry
    /// the store prefix (so two Pokémon never replace each other's), and `userInfo["pet"]` says whose it is.
    func notify(_ id: String, _ title: String, _ body: String, category: String? = nil, sound: Bool = false,
                info: [String: Any] = [:]) {
        guard Setting.notifications.isOn || category == "zap" else { return }   // the Downloads guard has its own switch
        let center = UNUserNotificationCenter.current()
        let id = key(id), store = store
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else { NSLog("PokePets: notifications not allowed (%@)", String(describing: error)); return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if sound { content.sound = .default }
            if let category { content.categoryIdentifier = category }
            content.userInfo = info.merging(["pet": store]) { a, _ in a }
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
                if let error { NSLog("PokePets: notification failed (%@)", String(describing: error)) }
            }
        }
    }

    /// Its ability just switched on: say so in a notification. Any future trigger for an ability should
    /// call this too.
    func announceAbility() {
        guard isOut, stage != .egg else { return }      // in its ball (or still an Egg), the ability isn't working
        notify("ability", "\(name)'s \(ability.name) activated!", ability.effect)
    }

    /// Downloads guard found something: a curious look at a file, and a notification offering to delete
    /// it. Nothing goes to the Trash unless you pick it.
    func offerZap(_ files: [URL], title: String, why: String) {
        if calm, !isFainted { feel(.surprised, thought: Pixels.file, for: 2.5) }
        notify("zap-" + (files.count == 1 ? files[0].path : "batch-\(Date().timeIntervalSince1970)"), title, why,
               category: "zap", info: ["paths": files.map(\.path)])
    }

    // MARK: Effects

    func image(_ face: Face) -> CGImage {
        NSImage(named: "\(species)-face-\(face.rawValue)")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    }

    /// Show a portrait (if emotion portraits are on).
    func feel(_ face: Face, caption: String? = nil, speaker: String? = nil, thought: CGImage? = nil, for seconds: TimeInterval = 2.5) {
        if Setting.faces.isOn || caption != nil {
            pet.showFace(image(face), caption: caption, speaker: speaker, thought: thought, for: seconds)
        }
    }

    func startChargeSparks(rate: Float) {
        stopChargeSparks()
        chargeSparks = pet.sparks(for: nil, rate: rate)
    }

    func stopChargeSparks() {
        if let e = chargeSparks { pet.stopEmitting(e) }
        chargeSparks = nil
    }
}
