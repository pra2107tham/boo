import SwiftUI
import AppKit

/// Momentary things Boo does that aren't tied to system state.
///
/// Separate from `Mood` on purpose: mood is a steady description of the
/// machine, an act is a brief performance on top of it. Acts always end
/// and hand control back.
enum Act: Equatable {
    case none
    case hearts        // showering little hearts
    case scared        // jump scare: huge eyes, then giggling
    case giggling      // the recovery half of a scare
    case dancing       // music is playing
    case sleeping      // you've been away a while
    case petted        // held the cursor on it
    case squashed      // being dragged
    case celebrating   // a long build just finished
}

/// One floating heart in the shower.
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: Double = 1
    var scale: CGFloat
    var kind: Kind

    enum Kind { case heart, star, note, sweat }
}

/// Drives everything that makes Boo feel like a creature rather than a gauge.
@MainActor
final class Personality: ObservableObject {
    @Published private(set) var act: Act = .none
    @Published private(set) var particles: [Particle] = []
    /// Where Boo is looking, in the -1…1 range Face expects.
    @Published private(set) var lookX: CGFloat = 0
    @Published private(set) var lookY: CGFloat = 0
    /// Drag squash: 1 is round, below 1 is squashed flat.
    @Published private(set) var squash: CGFloat = 1
    @Published private(set) var danceAngle: CGFloat = 0

    /// Set by the desktop window so cursor tracking knows where Boo is.
    var screenPosition: CGPoint = .zero
    /// Only the desktop Boo tracks the cursor; the menu bar one can't see it.
    var tracksCursor = false

    private var particleTimer: Timer?
    private var cursorTimer: Timer?
    private var idleTimer: Timer?
    private var danceTimer: Timer?
    private var lastUserActivity = Date()
    private var actResetTask: Task<Void, Never>?

    /// How long you must be away before Boo dozes off.
    private let sleepAfter: TimeInterval = 300

    /// Off by default. A ghost that jump-scares you unasked is a ghost you
    /// uninstall, so this is opt-in and rate-limited even when enabled.
    var scaresEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "booScaresEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "booScaresEnabled")
            newValue ? scheduleScare() : scareTimer?.invalidate()
            objectWillChange.send()
        }
    }

    private var scareTimer: Timer?

    init() {
        startCursorTracking()
        startIdleWatch()
        if scaresEnabled { scheduleScare() }
    }

    deinit {
        particleTimer?.invalidate()
        cursorTimer?.invalidate()
        idleTimer?.invalidate()
        danceTimer?.invalidate()
        scareTimer?.invalidate()
    }

    /// Scares land somewhere between 20 and 50 minutes apart, and never
    /// while you're away — startling an empty chair is pointless, and
    /// startling someone mid-sentence is just rude.
    private func scheduleScare() {
        scareTimer?.invalidate()
        let delay = Double.random(in: 1200...3000)
        scareTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.scaresEnabled else { return }
                if self.act == .none { self.scare() }
                self.scheduleScare()
            }
        }
    }

    // MARK: - Cursor peeking

    /// Boo watches your pointer. This is the single biggest "it's alive"
    /// signal — eyes that follow you read as attention, not animation.
    private func startCursorTracking() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.trackCursor() }
        }
    }

    private func trackCursor() {
        guard tracksCursor, act != .sleeping else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - screenPosition.x
        let dy = mouse.y - screenPosition.y

        // Saturate at ~220pt: past that it's "over there" and the eyes
        // shouldn't keep straining further.
        let reach: CGFloat = 220
        let nx = max(-1, min(1, dx / reach))
        // Screen y grows upward, the drawing's y grows downward.
        let ny = max(-1, min(1, -dy / reach))

        // Ease toward the target so the eyes glide instead of snapping.
        lookX += (nx - lookX) * 0.25
        lookY += (ny - lookY) * 0.25

        if hypot(dx, dy) < 400 { noteActivity() }
    }

    // MARK: - Idle and sleep

    private func startIdleWatch() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if Date().timeIntervalSince(self.lastUserActivity) > self.sleepAfter {
                    if self.act != .sleeping { self.act = .sleeping }
                } else if self.act == .sleeping {
                    self.wake()
                }
            }
        }
    }

    /// Called whenever you do something near Boo. Wakes it if it was asleep.
    func noteActivity() {
        lastUserActivity = Date()
        if act == .sleeping { wake() }
    }

    private func wake() {
        act = .none
        // A startled little shake on waking, then back to normal.
        emit(.star, count: 3)
    }

    // MARK: - Acts

    /// Click: a shower of hearts. The one everyone tries first.
    func showerHearts() {
        noteActivity()
        set(.hearts, for: 1.6)
        emit(.heart, count: 12)
    }

    /// Rare, deliberately startling, then immediately apologetic.
    func scare() {
        noteActivity()
        act = .scared
        actResetTask?.cancel()
        actResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            act = .giggling          // it laughs at you afterwards
            emit(.star, count: 6)
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            act = .none
        }
    }

    /// Hovering long enough reads as petting.
    func pet() {
        noteActivity()
        guard act == .none || act == .dancing else { return }
        set(.petted, for: 2.0)
        emit(.heart, count: 4)
    }

    /// A long build finishing deserves acknowledgement.
    func celebrate() {
        noteActivity()
        set(.celebrating, for: 2.5)
        emit(.star, count: 10)
    }

    func beginDrag() {
        noteActivity()
        actResetTask?.cancel()
        act = .squashed
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { squash = 0.82 }
    }

    func endDrag() {
        act = .none
        // Overshoot then settle — a bit of weight on landing.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) { squash = 1 }
    }

    /// Music started or stopped.
    func setDancing(_ dancing: Bool) {
        if dancing {
            guard act == .none else { return }
            act = .dancing
            startDanceClock()
        } else if act == .dancing {
            act = .none
            danceTimer?.invalidate(); danceTimer = nil
            withAnimation(.easeOut(duration: 0.3)) { danceAngle = 0 }
        }
    }

    private func startDanceClock() {
        danceTimer?.invalidate()
        danceTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.act == .dancing else { return }
                // A slow sway, roughly two seconds a cycle.
                self.danceAngle = sin(Date().timeIntervalSince1970 * 3) * 9
                // Occasional music notes drifting off.
                if Int.random(in: 0..<40) == 0 { self.emit(.note, count: 1) }
            }
        }
    }

    private func set(_ a: Act, for seconds: Double) {
        actResetTask?.cancel()
        act = a
        actResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, self.act == a else { return }
            self.act = .none
        }
    }

    // MARK: - Particles

    func emit(_ kind: Particle.Kind, count: Int) {
        for _ in 0..<count {
            particles.append(Particle(
                x: CGFloat.random(in: -18...18),
                y: CGFloat.random(in: -6...10),
                vx: CGFloat.random(in: -0.7...0.7),
                vy: CGFloat.random(in: -2.4 ... -1.2),
                scale: CGFloat.random(in: 0.6...1.15),
                kind: kind))
        }
        startParticleClock()
    }

    private func startParticleClock() {
        guard particleTimer == nil else { return }
        particleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.stepParticles() }
        }
    }

    /// Exposed for the self-check so particle decay can be driven without
    /// waiting on a real timer.
    func stepParticlesForTesting() { stepParticles() }

    private func stepParticles() {
        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy += 0.045          // gentle gravity, so they arc
            particles[i].vx *= 0.99
            particles[i].life -= 0.022
        }
        particles.removeAll { $0.life <= 0 }

        // Stop the clock when there's nothing to move — no idle timer burn.
        if particles.isEmpty {
            particleTimer?.invalidate()
            particleTimer = nil
        }
    }
}
