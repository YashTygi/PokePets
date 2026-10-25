import SwiftUI

/// Every behaviour you can switch on or off. Stored in UserDefaults (so @AppStorage in the
/// Settings window and `isOn` in the brain read the same value).
enum Setting: String, CaseIterable {
    case relationship, faces, greetings, hunger, exploreFiles, music, awayNaps, hideOnCamera, heat, wifi,
         thunderbolt, breakReminder, overApps, notifications, downloadsGuard, chatter

    var isOn: Bool { UserDefaults.standard.bool(forKey: rawValue) }

    var title: String {
        switch self {
        case .relationship: "Feelings & friendship"
        case .faces: "Emotion portraits"
        case .greetings: "Greets your cursor"
        case .hunger: "Gets hungry"
        case .exploreFiles: "Climbs desktop files"
        case .music: "Dances to music"
        case .awayNaps: "Naps while you're away"
        case .hideOnCamera: "Hides during video calls"
        case .heat: "Feels the heat"
        case .wifi: "Notices Wi-Fi drops"
        case .thunderbolt: "Delete animation"
        case .breakReminder: "Break reminders"
        case .overApps: "Walks over your apps"
        case .notifications: "Notifications"
        case .downloadsGuard: "Downloads guard"
        case .chatter: "Talks to you"
        }
    }

    var detail: String {
        switch self {
        case .relationship: "Affection and friendship XP; cries when dropped too much. Off: always cheerful."
        case .faces: "Shows a portrait bubble when it feels something."
        case .greetings: "Turns to you with hearts when your cursor comes close."
        case .hunger: "About every half hour it comes and asks you for a berry: drag one onto it from the menu bar dial."
        case .exploreFiles: "Now and then climbs onto the files on your desktop."
        case .music: "Dances, twirls and rolls now and then while Apple Music or Spotify is playing."
        case .awayNaps: "Curls up when you leave the Mac for 5 minutes; wakes up glad when you're back."
        case .hideOnCamera: "Goes back into its Poké Ball while your camera is on, and comes back out after."
        case .heat: "Sweats and slows down when your Mac runs hot; faints if it overheats."
        case .wifi: "Looks worried when you lose the internet, cheers up when it's back."
        case .thunderbolt: "Select files in Finder and press ⌥⌘⌫ (or ⌥-drop a file on a Pokémon): the one out on your desktop deletes them with its move (Pikachu's Thunderbolt) into the Trash. While on, this replaces Finder's own ⌥⌘⌫ \"Delete Immediately\", so files land in the Trash instead of being erased."
        case .breakReminder: "After a long stretch of non-stop use it stretches and suggests a break."
        case .downloadsGuard: "Spots big downloads, duplicate copies and installers you're done with, and offers to delete them into the Trash (a notification: Delete or Keep). Asks once per file."
        case .chatter: "Says what it's thinking in a little speech bubble, in its own voice: \"What's that? What's that?\" when your cursor comes close, \"Oh, it's you! ♥\" when it sees it's you, \"I'm full!\" after a berry."
        case .notifications: "Tells you when it levels up, gets hungry, its ability activates, or is ready to evolve (Evolve or Not Now right from the notification)."
        case .overApps: "Stays in front of app windows. Goes behind them for full-screen windows and videos, YouTube, and the apps listed below. Off: only on the desktop."
        }
    }

    /// The sections of General settings and of the welcome guide.
    enum Group: String, CaseIterable {
        case `where` = "Where they can go", moving = "Moving around", deleting = "Deleting files",
             care = "Care and feelings", mac = "Your Mac", notifications = "Notifications"

        var note: String? {
            switch self {
            case .where: "They always stay behind full-screen windows, videos and YouTube, whatever you pick here."
            case .deleting: "Nothing is ever erased: every delete goes to the Trash, where you can get it back."
            default: nil
            }
        }
    }

    var group: Group {
        switch self {
        case .overApps: .where
        case .exploreFiles, .greetings: .moving
        case .thunderbolt, .downloadsGuard: .deleting
        case .relationship, .faces, .chatter, .hunger: .care
        case .music, .awayNaps, .hideOnCamera, .heat, .wifi, .breakReminder: .mac
        case .notifications: .notifications
        }
    }

    static let breakMinutesKey = "breakMinutes"

    /// Bundle IDs of apps it always stays behind, one per line.
    static let behindAppsKey = "behindApps"
    static var behindApps: [String] {
        (UserDefaults.standard.string(forKey: behindAppsKey) ?? "").split(separator: "\n").map(String.init)
    }

    /// Playful animations (SpriteCollab names) you can individually allow; on unless you switched it off.
    static func moveAllowed(_ name: String) -> Bool { UserDefaults.standard.object(forKey: "move." + name) as? Bool ?? true }

    static func registerDefaults() {
        var defaults: [String: Any] = Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0 != .breakReminder) })
        defaults[breakMinutesKey] = 60
        UserDefaults.standard.register(defaults: defaults)
        // The playful moves used to have our own names; keep what you switched off under SpriteCollab's.
        let d = UserDefaults.standard
        for (old, new) in ["Stretch": "DeepBreath", "Twirl": "Rotate", "Somersault": "Tumble", "Dance": "Double"]
            where d.object(forKey: "move." + old) != nil {
            if d.object(forKey: "move." + new) == nil { d.set(d.bool(forKey: "move." + old), forKey: "move." + new) }
            d.removeObject(forKey: "move." + old)
        }
    }
}

/// A snapshot of how your Pokémon is doing, for the dial's stats card and the Settings window.
struct PetStats {
    let name: String
    let gender: String               // ♂ / ♀
    let nature: Nature
    let ability: (name: String, effect: String)
    let shiny: Bool
    let alola: Bool
    enum Pokerus { case none, infected, cured }
    let pokerus: Pokerus
    let stage: Stage
    let level: Int
    let exp, nextLevelEXP: Double     // total EXP now, and needed for the next level
    let levelProgress: Double        // 0…1 towards the next level
    let friendship: Double           // 0…255
    let hunger, energy: Double       // 0…1
    let portrait: CGImage
    let canEvolve: Bool              // its evolution item works now
    let evolveItem: Item?            // Thunder Stone, Linking Cord…
    let known: Set<String>           // moves it knows
    var isEgg: Bool { stage == .egg }
}

/// What the Settings window can ask of one Pokémon.
struct PetControls: Identifiable {
    let id: String                  // its store prefix ("pet" is the Pichu line)
    let stats: () -> PetStats
    let animations: () -> [(name: String, anim: Anim)]   // every SpriteCollab animation it has
    let directions: (String) -> [Anim]                   // one animation in all eight directions
    let playful: () -> [String]                          // the ones with an "In routine" switch
    let perform: (String) -> Void   // play one animation on the desktop, by gallery name
    let restart: () -> Void         // start over with a new Egg
    let why: () -> (choice: Intent?, at: Date, options: [Option], needs: [(String, Double)])
}

enum SettingsWindow {
    private static var window: NSWindow?

    static func show(_ party: [PetControls]) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "PokePets"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(party: party))
            w.center()
            window = w
            // Free the SwiftUI views when closed: the app only pays for Settings while it's open.
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in
                window?.contentView = nil
                window = nil
            }
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// The six Pokémon PokePets is building towards, in party order. Ones without `PetControls` yet show
/// as "coming soon".
struct Roster {
    let id: String, name: String, type: String, blurb: String
    static let all = [
        Roster(id: "pet", name: "Pikachu", type: "Electric", blurb: "Climbs your desktop, zaps files with Thunderbolt."),
        Roster(id: "gengar", name: "Gengar", type: "Ghost / Poison", blurb: "Flies anywhere, sinks through windows, steals your cursor."),
        Roster(id: "typhlosion", name: "Typhlosion", type: "Fire", blurb: "Coming soon."),
        Roster(id: "pidgeot", name: "Pidgeot", type: "Normal / Flying", blurb: "Coming soon."),
        Roster(id: "alakazam", name: "Alakazam", type: "Psychic", blurb: "Coming soon."),
        Roster(id: "lapras", name: "Lapras", type: "Water / Ice", blurb: "Coming soon."),
    ]
}

private enum Page: Hashable { case party, general, credits, pokemon(String) }

private struct SettingsView: View {
    let party: [PetControls]
    @State private var page: Page? = {                      // dev: -PokeSettings general | credits | <store>
        switch UserDefaults.standard.string(forKey: "PokeSettings") {
        case nil, "party": .party
        case "general": .general
        case "credits": .credits
        case let id?: .pokemon(id)
        }
    }()

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Label("Party", systemImage: "circle.grid.3x3.fill").tag(Page.party)
                Label("General", systemImage: "gearshape").tag(Page.general)
                Section("Your Pokémon") {
                    ForEach(party) { member in
                        let s = member.stats()
                        Label {
                            Text(s.isEgg ? "Egg" : s.name)
                        } icon: {
                            Image(decorative: s.portrait, scale: 1).interpolation(.none).resizable()
                                .frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .tag(Page.pokemon(member.id))
                    }
                }
                Section {
                    Label("Credits", systemImage: "heart").tag(Page.credits)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch page ?? .party {
            case .party: PartyGrid(party: party) { page = .pokemon($0) }
            case .general: GeneralSettings()
            case .credits: CreditsView()
            case .pokemon(let id):
                if let member = party.first(where: { $0.id == id }) { PokemonView(controls: member).id(id) }
            }
        }
        .frame(minWidth: 700, minHeight: 560)
    }
}

/// All six party slots. Click one of yours to open its page.
private struct PartyGrid: View {
    let party: [PetControls]
    let open: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your party").font(.title2.weight(.semibold))
                        Text("Click a Pokémon for its stats, guide, animations and its own tricks. The rules every Pokémon follows are under General.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    ForEach(Roster.all, id: \.id) { slot in
                        if let member = party.first(where: { $0.id == slot.id }) {
                            Button { open(member.id) } label: { PartyCard(slot: slot, stats: member.stats()) }
                                .buttonStyle(.plain)
                        } else {
                            PartyCard(slot: slot, stats: nil)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct PartyCard: View {
    let slot: Roster, stats: PetStats?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.quaternary)
                if let s = stats {
                    Image(decorative: s.portrait, scale: 1).interpolation(.none).resizable()
                        .frame(width: 48, height: 48).clipShape(Circle())
                } else {
                    Image(systemName: "questionmark").font(.title2.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                if let s = stats {
                    Text(s.isEgg ? "\(slot.name) · Egg" : "\(s.name) \(s.gender)\(s.shiny ? " ★" : "")").font(.headline)
                    Text(s.isEgg ? "Waiting to hatch in the dial" : "Lv \(s.level) · \(slot.type)").font(.caption).foregroundStyle(.secondary)
                    if !s.isEgg { ProgressView(value: s.friendship / Growth.maxFriendship).tint(.pink).controlSize(.small) }
                } else {
                    Text(slot.name).font(.headline).foregroundStyle(.secondary)
                    Text(slot.type).font(.caption).foregroundStyle(.tertiary)
                }
                Text(slot.blurb).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            if stats != nil { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(RoundedRectangle(cornerRadius: 14).fill(stats == nil ? AnyShapeStyle(.quinary) : AnyShapeStyle(.quaternary)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(hovering && stats != nil ? Color.yellow : .clear, lineWidth: 2))
        .opacity(stats == nil ? 0.6 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// One Pokémon's own page: its stats and tricks, animations, guide and brain.
private struct PokemonView: View {
    let controls: PetControls
    @State private var tab = UserDefaults.standard.integer(forKey: "PokeSettingsTab")   // dev: -PokeSettingsTab 1

    var body: some View {
        TabView(selection: $tab) {
            Form {
                StatsSection(controls: controls)
                SignatureSection(controls: controls)
            }
            .formStyle(.grouped)
            .tabItem { Label("Pokémon", systemImage: "bolt.fill") }.tag(0)

            Gallery(controls: controls)
                .tabItem { Label("Animations", systemImage: "film.stack") }.tag(1)

            Guide(controls: controls)
                .tabItem { Label("Guide", systemImage: "book") }.tag(2)

            WhyView(controls: controls)
                .tabItem { Label("Why?", systemImage: "brain") }.tag(3)
        }
        .padding(.top, 8)
    }
}

/// What only this Pokémon does, and its own switches.
private struct SignatureSection: View {
    let controls: PetControls

    var body: some View {
        switch controls.id {
        case "pet":
            Section {
                RegionPicker()
                Fact(icon: "bolt", title: "Thunderbolt", detail: "Its delete move: a bolt from its body to the file. With Thunder, files not on screen are struck from the sky.")
                Fact(icon: "battery.100.bolt", title: "Lightning Rod", detail: Growth.abilityEffect)
                Fact(icon: "wind", title: "Alolan Raichu", detail: "Surge Surfer (surfs faster while charging), floats about in open air and teleports next to your cursor.")
            } header: {
                Text("Pikachu's own tricks")
            }
        case "gengar":
            Section {
                Fact(icon: "wind", title: "Levitate · free flight", detail: "Flies anywhere on your screen in hopping arcs, hovers with its tongue out, and drifts back down. Never falls when you drop it. Gastly and Haunter float everywhere; Gengar walks short hops on the floor too.")
                Fact(icon: "circle.dotted.circle", title: "Shadow Ball", detail: "Its file delete: charges a Shadow Ball, throws it at the file's icon, the file is sucked into the shadow (to the Trash), and it eats the wisp that's left.")
                KeyToggle(key: Gengar.phaseKey) {
                    Text("Sinks into your window")
                    Text("Flies to the window you're working in, sinks into it, and pops its head up along an edge with its tongue out. Only where it may be in front of your apps (never full-screen apps, videos, YouTube or apps you listed in General).")
                }
                Fact(icon: "link", title: "Linking Cord", detail: "Haunter evolves into Gengar with a Linking Cord from the dial (in the games: by trading).")
            } header: {
                Text("Gengar's own tricks")
                KeyToggle(key: Gengar.lickKey) {
                    Text("Licks your screen")
                    Text("Comes right up to the glass, licks it with its tongue (Lick) and leaves a wet smear that drips and fades after a few seconds.")
                }
                KeyToggle(key: Gengar.snatchKey) {
                    Text("Steals your cursor")
                    Text("Gengar only. When your mouse sits untouched for a minute and a half, it grabs your cursor (a fake: the real one is just hidden), tugs it, and flies off with it. Touch the mouse or trackpad and it's yours again at once: \"Peek-a-boo!\"")
                }
                KeyToggle(key: Gengar.shadowKey) {
                    Text("Shadow tricks")
                    Text("Bursts into shadow clones (\"Which one's the real me?\"), leaves a trail of them when it flies far, and its own shadow runs off and swaps places with it.")
                }
                KeyToggle(key: Gengar.prankKey) {
                    Text("Pranks")
                    Text("Tickles your Dock, tries to drag your window away by its corner (it's too heavy), or pats ghostly handprints across your screen that fade after a few seconds.")
                }
                KeyToggle(key: Gengar.nightKey) {
                    Text("Ghost hour")
                    Text("From 7 pm to 6 am, or whenever your Mac is in dark mode, it glows a faint purple and gets up to much more mischief (and naps less).")
                }
            } footer: {
                Text("Gastly, Haunter and Gengar all lick; only Gengar has the Pull to steal your cursor.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }
}

/// A switch for one of a Pokémon's own tricks (stored under its key; on unless you switch it off).
private struct KeyToggle<Label: View>: View {
    @AppStorage private var on: Bool
    let label: () -> Label
    init(key: String, @ViewBuilder label: @escaping () -> Label) {
        _on = AppStorage(wrappedValue: true, key)
        self.label = label
    }
    var body: some View { Toggle(isOn: $on, label: label) }
}

/// The rules every Pokémon follows, grouped like the welcome guide.
struct GeneralSettings: View {
    var body: some View {
        Form {
            ForEach(Setting.Group.allCases, id: \.self) { group in
                Section {
                    ForEach(Setting.allCases.filter { $0.group == group }, id: \.self) { SettingToggle(setting: $0) }
                    if group == .mac { BreakMinutes() }
                } header: {
                    Text(group.rawValue)
                } footer: {
                    if let note = group.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                }
                if group == .where { BehindApps() }
            }
            FocusSection()
            Section {
                Button("Show the Welcome Guide Again…") { Onboarding.show(again: true) {} }
            }
        }
        .formStyle(.grouped)
    }
}

struct SettingToggle: View {
    let setting: Setting
    @AppStorage private var isOn: Bool

    init(setting: Setting) {
        self.setting = setting
        _isOn = AppStorage(wrappedValue: true, setting.rawValue)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(setting.title)
            Text(setting.detail)
        }
    }
}

/// Apps it always stays behind (it walks over all the others).
struct BehindApps: View {
    @AppStorage(Setting.behindAppsKey) private var raw = ""
    @AppStorage(Setting.overApps.rawValue) private var overApps = true
    private var ids: [String] { raw.split(separator: "\n").map(String.init) }

    var body: some View {
        Section {
            ForEach(ids, id: \.self) { id in
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                HStack {
                    if let url { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20) }
                    Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? id)
                    Spacer()
                    Button { raw = ids.filter { $0 != id }.joined(separator: "\n") } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                }
            }
            Button("Add App…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.allowsMultipleSelection = true
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                guard panel.runModal() == .OK else { return }
                let new = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }.filter { !ids.contains($0) }
                raw = (ids + new).joined(separator: "\n")
            }
        } header: {
            Text("Stays behind these apps")
        } footer: {
            Text("While one of these is in front, your Pokémon stays behind its windows, as it does for full-screen windows, videos and YouTube.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(!overApps)
    }
}

/// Focus: it sleeps while a Focus is on. macOS keeps Focus private to entitled apps, so two Shortcuts
/// automations per Focus tell it (Focus on → pokepets://focus, off → pokepets://unfocus).
private struct FocusSection: View {
    @AppStorage("focus.on") private var quiet = false

    var body: some View {
        Section {
            LabeledContent("Right now", value: quiet ? "Asleep: a Focus is on" : "Awake")
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up once for each Focus you use (Do Not Disturb, Work, Fitness…):").font(.callout)
                Text("1. Shortcuts › Automation › New Automation › Focus › pick the Focus › “When Turning On” › Run Immediately.")
                Text("2. Add the “Open URLs” action with  pokepets://focus")
                Text("3. Make another for “When Turning Off” with  pokepets://unfocus")
            }
            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            HStack {
                Button("Open Shortcuts") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app")) }
                Spacer()
                Button(quiet ? "Wake It Up" : "Quiet Now") { NSWorkspace.shared.open(URL(string: quiet ? "pokepets://unfocus" : "pokepets://focus")!) }
            }
        } header: {
            Text("Focus")
        } footer: {
            Text("While a Focus is on it sleeps and stays quiet: no greetings, asking for berries, break reminders or reactions to hooks. It wakes when the Focus ends.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct BreakMinutes: View {
    @AppStorage(Setting.breakMinutesKey) private var minutes = 60
    @AppStorage(Setting.breakReminder.rawValue) private var enabled = false

    var body: some View {
        Stepper("Remind me after \(minutes) minutes", value: $minutes, in: 15...180, step: 15)
            .disabled(!enabled)
    }
}

private struct StatsSection: View {
    let controls: PetControls

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            let s = controls.stats()
            Section {
                HStack(spacing: 16) {
                    Image(decorative: s.portrait, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 6) {
                        if s.isEgg {
                            Text("Egg").font(.title3.weight(.semibold))
                            Text("Something is moving inside! Click it in the menu bar dial to hatch it.").font(.caption)
                        } else {
                            Text("\(s.name) \(s.gender)\(s.shiny ? " ★" : "")  ·  Lv \(s.level)").font(.title3.weight(.semibold))
                            Text("\(s.nature.name) nature · Ability: \(s.ability.name) · \(s.stage.growthRate.name) growth"
                                 + (s.pokerus == .infected ? " · Pokérus (EXP ×2)" : s.pokerus == .cured ? " · Pokérus cured" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: s.levelProgress) {
                                Text("EXP \(Int(s.exp).formatted()) / \(Int(s.nextLevelEXP).formatted())").font(.caption)
                            }
                            if s.canEvolve, let item = s.evolveItem { Text("Ready to evolve: drag the \(item.name) from the menu bar dial onto it.").font(.caption) }
                        }
                    }
                }
                Meter(title: "Friendship  \(Int(s.friendship)) / 255", value: s.friendship / Growth.maxFriendship, tint: .pink)
                Meter(title: "Belly", value: 1 - s.hunger, tint: .orange)
                Meter(title: "Energy", value: s.energy, tint: .yellow)
            }
        }
    }
}

private struct Meter: View {
    let title: String, value: Double, tint: Color
    var body: some View {
        LabeledContent(title) { ProgressView(value: value).tint(tint).frame(width: 220) }
    }
}

/// Every animation SpriteCollab has for this Pokémon, under the site's names, turning through all eight
/// directions like the site does, with a button to make your Pokémon do it on the desktop and, for its
/// playful moves, a switch to allow it in its daily routine.
private struct Gallery: View {
    let controls: PetControls

    var body: some View {
        let playful = controls.playful()
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(controls.animations(), id: \.name) { item in
                    VStack(spacing: 6) {
                        AnimPreview(directions: controls.directions(item.name)).frame(width: 120, height: 110)
                        Text(item.name).font(.callout.weight(.medium))
                        Button("Play") { controls.perform(item.name) }
                        if playful.contains(item.name) { MoveToggle(name: item.name) } else { Spacer(minLength: 20) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
                }
            }
            .padding()
        }
    }
}

private struct MoveToggle: View {
    @AppStorage private var allowed: Bool
    init(name: String) { _allowed = AppStorage(wrappedValue: true, "move." + name) }
    var body: some View { Toggle("In routine", isOn: $allowed).toggleStyle(.switch).controlSize(.mini).font(.caption) }
}

/// One animation looping on the GPU (nearest-neighbour pixels), facing each of its directions in turn,
/// at least a second each, like the SpriteCollab site.
private struct AnimPreview: NSViewRepresentable {
    let directions: [Anim]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        guard let first = directions.first else { return view }
        let base = directions[min(Anim.right, directions.count - 1)]   // one floor line for every direction
        let sprite = CALayer()
        sprite.contents = first.image
        sprite.contentsRect = first.frames[0]
        sprite.magnificationFilter = .nearest
        let scale = min(2, 110 / first.frameSize.height)
        sprite.bounds = CGRect(x: 0, y: 0, width: first.frameSize.width * scale, height: first.frameSize.height * scale)
        sprite.anchorPoint = CGPoint(x: 0.5, y: (base.frameSize.height / 2 - base.feet) / base.frameSize.height)
        sprite.position = CGPoint(x: 60, y: 22)                              // every sprite stands on the same floor
        var images: [Any] = [], rects: [Any] = []
        for anim in directions {
            let loops = max(1, Int((1.2 / max(anim.duration, 0.05)).rounded(.up)))
            for _ in 0..<loops {
                for rect in anim.frames { images.append(anim.image); rects.append(rect) }
            }
        }
        let step = (directions.first.map { $0.duration / Double($0.frames.count) }) ?? 0.1
        let total = step * Double(rects.count)
        func track(_ key: String, _ values: [Any]) -> CAKeyframeAnimation {
            let k = CAKeyframeAnimation(keyPath: key)
            k.values = values
            k.calculationMode = .discrete
            return k
        }
        let loop = CAAnimationGroup()
        loop.animations = [track("contents", images), track("contentsRect", rects)]
        loop.duration = total
        loop.repeatCount = .infinity
        loop.isRemovedOnCompletion = false
        sprite.add(loop, forKey: "loop")
        view.layer?.addSublayer(sprite)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// How it all works, on four short pages: evolution, growth, traits, moves.
private struct Guide: View {
    let controls: PetControls
    private enum Page: String, CaseIterable { case evolution = "Evolution", growth = "Growth", traits = "Traits", moves = "Moves" }
    @State private var page = Page.evolution
    private var ghost: Bool { controls.id == "gengar" }        // the Gastly line (an Egg doesn't know yet)

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 4)

            TimelineView(.periodic(from: .now, by: 3)) { _ in
                let s = controls.stats()
                Form {
                    switch page {
                    case .evolution: EvolutionPage(s: s, ghost: ghost, restart: controls.restart)
                    case .growth: GrowthPage(s: s)
                    case .traits: TraitsPage(s: s, ghost: ghost)
                    case .moves: MovesPage(s: s, ghost: ghost)
                    }
                }
                .formStyle(.grouped)
            }
        }
    }
}

/// One tidy line of the guide: an icon, a title, a short explanation, and an optional value on the right.
private struct Fact: View {
    let icon: String, title: String, detail: String
    var value: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let value { Text(value).font(.callout.weight(.medium)).multilineTextAlignment(.trailing) }
        }
        .padding(.vertical, 2)
    }
}

private struct EvolutionPage: View {
    let s: PetStats, ghost: Bool, restart: () -> Void
    @State private var confirmRestart = false

    var body: some View {
        if ghost { ghostLine } else { pichuLine }
        if !s.isEgg {
            let dex = Growth.pokedex(s.stage, alola: s.alola)
            Section("Pokédex · \(s.name)") {
                Fact(icon: "book.closed", title: "The \(dex.genus) · \(dex.type)", detail: dex.entries.last?.text ?? "")
            }
        }
        Section {
            Button("Start over with a new Egg…", role: .destructive) { confirmRestart = true }
                .confirmationDialog("Start over with a new Egg?", isPresented: $confirmRestart) {
                    Button("Start Over", role: .destructive) { restart() }
                } message: {
                    Text("\(s.name) (Lv \(s.level)) goes away for good, and a new Egg appears in the dial.")
                }
        }
    }

    @ViewBuilder private var ghostLine: some View {
        Section {
            HStack(spacing: 6) {
                StageChip(stage: .egg, current: s.stage, line: Stage.gengar.line)
                Arrow(text: "Hatch")
                StageChip(stage: .gastly, current: s.stage)
                Arrow(text: "Lv \(GengarLine.haunterLevel)")
                StageChip(stage: .haunter, current: s.stage)
                Arrow(text: "Linking Cord")
                StageChip(stage: .gengar, current: s.stage)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        Section("How it evolves") {
            Fact(icon: "oval.portrait", title: "Egg → Gastly", detail: "Click the Egg in the menu bar dial.")
            Fact(icon: "arrow.up.circle", title: "Gastly → Haunter", detail: "Reaching Lv \(GengarLine.haunterLevel), as in the games. It asks you first: Evolve or Not Now.",
                 value: s.stage == .gastly ? "Lv \(s.level) / \(GengarLine.haunterLevel)" : nil)
            Fact(icon: "link", title: "Haunter → Gengar",
                 detail: "In the games Haunter evolves when traded. Here: drag the Linking Cord from the dial's tray onto it (it appears there once it's a Haunter).",
                 value: s.stage == .haunter ? "Ready!" : nil)
        }
    }

    @ViewBuilder private var pichuLine: some View {
        Section {
            HStack(spacing: 6) {
                StageChip(stage: .egg, current: s.stage)
                Arrow(text: "Hatch")
                StageChip(stage: .pichu, current: s.stage)
                Arrow(text: "Friendship 220")
                StageChip(stage: .pikachu, current: s.stage)
                Arrow(text: "Thunder Stone")
                VStack(spacing: 6) {
                    StageChip(stage: .raichu, current: s.alola ? .pikachu : s.stage)
                    StageChip(stage: .raichu, current: s.stage, alola: true, reached: s.alola)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        Section("How it evolves") {
            Fact(icon: "oval.portrait", title: "Egg → Pichu", detail: "Click the Egg in the menu bar dial.")
            Fact(icon: "heart", title: "Pichu → Pikachu", detail: "Levels up with friendship 220 or more, as in the games. It asks you first: Evolve or Not Now.",
                 value: s.stage == .pichu ? "\(Int(s.friendship)) / 220" : nil)
            Fact(icon: "bolt", title: "Pikachu → Raichu",
                 detail: "Drag a Thunder Stone onto it, then choose Evolve. The stone appears in the dial's tray from Lv \(Growth.thunderStoneLevel).",
                 value: s.stage == .pikachu ? (s.canEvolve ? "Ready!" : "Lv \(s.level) / \(Growth.thunderStoneLevel)") : nil)
            Fact(icon: "globe.asia.australia", title: "Region",
                 detail: "Kanto gives Raichu, Alola gives Alolan Raichu. Set it under Pokémon › Region.",
                 value: Region.current.name)
        }
    }
}

private struct GrowthPage: View {
    let s: PetStats

    var body: some View {
        Section("Levels") {
            Fact(icon: "chart.line.uptrend.xyaxis", title: "Real levels, 1 to 100",
                 detail: "\(s.stage.growthRate.name) growth: Lv 100 takes \(Int(s.stage.growthRate.exp(forLevel: 100)).formatted()) EXP in total, as in the games.",
                 value: s.isEgg ? nil : "Lv \(s.level)")
            Fact(icon: "clock", title: "Earned by spending time together",
                 detail: "Up to 2 % of a level per minute while it's out and awake (about 50 min a level). Slower when friendship is low; half speed when tired or on low battery.")
            Fact(icon: "pause.circle", title: "No EXP while…", detail: "it's in its ball, napping because you're away, or still an Egg.")
        }
        Section("Bonus EXP (share of a level)") {
            ForEach([("Petting (once per 15 min)", "3 %"), ("A berry", "8 %"), ("A berry it likes", "15 %"), ("Playing", "4 %"),
                     ("Exploring a file", "3 %"), ("Zapping a file", "10 %"), ("Dev hook: celebrate", "5 %")], id: \.0) {
                LabeledContent($0.0, value: $0.1)
            }
        }
        Section("Friendship · \(Int(s.friendship)) / 255") {
            ForEach([("Hatching", "starts at 120"), ("Petting, once per 15 min", "+2 (+3 with Nuzzle)"), ("A berry", "+2 (liked +4, disliked +1)"),
                     ("Levelling up", "+2"), ("Full", "belly over 85 % (a berry fills ~⅓)"), ("Hungry 8 h while you're on", "−10"), ("Coming back after being away", "+1"), ("Dropped hard", "−10")], id: \.0) {
                LabeledContent($0.0, value: $0.1)
            }
        }
        Section("Growth rates") {
            ForEach(GrowthRate.allCases, id: \.self) { rate in
                LabeledContent {
                    Text("\(String(format: "%.2g", rate.speed))× pace").monospacedDigit()
                } label: {
                    Text(rate.name).fontWeight(rate == s.stage.growthRate ? .bold : .regular)
                    Text("Lv 100 at \(Int(rate.exp(forLevel: 100)).formatted()) EXP")
                }
            }
        }
    }
}

private struct TraitsPage: View {
    let s: PetStats, ghost: Bool

    var body: some View {
        Section("Yours") {
            Fact(icon: "bolt.circle", title: "Ability · \(s.ability.name)", detail: s.ability.effect)
            Fact(icon: "person.2", title: "Gender", detail: "50 % ♂ / 50 % ♀, set when it hatches.", value: s.isEgg ? "?" : s.gender)
            Fact(icon: "sparkles", title: "Shiny", detail: "1 in \(Growth.shinyOdds.formatted()) Eggs. Different colours, stars at hatching, ★ by its name.",
                 value: s.isEgg ? "?" : s.shiny ? "Yes ★" : "No")
            Fact(icon: "cross.case", title: "Pokérus",
                 detail: "Rare (about 1 in 21,845). Doubles EXP for 1–4 days, then it's cured for good.",
                 value: s.pokerus == .infected ? "Active · EXP ×2" : s.pokerus == .cured ? "Cured" : "Never")
        }
        Section("Nature · \(s.isEgg ? "set when it hatches" : s.nature.name)") {
            if !s.isEgg {
                Fact(icon: "theatermasks", title: s.nature.name,
                     detail: s.nature.effect + (s.nature.likes.map { " Likes \($0.rawValue.lowercased()) berries" } ?? "")
                         + (s.nature.dislikes.map { ", dislikes \($0.rawValue.lowercased())." } ?? ""))
            }
            Fact(icon: "leaf", title: "Berry flavours", detail: "Cheri spicy · Aspear sour · Pecha sweet · Chesto dry · Rawst bitter · Oran any")
            DisclosureGroup("All 25 natures") {
                ForEach(Nature.all, id: \.self) { n in
                    LabeledContent {
                        Text(n.effect).font(.caption).foregroundStyle(.secondary)
                    } label: {
                        Text(n.name).fontWeight(n == s.nature && !s.isEgg ? .bold : .regular)
                        Text(n.up.map { "+\($0.rawValue) −\(n.down!.rawValue) · likes \(n.likes!.rawValue)" } ?? "Neutral")
                    }
                }
            }
        }
        if !ghost {
            Section("Alolan Raichu") {
                Fact(icon: "wind", title: Growth.alolaAbility, detail: Growth.alolaAbilityEffect)
                Fact(icon: "sparkle", title: "Psychic", detail: "Floats about in open air and teleports next to your cursor now and then.")
            }
        }
    }
}

private struct MovesPage: View {
    let s: PetStats, ghost: Bool
    @State private var form: String?

    var body: some View {
        let forms = ghost ? GuideForm.ghosts : GuideForm.all
        let yours = forms.first { $0.stage == s.stage && $0.alola == s.alola } ?? forms[0]
        let shown = forms.first { $0.id == form } ?? yours
        Section {
            Picker("Pokémon", selection: Binding(get: { shown.id }, set: { form = $0 })) {
                ForEach(forms) { Text($0.name + ($0.id == yours.id ? " (yours)" : "")).tag($0.id) }
            }
            Text("Real Scarlet/Violet level-up moves. ✓ means yours knows it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        MovesSection(form: shown, stats: s)
    }
}

private struct StageChip: View {
    let stage: Stage, current: Stage
    var alola = false
    var reached: Bool? = nil
    var line: [Stage]? = nil                    // for the Egg chip, which belongs to every line
    var body: some View {
        let line = self.line ?? stage.line
        let reached = self.reached ?? ((line.firstIndex(of: stage) ?? 0) <= (line.firstIndex(of: current) ?? 0))
        VStack(spacing: 4) {
            Image(decorative: portrait, scale: 1).interpolation(.none).resizable()
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
                .saturation(reached ? 1 : 0).opacity(reached ? 1 : 0.5)
            Text(alola ? "Alolan Raichu" : stage.name).font(.caption.weight(isCurrent ? .bold : .regular))
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10).stroke(isCurrent ? Color.yellow : .clear, lineWidth: 2))
    }
    private var isCurrent: Bool { stage == current && (reached ?? true) }
    private var portrait: CGImage {
        stage == .egg ? Pixels.eggPortrait
            : NSImage(named: "\(stage.rawValue)\(alola ? "-alola" : "")-face-happy")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    }
}

private struct Arrow: View {
    let text: String
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.right")
            Text(text).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(width: 70)
    }
}

private struct MoveRow: View {
    let move: Move, known: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: known ? "checkmark.circle.fill" : "circle").foregroundStyle(known ? .green : .secondary)
            Text("Lv \(move.level)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(move.name).font(.callout.weight(.medium))
                if let effect = move.effect { Text(effect).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if move.effect == nil { Text("Battle only").font(.caption).foregroundStyle(.tertiary) }
        }
    }
}

private struct RegionPicker: View {
    @AppStorage("region") private var region = Region.kanto.rawValue
    var body: some View {
        Picker(selection: $region) {
            ForEach(Region.allCases, id: \.self) { Text($0.name).tag($0.rawValue) }
        } label: {
            Text("Region")
            Text("Where it lives decides which Raichu a Thunder Stone makes. Alola gives Alolan Raichu.")
        }
    }
}

/// The forms the Guide covers.
private struct GuideForm: Identifiable {
    let stage: Stage, alola: Bool
    var id: String { stage.rawValue + (alola ? "-alola" : "") }
    var name: String { alola ? "Alolan Raichu" : stage.name }
    static let all = [GuideForm(stage: .pichu, alola: false), GuideForm(stage: .pikachu, alola: false),
                      GuideForm(stage: .raichu, alola: false), GuideForm(stage: .raichu, alola: true)]
    static let ghosts = [GuideForm(stage: .gastly, alola: false), GuideForm(stage: .haunter, alola: false), GuideForm(stage: .gengar, alola: false)]
}

private struct MovesSection: View {
    let form: GuideForm, stats: PetStats
    var body: some View {
        let moves = (Growth.moves + GengarLine.moves).filter { $0.stage == form.stage && $0.alola == form.alola }
        let isYours = stats.stage == form.stage && stats.alola == form.alola
        Section("\(form.name)'s moves") {
            ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                MoveRow(move: move, known: isYours && stats.known.contains(move.name))
            }
        }
    }
}

/// Every artist whose work PokePets uses, from PMD SpriteCollab's own credits (credits.json, generated
/// from each sprite set's credits.txt and its credit_names.txt).
private struct CreditsView: View {
    private struct Entry: Decodable {
        let artist, contact, set, kind, license, source: String
        let parts: [String]
    }

    private let artists: [(name: String, contact: String, entries: [Entry])] = {
        guard let url = Bundle.main.url(forResource: "credits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        let grouped = Dictionary(grouping: entries) { $0.artist }
        return grouped.map { ($0.key, $0.value[0].contact, $0.value) }
            .sorted { ($0.name == "CHUNSOFT" ? 1 : 0, $0.name.lowercased()) < ($1.name == "CHUNSOFT" ? 1 : 0, $1.name.lowercased()) }
    }()

    var body: some View {
        Form {
            Section {
                Text("All Pokémon sprites and portraits come from **PMD SpriteCollab**, a community project of pixel artists. Thank you to every artist below.")
                Link("sprites.pmdcollab.org", destination: URL(string: "https://sprites.pmdcollab.org")!)
            }
            ForEach(artists, id: \.name) { artist in
                Section {
                    ForEach(Array(artist.entries.enumerated()), id: \.offset) { _, e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(e.set) · \(e.kind)").font(.callout.weight(.medium))
                            Text(e.parts.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                            Text(e.license).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    HStack {
                        Text(artist.name)
                        Spacer()
                        if let url = Self.link(artist.contact) { Link(url.host() ?? "Link", destination: url).font(.caption) }
                    }
                }
            }
            Section("Also") {
                Text("Pokémon data (learnsets, growth rates, natures, Pokédex text): PokeAPI.")
                Link("pokeapi.co", destination: URL(string: "https://pokeapi.co")!)
                Text("Egg, berries, Thunder Stone, Poké Ball, hearts and sparks: pixel art made for PokePets.")
                Text("Pokémon © Nintendo, Creatures Inc., GAME FREAK inc. PokePets is an unofficial fan project, not for sale.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Turn a contact into a link: URLs as they are, "@name.bsky.social" into a Bluesky profile.
    private static func link(_ contact: String) -> URL? {
        let c = contact.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
        if c.hasPrefix("http") { return URL(string: c) }
        if c.hasPrefix("@"), c.contains(".") { return URL(string: "https://bsky.app/profile/" + c.dropFirst()) }
        return nil
    }
}

/// The utility AI, live: what it's doing, how it feels, and how every option scored last time it decided.
private struct WhyView: View {
    let controls: PetControls

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { context in
            let why = controls.why()
            Form {
                Section("Right now") {
                    if let choice = why.choice {
                        LabeledContent(choice.label) {
                            Text("decided \(Int(context.date.timeIntervalSince(why.at)))s ago").foregroundStyle(.secondary)
                        }
                    } else {
                        Text("It hasn't decided anything yet (an Egg, in its ball, or busy).").foregroundStyle(.secondary)
                    }
                    Text("Each time it finishes something, every option below gets a score: its considerations multiplied together. It picks the best (randomly among options within 15 % of the best), skips things it did recently, and leans towards carrying on with what it was doing. Being petted, picked up, fed or plugged in interrupts it right away.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("How it feels") {
                    ForEach(why.needs, id: \.0) { need in
                        LabeledContent(need.0) {
                            ProgressView(value: min(1, max(0, need.1))).frame(width: 200)
                        }
                    }
                }
                Section("Options, best first") {
                    ForEach(Array(why.options.enumerated()), id: \.offset) { _, option in
                        OptionRow(option: option, chosen: option.intent == why.choice)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct OptionRow: View {
    let option: Option, chosen: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(option.intent.label).font(.callout.weight(chosen ? .bold : .regular))
                if chosen { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                Spacer()
                Text(String(format: "%.2f", option.score)).font(.callout.monospacedDigit())
            }
            ProgressView(value: min(1, option.score)).tint(chosen ? .green : .accentColor)
            Text(option.reasons.map { "\($0.0) \(String(format: "%.2f", $0.1))" }.joined(separator: " × "))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
