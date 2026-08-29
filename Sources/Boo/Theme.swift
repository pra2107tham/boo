import SwiftUI

/// Type and colour for the panel.
///
/// The serif is what stops this looking like every other menu bar app.
/// New York is Apple's own serif — always installed, genuinely editorial,
/// and no font file to bundle or licence.
enum Theme {
    /// Big editorial serif for the mood sentence.
    static func serif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// Numbers. Monospaced so digits never jitter as the values tick.
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// Small tracked-out labels. These should recede, not compete.
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }
}

/// The blurred colour field behind the glass.
///
/// Generated rather than an image: it costs nothing to ship, animates
/// between states, and means the panel's atmosphere *is* the mood — you
/// read how the Mac is doing before you read a single word.
struct MoodBloom: View {
    let mood: Mood
    let tint: HeartTint
    /// Drives slow drift so the field is never quite static.
    let phase: Double

    private var palette: [Color] {
        switch mood {
        case .calm:
            [Color(red: 0.18, green: 0.56, blue: 0.42),
             Color(red: 0.12, green: 0.44, blue: 0.48),
             Color(red: 0.08, green: 0.29, blue: 0.25)]
        case .working:
            [Color(red: 0.20, green: 0.50, blue: 0.52),
             Color(red: 0.42, green: 0.46, blue: 0.24),
             Color(red: 0.12, green: 0.34, blue: 0.36)]
        case .strained:
            [Color(red: 0.85, green: 0.29, blue: 0.17),
             Color(red: 0.91, green: 0.47, blue: 0.12),
             Color(red: 0.55, green: 0.14, blue: 0.09)]
        case .tunedIn:
            [Color(red: 0.18, green: 0.66, blue: 0.63),
             Color(red: 0.43, green: 0.29, blue: 0.84),
             Color(red: 0.11, green: 0.37, blue: 0.56)]
        case .sleepy:
            [Color(red: 0.29, green: 0.27, blue: 0.48),
             Color(red: 0.20, green: 0.24, blue: 0.38),
             Color(red: 0.14, green: 0.16, blue: 0.28)]
        case .charged:
            [Color(red: 0.20, green: 0.66, blue: 0.44),
             Color(red: 0.36, green: 0.72, blue: 0.34),
             Color(red: 0.10, green: 0.40, blue: 0.30)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                blob(palette[0], size: w * 0.78,
                     x: w * 0.14 + CGFloat(sin(phase)) * 10,
                     y: h * 0.06 + CGFloat(cos(phase * 0.8)) * 8)
                blob(palette[1], size: w * 0.66,
                     x: w * 0.88 + CGFloat(cos(phase * 1.1)) * 10,
                     y: h * 0.18 + CGFloat(sin(phase * 0.9)) * 8)
                blob(palette[2], size: w * 0.72,
                     x: w * 0.42 + CGFloat(sin(phase * 0.7)) * 12,
                     y: h * 0.92 + CGFloat(cos(phase)) * 8)
            }
            // One big blur over the whole field rather than per-blob, so
            // the colours actually bleed into each other.
            .blur(radius: 38)
        }
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(x: x, y: y)
    }
}
