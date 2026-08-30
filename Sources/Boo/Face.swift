import SwiftUI

/// Boo's expression. The eyes carry the mood; the heart carries the load.
enum Mood: String, CaseIterable {
    case calm, working, strained, tunedIn, sleepy, charged

    /// What the panel says out loud. Plain sentences, never a nag.
    var headline: String {
        switch self {
        case .calm:     "All good"
        case .working:  "Busy but fine"
        case .strained: "Struggling"
        case .tunedIn:  "Tuned in"
        case .sleepy:   "Getting tired"
        case .charged:  "Topping up"
        }
    }
}

/// The heart doubles as the load gauge, so its colour is a separate axis
/// from the mood: audio wins, then load bands.
enum HeartTint: Equatable {
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
    var gazeY: CGFloat = 0       // -1 up … 0 level … +1 down
    /// A momentary performance layered over the mood.
    var act: Act = .none
    /// While peeking: true when hiding behind the LEFT edge, so the visible
    /// eye is the one facing the middle of the screen.
    var peekFromLeft = false
    /// While typing: which hand is currently down on the keys.
    var leftHandDown = true
    var heartScale: CGFloat = 1
    var bodyColor = Color(red: 0.969, green: 0.957, blue: 0.925)  // #F7F4EC
    /// Colour painted into the eyes when not punching through. Only used
    /// when `punchThrough` is false.
    var voidColor = Color(red: 0.051, green: 0.055, blue: 0.067)
    /// Cut the eyes out as real transparency instead of painting them.
    ///
    /// The menu bar needs this: a filled shape with same-coloured eyes
    /// drawn on top is just a blob once macOS tints it as a template
    /// image. Real holes survive the tint, and let the icon invert with
    /// the menu bar for free.
    var punchThrough = false

    private var eyeOffset: CGFloat { gaze * 2.6 }
    private var eyeOffsetY: CGFloat { gazeY * 2.0 }

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 64                       // one grid unit
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            if mood == .tunedIn { drawHeadphones(ctx, s: s, p: p) }

            if punchThrough {
                // Body and eyes share one transparency layer so
                // destinationOut erases to nothing rather than to whatever
                // is painted underneath.
                ctx.drawLayer { layer in
                    layer.fill(bodyPath(s: s), with: .color(bodyColor))
                    layer.blendMode = .destinationOut
                    drawEyes(layer, s: s, p: p)
                    drawHeartCutout(layer, s: s)
                }
            } else {
                ctx.fill(bodyPath(s: s), with: .color(bodyColor))
                drawEyes(ctx, s: s, p: p)
            }
            if !punchThrough { drawHeart(ctx, s: s) }

            switch act {
            case .typing:     drawGlasses(ctx, s: s, p: p); drawKeyboard(ctx, s: s)
            case .shivering:  drawShiver(ctx, s: s)
            case .sheltering: drawUmbrella(ctx, s: s)
            case .sipping:    drawMug(ctx, s: s)
            case .partying:   drawHat(ctx, s: s)
            default: break
            }

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
        let lx = 23 + eyeOffset, rx = 41 + eyeOffset, y: CGFloat = 31 + eyeOffsetY

        // An act overrides the mood's eyes while it runs.
        switch act {
        case .scared:
            // Huge round eyes — the whole joke is the size jump.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 6.4) * s, y: (y - 6.8) * s,
                               width: 12.8 * s, height: 13.6 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .giggling, .petted, .celebrating, .hearts:
            // Happy closed arcs, curving up.
            for cx in [lx, rx] {
                var arc = Path()
                arc.move(to: p(cx - 4.4, y + 1.6))
                arc.addQuadCurve(to: p(cx + 4.4, y + 1.6), control: p(cx, y - 4.4))
                ctx.stroke(arc, with: .color(voidColor),
                           style: .init(lineWidth: 3.2 * s, lineCap: .round))
            }
            return
        case .sleeping:
            // Flat closed lids — deeper asleep than the sleepy mood.
            for cx in [lx, rx] {
                var line = Path()
                line.move(to: p(cx - 4.2, y))
                line.addLine(to: p(cx + 4.2, y))
                ctx.stroke(line, with: .color(voidColor),
                           style: .init(lineWidth: 3.0 * s, lineCap: .round))
            }
            return
        case .squashed:
            // Squinting from the squeeze.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 4.3) * s, y: (y - 2.6) * s,
                               width: 8.6 * s, height: 5.2 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .swooping:
            // Determined little face — brows down, eyes forward.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 4.6) * s, y: (y - 3.4) * s,
                               width: 9.2 * s, height: 7.4 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .yawning:
            // Squeezed-shut eyes, the way a real yawn closes them.
            for cx in [lx, rx] {
                var arc = Path()
                arc.move(to: p(cx - 4.2, y + 1))
                arc.addQuadCurve(to: p(cx + 4.2, y + 1), control: p(cx, y - 3.4))
                ctx.stroke(arc, with: .color(voidColor),
                           style: .init(lineWidth: 3.0 * s, lineCap: .round))
            }
            return
        case .sneezing:
            // Scrunched tight.
            for cx in [lx, rx] {
                var l = Path()
                l.move(to: p(cx - 3.8, y - 1.2))
                l.addLine(to: p(cx + 3.8, y + 1.2))
                ctx.stroke(l, with: .color(voidColor),
                           style: .init(lineWidth: 2.8 * s, lineCap: .round))
            }
            return
        case .stargazing:
            // Looking up and slightly dreamy — bigger, raised.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 4.6) * s, y: (y - 6.2) * s,
                               width: 9.2 * s, height: 9.8 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .peeking:
            // One eye, on the side facing the screen — the other is behind
            // the edge. Slightly wide, because it is watching you.
            let cx = peekFromLeft ? rx : lx
            let r = CGRect(x: (cx - 4.6) * s, y: (y - 5) * s,
                           width: 9.2 * s, height: 10 * s)
            ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            return
        case .orbiting:
            // Cursor-sized, so detail is wasted: two big simple eyes that
            // still read at 26pt across.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 5.4) * s, y: (y - 5.4) * s,
                               width: 10.8 * s, height: 10.8 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .scratchpad:
            // Attentive: looking down at the bubbles it just produced.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 4.3) * s, y: (y - 3.2) * s,
                               width: 8.6 * s, height: 9.2 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .typing:
            // Eyes behind round glasses: normal pupils, lenses drawn later
            // so they sit over the top.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 3.6) * s, y: (y - 3.8) * s,
                               width: 7.2 * s, height: 7.6 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .shivering:
            // Squeezed shut against the cold.
            for cx in [lx, rx] {
                var l = Path()
                l.move(to: p(cx - 4, y))
                l.addLine(to: p(cx + 4, y))
                ctx.stroke(l, with: .color(voidColor),
                           style: .init(lineWidth: 3.2 * s, lineCap: .round))
            }
            return
        case .sheltering:
            // Worried: small eyes, raised.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 3.4) * s, y: (y - 4.4) * s,
                               width: 6.8 * s, height: 7.2 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .sipping, .partying:
            // Content, happy arcs.
            for cx in [lx, rx] {
                var arc = Path()
                arc.move(to: p(cx - 4.2, y + 1.4))
                arc.addQuadCurve(to: p(cx + 4.2, y + 1.4), control: p(cx, y - 3.8))
                ctx.stroke(arc, with: .color(voidColor),
                           style: .init(lineWidth: 3.2 * s, lineCap: .round))
            }
            return
        case .watching:
            // Wide and tracking.
            for cx in [lx, rx] {
                let r = CGRect(x: (cx - 5) * s, y: (y - 5.2) * s,
                               width: 10 * s, height: 10.4 * s)
                ctx.fill(Path(ellipseIn: r), with: .color(voidColor))
            }
            return
        case .dancing, .none, .spinning, .wobbling, .bouncing:
            break
        }

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
    private func heartPath(s: CGFloat) -> Path {
        let cells: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (28, 38, 3, 3), (33, 38, 3, 3), (26, 41, 12, 3), (28, 44, 8, 3), (30, 47, 4, 3)
        ]
        var heart = Path()
        for (x, y, w, h) in cells {
            heart.addRect(CGRect(x: x * s, y: y * s, width: w * s, height: h * s))
        }
        // Scale about the heart's own centre so the beat doesn't drift.
        let c = CGPoint(x: 32 * s, y: 43 * s)
        return heart.applying(
            CGAffineTransform(translationX: c.x, y: c.y)
                .scaledBy(x: heartScale, y: heartScale)
                .translatedBy(x: -c.x, y: -c.y))
    }

    private func drawHeart(_ ctx: GraphicsContext, s: CGFloat) {
        ctx.fill(heartPath(s: s), with: .color(tint.color))
    }

    /// Heart as a hole, for the template-image path. Tint can't survive
    /// there, so the shape has to carry the meaning on its own.
    private func drawHeartCutout(_ ctx: GraphicsContext, s: CGFloat) {
        ctx.fill(heartPath(s: s), with: .color(.black))
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

    /// Round glasses, drawn over the eyes.
    private func drawGlasses(_ ctx: GraphicsContext, s: CGFloat,
                             p: (CGFloat, CGFloat) -> CGPoint) {
        let y: CGFloat = 31 + eyeOffsetY
        for cx in [23 + eyeOffset, 41 + eyeOffset] {
            let lens = Path(ellipseIn: CGRect(x: (cx - 7) * s, y: (y - 7) * s,
                                              width: 14 * s, height: 14 * s))
            ctx.fill(lens, with: .color(Color(red: 0.47, green: 0.72, blue: 0.87)
                .opacity(0.16)))
            ctx.stroke(lens, with: .color(voidColor), lineWidth: 1.8 * s)
        }
        // Bridge, and arms going back past the head.
        var bridge = Path()
        bridge.move(to: p(30 + eyeOffset, y)); bridge.addLine(to: p(34 + eyeOffset, y))
        ctx.stroke(bridge, with: .color(voidColor), lineWidth: 1.6 * s)
    }

    /// Two stubby arms and a little keyboard. The hand that is down is the
    /// one currently pressing a key.
    private func drawKeyboard(_ ctx: GraphicsContext, s: CGFloat) {
        let leftY: CGFloat = leftHandDown ? 57 : 53
        let rightY: CGFloat = leftHandDown ? 53 : 57

        for (x, endX, endY) in [(19.0, 14.0, leftY), (45.0, 50.0, rightY)] {
            var arm = Path()
            arm.move(to: CGPoint(x: x * s, y: 45 * s))
            arm.addQuadCurve(to: CGPoint(x: endX * s, y: endY * s),
                             control: CGPoint(x: (x + endX) / 2 * s, y: 50 * s))
            ctx.stroke(arm, with: .color(bodyColor),
                       style: .init(lineWidth: 4.4 * s, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: (endX - 3.2) * s, y: (endY - 3.2) * s,
                                            width: 6.4 * s, height: 6.4 * s)),
                     with: .color(bodyColor))
        }

        // Keyboard body
        ctx.fill(Path(roundedRect: CGRect(x: 8 * s, y: 59 * s,
                                          width: 48 * s, height: 13 * s),
                      cornerRadius: 2.5 * s),
                 with: .color(Color(red: 0.13, green: 0.15, blue: 0.18)))
        // Keys
        for row in 0..<2 {
            for col in 0..<6 {
                let kx = 11 + CGFloat(col) * 7.4 + (row == 1 ? 2 : 0)
                let ky = 61.5 + CGFloat(row) * 5
                ctx.fill(Path(roundedRect: CGRect(x: kx * s, y: ky * s,
                                                  width: 5.4 * s, height: 3.4 * s),
                              cornerRadius: 0.8 * s),
                         with: .color(Color(red: 0.24, green: 0.27, blue: 0.31)))
            }
        }
    }

    private func drawShiver(_ ctx: GraphicsContext, s: CGFloat) {
        let cold = Color(red: 0.47, green: 0.72, blue: 0.87)
        for (x, y) in [(8.0, 24.0), (8.0, 36.0), (56.0, 24.0), (56.0, 36.0)] {
            var l = Path()
            l.move(to: CGPoint(x: x * s, y: y * s))
            l.addLine(to: CGPoint(x: (x < 32 ? x - 4 : x + 4) * s, y: (y - 2) * s))
            ctx.stroke(l, with: .color(cold),
                       style: .init(lineWidth: 1.8 * s, lineCap: .round))
        }
    }

    private func drawUmbrella(_ ctx: GraphicsContext, s: CGFloat) {
        var canopy = Path()
        canopy.move(to: CGPoint(x: 14 * s, y: 14 * s))
        canopy.addQuadCurve(to: CGPoint(x: 50 * s, y: 14 * s),
                            control: CGPoint(x: 32 * s, y: -2 * s))
        canopy.closeSubpath()
        ctx.fill(canopy, with: .color(HeartTint.hot.color))
        var stick = Path()
        stick.move(to: CGPoint(x: 32 * s, y: 14 * s))
        stick.addLine(to: CGPoint(x: 32 * s, y: 24 * s))
        ctx.stroke(stick, with: .color(HeartTint.hot.color), lineWidth: 2 * s)
    }

    private func drawMug(_ ctx: GraphicsContext, s: CGFloat) {
        let mug = Color(red: 0.24, green: 0.27, blue: 0.31)
        ctx.fill(Path(roundedRect: CGRect(x: 44 * s, y: 42 * s,
                                          width: 13 * s, height: 12 * s),
                      cornerRadius: 2 * s), with: .color(mug))
        var handle = Path()
        handle.move(to: CGPoint(x: 57 * s, y: 45 * s))
        handle.addQuadCurve(to: CGPoint(x: 57 * s, y: 51 * s),
                            control: CGPoint(x: 62 * s, y: 48 * s))
        ctx.stroke(handle, with: .color(mug), lineWidth: 1.8 * s)
        // Steam
        for x in [47.0, 52.0] {
            var st = Path()
            st.move(to: CGPoint(x: x * s, y: 40 * s))
            st.addQuadCurve(to: CGPoint(x: x * s, y: 34 * s),
                            control: CGPoint(x: (x + 2.4) * s, y: 37 * s))
            ctx.stroke(st, with: .color(bodyColor.opacity(0.45)),
                       style: .init(lineWidth: 1.5 * s, lineCap: .round))
        }
    }

    private func drawHat(_ ctx: GraphicsContext, s: CGFloat) {
        var hat = Path()
        hat.move(to: CGPoint(x: 32 * s, y: -6 * s))
        hat.addLine(to: CGPoint(x: 42 * s, y: 11 * s))
        hat.addLine(to: CGPoint(x: 22 * s, y: 11 * s))
        hat.closeSubpath()
        ctx.fill(hat, with: .color(HeartTint.idle.color))
        ctx.fill(Path(ellipseIn: CGRect(x: 29 * s, y: -10 * s,
                                        width: 6 * s, height: 6 * s)),
                 with: .color(HeartTint.busy.color))
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
