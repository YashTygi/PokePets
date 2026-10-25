import AppKit

extension Pixels {
    /// 12×12 Poké Ball, same outline colour and pixel size as the sprites. Rows 0–5 are the top
    /// half, rows 6–11 the bottom half (it splits along the band, like in the anime).
    static let pokeballRows = [
        "....kkkk....",
        "..kkrrrrkk..",
        ".krrrrrwwrk.",
        ".krrrrrrwrk.",
        "krrrrrrrrrrk",
        "kdddkkkkdddk",
        "kkkkkwwkkkkk",
        "kwwwkkkkwwwk",
        "kwwwwwwwwwwk",
        ".kwwwwwwwgk.",
        "..kkggggkk..",
        "....kkkk....",
    ]
    static let pokeball = image(pokeballRows)
    static let pokeballTop = image(Array(pokeballRows[0..<6]))
    static let pokeballBottom = image(Array(pokeballRows[6..<12]))

    /// The same art, enlarged by a whole number so every pixel stays a crisp square.
    static func scaled(_ image: CGImage, by factor: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: image.width * factor, height: image.height * factor,
                            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        return ctx.makeImage()!
    }
}

extension Pet {
    /// A solid-colour copy of the pet's current frame laid over it: the glowing energy form it
    /// takes when going into or coming out of a Poké Ball. Fade it with `opacity`.
    func silhouette(_ color: NSColor) -> CALayer {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let overlay = CALayer()
        overlay.frame = sprite.bounds
        overlay.backgroundColor = color.cgColor
        let mask = CALayer()
        mask.frame = sprite.bounds
        mask.contents = sprite.contents
        mask.contentsRect = sprite.presentation()?.contentsRect ?? sprite.contentsRect
        mask.magnificationFilter = .nearest
        overlay.mask = mask
        sprite.addSublayer(overlay)
        CATransaction.commit()
        return overlay
    }
}

/// Throwing and recalling: the Poké Ball, its flash, and the beam of light, as in the anime.
///
/// The pets live behind your windows, but these effects play in a short-lived overlay above
/// everything, so you always see them even when the desktop is covered. For the few seconds of the
/// animation the pet is lifted into that overlay too, then goes back home to the desktop layer.
/// Stage and overlay share the same coordinates (both cover the whole screen).
final class BallFX {
    private let window: NSWindow
    private let root: CALayer
    private let px: CGFloat                       // size of one Poké Ball pixel, in points

    init(screen: NSScreen, pixelSize: CGFloat) {
        px = pixelSize
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary, .auxiliary]
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        window.contentView = view
        root = view.layer!
    }

    // MARK: Release

    /// Throw a ball from `start` (the menu bar) to `ground`, bounce, pop it open with a white flash
    /// and beam, and have `pet` form at `spot` as glowing light. `emerged` runs once it's fully out.
    func release(_ pet: Pet, from start: CGPoint, ground: CGPoint, spot: CGPoint, emerged: @escaping () -> Void) {
        show()
        let home = pet.node.superlayer
        root.addSublayer(pet.node)
        let ball = makeBall(at: start)
        let rest = CGPoint(x: ground.x, y: ground.y + 6 * px)          // ball centre when sitting on the ground

        // Throw: an arc down from the menu bar, spinning.
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: rest, control: CGPoint(x: (start.x + rest.x) / 2, y: start.y + 40))
        animate(ball.node, "position", path: path, duration: 0.6, timing: .init(name: .easeIn))
        animate(ball.node, "transform.rotation.z", from: 0, to: -4 * CGFloat.pi, duration: 0.6)
        ball.node.position = rest

        // Two little bounces.
        after(0.6) {
            let bounce = CAKeyframeAnimation(keyPath: "position.y")
            bounce.values = [rest.y, rest.y + 7 * self.px, rest.y, rest.y + 2 * self.px, rest.y]
            bounce.keyTimes = [0, 0.3, 0.6, 0.8, 1]
            bounce.duration = 0.4
            ball.node.add(bounce, forKey: "bounce")
        }
        // Pop open: flash, beam to where the pet will stand.
        after(1.05) {
            self.open(ball)
            self.flash(at: rest, color: .white)
            self.beam(from: rest, to: CGPoint(x: spot.x, y: spot.y + 14 * self.px), color: .white)
        }
        after(1.2) { self.form(pet, at: spot) }
        // Ball closes and disappears.
        after(1.65) { self.close(ball) }
        after(1.85) {
            self.vanish(ball) {
                home?.addSublayer(pet.node)
                self.hide()
                emerged()
            }
        }
    }

    /// The pet forms from light at `spot`: a tiny white silhouette that grows, then gets its colours.
    private func form(_ pet: Pet, at spot: CGPoint) {
        pet.node.isHidden = false
        pet.drag(to: spot)
        let glow = pet.silhouette(NSColor(white: 1, alpha: 1))
        let grow = CAKeyframeAnimation(keyPath: "transform.scale")
        grow.values = [0.1, 1.12, 1]
        grow.keyTimes = [0, 0.75, 1]
        grow.duration = 0.4
        pet.node.add(grow, forKey: "grow")
        after(0.45) {
            glow.opacity = 0                                             // fades (implicit animation)
            pet.sparks(for: 0.3, rate: 16)
        }
        after(0.8) { glow.removeFromSuperlayer() }
    }

    // MARK: Hatch

    /// The Egg drops from the menu bar onto `spot`, wobbles, cracks twice, bursts open in a flash with
    /// its shell flying apart, and `pet` forms from the light. `hatched` runs once it's out.
    func hatch(_ pet: Pet, from start: CGPoint, spot: CGPoint, hatched: @escaping () -> Void) {
        show()
        let home = pet.node.superlayer
        root.addSublayer(pet.node)
        let size = CGSize(width: 12 * px, height: 15 * px)
        let rest = CGPoint(x: spot.x, y: spot.y + size.height / 2)
        let egg = CALayer()
        egg.bounds = CGRect(origin: .zero, size: size)
        egg.anchorPoint = CGPoint(x: 0.5, y: 0)                         // rocks on its base
        egg.position = CGPoint(x: rest.x, y: spot.y)
        egg.contents = Pixels.egg
        egg.magnificationFilter = .nearest
        root.addSublayer(egg)

        // Floats down from the menu bar and settles with a little bounce.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.x, y: start.y - size.height))
        path.addQuadCurve(to: egg.position, control: CGPoint(x: (start.x + rest.x) / 2, y: start.y + 30))
        animate(egg, "position", path: path, duration: 0.9, timing: .init(name: .easeIn))
        after(0.9) {
            let bounce = CAKeyframeAnimation(keyPath: "position.y")
            bounce.values = [spot.y, spot.y + 5 * self.px, spot.y, spot.y + 1.5 * self.px, spot.y]
            bounce.keyTimes = [0, 0.3, 0.6, 0.8, 1]
            bounce.duration = 0.35
            egg.add(bounce, forKey: "bounce")
        }
        // Wobbles, harder each time, cracking more.
        func wobble(_ at: TimeInterval, angle: CGFloat, crack: CGImage?) {
            after(at) {
                if let crack {
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    egg.contents = crack
                    CATransaction.commit()
                }
                let rock = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                rock.values = [0, angle, -angle, angle * 0.6, 0]
                rock.duration = 0.45
                egg.add(rock, forKey: "rock")
            }
        }
        wobble(1.6, angle: 0.15, crack: nil)
        wobble(2.4, angle: 0.22, crack: Pixels.eggCracked[0])
        wobble(3.1, angle: 0.3, crack: Pixels.eggCracked[1])

        // Bursts open: flash, the two halves of the shell fly apart and fade.
        after(3.75) {
            egg.removeFromSuperlayer()
            self.flash(at: CGPoint(x: rest.x, y: rest.y), color: .white)
            for (image, rows, dx, dy, spin) in [(Pixels.eggTop, 7.0, -10.0, 26.0, 0.9), (Pixels.eggBottom, 8.0, 12.0, 6.0, -0.5)] {
                let shell = CALayer()
                shell.contents = image
                shell.magnificationFilter = .nearest
                shell.bounds = CGRect(x: 0, y: 0, width: size.width, height: rows * self.px)
                let isTop = rows == 7
                shell.position = CGPoint(x: rest.x, y: spot.y + (isTop ? size.height - rows * self.px / 2 : rows * self.px / 2))
                self.root.addSublayer(shell)
                let to = CGPoint(x: shell.position.x + dx * self.px, y: shell.position.y + dy * self.px)
                self.animate(shell, "position", from: NSValue(point: shell.position), to: NSValue(point: to), duration: 0.5,
                             timing: .init(name: .easeOut), keep: true)
                self.animate(shell, "transform.rotation.z", from: 0, to: spin, duration: 0.5, keep: true)
                self.animate(shell, "opacity", from: 1, to: 0, duration: 0.5, keep: true)
                self.after(0.55) { shell.removeFromSuperlayer() }
            }
            self.form(pet, at: spot)
        }
        after(4.7) {
            home?.addSublayer(pet.node)
            self.hide()
            hatched()
        }
    }

    // MARK: Recall

    /// A ball appears beside `pet`, opens, a red beam hits the pet, it turns to red energy and is
    /// drawn into the ball, which shuts, wobbles and fades away.
    func recall(_ pet: Pet, done: @escaping () -> Void) {
        show()
        let home = pet.node.superlayer
        root.addSublayer(pet.node)
        let feet = pet.position
        let side: CGFloat = pet.facingRight ? 1 : -1
        let at = CGPoint(x: feet.x + side * 30 * px, y: feet.y + 16 * px)
        let ball = makeBall(at: at)
        animate(ball.node, "transform.scale", from: 0.2, to: 1, duration: 0.18)
        ball.node.opacity = 1

        after(0.25) { self.open(ball) }
        after(0.35) { self.beam(from: at, to: CGPoint(x: feet.x, y: feet.y + 14 * self.px), color: .systemRed) }
        after(0.45) {
            let red = pet.silhouette(NSColor(calibratedRed: 1, green: 0.2, blue: 0.25, alpha: 1))
            red.opacity = 0
            red.opacity = 1                                              // fades in (implicit animation)
            self.after(0.25) {
                // Drawn into the ball as energy.
                self.animate(pet.node, "transform.scale", from: 1, to: 0.05, duration: 0.3, timing: .init(name: .easeIn))
                self.animate(pet.node, "position", path: nil, from: NSValue(point: feet), to: NSValue(point: at),
                             duration: 0.3, timing: .init(name: .easeIn))
            }
            self.after(0.56) {
                pet.node.isHidden = true
                pet.node.removeAnimation(forKey: "transform.scale")
                pet.node.removeAnimation(forKey: "position")
                red.removeFromSuperlayer()
                home?.addSublayer(pet.node)
            }
        }
        after(0.62) { self.close(ball) }
        after(0.75) {
            let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            wobble.values = [0, 0.25, -0.25, 0.15, 0]
            wobble.duration = 0.5
            ball.node.add(wobble, forKey: "wobble")
        }
        after(1.3) {
            self.vanish(ball) {
                self.hide()
                done()
            }
        }
    }

    // MARK: Thunderbolt

    /// A crackling zigzag bolt from `a` to `b` that flickers a few times and bursts at `b`.
    /// `impact` runs the moment it hits (e.g. to send the file to the Trash).
    func bolt(from a: CGPoint, to b: CGPoint, thickness: CGFloat = 1, impact: @escaping () -> Void) {
        show()
        let glow = CAShapeLayer(), core = CAShapeLayer()
        for (line, width, color) in [(glow, 6 * px * thickness, NSColor.systemYellow.withAlphaComponent(0.45)),
                                     (core, 1.6 * px * thickness, NSColor(calibratedRed: 1, green: 1, blue: 0.75, alpha: 1))] {
            line.lineWidth = width
            line.lineJoin = .miter
            line.fillColor = nil
            line.strokeColor = color.cgColor
            line.shadowColor = NSColor.systemYellow.cgColor
            line.shadowRadius = 8
            line.shadowOpacity = 1
            line.shadowOffset = .zero
            root.addSublayer(line)
        }
        func zigzag() -> CGPath {                                       // jagged line, new shape each flicker
            let path = CGMutablePath()
            path.move(to: a)
            let dx = b.x - a.x, dy = b.y - a.y, length = max(1, hypot(dx, dy))
            let normal = CGPoint(x: -dy / length, y: dx / length)
            let segments = max(4, Int(length / 28))
            for i in 1..<segments {
                let t = CGFloat(i) / CGFloat(segments), jitter = CGFloat.random(in: -7...7) * px
                path.addLine(to: CGPoint(x: a.x + dx * t + normal.x * jitter, y: a.y + dy * t + normal.y * jitter))
            }
            path.addLine(to: b)
            return path
        }
        for (i, delay) in [0.0, 0.06, 0.12, 0.2].enumerated() {
            after(delay) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let path = zigzag()
                glow.path = path
                core.path = path
                glow.opacity = i == 3 ? 0.5 : 1
                core.opacity = i == 3 ? 0.5 : 1
                CATransaction.commit()
            }
        }
        after(0.08) {
            self.flash(at: b, color: .systemYellow)
            impact()
        }
        after(0.32) {
            glow.removeFromSuperlayer()
            core.removeFromSuperlayer()
        }
        after(0.5) { self.hide() }
    }

    // MARK: Shadow Ball

    /// Gengar's file delete. A Shadow Ball swells at `hand` for `charge` seconds, then arcs to `target`.
    /// There the file's `icon` shows over its real one and is sucked into a swirling shadow (`impact` runs as
    /// it hits: the file goes to the Trash underneath). What's left, a little wisp, floats back to `mouth()`
    /// and `eaten` runs as it arrives. `throwing` runs when the ball leaves its hand.
    func shadowBall(at hand: CGPoint, charge: TimeInterval, to target: CGPoint, icon: CGImage?, mouth: @escaping () -> CGPoint,
                    throwing: @escaping () -> Void, impact: @escaping () -> Void, eaten: @escaping () -> Void) {
        show()
        let size = 10 * px
        let orb = CALayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        orb.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        orb.position = hand
        orb.contents = Pixels.shadowBall
        orb.magnificationFilter = .nearest
        orb.shadowColor = NSColor(calibratedRed: 0.7, green: 0.35, blue: 1, alpha: 1).cgColor
        orb.shadowRadius = 10
        orb.shadowOpacity = 0.9
        orb.shadowOffset = .zero
        root.addSublayer(orb)
        CATransaction.commit()
        // Charging: swells from a speck, pulsing.
        let swell = CAKeyframeAnimation(keyPath: "transform.scale")
        swell.values = [0.15, 0.6, 0.5, 0.9, 0.8, 1]
        swell.duration = charge
        orb.add(swell, forKey: "swell")
        spin(orb, period: 0.6)

        after(charge) {
            throwing()
            let lift = max(40, hypot(target.x - hand.x, target.y - hand.y) * 0.25)
            let path = CGMutablePath()
            path.move(to: hand)
            path.addQuadCurve(to: target, control: CGPoint(x: (hand.x + target.x) / 2, y: max(hand.y, target.y) + lift))
            self.animate(orb, "position", path: path, duration: 0.45, timing: CAMediaTimingFunction(name: .easeIn), keep: true)
        }
        after(charge + 0.45) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            orb.removeAnimation(forKey: "position")
            orb.position = target
            CATransaction.commit()
            self.flash(at: target, color: NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.9, alpha: 1))
            // The file, sucked into the shadow: spins, shrinks and fades into the swelling orb.
            if let icon {
                let file = CALayer()
                file.contents = icon
                file.bounds = CGRect(x: 0, y: 0, width: 56, height: 56)
                file.position = target
                self.root.insertSublayer(file, below: orb)
                self.animate(file, "transform.scale", from: 1, to: 0.05, duration: 0.7, timing: CAMediaTimingFunction(name: .easeIn), keep: true)
                self.animate(file, "transform.rotation.z", from: 0, to: -4 * CGFloat.pi, duration: 0.7, keep: true)
                self.animate(file, "opacity", from: 1, to: 0, duration: 0.7, timing: CAMediaTimingFunction(name: .easeIn), keep: true)
                self.after(0.75) { file.removeFromSuperlayer() }
            }
            impact()
            self.animate(orb, "transform.scale", from: 1, to: 2.2, duration: 0.35, keep: true)
            self.spin(orb, period: 0.25)
        }
        after(charge + 0.45 + 0.75) {
            // Only a wisp is left. It drifts back and is gobbled up.
            self.animate(orb, "transform.scale", from: 2.2, to: 0.35, duration: 0.25, keep: true)
            let start = target, end = mouth()
            let path = CGMutablePath()
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + 60))
            self.animate(orb, "position", path: path, duration: 0.6, timing: CAMediaTimingFunction(name: .easeInEaseOut), keep: true)
        }
        after(charge + 0.45 + 0.75 + 0.6) {
            orb.removeFromSuperlayer()
            eaten()
            self.after(0.1) { self.hide() }
        }
    }

    // MARK: Lick

    /// A wet lick mark on the "glass" at `point` (it's drawn over your apps, like it's on your screen),
    /// with a few drips running down from it. Everything fades away after a few seconds.
    func saliva(at point: CGPoint) {
        show()
        func pixel(_ image: CGImage, at p: CGPoint) -> CALayer {
            let l = CALayer()
            l.contents = image
            l.magnificationFilter = .nearest
            l.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * px, height: CGFloat(image.height) * px)
            l.position = p
            l.opacity = 0.75
            return l
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let smear = pixel(Pixels.saliva, at: point)
        root.addSublayer(smear)
        var drips: [CALayer] = []
        for _ in 0..<Int.random(in: 2...3) {
            let start = CGPoint(x: point.x + .random(in: -5...5) * px, y: point.y - 3 * px)
            let d = pixel(Pixels.drip, at: start)
            root.addSublayer(d)
            drips.append(d)
        }
        CATransaction.commit()
        animate(smear, "transform.scale", from: 0.6, to: 1, duration: 0.15)
        for (i, d) in drips.enumerated() {                       // run down the glass, one after another, slowing as they go
            let fall = CGFloat.random(in: 18...40) * px
            after(0.4 + Double(i) * 0.5) {
                self.animate(d, "position", from: NSValue(point: d.position),
                             to: NSValue(point: CGPoint(x: d.position.x, y: d.position.y - fall)),
                             duration: .random(in: 2...3.2), timing: CAMediaTimingFunction(name: .easeOut), keep: true)
            }
        }
        after(4) {
            for l in [smear] + drips { self.animate(l, "opacity", from: 0.75, to: 0, duration: 1.5, keep: true) }
        }
        after(5.6) {
            for l in [smear] + drips { l.removeFromSuperlayer() }
            self.hide()
        }
    }

    // MARK: Prints

    /// Stamps `image` at each point in turn (`every` seconds apart), as if pressed on the glass; they
    /// fade away together a few seconds after the last one. `flipped`: mirror every other one (left/right hand).
    func stamp(_ image: CGImage, at points: [CGPoint], every: TimeInterval, flipped: Bool = true) {
        show()
        var marks: [CALayer] = []
        for (i, p) in points.enumerated() {
            after(Double(i) * every) {
                let l = CALayer()
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                l.contents = image
                l.magnificationFilter = .nearest
                l.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) * self.px, height: CGFloat(image.height) * self.px)
                l.position = p
                l.opacity = 0.7
                if flipped, i % 2 == 1 { l.transform = CATransform3DMakeScale(-1, 1, 1) }
                self.root.addSublayer(l)
                CATransaction.commit()
                self.animate(l, "transform.scale", from: 1.3, to: 1, duration: 0.12)
                marks.append(l)
            }
        }
        let last = Double(points.count) * every
        after(last + 4) { for l in marks { self.animate(l, "opacity", from: 0.7, to: 0, duration: 1.5, keep: true) } }
        after(last + 5.6) {
            for l in marks { l.removeFromSuperlayer() }
            self.hide()
        }
    }

    private func spin(_ layer: CALayer, period: CFTimeInterval) {
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = 2 * CGFloat.pi
        turn.duration = period
        turn.repeatCount = .infinity
        layer.add(turn, forKey: "spin")
    }

    // MARK: Pieces

    private struct Ball { let node: CALayer; let top: CALayer }

    /// A ball (two halves, so the top can hinge open) centred at `point`.
    private func makeBall(at point: CGPoint) -> Ball {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let size = 12 * px
        let node = CALayer()
        node.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        node.position = point
        let bottom = CALayer()
        bottom.frame = CGRect(x: 0, y: 0, width: size, height: size / 2)
        bottom.contents = Pixels.pokeballBottom
        bottom.magnificationFilter = .nearest
        let top = CALayer()
        top.anchorPoint = .zero                                          // hinge at the back (left) of the band
        top.bounds = CGRect(x: 0, y: 0, width: size, height: size / 2)
        top.position = CGPoint(x: 0, y: size / 2)
        top.contents = Pixels.pokeballTop
        top.magnificationFilter = .nearest
        node.addSublayer(bottom)
        node.addSublayer(top)
        root.addSublayer(node)
        CATransaction.commit()
        return Ball(node: node, top: top)
    }

    private func open(_ ball: Ball) {
        animate(ball.top, "transform.rotation.z", from: 0, to: 0.95, duration: 0.12, keep: true)
    }

    private func close(_ ball: Ball) {
        animate(ball.top, "transform.rotation.z", from: 0.95, to: 0, duration: 0.1, keep: true)
    }

    private func vanish(_ ball: Ball, then done: @escaping () -> Void) {
        animate(ball.node, "transform.scale", from: 1, to: 0.2, duration: 0.25, keep: true)
        animate(ball.node, "opacity", from: 1, to: 0, duration: 0.25, keep: true)
        after(0.27) {
            ball.node.removeFromSuperlayer()
            done()
        }
    }

    /// A burst of light at the ball: a glowing disc that swells and fades.
    private func flash(at point: CGPoint, color: NSColor) {
        let disc = CALayer()
        disc.bounds = CGRect(x: 0, y: 0, width: 24 * px, height: 24 * px)
        disc.position = point
        disc.cornerRadius = 12 * px
        disc.backgroundColor = color.withAlphaComponent(0.9).cgColor
        disc.shadowColor = color.cgColor
        disc.shadowRadius = 10
        disc.shadowOpacity = 1
        disc.shadowOffset = .zero
        disc.opacity = 0
        root.addSublayer(disc)
        animate(disc, "transform.scale", from: 0.2, to: 1.6, duration: 0.35)
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 0]
        fade.keyTimes = [0, 0.2, 1]
        fade.duration = 0.35
        disc.add(fade, forKey: "fade")
        after(0.4) { disc.removeFromSuperlayer() }
    }

    /// The streak of light from the ball to the pet: shoots out, glows, then fades.
    private func beam(from a: CGPoint, to b: CGPoint, color: NSColor) {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        for (width, alpha) in [(5 * px, 0.35), (2 * px, 1.0)] {          // soft outer glow + bright core
            let line = CAShapeLayer()
            line.path = path
            line.lineWidth = width
            line.lineCap = .round
            line.strokeColor = color.withAlphaComponent(alpha).cgColor
            line.shadowColor = color.cgColor
            line.shadowRadius = 8
            line.shadowOpacity = 1
            line.shadowOffset = .zero
            root.addSublayer(line)
            animate(line, "strokeEnd", from: 0, to: 1, duration: 0.12)
            after(0.3) { line.opacity = 0 }                              // fades (implicit animation)
            after(0.6) { line.removeFromSuperlayer() }
        }
    }

    // MARK: Helpers

    private func show() { window.orderFrontRegardless() }
    private func hide() { if root.sublayers?.isEmpty ?? true { window.orderOut(nil) } }

    private func after(_ seconds: TimeInterval, _ f: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: f)
    }

    private func animate(_ layer: CALayer, _ keyPath: String, path: CGPath? = nil, from: Any? = nil, to: Any? = nil,
                         duration: CFTimeInterval, timing: CAMediaTimingFunction? = nil, keep: Bool = false) {
        let a = CAKeyframeAnimation(keyPath: keyPath)
        if let path { a.path = path } else { a.values = [from as Any, to as Any] }
        a.duration = duration
        a.timingFunction = timing
        if keep {                                                       // stay at the end value
            a.fillMode = .forwards
            a.isRemovedOnCompletion = false
        }
        layer.add(a, forKey: keyPath)
    }
}
