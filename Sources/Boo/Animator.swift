import SwiftUI

/// Drives the small involuntary movements that make Boo read as alive
/// rather than as an icon that changes.
///
/// All of it stops when the display sleeps or the Mac is low on battery —
/// a menu bar pet that drains your battery is a bad joke.
@MainActor
final class Animator: ObservableObject {
    @Published private(set) var blinking = false
    @Published private(set) var gaze: CGFloat = 0
    @Published private(set) var heartScale: CGFloat = 1
    @Published private(set) var float: CGFloat = 0

    /// Beat interval follows CPU: 4s idle, 0.4s pegged.
    var beatInterval: Double = 4 {
        didSet {
            guard abs(beatInterval - oldValue) > 0.05 else { return }
            restartHeart()
        }
    }

    /// Set false to freeze everything (display asleep, battery saver).
    var animating = true {
        didSet {
            guard animating != oldValue else { return }
            animating ? start() : stop()
        }
    }

    private var blinkTimer: Timer?
    private var heartTimer: Timer?
    private var floatTimer: Timer?

    init() { start() }
    deinit {
        blinkTimer?.invalidate()
        heartTimer?.invalidate()
        floatTimer?.invalidate()
    }

    private func start() {
        scheduleBlink()
        restartHeart()
        // Idle float: a slow sine, ±0.5px. Small enough to feel like
        // breathing rather than motion you consciously notice.
        floatTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.float = sin(Date().timeIntervalSince1970 / 3 * .pi * 2) * 0.5
            }
        }
    }

    private func stop() {
        blinkTimer?.invalidate(); blinkTimer = nil
        heartTimer?.invalidate(); heartTimer = nil
        floatTimer?.invalidate(); floatTimer = nil
        blinking = false
        gaze = 0
        heartScale = 1
        float = 0
    }

    // MARK: - Blinking and glancing

    /// Blinks land every 4–7s. Roughly one in four also glances aside,
    /// which is what stops the idle loop feeling metronomic.
    private func scheduleBlink() {
        let delay = Double.random(in: 4...7)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.animating else { return }
                self.blink()
                self.scheduleBlink()
            }
        }
    }

    private func blink() {
        blinking = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            blinking = false

            guard Int.random(in: 0..<4) == 0 else { return }
            // Glance: look aside, hold, come back.
            withAnimation(.easeOut(duration: 0.18)) {
                gaze = Bool.random() ? -1 : 1
            }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.18)) { gaze = 0 }
        }
    }

    // MARK: - Heartbeat

    private func restartHeart() {
        heartTimer?.invalidate()
        guard animating else { return }
        heartTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.beat() }
        }
    }

    private func beat() {
        withAnimation(.easeOut(duration: 0.12)) { heartScale = 1.15 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.18)) { heartScale = 1 }
        }
    }
}
