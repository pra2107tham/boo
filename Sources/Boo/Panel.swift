import SwiftUI

/// One metric. `fraction` nil means no bar — used for the audio row.
struct Reading: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let fraction: Double?
    let tint: Color

    static func percent(_ name: String, _ pct: Double) -> Reading {
        Reading(name: name, value: "\(Int(pct.rounded()))", fraction: pct / 100,
                tint: pct >= 85 ? HeartTint.hot.color
                    : pct >= 60 ? HeartTint.busy.color
                    : HeartTint.idle.color)
    }
}

/// What you get when you click Boo.
///
/// Soft mood-coloured light behind dark glass, an editorial serif for the
/// sentence, tabular numbers side by side. Deliberately not a dashboard —
/// no graphs, no history, no process list.
struct Panel: View {
    let mood: Mood
    let tint: HeartTint
    let subtitle: String
    let readings: [Reading]
    @ObservedObject var desktop: DesktopBoo
    @ObservedObject var personality: Personality

    /// Slow drift for the bloom, so the panel is never quite static.
    @State private var phase: Double = 0

    /// The three percentage stats; the audio row is handled separately.
    private var stats: [Reading] { readings.filter { $0.fraction != nil } }
    private var output: Reading? { readings.first { $0.fraction == nil } }

    var body: some View {
        ZStack {
            MoodBloom(mood: mood, tint: tint, phase: phase)
            // The glass: a translucent dark wash over the colour field.
            // Without it the bloom is pretty but the text is unreadable.
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.black.opacity(0.34))

            VStack(spacing: 0) {
                hero
                statRow
                if let output { outputRow(output) }
                footer
            }
        }
        .frame(width: 272)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .task {
            // 12fps is plenty for something this slow, and cheap.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
                phase += 0.012
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 3) {
            ZStack {
                Face(mood: mood, tint: tint, act: personality.act)
                    .frame(width: 76, height: 76)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                ParticleLayer(particles: personality.particles)
                    .frame(width: 120, height: 120)
            }
            .contentShape(Rectangle())
            .onTapGesture { personality.showerHearts() }

            Text(mood.headline)
                .font(Theme.serif(27))
                .foregroundStyle(.white)
                .padding(.top, 6)

            Text(subtitle)
                .font(Theme.body(11.5))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.top, 26)
        .padding(.bottom, 20)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, r in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 34)
                        .padding(.horizontal, 14)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(r.value)
                            .font(Theme.number(19))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("%")
                            .font(Theme.body(10))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Text(r.name.uppercased())
                        .font(Theme.label(9))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.42))
                    // A hairline bar, not a chunky one — the number is the
                    // message, the bar is only a glance-check.
                    Capsule()
                        .fill(Color.white.opacity(0.13))
                        .frame(height: 2)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule().fill(r.tint)
                                    .frame(width: geo.size.width * (r.fraction ?? 0))
                            }
                        }
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Output

    private func outputRow(_ r: Reading) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "headphones")
                .font(.system(size: 10))
                .foregroundStyle(playing ? HeartTint.audio.color : .white.opacity(0.45))
            Text(r.value)
                .font(Theme.number(10.5))
                .foregroundStyle(.white.opacity(playing ? 0.72 : 0.5))
                .lineLimit(1)
            Spacer(minLength: 6)
            if playing {
                EqualizerBars()
            } else {
                Text("quiet")
                    .font(Theme.number(10))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }

    private var playing: Bool { mood == .tunedIn }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Check(label: "Desktop", isOn: $desktop.isVisible)
            Check(label: "Spooky", isOn: Binding(
                get: { personality.scaresEnabled },
                set: { personality.scaresEnabled = $0 }))
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(Theme.body(11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }
}

/// A checkbox that matches the panel rather than the system's blue one,
/// which looks wrong against the glass.
private struct Check: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isOn ? HeartTint.idle.color : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(isOn ? 0 : 0.22), lineWidth: 1)
                    )
                    .overlay {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.7))
                        }
                    }
                    .frame(width: 13, height: 13)
                Text(label)
                    .font(Theme.body(11))
                    .foregroundStyle(.white.opacity(isOn ? 0.72 : 0.45))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Four bars that dance while audio plays.
private struct EqualizerBars: View {
    @State private var phase: Double = 0
    private let heights: [Double] = [0.45, 1.0, 0.65, 0.85]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(HeartTint.audio.color)
                    .frame(width: 2,
                           height: 4 + 7 * abs(sin(phase + Double(i) * 0.7)) * heights[i])
            }
        }
        .frame(height: 11, alignment: .bottom)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(90))
                phase += 0.42
            }
        }
    }
}
