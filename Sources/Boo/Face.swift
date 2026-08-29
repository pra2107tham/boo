import SwiftUI

/// Boo's expression. The eyes carry the mood; the heart carries the load.
enum Mood: String, CaseIterable {
    case calm, working, strained, tunedIn, sleepy, charged

    /// What the panel says out loud. Plain sentences, never a nag.
    var headline: String {
        switch self {
        case .calm:     "All good"
        case .working:  "Busy but fine"
        case .strained: "Struggling a bit"
        case .tunedIn:  "Tuned in"
        case .sleepy:   "Getting tired"
        case .charged:  "Topping up"
        }
    }
}

/// The heart doubles as the load gauge, so its colour is a separate axis
/// from the mood: audio wins, then load bands.
enum HeartTint {
    case idle, busy, hot, audio

    var color: Color {
        switch self {
        case .idle:  Color(red: 0.357, green: 0.788, blue: 0.541)  // #5BC98A
        case .busy:  Color(red: 0.961, green: 0.651, blue: 0.137)  // #F5A623
        case .hot:   Color(red: 0.937, green: 0.373, blue: 0.298)  // #EF5F4C
        case .audio: Color(red: 0.341, green: 0.769, blue: 0.753)  // #57C4C0
        }
    }
}

/// The ghost. Drawn on a 64x64 grid so every dimension matches the spec.
///
/// Body silhouette never changes — only eyes, tint and accessories do.
/// That constancy is what makes it recognisable at 18px.
struct Face: View {
    let mood: Mood
    let tint: HeartTint
    var blinking = false
    var gaze: CGFloat = 0        // -1 left … 0 ahead … +1 right
    var heartScale: CGFloat = 1
    var bodyColor = Color(red: 0.969, green: 0.957, blue: 0.925)  // #F7F4EC
    /// Punched-through holes show the background, so eyes need its colour.
    var voidColor = Color(red: 0.051, green: 0.055, blue: 0.067)

    private var eyeOffset: CGFloat { gaze * 2.6 }

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 64                       // one grid unit
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            if mood == .tunedIn { drawHeadphones(ctx, s: s, p: p) }

            ctx.fill(bodyPath(s: s), with: .color(bodyColor))
            drawEyes(ctx, s: s, p: p)
            drawHeart(ctx, s: s)

            switch mood {
            case .strained: drawSweat(ctx, s: s)
            case .charged:  drawBolt(ctx, s: s)
            case .sleepy:   drawZ(ctx, s: s)
            default: break
            }
        }
    }

    // Dome plus a three-wave hem. Three, never four — four reads as fabric.
    private func bodyPath(s: CGFloat) -> Path {
        var b = Path()
        b.move(to: CGPoint(x: 32 * s, y: 5 * s))
        b.addCurve(to: CGPoint(x: 55 * s, y: 28.5 * s),
                   control1: CGPoint(x: 45.8 * s, y: 5 * s),
                   control2: CGPoint(x: 55 * s, y: 15 * s))
        b.addLine(to: CGPoint(x: 55 * s, y: 48.2 * s))
        // Hem: alternating dips, each a pair of quarter-arcs.
        let hem: [(CGFloat, CGFloat)] = [(50, 50.6), (43.5, 50.6), (36.6, 50.6),
                                         (30.1, 50.6), (23.2, 50.6), (16.7, 50.6)]
        b.addCurve(to: CGPoint(x: hem[0].0 * s, y: hem[0].1 * s),
                   control1: CGPoint(x: 55 * s, y: 51.4 * s),
                   control2: CGPoint(x: 52 * s, y: 52.6 * s))
        for i in stride(from: 1, to: hem.count, by: 1) {
            let prev = hem[i - 1], cur = hem[i]
            let midY: CGFloat = i.isMultiple(of: 2) ? 52.6 : 48.7
            b.addCurve(to: CGPoint(x: cur.0 * s, y: cur.1 * s),
                       control1: CGPoint(x: (prev.0 - 1.9) * s, y: midY * s),
                       control2: CGPoint(x: (cur.0 + 1.9) * s, y: midY * s))
        }
        b.addCurve(to: CGPoint(x: 12 * s, y: 48.2 * s),
                   control1: CGPoint(x: 14.7 * s, y: 52.6 * s),
                   control2: CGPoint(x: 12 * s, y: 51.4 * s))
        b.addLine(to: CGPoint(x: 12 * s, y: 28.5 * s))
        b.addCurve(to: CGPoint(x: 32 * s, y: 5 * s),
                   control1: CGPoint(x: 12 * s, y: 15 * s),
                   control2: CGPoint(x: 18.2 * s, y: 5 * s))
        b.closeSubpath()
        return b
    }

    // Eyes sit on y=31, just below centre — the baby proportion. Raising
    // them ages the character instantly, so this number is load-bearing.
    private func drawEyes(_ ctx: GraphicsContext, s: CGFloat, p: (CGFloat, CGFloat) -> CGPoint) {
        let lx = 23 + eyeOffset, rx = 41 + eyeOffset, y: CGFloat = 31

        if blinking || mood == .sleepy {
            for cx in [lx, rx] {
                var arc = Path()
                arc.move(to: p(cx - 4.4, y))
                arc.addQuadCurve(to: p(cx + 4.4, y), control: p(cx, y + 4.4))
                ctx.stroke(arc, with: .color(voidColor),
                           style: .init(lineWidth: 3.2 * s, lineCap: .round))
            }
            return
        }

        switch mood {
        case .strained:  // slanted brows reading as effort
            for (cx, dir) in [(lx, CGFloat(1)), (rx, CGFloat(-1))] {
                var l = Path()
                l.move(to: p(cx - 4.4 * dir, y - 2.6))
                l.addLine(to: p(cx + 4.4 * dir, y + 2.6))
                ctx.stroke(l, with: .color(voidColor),
                           style: .init(lineWidth: 3.4 * s, lineCap: .round))
            }
        case .charged:   // happy upward arcs
            for cx in [lx, rx] {
                var v = Path()
                v.move(to: p(cx - 4.4, y + 2))
                v.addLine(to: p(cx, y - 3))
                v.addLine(to: p(cx + 4.4, y + 2))
                ctx.stroke(v, with: .color(voidColor),
                           style: .init(lineWidth: 3.2 * s, lineCap: .round, lineJoin: .round))
            }
        default:         // resting: two slightly-taller-than-wide ovals
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 4.3) * s, y: (y - 4.6) * s,
                               width: 8.6 * s, height: 9.2 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
        }
    }

    // A 3px pixel grid keeps the heart crisp instead of muddy at small sizes.
    private func drawHeart(_ ctx: GraphicsContext, s: CGFloat) {
        let cells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (28, 38, 3, 3), (33, 38, 3, 3), (26, 41, 12, 3), (28, 44, 8, 3), (30, 47, 4, 3)
        ]
        var heart = Path()
        for (x, y, w, h) in cells {
            heart.addRect(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
        }
        // Scale about the heart's own centre so the beat doesn't drift.
        let c = CGPoint(x: 32 * s, y: 43 * s)
        let beat = heart.applying(
            CGAffineTransform(translationX: c.x, y: c.y)
                .scaledBy(x: heartScale, y: heartScale)
                .translatedBy(x: -c.x, y: -c.y))
        ctx.fill(beat, with: .color(tint.color))
    }

    private func drawHeadphones(_ ctx: GraphicsContext, s: CGFloat,
                                p: (CGFloat, CGFloat) -> CGPoint) {
        var band = Path()
        band.move(to: p(12, 30.5))
        band.addLine(to: p(12, 26))
        band.addArc(center: p(32, 26), radius: 20 * s,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        band.addLine(to: p(52, 30.5))
        ctx.stroke(band, with: .color(bodyColor),
                   style: .init(lineWidth: 4 * s, lineCap: .round))
        for x in [CGFloat(6.5), 48] {
            ctx.fill(Path(roundedRect: CGRect(x: x * s, y: 28 * s,
                                              width: 9.5 * s, height: 15 * s),
                          cornerRadius: 4.7 * s), with: .color(bodyColor))
        }
    }

    private func drawSweat(_ ctx: GraphicsContext, s: CGFloat) {
        var d = Path()
        d.move(to: CGPoint(x: 52 * s, y: 14 * s))
        d.addQuadCurve(to: CGPoint(x: 52 * s, y: 23 * s),
                       control: CGPoint(x: 56.4 * s, y: 19 * s))
        d.addQuadCurve(to: CGPoint(x: 52 * s, y: 14 * s),
                       control: CGPoint(x: 47.6 * s, y: 19 * s))
        ctx.fill(d, with: .color(Color(red: 0.475, green: 0.722, blue: 0.867)))
    }

    private func drawBolt(_ ctx: GraphicsContext, s: CGFloat) {
        var b = Path()
        b.move(to: CGPoint(x: 52 * s, y: 8 * s))
        b.addLine(to: CGPoint(x: 47.4 * s, y: 16 * s))
        b.addLine(to: CGPoint(x: 50.8 * s, y: 16 * s))
        b.addLine(to: CGPoint(x: 48.4 * s, y: 23 * s))
        b.addLine(to: CGPoint(x: 54.4 * s, y: 14 * s))
        b.addLine(to: CGPoint(x: 51 * s, y: 14 * s))
        b.closeSubpath()
        ctx.fill(b, with: .color(HeartTint.idle.color))
    }

    private func drawZ(_ ctx: GraphicsContext, s: CGFloat) {
        var z = Path()
        z.move(to: CGPoint(x: 46 * s, y: 9 * s))
        z.addLine(to: CGPoint(x: 53 * s, y: 9 * s))
        z.addLine(to: CGPoint(x: 46 * s, y: 16 * s))
        z.addLine(to: CGPoint(x: 53 * s, y: 16 * s))
        ctx.stroke(z, with: .color(bodyColor.opacity(0.8)),
                   style: .init(lineWidth: 2 * s, lineCap: .round, lineJoin: .round))
    }
}
