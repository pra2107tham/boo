import SwiftUI

/// One metric row. `nil` fraction means "no bar" — used for the audio row,
/// which is a name rather than a percentage.
struct Reading: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let fraction: Double?
    let tint: Color

    static func percent(_ name: String, _ pct: Double) -> Reading {
        Reading(name: name, value: "\(Int(pct.rounded()))%", fraction: pct / 100,
                tint: pct >= 85 ? HeartTint.hot.color
                    : pct >= 60 ? HeartTint.busy.color
                    : HeartTint.idle.color)
    }
}

/// What you get when you click Boo: the face big, a sentence, four rows.
/// Deliberately not a dashboard — no graphs, no history, no process list.
struct Panel: View {
    let mood: Mood
    let tint: HeartTint
    let subtitle: String
    let readings: [Reading]
    @ObservedObject var desktop: DesktopBoo

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 11) {
                Face(mood: mood, tint: tint)
                    .frame(width: 84, height: 84)
                VStack(spacing: 3) {
                    Text(mood.headline)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)

            Divider()

            ForEach(readings) { r in
                HStack(spacing: 12) {
                    Text(r.name)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if let f = r.fraction {
                        Capsule()
                            .fill(.quaternary)
                            .frame(width: 62, height: 4)
                            .overlay(alignment: .leading) {
                                Capsule().fill(r.tint).frame(width: 62 * f, height: 4)
                            }
                    }
                    Text(r.value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: r.fraction == nil ? nil : 38, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                if r.id != readings.last?.id { Divider().padding(.leading, 18) }
            }

            Divider()

            HStack {
                Toggle("On desktop", isOn: $desktop.isVisible)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(width: 268)
    }
}
