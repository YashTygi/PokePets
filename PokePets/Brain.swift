import Foundation

/// The utility AI: every few minutes at most, when an action ends, each possible action gets a score
/// from 0 to 1 built from simple considerations about how the Pokémon feels. It picks the best (with a
/// little variety among near-equal options), then sleeps until the action finishes. No models: a few
/// dozen multiplications per decision.
enum Intent: String, CaseIterable {
    case nap, rest, sit, askForBerry, inspect, explore, patrol, visit, play, dance, chargeUp, surfLaps,
         levitate, teleport, daydream, yawn, sniff, hum, bask, fly, phase, lick, snatch, clone, shadowGag, prank

    /// What it's doing, in words (for the "Why?" panel).
    var label: String {
        switch self {
        case .nap: "Napping"
        case .rest: "Catching its breath"
        case .sit: "Sitting quietly"
        case .askForBerry: "Asking you for a berry"
        case .inspect: "Checking out a new file"
        case .explore: "Exploring the desktop files"
        case .patrol: "Patrolling its territory"
        case .visit: "Coming over to you"
        case .play: "Playing"
        case .dance: "Dancing to the music"
        case .chargeUp: "Charging up"
        case .surfLaps: "Surfing laps on the charge"
        case .levitate: "Floating about"
        case .teleport: "Teleporting to you"
        case .daydream: "Daydreaming"
        case .yawn: "Yawning and stretching"
        case .sniff: "Sniffing around"
        case .hum: "Humming to itself"
        case .bask: "Basking in the sun"
        case .fly: "Flying about"
        case .phase: "Sinking into your window"
        case .lick: "Licking your screen"
        case .snatch: "Stealing your cursor"
        case .clone: "Making shadow clones"
        case .shadowGag: "Chasing its own shadow"
        case .prank: "Up to no good"
        }
    }

    /// Seconds before it wants to do this again (scores recover gradually over this time).
    var cooldown: Double {
        switch self {
        case .play: 90
        case .askForBerry: 90                     // asks, then gives you a moment to fetch one
        case .dance: 40
        case .explore: 180
        case .visit, .teleport, .levitate, .chargeUp: 120
        case .surfLaps: 60
        case .rest: 30
        case .patrol: 20
        case .daydream: 150
        case .yawn, .hum: 240
        case .sniff: 90
        case .bask: 600
        case .fly: 45
        case .phase: 150
        case .lick: 300
        case .snatch: 900                             // a prank, not a habit
        case .clone: 240
        case .shadowGag: 420
        case .prank: 300
        default: 0
        }
    }

    /// Moving about, playing, exploring: these use up boredom.
    var isActive: Bool { [.patrol, .visit, .play, .dance, .explore, .inspect, .surfLaps, .levitate, .teleport, .sniff, .fly, .phase, .lick, .snatch, .clone, .shadowGag, .prank].contains(self) }
}

/// Everything the brain considers, as numbers from 0 to 1 (or yes/no).
struct Mind {
    var energy = 0.8, hunger = 0.3, friendship = 0.5, boredom = 0.3, neglect = 0.0
    var night = false, daytime = false, charging = false, lowBattery = false, music = false
    var hungerOn = true, caring = true
    var newFile = false, filesToExplore = false, cursorReachable = false, openAir = false
    var canPlay = false, knowsElectroBall = false, knowsPsychic = false
    var alolan = false
    var ghost = false                              // Levitate: flies anywhere on the screen
    var windowToHaunt = false                      // a ghost, and you're working in a window it may be in front of
    var canLick = false                            // knows Lick, and may lick your screen
    var cursorLeftAlone = false                    // your mouse untouched for a while (Gengar may steal the cursor)
    var shadowTricks = false                       // may make shadow clones and play with its shadow
    var canPrank = false                           // may play pranks (and has somewhere to play them)
    var ghostHour = false                          // evening, night or dark mode: a ghost's favourite time
    var nature = Nature.all[0]
}

struct Option {
    let intent: Intent
    var score: Double
    var reasons: [(String, Double)]
}

struct Brain {
    private(set) var options: [Option] = []
    private(set) var choice: Intent?
    private(set) var decidedAt = Date.distantPast
    private var lastDone: [Intent: Date] = [:]

    /// `x` mapped onto 0…1 between `a` (→ 0) and `b` (→ 1), smoothed. Works both ways (a > b: falling).
    static func ramp(_ x: Double, _ a: Double, _ b: Double) -> Double {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    /// Score every action for this state of mind.
    static func score(_ m: Mind) -> [Option] {
        let r = ramp
        let awake = r(m.energy, 0.15, 0.35)                      // has the energy to do things at all
        let sleepy = m.nature.sleepy ? 1.25 : 1.0
        func o(_ i: Intent, _ weight: Double, _ parts: [(String, Double)]) -> Option {
            Option(intent: i, score: weight * parts.map(\.1).reduce(1, *), reasons: parts)
        }
        var all: [Option] = [
            o(.nap, 1.0 * sleepy, [("tired", max(r(m.energy, 0.35, 0.05), m.night ? r(m.energy, 0.65, 0.3) : 0)),
                                   ("low battery", m.lowBattery ? 1.2 : 1)]),
            o(.rest, 0.75 * sleepy, [("a bit tired", r(m.energy, 0.55, 0.25)), ("low battery", m.lowBattery ? 1.4 : 1)]),
            o(.sit, 1, [("calm", 0.18 + 0.25 * r(m.energy, 0.75, 0.45))]),
            o(.askForBerry, 1, [("hungry", m.hungerOn ? r(m.hunger, 0.6, 0.9) : 0)]),
            o(.inspect, 0.95, [("new file!", m.newFile ? 1 : 0), ("awake", awake)]),
            o(.explore, m.alolan ? 0.45 : 0.6, [("files to explore", m.filesToExplore ? 1 : 0), ("energetic", r(m.energy, 0.5, 0.8)),
                                                 ("bored", 0.3 + 0.7 * m.boredom)]),
            o(.patrol, m.alolan ? 0.3 : 0.65, [("energy", r(m.energy, 0.3, 0.6)), ("bored", 0.3 + 0.7 * m.boredom)]),
            o(.visit, m.nature.shy ? 0.25 : 0.5, [("cursor nearby", m.cursorReachable ? 1 : 0), ("awake", awake),
                                                   ("wants you", 0.3 + 0.7 * max(m.neglect, r(m.friendship, 0.5, 0.9)))]),
            o(.play, (m.alolan ? 0.55 : 0.85) * Double(m.nature.playfulness) / 3,
              [("knows playful moves", m.canPlay ? 1 : 0), ("energetic", r(m.energy, 0.45, 0.7)),
               ("likes you", m.caring ? r(m.friendship, 0.3, 0.6) : 1), ("bored", 0.3 + 0.7 * m.boredom)]),
            o(.dance, 0.85, [("music on", m.music ? 1 : 0), ("energy", r(m.energy, 0.25, 0.5))]),
        ]
        // Little everyday things: short, on the spot, never in your way. They keep it from looking idle.
        all += [
            o(.daydream, 0.5, [("calm", r(m.energy, 0.3, 0.6)), ("quiet moment", 0.4 + 0.6 * (1 - m.boredom))]),
            o(.yawn, 0.7 * sleepy, [("getting sleepy", r(m.energy, 0.55, 0.35) * r(m.energy, 0.15, 0.25))]),
            o(.sniff, 0.45, [("energy", r(m.energy, 0.35, 0.6)), ("bored", 0.3 + 0.7 * m.boredom)]),
            o(.hum, 0.4, [("likes you", r(m.friendship, 0.5, 0.85)), ("awake", awake), ("no music on", m.music ? 0 : 1)]),
            o(.bask, 0.5, [("sunny daytime", m.daytime ? 1 : 0), ("relaxed", r(m.energy, 0.3, 0.6) * r(m.energy, 1, 0.85))]),
        ]
        if m.alolan {
            all += [
                o(.levitate, 0.9, [("open air", m.openAir ? 1 : 0), ("energy", r(m.energy, 0.35, 0.6)), ("bored", 0.4 + 0.6 * m.boredom)]),
                o(.teleport, 0.4, [("knows Psychic", m.knowsPsychic ? 1 : 0), ("cursor nearby", m.cursorReachable ? 1 : 0),
                                   ("likes you", 0.3 + 0.7 * r(m.friendship, 0.3, 0.8))]),
                o(.surfLaps, 0.6, [("charging (Surge Surfer)", m.charging ? 1 : 0), ("energy", r(m.energy, 0.3, 0.6))]),
            ]
        } else if m.ghost {
            all.append(o(.fly, 0.95, [("Levitate", 1), ("energy", r(m.energy, 0.3, 0.55)), ("bored", 0.35 + 0.65 * m.boredom)]))
            all.append(o(.phase, 0.8, [("your window to haunt", m.windowToHaunt ? 1 : 0), ("energy", r(m.energy, 0.3, 0.55)),
                                       ("bored", 0.4 + 0.6 * m.boredom)]))
            all.append(o(.lick, 0.6, [("knows Lick", m.canLick ? 1 : 0), ("energy", r(m.energy, 0.3, 0.55)), ("bored", 0.3 + 0.7 * m.boredom)]))
            all.append(o(.snatch, 1.3, [("cursor left alone", m.cursorLeftAlone ? 1 : 0), ("awake", r(m.energy, 0.2, 0.4))]))
            all.append(o(.clone, 0.55, [("shadow tricks", m.shadowTricks ? 1 : 0), ("energy", r(m.energy, 0.35, 0.6)), ("bored", 0.3 + 0.7 * m.boredom)]))
            all.append(o(.shadowGag, 0.45, [("shadow tricks", m.shadowTricks ? 1 : 0), ("energy", r(m.energy, 0.3, 0.55)), ("bored", 0.3 + 0.7 * m.boredom)]))
            all.append(o(.prank, 0.65, [("pranks", m.canPrank ? 1 : 0), ("energy", r(m.energy, 0.3, 0.55)), ("bored", 0.3 + 0.7 * m.boredom)]))
            // A ghost's hour: more mischief, fewer naps (ghosts are night owls, the opposite of everyone else).
            if m.ghostHour {
                let mischief: Set<Intent> = [.fly, .phase, .lick, .clone, .shadowGag, .prank]
                all = all.map { option in
                    var o = option
                    if mischief.contains(o.intent) { o.score *= 1.4; o.reasons.append(("ghost hour", 1.4)) }
                    if [.nap, .rest, .yawn, .bask].contains(o.intent) { o.score *= 0.6; o.reasons.append(("ghost hour", 0.6)) }
                    return o
                }
            }
        } else {
            all.append(o(.chargeUp, 0.45, [("charging", m.charging ? 1 : 0), ("knows Electro Ball", m.knowsElectroBall ? 1 : 0)]))
        }
        return all
    }

    /// Pick what to do: scores with cooldowns (recently done → lower) and momentum (keep the mood going),
    /// then a weighted pick among options within 15 % of the best, so it's lively but never erratic.
    mutating func decide(_ mind: Mind, now: Date = Date()) -> Intent {
        var scored = Self.score(mind).map { option -> Option in
            var o = option
            if o.intent.cooldown > 0, let last = lastDone[o.intent] {
                let recovered = min(1, now.timeIntervalSince(last) / o.intent.cooldown)
                o.score *= recovered
                o.reasons.append(("done recently", recovered))
            }
            if o.intent == choice, o.intent.cooldown == 0 { o.score *= 1.1; o.reasons.append(("keeps going", 1.1)) }
            return o
        }
        scored.sort { $0.score > $1.score }
        let best = scored.first?.score ?? 0
        let top = scored.filter { $0.score >= best * 0.85 && $0.score > 0 }
        var roll = Double.random(in: 0..<max(1e-9, top.map(\.score).reduce(0, +)))
        var picked = top.first?.intent ?? .sit
        for o in top { if roll < o.score { picked = o.intent; break }; roll -= o.score }
        options = scored
        choice = picked
        decidedAt = now
        lastDone[picked] = now
        return picked
    }

    /// Self-check: `swift PokePets/Growth.swift PokePets/Brain.swift` with `Brain.check()`.
    static func check() {
        var tired = Mind(); tired.energy = 0.08
        assert(score(tired).max { $0.score < $1.score }!.intent == .nap)
        var hungry = Mind(); hungry.hunger = 0.95; hungry.energy = 0.7
        assert(score(hungry).max { $0.score < $1.score }!.intent == .askForBerry)
        var news = Mind(); news.newFile = true; news.energy = 0.8
        assert(score(news).max { $0.score < $1.score }!.intent == .inspect)
        var party = Mind(); party.music = true; party.energy = 0.8
        assert(score(party).max { $0.score < $1.score }!.intent == .dance)
        var floaty = Mind(); floaty.alolan = true; floaty.openAir = true; floaty.energy = 0.8; floaty.boredom = 0.8
        assert(score(floaty).max { $0.score < $1.score }!.intent == .levitate)
        var ghost = Mind(); ghost.ghost = true; ghost.energy = 0.8; ghost.boredom = 0.8
        assert(score(ghost).max { $0.score < $1.score }!.intent == .fly)
        assert(!score(Mind()).contains { $0.intent == .fly })
        ghost.windowToHaunt = true
        assert(score(ghost).first { $0.intent == .phase }!.score > 0.5)
        assert(score(ghost).first { $0.intent == .snatch }!.score == 0)
        ghost.cursorLeftAlone = true
        assert(score(ghost).max { $0.score < $1.score }!.intent == .snatch)
        var owl = Mind(); owl.ghost = true; owl.energy = 0.3; owl.night = true
        let napDay = score(owl).first { $0.intent == .nap }!.score
        owl.ghostHour = true
        assert(score(owl).first { $0.intent == .nap }!.score < napDay)
        owl.canPrank = true; owl.energy = 0.8; owl.boredom = 0.8
        assert(score(owl).first { $0.intent == .prank }!.score > 0.7)
        // Cooldown: right after playing, play shouldn't win again.
        var brain = Brain(); var playful = Mind(); playful.canPlay = true; playful.energy = 0.9; playful.boredom = 1; playful.friendship = 0.9
        _ = brain.decide(playful)
        brain.lastDone[.play] = Date()
        assert(brain.decide(playful) != .play)
        var sleepyish = Mind(); sleepyish.energy = 0.3; sleepyish.boredom = 0
        assert(score(sleepyish).first { $0.intent == .yawn }!.score > 0.3)
        assert(abs(ramp(0.5, 0, 1) - 0.5) < 1e-9 && ramp(0.2, 0.35, 0.05) > 0.4 && ramp(2, 0, 1) == 1)
    }
}
