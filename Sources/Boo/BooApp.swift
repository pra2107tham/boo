import SwiftUI

@main
struct BooApp: App {
    /// UI-only build: cycle the moods by hand so every state can be seen
    /// without needing a hot CPU or a dying battery. Real signals land in
    /// the next PR.
    @State private var mood: Mood = .calm

    var body: some Scene {
        MenuBarExtra {
            Panel(mood: mood,
                  tint: sampleTint,
                  subtitle: sampleSubtitle,
                  readings: sampleReadings)
            Divider()
            // Temporary scaffolding — replaced by real readings in PR2.
            Picker("Preview mood", selection: $mood) {
                ForEach(Mood.allCases, id: \.self) { Text($0.headline).tag($0) }
            }
        } label: {
            Face(mood: mood, tint: sampleTint,
                 bodyColor: .primary, voidColor: .clear)
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }

    private var sampleTint: HeartTint {
        switch mood {
        case .tunedIn:  .audio
        case .strained: .hot
        case .working:  .busy
        case .sleepy:   .busy
        default:        .idle
        }
    }

    private var sampleSubtitle: String {
        switch mood {
        case .calm:     "barely doing anything"
        case .working:  "a few things running"
        case .strained: "Xcode is eating everything"
        case .tunedIn:  "AirPods Pro"
        case .sleepy:   "might want a charger soon"
        case .charged:  "plugged in and happy"
        }
    }

    private var sampleReadings: [Reading] {
        switch mood {
        case .strained:
            [.percent("Processor", 94), .percent("Memory", 88), .percent("Battery", 61),
             Reading(name: "Output", value: "MacBook Speakers", fraction: nil, tint: .clear)]
        case .sleepy:
            [.percent("Processor", 12), .percent("Memory", 41), .percent("Battery", 14),
             Reading(name: "Output", value: "MacBook Speakers", fraction: nil, tint: .clear)]
        default:
            [.percent("Processor", 18), .percent("Memory", 54), .percent("Battery", 82),
             Reading(name: "Output", value: "AirPods Pro", fraction: nil, tint: .clear)]
        }
    }
}
