import AppKit

/// The Pichu line: Pichu → Pikachu → Raichu or Alolan Raichu. Everything it shares with other Pokémon
/// lives in `Companion`; this is only what makes it a Pikachu: its sprites and moves, Lightning Rod and
/// Surge Surfer, evolving by friendship and the Thunder Stone, and the Thunderbolt that zaps your files.
/// It saves under "pet.*" (it was the first Pokémon, so it keeps the keys it always had).
final class Pikachu: Companion {
    init(power: Power, senses: Senses) {
        super.init(store: "pet", power: power, senses: senses)
    }

    override func sheetName(_ stage: Stage, form: String?, shiny: Bool) -> String {
        (stage == .egg ? "pichu" : stage.rawValue) + (stage == .raichu && form == "alola" ? "-alola" : "")
            + (shiny && stage != .egg ? "-shiny" : "")
    }
    override var firstStage: Stage { .pichu }
    override var isAlolan: Bool { stage == .raichu && form == "alola" }
    override var name: String { isAlolan ? "Alolan Raichu" : stage.name }
    override var ability: (name: String, effect: String) {
        isAlolan ? (Growth.alolaAbility, Growth.alolaAbilityEffect) : (Growth.ability, Growth.abilityEffect)
    }
    /// Both of its abilities work while your Mac charges.
    override var abilityOnCharge: Bool { true }
    override var known: Set<String> { Growth.known(stage: stage, level: level, alola: isAlolan) }
    override var learnset: [Move] { Growth.moves }
    override var signatureMoves: Set<String> { ["Psychic", "Thunder Punch"] }
    override var canEvolve: Bool { stage == .pikachu && level >= Growth.thunderStoneLevel }
    override var evolveItem: Item? { stage == .pikachu ? .thunderStone : nil }

    override var cry: String { isAlolan ? "Rai rai" : stage == .pichu ? "Pichu" : stage == .raichu ? "Rai" : "Pika" }

    /// Cheerful and sparky, like a PMD partner: it calls you "partner" and its cheeks spark when it's happy.
    override var voice: [Moment: [String]] {
        [.curious: ["{cry}? What's that? What's that?", "{cry}?! Is something there?"],
         .recognized: ["{cry}! It's you! ♥", "{cry} {cry}! I knew it was you!"],
         .startled: ["{cry}?! You scared me!", "Bzzt! Don't sneak up on me!"],
         .petted: ["{cry}~ ♥ That feels nice!", "Hehe! My cheeks are sparking!", "{cry} {cry}! You're my favourite!"],
         .pettedSleepy: ["{cry}… so sleepy…", "Low battery… but that's nice…"],
         .pickedUp: ["{cry} {cry}! Wheee!", "Higher! Higher!"],
         .pickedUpWorried: ["Don't drop me again, okay?", "{cry}… careful…"],
         .droppedHard: ["Ow… that really hurt…", "{cry}… *sniff*"],
         .dizzy: ["Everything's spinning… {cry}…"],
         .askBerry: ["{cry}! I'm hungry! Got a berry?", "My tummy's sparking… food, please!"],
         .ateFavourite: ["My favourite!! {cry} {cry}! ♥", "This is the best berry ever!"],
         .ate: ["Yum! That hit the spot!", "{cry}! Delicious!"],
         .ateDisliked: ["…Bleh. Thanks, I guess.", "{cry}… not my favourite."],
         .full: ["I'm full! I couldn't eat another bite.", "{cry}… so stuffed!"],
         .woke: ["*yawn* Fully charged!", "{cry}! Good nap!"],
         .userBack: ["{cry}! You're back! I missed you!"],
         .itemNear: ["Ooh! Is that for me?", "{cry}?! A berry?!"],
         .offline: ["Huh? The signal's gone…"],
         .online: ["Phew! Back online!"],
         .hot: ["So hot… I'm overheating…"],
         .deleted: ["Zap! Did you see that?!", "{cry}! Gone in a flash!"],
         .celebrate: ["{cry} {cry}! We did it!"],
         .failed: ["{cry}… ugh… we'll get it next time."],
         .done: ["All done! Great job, partner!"],
         .hello: ["{cry}! Hi there!"],
         .playing: ["{cry}! Watch this!", "Hehe, this is fun!"]]
    }
    /// Alolan Raichu rides its tail on psychic power: it never falls.
    override var floats: Bool { isAlolan }
    /// Nuzzle: petting builds friendship faster.
    override var pettingFriendship: Double { knows("Nuzzle") ? 3 : 2 }
    /// Surge Surfer surfs faster while your Mac charges.
    override var paceBoost: Double { ability.name == Growth.alolaAbility && power.charging ? 1.5 : 1 }

    /// Playful moves come with learned moves (DeepBreath always, Rotate with Double Team, Tumble with
    /// Agility, Double with Charm) and can be switched off one by one in Settings.
    override var unlockedMoves: [String] {
        let needs = ["Rotate": "Double Team", "Tumble": "Agility", "Double": "Charm"]
        return playful.filter { (needs[$0].map(knows) ?? true) && Setting.moveAllowed($0) }
    }

    /// Quick Attack: leaps up big heights.
    override func refreshMoves() { pet.canLeap = knows("Quick Attack") }

    /// Lightning Rod: plugged in, it soaks up the power. Energy refills (empty → full in 10 min) and
    /// instead of getting hungry it slowly fills up.
    override func absorbsCharge(minutes: Double) -> Bool {
        guard power.charging, ability.name == Growth.ability else { return false }
        energy = min(1, energy + minutes / 10)
        hunger = max(0, hunger - minutes / 30)
        return true
    }

    /// Pichu levels up with friendship ≥ 220: it offers to evolve (asked again each level until you say yes).
    override func didLevelUp() {
        if stage == .pichu, friendship >= Growth.pichuEvolvesAt { offerEvolution(to: .pikachu) }
    }

    /// Sweet Kiss: a second burst of hearts.
    override func petted() {
        if knows("Sweet Kiss") { pet.after(0.5) { [weak self] in self?.pet.hearts() } }
    }

    override func evolutionName(_ to: Stage, form: String?) -> String { form == "alola" ? "Alolan Raichu" : to.name }

    /// The Thunder Stone: Pikachu (Lv 20+) evolves; the region decides which Raichu.
    override func use(_ item: Item) -> Bool {
        guard item == .thunderStone else { return false }
        canEvolve ? offerEvolution(to: .raichu, form: Region.current == .alola ? "alola" : nil, askNow: true) : feel(.surprised)
        return true
    }

    override func startDemo(_ name: String) -> Bool {
        switch name {
        case "float" where isAlolan:                                   // floats about (even behind windows), then normal
            pet.after(1) { [weak self] in self?.levitate(anywhere: true) { [weak self] in self?.think() } }
            return true
        case "stone": pet.after(2) { [weak self] in self?.received(.thunderStone) }   // Pikachu Lv 20+: evolves (region decides)
        case "evolve":                                               // Pichu with 230 friendship levels up → evolves
            if stage == .pichu { friendship = 230; exp = stage.growthRate.exp(forLevel: level + 1) - 0.1; gainEXP(0.1) }
        default: break
        }
        return false
    }

    /// Charger plugged in: a short burst of joy, about 1.7 s: a shock with sparks, then a charge-up.
    override func chargerPlugged() {
        feel(.joyous, caption: "\(ability.name) is drawing in the power!", for: 3)
        guard knows("Spark") else {                     // too young for Spark: just a happy little hop of the ears
            super.chargerPlugged()
            return
        }
        let wasDown = isFainted
        isFainted = false
        var steps: [Step] = []
        if wasDown {
            steps.append { [weak self] next in self?.pet.once(self!.a.wake, done: next) }
        }
        steps += [
            { [weak self] next in
                guard let self else { return }
                pet.sparks(for: 0.5, rate: 24)
                pet.once(a.shock, times: 2, done: next)               // 0.7 s
            },
            { [weak self] next in
                guard let self else { return }
                startChargeSparks(rate: 6)
                pet.stay(a.charge, for: 1.0, done: next)
            },
        ]
        stop { [weak self] in run(steps) { [weak self] in self?.think() } }
    }

    /// `pokepets celebrate`: a Thunder Shock and a happy pose (Discharge: sparks everywhere).
    override func celebrateHook() {
        stop { [weak self] in
            guard let self else { return }
            chat(.celebrate, .joyous)
            gainEXP(Growth.Bonus.celebrate)
            _ = knows("Discharge") ? pet.sparks(for: 1.2, rate: 60) : pet.sparks(for: 0.6, rate: 24)
            run([{ [weak self] next in self?.pet.once(self!.a.shock, times: 2, done: next) },
                 { [weak self] next in self?.pet.once(self!.a.pose, done: next) }]) { [weak self] in self?.think() }
        }
    }

    /// Thunderbolt: it charges up and zaps each file, from its body to the file's icon (its row in a
    /// Finder window, or on the desktop), or from the sky onto it with Thunder for files elsewhere,
    /// and the file goes to the Trash.
    override func attack(_ urls: [URL], at spots: [URL: CGPoint]) {
        guard let fx else { return }
        stop { [weak self] in
            guard let self else { return }
            let steps: [Step] = urls.map { url in { [weak self] next in
                guard let self else { return }
                let here = pet.position, dir: CGFloat = pet.facingRight ? 1 : -1
                let icon = spots[url] ?? pet.iconCenter(url)       // its row or icon in Finder, or on the desktop
                let target = icon ?? CGPoint(x: here.x + dir * 30 * pet.scale, y: here.y + 6 * pet.scale)
                let body = CGPoint(x: here.x, y: here.y + 16 * pet.scale)
                let from = icon == nil && knows("Thunder") ? CGPoint(x: target.x, y: target.y + 1200) : body   // Thunder strikes from the sky
                let big = knows("Thunderbolt")
                feel(.determined, caption: big ? "Thunderbolt!" : "Thunder Shock!", for: 1.5)
                pet.face(right: target.x >= here.x)
                startChargeSparks(rate: 10)
                pet.stay(a.charge, for: 0.5) { [weak self] in
                    guard let self else { return }
                    stopChargeSparks()
                    pet.once(a.shock, times: 3, done: next)
                    fx.bolt(from: from, to: target, thickness: big ? 2 : 1) {
                        do { try FileManager.default.trashItem(at: url, resultingItemURL: nil); self.gainEXP(Growth.Bonus.zapFile) }
                        catch { self.feel(.sigh) }                                   // couldn't (e.g. no permission)
                    }
                }
            } }
            run(steps + [{ [weak self] next in self?.victoryLap(next) }]) { [weak self] in
                self?.think()
            }
        }
    }
}
