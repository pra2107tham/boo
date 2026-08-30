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

        // The old version counted at most ONE keystroke per poll, and polls
        // are 2s apart — so "3 keys within 2 seconds" could never be
        // satisfied no matter how fast you typed. It was impossible by
        // construction, not merely strict.
        //
        // The idle timer is the whole signal: if it is low, a key was
        // pressed recently. That is all "is typing" needs to mean.
        lastKeyTime = since

        r.isTyping = Self.isTyping(idle: since)
        r.typingIntensity = Self.intensity(idle: since)

        r.freeDiskGB = Self.freeDiskGB()
        // No public API reports fan RPM on Apple Silicon, so sustained heavy
        // load is the honest proxy — say so rather than pretending to sense.
        r.fansLikelySpinning = cpu >= 80
        r.uptime = ProcessInfo.processInfo.systemUptime
        return r
    }

    /// Typing = a key pressed in the last couple of seconds.
    ///
    /// Exposed so the threshold is testable without a human at the
    /// keyboard — the previous version needed 3 keystrokes inside a 2s
    /// window while only ever sampling once per 2s poll, which no amount
    /// of fast typing could satisfy.
    static func isTyping(idle: Double) -> Bool { idle < 2.5 }

    /// Hot right after a keystroke, cooling toward zero as you pause.
    static func intensity(idle: Double) -> Double {
        max(0, min(1, (2.5 - idle) / 2.5))
    }

    private static func freeDiskGB() -> Double? {
        guard let values = try? URL(fileURLWithPath: "/")
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return Double(bytes) / 1_073_741_824
    }
}
