import Foundation
import AppKit
import IOKit

/// What you are doing, and what the machine is doing about it.
///
/// Everything here is a public API needing no permission. Notably the typing
/// signal reports only *when* a key was last pressed — never which one — so
/// Boo cannot read what you type, by construction rather than by promise.
struct Activity {
    /// Keystrokes seen in the last sampling window.
    private var recentKeys: [Date] = []
    private var lastKeyTime: TimeInterval = .greatestFiniteMagnitude

    struct Reading {
        var isTyping = false
        /// 0…1, how hard you are going. Drives how fast the hands move.
        var typingIntensity: Double = 0
        /// Seconds since the last keystroke.
        var idleSeconds: Double = 0
        /// Free space on the boot volume, in GB. nil when it can't be read.
        var freeDiskGB: Double?
        /// True when the machine is working hard enough to spin fans up.
        var fansLikelySpinning = false
        /// Seconds the Mac has been up.
        var uptime: TimeInterval = 0
    }

    mutating func read(cpu: Double, now: Date = Date()) -> Reading {
        var r = Reading()

        // secondsSinceLastEventType tells us WHEN, never WHAT. No
        // accessibility permission, no key contents, ever.
        let since = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .keyDown)
        r.idleSeconds = since

        // A falling value means a key was pressed since the last sample.
        if since < lastKeyTime { recentKeys.append(now) }
        lastKeyTime = since

        // Keep a 4-second window and judge intensity from its density.
        recentKeys.removeAll { now.timeIntervalSince($0) > 4 }
        // Enter on 3 keys in 2s, leave after 4s of silence, matching the
        // design's thresholds.
        let recentCount = recentKeys.filter { now.timeIntervalSince($0) <= 2 }.count
        r.isTyping = recentCount >= 3 || (since < 4 && recentKeys.count >= 3)
        // ~8 keys in 4s is a brisk pace; cap there so the hands do not blur.
        r.typingIntensity = min(1, Double(recentKeys.count) / 8)

        r.freeDiskGB = Self.freeDiskGB()
        // No public API reports fan RPM on Apple Silicon, so sustained heavy
        // load is the honest proxy — say so rather than pretending to sense.
        r.fansLikelySpinning = cpu >= 80
        r.uptime = ProcessInfo.processInfo.systemUptime
        return r
    }

    private static func freeDiskGB() -> Double? {
        guard let values = try? URL(fileURLWithPath: "/")
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return Double(bytes) / 1_073_741_824
    }
}
