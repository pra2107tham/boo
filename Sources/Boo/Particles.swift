import SwiftUI

/// Draws the hearts, stars and notes that fly off Boo.
///
/// One Canvas for the whole swarm rather than a view per particle —
/// a dozen SwiftUI views appearing and vanishing 30 times a second is
/// far more work than one draw call.
struct ParticleLayer: View {
    let particles: [Particle]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            for p in particles {
                let x = cx + p.x, y = cy + p.y
                let alpha = min(1, p.life * 1.4)   // fade only near the end
                ctx.opacity = alpha
                switch p.kind {
                case .heart: drawHeart(ctx, x: x, y: y, scale: p.scale)
                case .star:  drawStar(ctx, x: x, y: y, scale: p.scale)
                case .note:  drawNote(ctx, x: x, y: y, scale: p.scale)
                case .sweat: drawSweat(ctx, x: x, y: y, scale: p.scale)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Same pixel-grid heart as Boo's own, so the shower reads as "its"
    /// hearts rather than generic clip art.
    private func drawHeart(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let u = 1.6 * scale
        var path = Path()
        for (dx, dy, w, h) in [(-2.0, -3.0, 2.0, 2.0), (0.0, -3.0, 2.0, 2.0),
                               (-3.0, -1.0, 6.0, 2.0), (-2.0, 1.0, 4.0, 2.0),
                               (-1.0, 3.0, 2.0, 2.0)] {
            path.addRect(CGRect(x: x + dx * u, y: y + dy * u,
                                width: w * u, height: h * u))
        }
        ctx.fill(path, with: .color(Color(red: 0.945, green: 0.396, blue: 0.478)))
    }

    private func drawStar(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let r = 3.4 * scale
        var path = Path()
        // Four-point sparkle: cheaper than a five-point star and reads
        // better at this size.
        path.move(to: CGPoint(x: x, y: y - r))
        path.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x, y: y))
        ctx.fill(path, with: .color(Color(red: 0.961, green: 0.784, blue: 0.306)))
    }

    private func drawNote(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let u = 1.5 * scale
        var path = Path()
        path.addEllipse(in: CGRect(x: x - 2 * u, y: y, width: 3.4 * u, height: 2.6 * u))
        path.addRect(CGRect(x: x + 1 * u, y: y - 5 * u, width: 0.9 * u, height: 6 * u))
        path.addRect(CGRect(x: x + 1 * u, y: y - 5 * u, width: 3 * u, height: 0.9 * u))
        ctx.fill(path, with: .color(Color(red: 0.341, green: 0.769, blue: 0.753)))
    }

    private func drawSweat(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let r = 3 * scale
        var path = Path()
        path.move(to: CGPoint(x: x, y: y - r))
        path.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x + r, y: y))
        path.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x - r, y: y))
        ctx.fill(path, with: .color(Color(red: 0.475, green: 0.722, blue: 0.867)))
    }
}

/// A fading comet tail behind Boo while it laps your cursor.
///
/// The trail is what sells the speed — without it a small ghost moving in a
/// circle just looks like it is being dragged.
struct OrbitTrail: View {
    /// Screen-space points, oldest first.
    let points: [CGPoint]

    var body: some View {
        Canvas { ctx, size in
            guard points.count > 1, let head = points.last else { return }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)

            for (i, p) in points.enumerated() {
                // Older points are smaller and fainter.
                let age = Double(i) / Double(points.count)
                let radius = 1.5 + 3.5 * age
                // Positions are absolute screen points; draw them relative
                // to where the ghost currently is.
                let dx = p.x - head.x
                let dy = head.y - p.y          // screen y is inverted
                let rect = CGRect(x: centre.x + dx - radius,
                                  y: centre.y + dy - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.opacity = age * 0.45
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(Color(red: 0.969, green: 0.957, blue: 0.925)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The door Boo hides behind when it peeks.
///
/// The sliding was never the problem — there was nothing to hide BEHIND, so
/// a ghost drifting sideways just looked lost. A door gives the movement a
/// reason, and it is the difference between "peeking" and "wandering off".
struct PeekDoor: View {
    /// 0 = absent, 1 = fully there.
    let open: CGFloat
    /// Which side of Boo the door stands on.
    let fromLeft: Bool

    /// Door size and gap, shared with the mask so the two cannot drift
    /// apart — they were computed separately before, which is exactly how
    /// Boo ended up clipped in one place and the door drawn in another.
    /// As wide as Boo, or he cannot be hidden by it — a 74pt door could
    /// never cover a 96pt ghost however far he slid.
    static let width: CGFloat = 96
    static let height: CGFloat = 112

    /// Where the door's INNER edge sits, relative to the view centre.
    /// Boo spans -48...+48 at rest, so -56 puts the door fully clear of
    /// him until he moves. Anything closer means he starts out already
    /// half-covered, which reads as broken rather than as hiding.
    static let innerEdge: CGFloat = 56

    /// Horizontal centre of the door relative to the view centre.
    static func centreX(fromLeft: Bool) -> CGFloat {
        (fromLeft ? -1 : 1) * (innerEdge + width / 2)
    }

    var body: some View {
        Canvas { ctx, size in
            guard open > 0.01 else { return }
            let w = Self.width, h = Self.height
            // Sits beside Boo, on the side it ducks toward.
            let x = size.width / 2 + Self.centreX(fromLeft: fromLeft) - w / 2
            let y = size.height / 2 - h / 2

            ctx.opacity = Double(open)
            // Swing in from the hinge side rather than fading in flat.
            let swing = 0.35 + 0.65 * open
            let panel = CGRect(x: fromLeft ? x + w * (1 - swing) : x,
                               y: y, width: w * swing, height: h)

            // Frame
            let frame = Path(roundedRect: panel.insetBy(dx: -3, dy: -3),
                             cornerRadius: 4)
            ctx.fill(frame, with: .color(Color(red: 0.16, green: 0.13, blue: 0.11)))

            // Door face
            let door = Path(roundedRect: panel, cornerRadius: 2)
            ctx.fill(door, with: .color(Color(red: 0.42, green: 0.29, blue: 0.20)))

            // Two recessed panels, so it reads as a door and not a plank.
            if swing > 0.6 {
                let inset = panel.insetBy(dx: panel.width * 0.16, dy: 12)
                for i in 0..<2 {
                    let ph = (inset.height - 8) / 2
                    let r = CGRect(x: inset.minX, y: inset.minY + CGFloat(i) * (ph + 8),
                                   width: inset.width, height: ph)
                    ctx.stroke(Path(roundedRect: r, cornerRadius: 2),
                               with: .color(Color(red: 0.30, green: 0.20, blue: 0.13)),
                               lineWidth: 1.5)
                }
                // Handle on the opening edge.
                let hx = fromLeft ? panel.minX + 8 : panel.maxX - 8
                ctx.fill(Path(ellipseIn: CGRect(x: hx - 2.5, y: panel.midY - 2.5,
                                                width: 5, height: 5)),
                         with: .color(Color(red: 0.85, green: 0.72, blue: 0.42)))
            }
        }
        .allowsHitTesting(false)
    }
}
