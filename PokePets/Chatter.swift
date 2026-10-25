import AppKit

/// What your Pokémon says, when "Talks to you" is on: a line for each moment you share, in its own voice
/// (each species has its own lines; these are the fallback). Written in the spirit of Pokémon Mystery
/// Dungeon's partner talk, as original lines. `{name}` is its name, `{cry}` its cry ("Pika", "Kekeke").
enum Moment: CaseIterable {
    case curious, recognized, startled, petted, pettedSleepy, pickedUp, pickedUpWorried, droppedHard, dizzy,
         askBerry, ateFavourite, ate, ateDisliked, full, woke, userBack, itemNear, offline, online, hot,
         deleted, celebrate, failed, done, hello, playing, morning

    /// The fallback lines, for any species without its own.
    var lines: [String] {
        switch self {
        case .curious: ["Hm? What's that? What's that?", "Ooh? What's this?", "Who's there?"]
        case .recognized: ["Oh! It's you! ♥", "It's you! Hello!", "Hehe, I knew it was you!"]
        case .startled: ["Eek! You scared me!", "Whoa! Not so fast!"]
        case .petted: ["Hehe, that tickles!", "More, more! ♥", "I like you too!"]
        case .pettedSleepy: ["Mm… so sleepy…", "That's nice… zzz…"]
        case .pickedUp: ["Wheee! Up we go!", "Look how high I am!"]
        case .pickedUpWorried: ["Careful! Don't drop me again!", "Hold on tight, okay?"]
        case .droppedHard: ["Ow ow ow… that really hurt…", "Why'd you drop me?!"]
        case .dizzy: ["The world is spinning…", "Whoa… everything's going round…"]
        case .askBerry: ["I'm hungry… got a berry?", "My tummy's rumbling!"]
        case .ateFavourite: ["My favourite!! You're the best!", "This one's the best kind!"]
        case .ate: ["Yum! That hit the spot!", "Munch munch… delicious!"]
        case .ateDisliked: ["…Bleh. Thanks, I guess.", "Not my favourite… but thank you."]
        case .full: ["I'm full! I couldn't eat another bite.", "I'm stuffed! Maybe later?"]
        case .woke: ["Mm… that was a good nap!", "*yawn* What did I miss?"]
        case .userBack: ["You're back! I missed you!", "Welcome back!"]
        case .itemNear: ["Ooh! Is that for me?", "Is that a berry?!"]
        case .offline: ["Huh? The internet's gone…", "Uh oh… we're offline."]
        case .online: ["Phew, it's back!", "The internet's back!"]
        case .hot: ["It's so hot in here…", "Phew… your Mac's burning up."]
        case .deleted: ["Gone! Did you see that?", "All tidy now!"]
        case .celebrate: ["We did it! Woohoo!", "Great job, partner!"]
        case .failed: ["Ugh… let's try again.", "Oof… that didn't work."]
        case .done: ["All done! Great work!", "Finished! Nice one!"]
        case .hello: ["Hi there!", "Hello, partner!"]
        case .playing: ["Watch this!", "Hehe, this is fun!"]
        case .morning: ["Good morning! Ready for today?"]
        }
    }
}

extension Companion {
    /// One thing it might say right now, in its own voice.
    func line(_ moment: Moment) -> String? {
        guard let line = (voice[moment] ?? moment.lines).randomElement() else { return nil }
        return line.replacingOccurrences(of: "{name}", with: name).replacingOccurrences(of: "{cry}", with: cry)
    }

    /// Feel something and, when "Talks to you" is on, say it. `otherwise`: the caption it shows when it
    /// isn't talking (most moments have none).
    func chat(_ moment: Moment, _ face: Face, thought: CGImage? = nil, otherwise: String? = nil, for seconds: TimeInterval = 2.5) {
        let said = Setting.chatter.isOn ? line(moment) : nil
        feel(face, caption: said ?? otherwise, speaker: said == nil ? nil : name, thought: thought, for: said == nil ? seconds : max(seconds, 3))
    }
}
