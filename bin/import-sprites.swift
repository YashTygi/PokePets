import AppKit

// Import one Pokémon (and its shiny) from PMD SpriteCollab into the app exactly as the site has it: every
// animation's full sheet (all 8 directions, as published) and its AnimData.xml, unchanged. The app picks
// the rows it needs at load (facing right on the desktop, all 8 in the Settings gallery). Portraits get
// fallbacks for emotions not drawn yet, and the artists are added to credits.json.
//
//   swift bin/import-sprites.swift 0094 gengar Gengar
//   swift bin/import-sprites.swift 0026/0001 raichu-alola "Alolan Raichu" --keep-portraits
//
// Downloads go to a fresh temp folder; only the PNGs, the XML and credits.json land in the app.
let args = CommandLine.arguments
guard args.count >= 4 else { print("usage: import-sprites.swift <dex[/form]> <species> <Title> [--keep-portraits]"); exit(1) }
let path = args[1], species = args[2], title = args[3], keepPortraits = args.contains("--keep-portraits")
let dex = String(path.prefix(4))
let form = path.split(separator: "/").dropFirst().first.map(String.init)       // "0001" for Alolan Raichu
let shinyPath = form == nil ? path + "/0000/0001" : path + "/0001"
let source = "https://sprites.pmdcollab.org/#/\(dex)" + (form.map { "?form=\(Int($0)!)" } ?? "")
let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let app = here.appendingPathComponent("../PokePets").standardized
let base = "https://raw.githubusercontent.com/PMDCollab/SpriteCollab/master"
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("spritecollab-\(dex)-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func fetch(_ path: String) -> Data? {
    let local = tmp.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_"))
    if let d = try? Data(contentsOf: local) { return d }
    guard let d = try? Data(contentsOf: URL(string: "\(base)/\(path)")!), !d.isEmpty,
          !(String(data: d.prefix(20), encoding: .utf8) ?? "").hasPrefix("404") else { return nil }
    try? d.write(to: local)
    return d
}

func save(_ image: CGImage, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: app.appendingPathComponent(name + ".png"))
}

/// Animation names in AnimData.xml, and which ones are copies of another (no sheet of their own).
func animNames(_ xml: Data) -> [(name: String, copyOf: String?)] {
    final class P: NSObject, XMLParserDelegate {
        var out: [(String, String?)] = [], name = "", copy: String?, text = ""
        func parser(_ p: XMLParser, didStartElement e: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) { text = ""; if e == "Anim" { name = ""; copy = nil } }
        func parser(_ p: XMLParser, foundCharacters s: String) { text += s }
        func parser(_ p: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if e == "Name" { name = t } else if e == "CopyOf" { copy = t } else if e == "Anim" { out.append((name, copy)) }
        }
    }
    let p = P(), parser = XMLParser(data: xml)
    parser.delegate = p
    parser.parse()
    return p.out
}

/// Replace this species' sheets: every animation's full sheet as `<prefix>-<name lowercased>.png`.
func importSprites(variant: String, prefix: String) -> [String] {
    guard let xml = fetch("sprite/\(variant)/AnimData.xml") else { print("no sprites for \(prefix)"); return [] }
    let keep = ["eathold"]                                            // hand-made extras that aren't SpriteCollab's
    for f in (try? FileManager.default.contentsOfDirectory(atPath: app.path)) ?? []
        where f.hasPrefix(prefix + "-") && f.hasSuffix(".png") && !f.hasPrefix(prefix + "-face-") && !f.hasPrefix(prefix + "-shiny")
            && !f.hasPrefix(prefix + "-alola") && !keep.contains(where: { f.contains($0) }) {
        try? FileManager.default.removeItem(at: app.appendingPathComponent(f))
    }
    try! xml.write(to: app.appendingPathComponent("\(prefix)-anim.xml"))
    var written: [String] = []
    for a in animNames(xml) {
        guard a.copyOf == nil else { written.append(a.name); continue }      // a copy: the app reuses the other sheet
        guard let d = fetch("sprite/\(variant)/\(a.name)-Anim.png") else { print("  missing sheet \(a.name)"); continue }
        try! d.write(to: app.appendingPathComponent("\(prefix)-\(a.name.lowercased()).png"))
        written.append(a.name)
    }
    print("\(prefix): \(written.count) animations")
    return written
}

/// Our 11 emotions; SpriteCollab names, with the closest stand-in when an artist hasn't drawn one yet.
let faces: [(ours: String, theirs: [String])] = [
    ("happy", ["Happy", "Normal"]), ("joyous", ["Joyous", "Happy", "Normal"]), ("angry", ["Angry", "Determined", "Normal"]),
    ("crying", ["Crying", "Teary-Eyed", "Sad", "Pain"]), ("pain", ["Pain", "Sad", "Normal"]), ("dizzy", ["Dizzy", "Stunned", "Pain"]),
    ("worried", ["Worried", "Sad", "Surprised"]), ("surprised", ["Surprised", "Normal"]), ("sigh", ["Sigh", "Sad", "Normal"]),
    ("determined", ["Determined", "Angry", "Normal"]), ("inspired", ["Inspired", "Joyous", "Happy", "Normal"]),
]

func importPortraits(variant: String, prefix: String) -> [String] {
    var got: [String] = []
    if keepPortraits { return [] }
    for f in faces {
        for name in f.theirs {
            guard let d = fetch("portrait/\(variant)/\(name).png"),
                  let img = NSImage(data: d)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            save(img, "\(prefix)-face-\(f.ours)")
            got.append(name)
            break
        }
    }
    print("\(prefix): portraits from \(Set(got).sorted().joined(separator: ", "))")
    return got
}

// MARK: Credits

let names: [String: (name: String, contact: String)] = {
    guard let d = fetch("credit_names.txt"), let s = String(data: d, encoding: .utf8) else { return [:] }
    var out: [String: (String, String)] = [:]
    for line in s.split(separator: "\n").dropFirst() {
        let c = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        if c.count >= 2 { out[c[1]] = (c[0], c.count > 2 ? c[2] : "") }
    }
    return out
}()

func license(_ s: String) -> String {
    switch s {
    case "Unspecified": "Unspecified (original game asset)"
    case "PMDCollab_1": "PMDCollab License v1"
    case "PMDCollab_2": "PMDCollab License v2"
    case "CC_BY-NC": "CC BY-NC 4.0"
    default: s.replacingOccurrences(of: "_", with: " ")
    }
}

func credits(_ kind: String, folder: String, set: String, used: Set<String>) -> [[String: Any]] {
    guard let d = fetch("\(folder)/credits.txt"), let s = String(data: d, encoding: .utf8) else { return [] }
    var claimed = Set<String>(), entries: [[String: Any]] = []
    for line in s.split(separator: "\n").reversed() {                // newest first: later artists replace earlier work
        let c = line.split(separator: "\t").map(String.init)
        guard c.count >= 5 else { continue }
        let parts = c[4].split(separator: ",").map(String.init).filter { used.contains($0) && !claimed.contains($0) }
        guard !parts.isEmpty else { continue }
        claimed.formUnion(parts)
        let who = c[1] == "CHUNSOFT" ? (name: "CHUNSOFT", contact: "https://www.spike-chunsoft.com/") : names[c[1]] ?? (c[1], "")
        entries.append(["artist": who.name, "contact": who.contact, "set": set, "kind": kind, "parts": parts,
                        "license": license(c[3]), "source": source])
    }
    return entries
}

var newCredits: [[String: Any]] = []
for (variant, prefix, set) in [(path, species, title), (shinyPath, species + "-shiny", "Shiny " + title)] {
    let anims = importSprites(variant: variant, prefix: prefix)
    let faces = importPortraits(variant: variant, prefix: prefix)
    newCredits += credits("Sprites", folder: "sprite/\(variant)", set: set, used: Set(anims))
    if !keepPortraits { newCredits += credits("Portraits", folder: "portrait/\(variant)", set: set, used: Set(faces)) }
}
let creditsURL = app.appendingPathComponent("credits.json")
var all = (try? JSONSerialization.jsonObject(with: Data(contentsOf: creditsURL))) as? [[String: Any]] ?? []
// Re-import replaces this set's credits (sprites only, when portraits are kept).
all.removeAll { e in
    guard let set = e["set"] as? String, [title, "Shiny " + title].contains(set) else { return false }
    return !keepPortraits || e["kind"] as? String == "Sprites"
}
all += newCredits
try! JSONSerialization.data(withJSONObject: all, options: [.prettyPrinted, .sortedKeys]).write(to: creditsURL)
print("credits.json: \(newCredits.count) entries for \(title)")
try? FileManager.default.removeItem(at: tmp)
