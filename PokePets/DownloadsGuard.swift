import AppKit

/// Downloads guard: notices downloads you probably don't need any more (big files, duplicate copies,
/// installers you've finished with) and reports each one once, so the Pokémon can offer to zap it.
///
/// Event-driven: a file-system watch on ~/Downloads (rescanned 2 s after it changes) and disk image
/// mount/unmount notifications. Scans run off the main thread (comparing big files takes a moment).
/// Nothing is ever deleted here; that only happens if you pick Thunderbolt.
final class DownloadsGuard {
    /// Files worth offering (one, or a batch of duplicates), a short title and why. Called on the main thread.
    var onFind: (([URL], String, String) -> Void)?

    static let bigFile = 500_000_000                 // bytes
    static let oldInstaller: TimeInterval = 7 * 86_400

    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    private let work = DispatchQueue(label: "PokePets.downloads", qos: .utility)   // scans and `offered` live here
    private var watch: DispatchSourceFileSystemObject?
    private var seen: Set<String>?                   // nil until the first scan
    private var images: [String: URL] = [:]          // mount point → the disk image it came from
    /// Files already offered (kept, so you're never asked twice about the same file).
    private var offered = Set(UserDefaults.standard.stringArray(forKey: "downloads.offered") ?? [])

    init() {
        let fd = open(folder.path, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
            var pending: DispatchWorkItem?
            source.setEventHandler { [weak self] in        // downloads land in bursts: wait for it to settle
                pending?.cancel()
                let work = DispatchWorkItem { self?.scan() }
                pending = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            watch = source
        }
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in self?.readImages() }
        ws.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
            guard let volume = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
                  let image = self?.images.removeValue(forKey: volume.standardizedFileURL.path),
                  image.deletingLastPathComponent().standardizedFileURL == self?.folder.standardizedFileURL,
                  FileManager.default.fileExists(atPath: image.path) else { return }
            self?.work.async { self?.offer([image], "Installer left behind", "You've ejected \(image.lastPathComponent). Done installing? Zap the installer.") }
        }
        readImages()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.scan() }   // after launch settles
    }

    private func scan() { work.async { [weak self] in self?.scanNow() } }

    /// Look at what's new in Downloads. New duplicates and big files are offered one by one. On the first
    /// look (at launch), what was already there: old installers, plus every duplicate in one batch.
    private func scanNow() {
        guard Setting.downloadsGuard.isOn else { return }
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey, .creationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                       options: .skipsHiddenFiles) else { return }
        let first = seen == nil
        var seen = self.seen ?? []
        var sizes: [String: Int] = [:], existing: [URL] = []
        for f in files { sizes[f.lastPathComponent] = (try? f.resourceValues(forKeys: [.fileSizeKey]))?.fileSize }
        for file in files {
            let name = file.lastPathComponent, ext = file.pathExtension.lowercased()
            guard let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  !["crdownload", "download", "part", "partial"].contains(ext) else { continue }   // still downloading
            let size = v.fileSize ?? 0, isNew = !seen.contains(name)
            seen.insert(name)
            if ["dmg", "pkg"].contains(ext), let made = v.creationDate, Date().timeIntervalSince(made) > Self.oldInstaller {
                offer([file], "Old installer", "\(name) has been in Downloads for over a week (\(Self.size(size))). Zap it?")
            } else if first || isNew, let original = Self.original(of: name), sizes[original] == size,
                      FileManager.default.contentsEqual(atPath: file.path, andPath: folder.appendingPathComponent(original).path) {
                if first { existing.append(file) }                       // same bytes, not just the same size
                else { offer([file], "Duplicate download", "\(name) is a copy of \(original). Zap the copy?") }
            } else if !first, isNew, size >= Self.bigFile {
                offer([file], "Big download", "\(name) takes \(Self.size(size)). Zap it when you're done with it.")
            }
        }
        self.seen = seen
        let total = existing.reduce(0) { $0 + (sizes[$1.lastPathComponent] ?? 0) }
        offer(existing, existing.count == 1 ? "Duplicate download" : "\(existing.count) duplicate downloads",
              "Exact copies of files already in Downloads (\(Self.size(total))). Thunderbolt them all?")
    }

    /// Report files not offered before (call on `work`).
    private func offer(_ files: [URL], _ title: String, _ why: String) {
        let fresh = files.filter { offered.insert($0.path).inserted }
        guard Setting.downloadsGuard.isOn, !fresh.isEmpty else { return }
        UserDefaults.standard.set(Array(offered.suffix(1000)), forKey: "downloads.offered")
        DispatchQueue.main.async { [weak self] in self?.onFind?(fresh, title, why) }
    }

    /// Which disk image each mounted volume came from (`hdiutil info`), so we know when you eject one.
    private func readImages() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process(), out = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            p.arguments = ["info", "-plist"]
            p.standardOutput = out
            guard (try? p.run()) != nil else { return }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let list = plist["images"] as? [[String: Any]] else { return }
            var found: [String: URL] = [:]
            for image in list {
                guard let path = image["image-path"] as? String else { continue }
                for entity in image["system-entities"] as? [[String: Any]] ?? [] {
                    if let mount = entity["mount-point"] as? String { found[URL(fileURLWithPath: mount).standardizedFileURL.path] = URL(fileURLWithPath: path) }
                }
            }
            DispatchQueue.main.async { self?.images.merge(found) { _, new in new } }
        }
    }

    /// "Report (1).pdf" / "Report 2.pdf" → "Report.pdf" (how browsers and Finder name repeat downloads).
    static func original(of name: String) -> String? {
        let url = URL(fileURLWithPath: name), ext = url.pathExtension, base = url.deletingPathExtension().lastPathComponent
        guard let r = base.range(of: #" ?(\(\d+\)|\d+)$"#, options: .regularExpression), r.lowerBound > base.startIndex,
              base[r].contains(" ") || base[r].hasPrefix("(") else { return nil }
        let stem = String(base[..<r.lowerBound])
        return ext.isEmpty ? stem : "\(stem).\(ext)"
    }

    static func size(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }

    /// Self-check: `DownloadsGuard.check()`.
    static func check() {
        assert(original(of: "Report (1).pdf") == "Report.pdf")
        assert(original(of: "Report 2.pdf") == "Report.pdf")
        assert(original(of: "setup(3).dmg") == "setup.dmg")
        assert(original(of: "Report.pdf") == nil)
        assert(original(of: "2024.pdf") == nil)
        assert(original(of: "IMG_0042.jpg") == nil)
    }
}
