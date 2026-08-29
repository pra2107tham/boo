import SwiftUI

/// Owns the polling loop and the current mood. One timer, one snapshot,
/// no reactive machinery — this ticks every 2s for as long as the Mac is on.
@MainActor
final class BooState: ObservableObject {
    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var mood: Mood = .calm

    private let metrics = SystemMetrics()
    private let engine = MoodEngine()
    private var timer: Timer?

    init() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let s = metrics.read()
        snapshot = s
        mood = engine.update(s)
    }

    var tint: HeartTint { MoodEngine.tint(for: snapshot) }

    var subtitle: String {
        switch mood {
        case .calm:     "barely doing anything"
        case .working:  "a few things running"
        case .strained: "something is working hard"
        case .tunedIn:  snapshot.outputDevice
        case .sleepy:   "might want a charger soon"
        case .charged:  "plugged in and happy"
        }
    }

    var readings: [Reading] {
        var rows: [Reading] = [
            .percent("Processor", snapshot.cpu),
            .percent("Memory", snapshot.memory)
        ]
        if let b = snapshot.battery {
            rows.append(.percent("Battery", b))
        }
        rows.append(Reading(name: "Output", value: snapshot.outputDevice,
                            fraction: nil, tint: .clear))
        return rows
    }
}

@main
struct BooApp: App {
    @StateObject private var state = BooState()

    init() {
        if CommandLine.arguments.contains("--self-check") { SelfCheck.run() }
    }

    var body: some Scene {
        MenuBarExtra {
            Panel(mood: state.mood,
                  tint: state.tint,
                  subtitle: state.subtitle,
                  readings: state.readings)
        } label: {
            Face(mood: state.mood, tint: state.tint,
                 bodyColor: .primary, voidColor: .clear)
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}
