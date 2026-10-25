import AVFoundation
import Network

/// What's going on around the Pokémon: you stepping away, your camera, the Mac's temperature,
/// the internet, music. Everything is a system notification except one cheap idle check every 20 s.
final class Senses {
    var onAway: (() -> Void)?
    var onBack: (() -> Void)?
    var onBreakTime: (() -> Void)?
    var onCamera: ((Bool) -> Void)?
    var onHeat: (() -> Void)?
    var onOnline: ((Bool) -> Void)?

    private(set) var away = false
    private(set) var musicPlaying = false
    private(set) var cameraOn = false
    var thermal: ProcessInfo.ThermalState { ProcessInfo.processInfo.thermalState }

    private var activeSince = Date()                  // start of the current stretch of you using the Mac
    private var idleTimer: Timer?
    private var cameraWatches: [NSKeyValueObservation] = []
    private let network = NWPathMonitor()
    private var online: Bool?

    init() {
        checkIdle()
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.onHeat?() }
        network.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let now = path.status == .satisfied
                if let before = self.online, before != now { self.onOnline?(now) }
                self.online = now
            }
        }
        network.start(queue: .global(qos: .utility))
        watchCameras()
        watchMusic()
    }

    // MARK: Away / break

    /// Seconds since your last key press, click or mouse move (any app; needs no permission).
    private var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Every 20 s normally; every 2 s while you're away, so it notices quickly when you're back.
    private func checkIdle() {
        let idle = idleSeconds
        if !away, idle > 5 * 60 {
            away = true
            onAway?()
        } else if away, idle < 3 {
            away = false
            activeSince = Date()
            onBack?()
        }
        if !away, Setting.breakReminder.isOn {
            let limit = TimeInterval(max(15, UserDefaults.standard.integer(forKey: Setting.breakMinutesKey))) * 60
            if Date().timeIntervalSince(activeSince) > limit {
                activeSince = Date()                      // next reminder after another full stretch
                onBreakTime?()
            }
        }
        idleTimer = Timer.scheduledTimer(withTimeInterval: away ? 2 : 20, repeats: false) { [weak self] _ in
            self?.checkIdle()
        }
        idleTimer?.tolerance = 2
    }

    // MARK: Camera

    /// Every camera's "in use by another app" flag, watched for changes (no camera permission needed).
    private func watchCameras() {
        let cameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external],
                                                       mediaType: .video, position: .unspecified).devices
        cameraWatches = cameras.map { camera in
            camera.observe(\.isInUseByAnotherApplication, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.cameraChanged(cameras) }
            }
        }
    }

    private func cameraChanged(_ cameras: [AVCaptureDevice]) {
        let on = cameras.contains { $0.isInUseByAnotherApplication }
        guard on != cameraOn else { return }
        cameraOn = on
        onCamera?(on)
    }

    // MARK: Music

    /// Apple Music and Spotify announce play/pause to the whole system; we just listen.
    private func watchMusic() {
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            DistributedNotificationCenter.default().addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] note in
                self?.musicPlaying = (note.userInfo?["Player State"] as? String) == "Playing"
            }
        }
    }
}
