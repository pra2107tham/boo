import SwiftUI

/// Owns the polling loop, the mood, and the animation clock.
@MainActor
final class BooState: ObservableObject {
    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var mood: Mood = .calm

    let animator = Animator()

    private let metrics = SystemMetrics()
    private let engine = MoodEngine()
    private var timer: Timer?

    init() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        observePowerAndSleep()
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let s = metrics.read()
        snapshot = s
        mood = engine.update(s)
        animator.beatInterval = MoodEngine.beatInterval(cpu: s.cpu)

        // Stop animating on low battery. The face still updates; it just
        // stops costing anything to look at.
        if let b = s.battery, b <= 20, !s.isCharging {
            animator.animating = false
        } else if !animator.animating {
            animator.animating = true
        }
    }

    /// Freeze while the display is asleep — nobody is looking, and waking
    /// the GPU 20 times a second for an invisible ghost is indefensible.
    private func observePowerAndSleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.animator.animating = false }
        }
        center.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.animator.animating = true }
        }
    }

    var tint: HeartTint { MoodEngine.tint(for: snapshot) }

    var subtitle: String {
        switch mood {
        case .calm:     "barely doing anything"
        case .working:
            if let p = snapshot.busiestProcess { "\(p) is busy" } else { "a few things running" }
        case .strained:
            if let p = snapshot.busiestProcess { "\(p) is eating everything" }
            else { "something is working hard" }
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
    @StateObject private var state: BooState
    @StateObject private var desktop: DesktopBoo

    init() {
        if CommandLine.arguments.contains("--self-check") { SelfCheck.run() }
        // DesktopBoo needs the state it renders, so both are built here and
        // the same instance is handed to the panel and the floating window.
        let s = BooState()
        _state = StateObject(wrappedValue: s)
        _desktop = StateObject(wrappedValue: DesktopBoo(state: s))
    }

    var body: some Scene {
        MenuBarExtra {
            Panel(mood: state.mood,
                  tint: state.tint,
                  subtitle: state.subtitle,
                  readings: state.readings,
                  desktop: desktop)
        } label: {
            MenuBarFace(mood: state.mood, tint: state.tint, animator: state.animator)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Separate view so it observes the animator itself — the App struct is not
/// re-evaluated often enough to drive 20fps motion.
private struct MenuBarFace: View {
    let mood: Mood
    let tint: HeartTint
    @ObservedObject var animator: Animator

    var body: some View {
        Face(mood: mood,
             tint: tint,
             blinking: animator.blinking,
             gaze: animator.gaze,
             heartScale: animator.heartScale,
             bodyColor: .primary,
             punchThrough: true)
            .frame(width: 18, height: 18)
            .offset(y: animator.float)
    }
}
