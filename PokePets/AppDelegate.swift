import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var stage: StageWindow?
    private var power: Power?
    private var senses: Senses?
    private var party: [Companion] = []          // keep everything alive
    private var ballFX: BallFX?
    private var dial: PartyDial?
    private var thunderboltKey: ThunderboltKey?
    private var downloads: DownloadsGuard?

    /// Which Pokémon you last sent out (its store prefix), so it's the one out next launch.
    static let outKey = "party.out"

    /// Who deletes files (⌥⌘⌫, the Downloads guard): the first Pokémon out on the desktop, else the lead.
    private var deleter: Companion? { party.first { $0.calm } ?? party.first }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Setting.registerDefaults()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: "evolve", actions: [
            UNNotificationAction(identifier: "evolve", title: "Evolve"),
            UNNotificationAction(identifier: "later", title: "Not Now"),
        ], intentIdentifiers: []), UNNotificationCategory(identifier: "zap", actions: [
            UNNotificationAction(identifier: "zap", title: "Delete", options: .destructive),
            UNNotificationAction(identifier: "keep", title: "Keep"),
        ], intentIdentifiers: [])])
        guard let screen = NSScreen.main else { return }
        let stage = StageWindow(screen: screen)
        stage.orderFrontRegardless()

        let power = Power()
        let senses = Senses()
        let party: [Companion] = [Pikachu(power: power, senses: senses), Gengar(power: power, senses: senses)]
        // Only one Pokémon out at a time: the one you last sent out (else the first that has hatched).
        let lead = party.first { $0.isOut && $0.store == UserDefaults.standard.string(forKey: Self.outKey) } ?? party.first { $0.isOut }
        for member in party where member !== lead && member.isOut { member.keepInBall() }
        for (i, member) in party.enumerated() {
            stage.add(member.pet, x: screen.frame.width * CGFloat(i + 1) / CGFloat(party.count + 1))   // spread along the floor
        }
        // The Mac's events go to the whole party.
        power.onChange = { party.forEach { $0.powerChanged() } }
        senses.onAway = { party.forEach { $0.userLeft() } }
        senses.onBack = { party.forEach { $0.userReturned() } }
        senses.onBreakTime = { party.first { $0.calm }?.suggestBreak() }      // one reminder, not one per Pokémon
        senses.onCamera = { on in party.forEach { $0.cameraChanged(on) } }
        senses.onHeat = { party.forEach { $0.heatChanged() } }
        senses.onOnline = { online in party.forEach { $0.internetChanged(online) } }

        // Menu bar Poké Ball → party dial → throw / recall, feed, stats.
        let fx = BallFX(screen: screen, pixelSize: party[0].pet.scale)
        let origin = screen.frame.origin
        let toStage: (CGPoint) -> CGPoint = { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        let dial = PartyDial(party: party.map { member in
            PartyMember(stats: { [weak member] in member!.stats },
                        portrait: { [weak member] in member!.portrait },
                        isOut: { [weak member] in member?.isOut ?? false },
                        toggle: { [weak member] start in
                            guard let member else { return }
                            guard !member.isOut else { member.toggleBall(from: toStage(start), fx: fx); return }   // calling it back
                            // Sending it out (or hatching it): whoever is out goes back into its ball first.
                            let others = party.filter { $0 !== member && $0.isOut }
                            others.forEach { $0.toggleBall() }
                            UserDefaults.standard.set(member.store, forKey: Self.outKey)
                            let go = { member.toggleBall(from: toStage(start), fx: fx) }
                            others.isEmpty ? go() : DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: go)
                        })
        })
        dial.onItemDrag = { [weak stage] point in stage?.itemDragMoved(point) }
        dial.onSettings = { [weak self] in self?.showSettings() }
        for member in party {
            member.fx = fx
            member.cursor = { toStage(NSEvent.mouseLocation) }
            member.ballStart = { [weak dial] in toStage(dial?.ballStart ?? .zero) }
        }
        let key = ThunderboltKey()
        key.onStrike = { [weak self] urls, spots in self?.deleter?.strike(urls, at: spots.mapValues(toStage)) }
        thunderboltKey = key
        // Reading ~/Downloads makes macOS ask for permission: only after the welcome guide has explained it.
        Onboarding.afterGuide { [weak self] in
            let downloads = DownloadsGuard()
            downloads.onFind = { [weak self] files, title, why in self?.deleter?.offerZap(files, title: title, why: why) }
            self?.downloads = downloads
        }
        party.forEach { $0.start() }

        self.stage = stage
        self.power = power
        self.senses = senses
        self.party = party
        self.ballFX = fx
        self.dial = dial

        if !Onboarding.done { Onboarding.show { [weak self] in self?.showSettings() } }
        if UserDefaults.standard.string(forKey: "PokeSettings") != nil { showSettings() }   // dev: open Settings at launch
    }

    private func showSettings() {
        SettingsWindow.show(party.map { member in
            PetControls(id: member.store,
                        stats: { [weak member] in member!.stats },
                        animations: { [weak member] in member?.animations ?? [] },
                        directions: { [weak member] in member?.directions($0) ?? [] },
                        playful: { [weak member] in member?.playful ?? [] },
                        perform: { [weak member] in member?.perform($0) },
                        restart: { [weak member] in member?.restart() },
                        why: { [weak member] in member!.why })
        })
    }

    /// Quitting while Gengar holds your cursor: show it again (macOS would too, but don't leave it to that).
    func applicationWillTerminate(_ notification: Notification) { Cursor.show() }

    /// Show its notifications even while the app is "active" (it's a menu bar app, so it often is).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .list, .sound])
    }

    /// Evolve / Not Now, Delete / Keep, picked right in the notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let paths = info["paths"] as? [String] ?? []
        let owner = info["pet"] as? String ?? "pet"
        DispatchQueue.main.async { [weak self] in
            guard let self else { done(); return }
            if action == "evolve" || action == "later" { party.first { $0.store == owner }?.answerEvolution(action == "evolve") }
            if action == "zap" {                                     // its delete move: into the Trash
                let files = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
                deleter?.strike(Array(files.prefix(3)))                  // a few hits; a big batch's rest go quietly
                for file in files.dropFirst(3) { try? FileManager.default.trashItem(at: file, resultingItemURL: nil) }
            }
            done()
        }
    }

    /// `pokepets://celebrate`, `pokepets://fail`, … (see bin/pokepets). The whole party reacts.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "pokepets" { party.forEach { $0.hook(url.host ?? "hello") } }
        // Opening a URL (e.g. from a Shortcuts automation) activates the app: give focus straight back
        // unless the Settings window is open.
        if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) { NSApp.deactivate() }
    }
}
