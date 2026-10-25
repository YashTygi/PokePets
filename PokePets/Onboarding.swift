import SwiftUI
import UserNotifications

/// The welcome guide, shown once on first launch (and from General settings). It walks through the
/// rules every Pokémon follows, one group at a time, with each switch right there to turn on or off
/// and each permission explained before macOS asks for it. Each Pokémon's own tricks are on its page.
enum Onboarding {
    static var done: Bool { UserDefaults.standard.bool(forKey: "onboarded") }
    private static var window: NSWindow?
    /// Run once the guide is finished (or closed): things that make macOS ask for permission wait for it,
    /// so every prompt comes after it's been explained.
    static var whenDone: [() -> Void] = []

    private static func markDone() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        let waiting = whenDone
        whenDone = []
        waiting.forEach { $0() }
    }

    /// `f` now if the guide is done, otherwise as soon as it is.
    static func afterGuide(_ f: @escaping () -> Void) { done ? f() : whenDone.append(f) }

    /// `finished`: called after the last page (the app opens the party screen).
    static func show(again: Bool = false, finished: @escaping () -> Void) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: OnboardingView {
                markDone()
                window?.close()
                if !again { finished() }
            })
            w.center()
            window = w
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in
                markDone()                                               // closing it early counts too: no nagging
                window?.contentView = nil
                window = nil
            }
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct OnboardingView: View {
    let finish: () -> Void
    private enum Step: Int, CaseIterable { case welcome, where_, moving, deleting, care, mac, notifications, party }
    @State private var step = Step(rawValue: UserDefaults.standard.integer(forKey: "PokeWelcomePage")) ?? .welcome   // dev: -PokeWelcomePage 3

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case .welcome: Welcome()
                    case .where_: GroupPage(group: .where, icon: "macwindow.on.rectangle",
                                            text: "Your Pokémon live on a see-through layer over your screen. You choose whether they walk over your app windows or only on the desktop, and which apps they always stay behind.",
                                            extra: AnyView(BehindApps()),
                                            permission: "To tell when you're watching YouTube, macOS asks once per browser whether PokePets may read its address bar. Saying no just means they won't hide for YouTube in that browser.")
                    case .moving: GroupPage(group: .moving, icon: "figure.walk",
                                            text: "They walk along the bottom of the screen, hop onto the Dock, climb your desktop files and come over to your cursor.",
                                            extra: AnyView(PermissionRow.finder),
                                            permission: nil)
                    case .deleting: GroupPage(group: .deleting, icon: "trash",
                                              text: "Select files in Finder and press ⌥⌘⌫, or ⌥-drop them onto a Pokémon: the one out on your desktop deletes them with its own move, aimed at the file's icon.",
                                              extra: AnyView(PermissionRow.accessibility),
                                              permission: nil)
                    case .care: GroupPage(group: .care, icon: "heart", text: "They have feelings, get hungry, and grow with real levels and friendship. Feed them berries from the menu bar dial. Turn these off for a pet that's always cheerful and never asks for anything.", extra: nil, permission: nil)
                    case .mac: GroupPage(group: .mac, icon: "laptopcomputer", text: "They notice what's going on around them: music playing, your camera turning on, the battery, heat, Wi-Fi, and you stepping away.", extra: AnyView(BreakMinutes()), permission: nil)
                    case .notifications: GroupPage(group: .notifications, icon: "bell.badge", text: "A notification when a Pokémon levels up, gets hungry, its ability activates, or is ready to evolve (with Evolve and Not Now right in it).", extra: AnyView(PermissionRow.notifications), permission: nil)
                    case .party: MeetParty()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 44)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                if step != .welcome { Button("Back") { step = Step(rawValue: step.rawValue - 1)! } }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.self) { s in
                        Circle().fill(s == step ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step == .party {
                    Button("Open My Party", action: finish).keyboardShortcut(.defaultAction)
                } else {
                    Button(step == .welcome ? "Get Started" : "Next") { step = Step(rawValue: step.rawValue + 1)! }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 640, height: 600)
    }
}

private struct Welcome: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 128, height: 128)
            Text("Welcome to PokePets").font(.largeTitle.weight(.bold))
            Text("Pokémon that live on your desktop: they roam, play, nap, get hungry, grow and evolve, and help tidy your files.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: 12) {
            Point(icon: "circle.circle", title: "The Poké Ball in your menu bar",
                  text: "Click it for your party: send a Pokémon out, call it back, see how it's doing, drag a berry onto it. Right-click it for Settings and Quit.")
            Point(icon: "slider.horizontal.3", title: "First, the house rules",
                  text: "The next pages set up what every Pokémon may do: where it can go, deleting files, feelings, and what it notices on your Mac. Everything can be changed later in Settings › General.")
            Point(icon: "sparkles", title: "Then, each Pokémon's own tricks",
                  text: "What only one Pokémon does (Pikachu's Thunderbolt, Gengar's pranks…) is explained on its own page in Settings.")
        }
    }
}

/// One group of settings: an explanation, its switches, and anything it needs from macOS.
private struct GroupPage: View {
    let group: Setting.Group, icon: String, text: String
    let extra: AnyView?
    let permission: String?

    var body: some View {
        Label(group.rawValue, systemImage: icon).font(.title.weight(.bold))
        Text(text).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        Form {
            Section {
                ForEach(Setting.allCases.filter { $0.group == group }, id: \.self) { SettingToggle(setting: $0) }
            } footer: {
                if let note = group.note { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
            if let extra { extra }
            if let permission {
                Section { Text(permission).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(minHeight: 260)
    }
}

/// A permission macOS asks for, explained, with a button to ask now.
private struct PermissionRow: View {
    let title: String, why: String, button: String
    let granted: () -> Bool
    let ask: () -> Void
    @State private var refresh = 0

    var body: some View {
        Section {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(why).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                let _ = refresh
                if granted() {
                    Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
                } else {
                    Button(button) { ask(); DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { refresh += 1 } }
                }
            }
        } header: {
            Text("Permission")
        }
    }

    static let finder = PermissionRow(
        title: "Desktop files", why: "To climb your desktop files, PokePets asks Finder where they are. macOS asks you once.",
        button: "Ask Now", granted: { UserDefaults.standard.bool(forKey: "onboarding.finderAsked") },
        ask: {
            _ = StageWindow.desktopIcons(screenHeight: NSScreen.main?.frame.height ?? 0)
            UserDefaults.standard.set(true, forKey: "onboarding.finderAsked")
        })

    static let accessibility = PermissionRow(
        title: "Accessibility (optional)",
        why: "Lets it aim exactly at a file's icon in Finder windows and next to desktop widgets. Without it, it still deletes, just aimed less precisely. Turn on PokePets in System Settings › Privacy & Security › Accessibility.",
        button: "Open Settings", granted: { AXIsProcessTrusted() },
        ask: { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) })

    static let notifications = PermissionRow(
        title: "Notifications", why: "macOS asks once whether PokePets may show notifications.",
        button: "Ask Now", granted: { UserDefaults.standard.bool(forKey: "onboarding.notificationsAsked") },
        ask: {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            UserDefaults.standard.set(true, forKey: "onboarding.notificationsAsked")
        })
}

private struct MeetParty: View {
    var body: some View {
        Label("Meet your party", systemImage: "circle.grid.3x3.fill").font(.title.weight(.bold))
        Text("Each Pokémon starts as an Egg in the menu bar dial. Click it to hatch. Here's who's coming:")
            .font(.title3).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Roster.all, id: \.id) { slot in
                Point(icon: slot.id == "pet" ? "bolt.fill" : slot.id == "gengar" ? "moon.stars.fill" : "lock",
                      title: "\(slot.name) · \(slot.type)", text: slot.blurb)
            }
        }
        Text("You'll find each one's guide, stats and its own switches in Settings, under its name.")
            .font(.callout).foregroundStyle(.secondary)
    }
}

private struct Point: View {
    let icon: String, title: String, text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.accentColor).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
