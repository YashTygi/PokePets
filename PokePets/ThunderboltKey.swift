import AppKit
import Carbon.HIToolbox

/// ⌥⌘⌫ in Finder → Thunderbolt the selected files into the Trash.
///
/// Finder's own ⌥⌘⌫ is "Delete Immediately" (no Trash). While Finder is the active app and
/// Thunderbolt delete is on, we take over just that one shortcut (a Carbon hot key: no permission
/// needed), so the files go to the Trash instead, where you can still get them back.
final class ThunderboltKey {
    /// The files, and where each one sits on screen (Cocoa screen points) when Finder shows it in a window.
    var onStrike: (([URL], [URL: CGPoint]) -> Void)?
    private var hotKey: EventHotKeyRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            let key = Unmanaged<ThunderboltKey>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async { key.pressed() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] _ in self?.update() }
        update()
    }

    /// Hold the shortcut only while Finder is in front (other apps keep their own ⌥⌘⌫).
    private func update() {
        let finder = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
        if finder, Setting.thunderbolt.isOn, hotKey == nil {
            RegisterEventHotKey(UInt32(kVK_Delete), UInt32(cmdKey | optionKey), EventHotKeyID(signature: 0x504B_5054, id: 1),
                                GetApplicationEventTarget(), 0, &hotKey)
        } else if !(finder && Setting.thunderbolt.isOn), let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    private func pressed() {
        guard Setting.thunderbolt.isOn else { return }
        let script = """
            tell application "Finder"
                set out to {}
                repeat with f in (selection as alias list)
                    set end of out to POSIX path of f
                end repeat
                return out
            end tell
            """
        var error: NSDictionary?
        guard let list = NSAppleScript(source: script)?.executeAndReturnError(&error), error == nil,
              list.numberOfItems > 0 else { return }
        let urls = (1...list.numberOfItems).compactMap { list.atIndex($0)?.stringValue }.map { URL(fileURLWithPath: $0) }
        if !urls.isEmpty { onStrike?(urls, Self.spots(of: urls)) }
    }

    /// Where Finder's front window shows the selected files, read through Accessibility (asks for
    /// permission once). List and column views select rows, icon and gallery views select items; each
    /// is matched to a file by the name it shows (with or without the extension).
    /// ponytail: walks at most 3,000 elements; Finder only builds rows that are on screen, so that's plenty.
    static func spots(of urls: [URL]) -> [URL: CGPoint] {
        guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary),
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              let window: AXUIElement = AX.value(AXUIElementCreateApplication(finder.processIdentifier), kAXFocusedWindowAttribute)
        else { return [:] }
        var selected: [AXUIElement] = [], queue = [window], seen = 0
        while !queue.isEmpty, seen < 3000 {
            let e = queue.removeFirst(); seen += 1
            selected += (AX.value(e, kAXSelectedRowsAttribute) as [AXUIElement]?) ?? (AX.value(e, kAXSelectedChildrenAttribute) as [AXUIElement]?) ?? []
            queue += (AX.value(e, kAXChildrenAttribute) as [AXUIElement]?) ?? []
        }
        let top = NSScreen.screens.first?.frame.height ?? 0          // AX counts down from the top of the main screen
        var spots: [URL: CGPoint] = [:]
        for item in selected {
            guard let (label, text) = named(item, depth: 4),
                  let url = urls.first(where: { [$0.lastPathComponent, $0.deletingPathExtension().lastPathComponent].contains(text) }),
                  let box = AX.frame(item), let name = AX.frame(label) else { continue }
            // An icon-sized item: hit its middle. A wide row: hit the icon, just left of the name.
            let p = box.width < 3 * box.height ? CGPoint(x: box.midX, y: box.midY) : CGPoint(x: name.minX - 10, y: name.midY)
            spots[url] = CGPoint(x: p.x, y: top - p.y)
        }
        return spots
    }

    /// The element showing a name (a text field or titled item) in `e` or below it, and that name.
    private static func named(_ e: AXUIElement, depth: Int) -> (AXUIElement, String)? {
        for key in [kAXFilenameAttribute, kAXTitleAttribute, kAXValueAttribute] {
            if let s: String = AX.value(e, key), !s.isEmpty { return (e, s) }
        }
        guard depth > 0 else { return nil }
        for child in (AX.value(e, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
            if let found = named(child, depth: depth - 1) { return found }
        }
        return nil
    }
}

/// Reading what other apps show on screen, through Accessibility.
enum AX {
    static func value<T>(_ e: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    /// Frame on screen, measured from the top left of the main screen.
    static func frame(_ e: AXUIElement) -> CGRect? {
        guard let p: AXValue = value(e, kAXPositionAttribute), let s: AXValue = value(e, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p, .cgPoint, &origin); AXValueGetValue(s, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }
}
