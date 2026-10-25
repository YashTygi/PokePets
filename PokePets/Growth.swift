import Foundation

/// Every stage of every line in the party, with the real games' numbers: Scarlet/Violet level-up moves,
/// EXP curves, friendship on a 0–255 scale, and the real evolution rules (from PokePets' PokeAPI data).
enum Stage: String, CaseIterable {
    case egg, pichu, pikachu, raichu, gastly, haunter, gengar

    var name: String { self == .egg ? "Egg" : rawValue.capitalized }
    /// Its evolution line, Egg first (an Egg on its own counts as the Pichu line; the species knows better).
    var line: [Stage] { [.gastly, .haunter, .gengar].contains(self) ? [.egg, .gastly, .haunter, .gengar] : [.egg, .pichu, .pikachu, .raichu] }
    /// Real growth groups: the Pichu line is Medium Fast, the Gastly line Medium Slow.
    var growthRate: GrowthRate { line.contains(.gengar) ? .mediumSlow : .mediumFast }
    var next: Stage? { line.firstIndex(of: self).flatMap { line.indices.contains($0 + 1) ? line[$0 + 1] : nil } }
}

/// The six real growth-rate groups. A species' group sets how much EXP each level takes; since EXP
/// comes in at the same pace for everyone, Fast groups level up sooner and Slow ones later.
enum GrowthRate: String, CaseIterable {
    case erratic, fast, mediumFast, mediumSlow, slow, fluctuating

    var name: String {
        switch self {
        case .erratic: "Erratic"
        case .fast: "Fast"
        case .mediumFast: "Medium Fast"
        case .mediumSlow: "Medium Slow"
        case .slow: "Slow"
        case .fluctuating: "Fluctuating"
        }
    }

    /// Total EXP to reach level `n` (the games' formulas; Lv 1 = 0).
    func exp(forLevel level: Int) -> Double {
        guard level > 1 else { return 0 }
        let n = Double(level), n3 = n * n * n
        switch self {
        case .erratic:
            if level < 50 { return (n3 * (100 - n) / 50).rounded(.down) }
            if level < 68 { return (n3 * (150 - n) / 100).rounded(.down) }
            if level < 98 { return (n3 * ((1911 - 10 * n) / 3).rounded(.down) / 500).rounded(.down) }
            return (n3 * (160 - n) / 100).rounded(.down)
        case .fast: return (4 * n3 / 5).rounded(.down)
        case .mediumFast: return n3
        case .mediumSlow: return (6 * n3 / 5 - 15 * n * n + 100 * n - 140).rounded(.down)
        case .slow: return (5 * n3 / 4).rounded(.down)
        case .fluctuating:
            if level < 15 { return (n3 * (((n + 1) / 3).rounded(.down) + 24) / 50).rounded(.down) }
            if level < 36 { return (n3 * (n + 14) / 50).rounded(.down) }
            return (n3 * ((n / 2).rounded(.down) + 32) / 50).rounded(.down)
        }
    }

    func level(forEXP exp: Double) -> Int {
        var level = 1
        while level < 100, self.exp(forLevel: level + 1) <= exp { level += 1 }
        return level
    }

    /// Pace relative to Medium Fast, from how much EXP Lv 100 takes (Fast 1.25×, Slow 0.8×, …).
    var speed: Double { 1_000_000 / exp(forLevel: 100) }
}

/// Kanto (the default) or Alola. Like the games, it decides which Raichu a Thunder Stone makes.
enum Region: String, CaseIterable {
    case kanto, alola
    var name: String { rawValue.capitalized }
    static var current: Region { Region(rawValue: UserDefaults.standard.string(forKey: "region") ?? "") ?? .kanto }
}

/// A Pokémon's nature (the real 25): raises one stat and lowers another, and sets which berry
/// flavour it likes and dislikes. In PokePets the stats show up as personality on your desktop.
struct Nature: Hashable {
    enum Stat: String { case attack = "Attack", defense = "Defense", spAttack = "Sp. Atk", spDefense = "Sp. Def", speed = "Speed" }
    let name: String
    let up: Stat?, down: Stat?

    /// The flavour each stat goes with (as in the games).
    private static func flavour(_ s: Stat?) -> Flavour? {
        switch s {
        case .attack: .spicy
        case .defense: .sour
        case .speed: .sweet
        case .spAttack: .dry
        case .spDefense: .bitter
        case nil: nil
        }
    }
    var likes: Flavour? { Self.flavour(up) }
    var dislikes: Flavour? { Self.flavour(down) }

    /// Desktop personality.
    var walkSpeed: Double { up == .speed ? 1.25 : down == .speed ? 0.8 : 1 }      // fast or slow walker
    var playfulness: Int { [.attack, .speed].contains(up) ? 5 : [.defense, .spDefense].contains(up) ? 2 : 3 }
    var sleepy: Bool { down == .speed || name == "Lax" }                           // naps more
    var shy: Bool { name == "Timid" || name == "Bashful" }                          // shies away from the cursor until it trusts you

    var effect: String {
        var parts: [String] = []
        if walkSpeed > 1 { parts.append("walks faster") } else if walkSpeed < 1 { parts.append("walks slower") }
        if playfulness > 3 { parts.append("plays more") } else if playfulness < 3 { parts.append("plays less") }
        if sleepy { parts.append("naps more") }
        if shy { parts.append("shy with your cursor until friendship is high") }
        return parts.isEmpty ? "No particular quirks." : parts.joined(separator: ", ").capitalizedFirst + "."
    }

    static let all: [Nature] = [
        ("Hardy", nil, nil), ("Lonely", .attack, .defense), ("Brave", .attack, .speed), ("Adamant", .attack, .spAttack),
        ("Naughty", .attack, .spDefense), ("Bold", .defense, .attack), ("Docile", nil, nil), ("Relaxed", .defense, .speed),
        ("Impish", .defense, .spAttack), ("Lax", .defense, .spDefense), ("Timid", .speed, .attack), ("Hasty", .speed, .defense),
        ("Serious", nil, nil), ("Jolly", .speed, .spAttack), ("Naive", .speed, .spDefense), ("Modest", .spAttack, .attack),
        ("Mild", .spAttack, .defense), ("Quiet", .spAttack, .speed), ("Bashful", nil, nil), ("Rash", .spAttack, .spDefense),
        ("Calm", .spDefense, .attack), ("Gentle", .spDefense, .defense), ("Sassy", .spDefense, .speed),
        ("Careful", .spDefense, .spAttack), ("Quirky", nil, nil),
    ].map { Nature(name: $0.0, up: $0.1, down: $0.2) }

    static func named(_ name: String?) -> Nature? { all.first { $0.name == name } }
}

enum Flavour: String { case spicy = "Spicy", sour = "Sour", sweet = "Sweet", dry = "Dry", bitter = "Bitter" }

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

struct Move {
    let name: String
    let level: Int
    let stage: Stage
    var alola = false
    /// What it does on your desktop (nil: a battle move with no desktop effect).
    let effect: String?
}

enum Growth {
    // MARK: Evolution (real rules)

    static let hatchFriendship = 120.0         // hatched Pokémon start at 120 (base friendship is 70)
    static let pichuEvolvesAt = 220.0          // Pichu → Pikachu: level up with friendship ≥ 220
    /// Pikachu → Raichu takes a Thunder Stone. The games allow it at any level; here the stone is
    /// offered from Lv 20 (when Pikachu learns Spark), so you get some time with Pikachu first.
    static let thunderStoneLevel = 20
    static let maxFriendship = 255.0

    // MARK: Ability and gender (real data for the Pichu line)

    /// The Pichu line's abilities are Static and, as its hidden ability, Lightning Rod. PokePets gives
    /// yours Lightning Rod, and makes it do something on your Mac.
    static let ability = "Lightning Rod"
    static let abilityEffect = "While your Mac is charging, it soaks up the power: its energy refills and it doesn't get hungry."
    /// Alolan Raichu's only ability. In the games it doubles Speed on Electric Terrain.
    static let alolaAbility = "Surge Surfer"
    static let alolaAbilityEffect = "While your Mac is charging, it surfs around 50 % faster."

    // MARK: Shiny and Pokérus (real odds)

    static let shinyOdds = 4096                  // 1 in 4,096, the modern games' odds
    /// In the games each encounter has a 3 in 65,536 (about 1 in 21,845) chance of Pokérus. Here each
    /// time it decides what to do is a roll. It lasts 1–4 days, then it's cured and can't catch it again.
    static let pokerusOdds = 65_536.0 / 3
    static let pokerusDays = 1...4
    static let femaleChance = 0.5                // gender ratio 50 % ♂ / 50 % ♀

    // MARK: Levels

    /// Share of the current level gained per minute out on the desktop, awake: 2 % (a level in 50 min)
    /// for Medium Fast at full friendship, scaled by the growth rate's pace (Fast 1.25×, Slow 0.8×, …).
    /// Friendship scales it too (0 friendship: 30 % of the pace). Tired or low battery: half.
    /// ponytail: one tuning knob (`perMinute`); real games level by battles, we level by good company.
    static let perMinute = 0.02
    static func levelShare(perMinute friendship: Double, tired: Bool, rate: GrowthRate) -> Double {
        perMinute * rate.speed * (0.3 + 0.7 * min(1, max(0, friendship / maxFriendship))) * (tired ? 0.5 : 1)
    }

    /// Bonus EXP for things you do together, as a share of the current level.
    enum Bonus {
        static let pet = 0.03, play = 0.04, explore = 0.03, berry = 0.08, favouriteBerry = 0.15
        static let zapFile = 0.1, celebrate = 0.05
    }

    /// A berry fills `berryFill` of its belly. Belly above `fullBelly`: it won't eat (no spamming berries
    /// for friendship: the belly empties over ~40 min, so about one berry every 15 min at most).
    static let berryFill = 0.35, fullBelly = 0.85
    /// Hungry (belly under 40 %) for this many minutes while you're at the Mac: friendship −`hungryPenalty`.
    static let hungryMinutes = 8.0 * 60, hungryPenalty = 10.0
    /// Petting adds friendship and EXP at most once per this many minutes (the hearts come every time).
    static let pettingMinutes = 15.0

    // MARK: Moves (Scarlet/Violet level-up learnsets)

    /// What each move does on your desktop (moves not listed are battle-only).
    private static let effects: [String: String] = [
        "Thunder Shock": "Select files in Finder and press ⌥⌘⌫: zaps them into the Trash.",
        "Sweet Kiss": "Greets you with an extra burst of hearts.",
        "Nuzzle": "Petting it builds friendship faster.",
        "Charm": "Dances: to music and in its playful moments.",
        "Quick Attack": "Leaps up big heights: stacked desktop files, high icons.",
        "Double Team": "Learns the Twirl.",
        "Electro Ball": "Charges up with sparks now and then while plugged in.",
        "Spark": "Celebrates the charger with a Thunder Shock and sparks.",
        "Agility": "Learns the Somersault.",
        "Discharge": "`pokepets celebrate` sets off sparks all around.",
        "Thunderbolt": "The file zap becomes a bigger, brighter bolt.",
        "Thunder": "Files not on the Desktop are struck from the sky.",
    ]

    /// Level-up learnsets, Scarlet/Violet (PokeAPI). Level 1 includes moves an evolved Pokémon starts with;
    /// Raichu's Thunder Punch is its evolution move.
    private static let learnsets: [(Stage, [(Int, String)])] = [
        (.pichu, [(1, "Thunder Shock"), (1, "Tail Whip"), (4, "Play Nice"), (8, "Sweet Kiss"), (12, "Nuzzle"),
                  (16, "Nasty Plot"), (20, "Charm")]),
        (.pikachu, [(1, "Thunder Shock"), (1, "Tail Whip"), (1, "Growl"), (1, "Play Nice"), (1, "Sweet Kiss"),
                    (1, "Nuzzle"), (1, "Nasty Plot"), (1, "Charm"), (1, "Quick Attack"), (4, "Thunder Wave"),
                    (8, "Double Team"), (12, "Electro Ball"), (16, "Feint"), (20, "Spark"), (24, "Agility"),
                    (28, "Iron Tail"), (32, "Discharge"), (36, "Thunderbolt"), (40, "Light Screen"), (44, "Thunder")]),
        (.raichu, [(1, "Thunder Punch")] + ["Thunder Shock", "Tail Whip", "Growl", "Play Nice", "Sweet Kiss", "Nuzzle",
                   "Nasty Plot", "Charm", "Quick Attack", "Thunder Wave", "Double Team", "Electro Ball", "Feint",
                   "Spark", "Agility", "Iron Tail", "Discharge", "Light Screen", "Thunder"].map { (1, $0) }
                   + [(5, "Thunderbolt")]),
    ]

    /// Alolan Raichu (Scarlet/Violet): Psychic is its evolution move.
    private static let alolaLearnset: [(Int, String)] = [(1, "Psychic")] + ["Thunder Shock", "Tail Whip", "Growl", "Play Nice",
        "Sweet Kiss", "Nuzzle", "Nasty Plot", "Charm", "Quick Attack", "Thunder Wave", "Double Team", "Electro Ball", "Feint",
        "Spark", "Agility", "Iron Tail", "Discharge", "Light Screen", "Thunder"].map { (1, $0) } + [(5, "Thunderbolt")]

    static let moves: [Move] = learnsets.flatMap { stage, list in
        list.map { Move(name: $0.1, level: $0.0, stage: stage, effect: effects[$0.1]) }
    } + alolaLearnset.map { Move(name: $0.1, level: $0.0, stage: .raichu, alola: true,
                                 effect: $0.1 == "Psychic" ? "Teleports next to your cursor now and then." : effects[$0.1]) }

    // MARK: Pokédex (English entries via PokeAPI)

    static func pokedex(_ stage: Stage, alola: Bool) -> (genus: String, type: String, entries: [(game: String, text: String)]) {
        switch (stage, alola) {
        case (.pichu, _): ("Tiny Mouse Pokémon", "Electric", [
            ("Sun", "It is not yet skilled at controlling electricity. If you take your eyes off it, it may shock itself."),
            ("Moon", "Despite this Pokémon’s cute appearance, those who want to live with one should prepare to be on the receiving end of its electric jolts."),
            ("Ultra Sun", "It still can’t use electricity well. When it’s surprised or excited, it discharges electricity unintentionally.")])
        case (.pikachu, _): ("Mouse Pokémon", "Electric", [
            ("Sun", "A plan was recently announced to gather many Pikachu and make an electric power plant."),
            ("Moon", "It’s in its nature to store electricity. It feels stressed now and then if it’s unable to fully discharge the electricity."),
            ("Ultra Sun", "Its nature is to store up electricity. Forests where nests of Pikachu live are dangerous, since the trees are so often struck by lightning.")])
        case (.raichu, false): ("Mouse Pokémon", "Electric", [
            ("Sun", "It unleashes electric shocks that can reach 100,000 volts. When agitated, it can knock out even an Indian elephant."),
            ("Moon", "It becomes aggressive when it has electricity stored up. At such times, even its Trainer has to take care to avoid being attacked."),
            ("Ultra Sun", "As electricity builds up inside its body, it becomes more aggressive. One theory is that the electricity buildup is actually causing stress.")])
        case (.raichu, true): ("Mouse Pokémon", "Electric / Psychic", [
            ("Sun", "It only evolves to this form in the Alola region. According to researchers, its diet is one of the causes of this change."),
            ("Moon", "It uses psychokinesis to control electricity. It hops aboard its own tail, using psychic power to lift the tail and move about while riding it."),
            ("Ultra Sun", "It focuses psychic energy into its tail and rides it like it’s surfing. Another name for this Pokémon is “hodad.”"),
            ("Let’s Go, Pikachu!", "It loves pancakes prepared with a secret Alolan recipe. Some wonder whether that recipe holds the key to this Pokémon’s evolution.")])
        case (.gastly, _), (.haunter, _), (.gengar, _): GengarLine.pokedex(stage)
        case (.egg, _): ("Egg", "", [])
        }
    }

    /// Moves known at `stage` and `level`: everything its line learns up to here (moves are kept on evolving).
    static func known(stage: Stage, level: Int, alola: Bool = false) -> Set<String> {
        guard stage != .egg else { return [] }
        let reached = stage.line.prefix { $0 != stage } + [stage]
        return Set(moves.filter { reached.contains($0.stage) && $0.level <= level && (!$0.alola || alola) && !(alola && $0.stage == .raichu && !$0.alola) }
            .map(\.name))
    }

    /// Self-check: `swift PokePets/Growth.swift` (or call from a debugger).
    static func check() {
        let mf = GrowthRate.mediumFast
        assert(mf.exp(forLevel: 1) == 0 && mf.exp(forLevel: 2) == 8 && mf.exp(forLevel: 100) == 1_000_000)
        assert(mf.level(forEXP: 0) == 1 && mf.level(forEXP: 7.9) == 1 && mf.level(forEXP: 8) == 2 && mf.level(forEXP: 46_656) == 36)
        assert(mf.level(forEXP: 2_000_000) == 100)
        // Lv 100 totals from the games:
        let totals: [GrowthRate: Double] = [.erratic: 600_000, .fast: 800_000, .mediumFast: 1_000_000,
                                            .mediumSlow: 1_059_860, .slow: 1_250_000, .fluctuating: 1_640_000]
        for (rate, total) in totals { assert(rate.exp(forLevel: 100) == total, "\(rate)") }
        assert(GrowthRate.mediumSlow.exp(forLevel: 2) == 9 && GrowthRate.erratic.exp(forLevel: 2) == 15)
        assert(known(stage: .pichu, level: 3) == ["Thunder Shock", "Tail Whip"])
        assert(!known(stage: .pichu, level: 50).contains("Quick Attack"))
        assert(known(stage: .pikachu, level: 1).contains("Quick Attack") && !known(stage: .pikachu, level: 35).contains("Thunderbolt"))
        assert(known(stage: .raichu, level: 5).contains("Thunderbolt") && known(stage: .raichu, level: 1).contains("Agility"))
        assert(known(stage: .pikachu, level: 2).contains("Play Nice"))
        assert(known(stage: .raichu, level: 30, alola: true).contains("Psychic") && !known(stage: .raichu, level: 30).contains("Psychic"))
        assert(Nature.all.count == 25 && Set(Nature.all.map(\.name)).count == 25)
        assert(Nature.named("Jolly")!.likes == .sweet && Nature.named("Jolly")!.dislikes == .dry && Nature.named("Hardy")!.likes == nil)
        assert(Nature.named("Brave")!.walkSpeed == 0.8 && Nature.named("Timid")!.shy)
        assert(abs(levelShare(perMinute: 255, tired: false, rate: .mediumFast) - 0.02) < 1e-9)
        assert(abs(levelShare(perMinute: 0, tired: true, rate: .mediumFast) - 0.003) < 1e-9)
        assert(abs(levelShare(perMinute: 255, tired: false, rate: .fast) - 0.025) < 1e-9)
    }
}
