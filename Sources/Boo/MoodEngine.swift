import Foundation

/// Turns a stream of snapshots into a mood, without flickering.
///
/// Two mechanisms stop the face twitching during a build:
///   1. Enter and leave thresholds differ (hysteresis) — 85% in, 75% out.
///   2. A state must hold for `dwell` before it's believed.
/// Without both, a face that flips every 2s would be unbearable.
final class MoodEngine {
    private(set) var mood: Mood = .calm

    /// Candidate the readings currently point at, and when it first appeared.
    private var pending: (mood: Mood, since: Date)?
    private let dwell: TimeInterval

    /// Strained is sticky once entered — this tracks that latch.
    private var wasStrained = false

    init(dwell: TimeInterval = 5) {
        self.dwell = dwell
    }

    /// Feed a snapshot; get the mood to draw. `now` is injectable for tests.
    @discardableResult
    func update(_ s: Snapshot, now: Date = Date()) -> Mood {
        let target = classify(s)

        if target == mood {
            pending = nil                      // already there, nothing to wait for
            return mood
        }
        if pending?.mood != target {
            pending = (target, now)            // new candidate, restart the clock
        }
        // Check immediately so a zero-dwell state (power changes) applies on
        // this very tick rather than waiting for the next one.
        if let p = pending, now.timeIntervalSince(p.since) >= dwellFor(target) {
            mood = target
            pending = nil
        }
        return mood
    }

    /// Power changes are physical and unambiguous, so they apply at once —
    /// waiting 5s to notice a plugged-in charger just feels broken.
    private func dwellFor(_ m: Mood) -> TimeInterval {
        switch m {
        case .charged, .sleepy, .tunedIn: 0
        default: dwell
        }
    }

    /// Highest-priority matching state wins, per the spec's table.
    private func classify(_ s: Snapshot) -> Mood {
        if s.isCharging { wasStrained = false; return .charged }
        if let b = s.battery, b <= 20 { wasStrained = false; return .sleepy }

        // Hysteresis: needs 85 to enter, but stays until it drops below 75.
        if s.cpu >= 85 { wasStrained = true }
        else if s.cpu < 75 { wasStrained = false }
        if wasStrained { return .strained }

        // Sound actually playing is what matters, not the device type.
        // Speakers playing music count; silent headphones do not.
        if s.isPlayingAudio { return .tunedIn }
        if s.cpu >= 30 { return .working }
        return .calm
    }

    /// Heart tint is a separate axis from mood: audio overrides, then load.
    static func tint(for s: Snapshot) -> HeartTint {
        if s.isPlayingAudio { return .audio }
        if s.cpu >= 85 { return .hot }
        if s.cpu >= 30 { return .busy }
        return .idle
    }

    /// Beat interval in seconds — 4s when idle, 0.4s when pegged.
    static func beatInterval(cpu: Double) -> Double {
        let t = min(max(cpu, 0), 100) / 100
        return 4 - (t * 3.6)
    }
}
