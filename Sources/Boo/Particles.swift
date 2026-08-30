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
