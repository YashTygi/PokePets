import Foundation
import IOKit.ps

/// Battery level and charger state. macOS calls us when either changes (no polling).
///
/// Testing without unplugging: launch with
///   -PokePowerScript "60 18 4 50c 50"   (one state every -PokePowerStep seconds, default 12;
///                                        a number is the battery %, a trailing "c" means charger in)
final class Power {
    private(set) var level = 100          // percent
    private(set) var charging = false     // true while the charger is connected
    var onChange: (() -> Void)?

    private var fake: (level: Int, charging: Bool)?

    init() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            Unmanaged<Power>.fromOpaque(context!).takeUnretainedValue().refresh()
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        read()
        if let script = UserDefaults.standard.string(forKey: "PokePowerScript") {
            let step = UserDefaults.standard.double(forKey: "PokePowerStep")
            play(script.split(separator: " ").map(String.init), every: step > 0 ? step : 12, index: 0)
        }
    }

    private func refresh() {
        let before = (level, charging)
        read()
        if before != (level, charging) { onChange?() }
    }

    private func read() {
        if let fake {
            (level, charging) = fake
            return
        }
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = d[kIOPSCurrentCapacityKey] as? Int,
                  let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            level = current * 100 / max
            charging = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return
        }
        (level, charging) = (100, true)   // desktop Mac without a battery: always "plugged in"
    }

    private func play(_ steps: [String], every seconds: TimeInterval, index: Int) {
        guard !steps.isEmpty else { return }
        let s = steps[index % steps.count]
        fake = (Int(s.filter(\.isNumber)) ?? 100, s.hasSuffix("c"))
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.play(steps, every: seconds, index: index + 1)
        }
    }
}
