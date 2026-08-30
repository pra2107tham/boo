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
    case swooping      // flying over to nag you about focus
    case peeking       // hiding at a screen edge, one eye out
    case spinning      // a happy little barrel roll
    case yawning       // stretching, mid-idle
    case wobbling      // jelly wobble in place
    case sneezing      // tiny sneeze, recoil
    case bouncing      // hopping up and down
    case stargazing    // drifting upward, looking up
    case orbiting      // tiny, doing laps around the cursor
    case scratchpad    // bubbles out, waiting for a note
}

/// The things Boo does on its own when nothing else is happening.
/// Picked at random so the idle loop never feels like a repeating cycle.
enum Idle: CaseIterable {
    case spin, yawn, wobble, sneeze, bounce, stargaze, lookAround, hiccup

    var act: Act {
        switch self {
        case .spin:       .spinning
        case .yawn:       .yawning
        case .wobble:     .wobbling
        case .sneeze:     .sneezing
        case .bounce:     .bouncing
        case .stargaze:   .stargazing
        case .lookAround: .none
        case .hiccup:     .wobbling
        }
    }

    var duration: Double {
        switch self {
        case .spin: 0.9
        case .yawn: 1.8
        case .wobble: 1.1
        case .sneeze: 0.8
        case .bounce: 1.4
        case .stargaze: 2.4
        case .lookAround: 2.0
        case .hiccup: 0.5
        }
    }
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
    /// Lean angle while being dragged, degrees.
    @Published private(set) var dragTilt: Double = 0
    /// 0 = no door, 1 = door fully there. Drives the thing Boo hides behind.
    @Published private(set) var doorOpen: CGFloat = 0
    /// How far Boo has ducked behind the door edge.
    @Published private(set) var peekSlide: CGFloat = 0
    /// Which side the door is on, so the visible eye is the far one.
    @Published private(set) var peekFromLeft = false
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
    private var swoopTimer: Timer?
    private var orbitTimer: Timer?
    private var idleTimer2: Timer?

    /// What Boo says when it swoops over. Short, ghostly, never bossy.
    static let focusLines = [
        "ssshhh… focus", "oi. eyes here", "boo believes in you",
        "still with me?", "one more push", "sssfocus",
        "you got this", "back to it, friend", "ssshh… almost there",
    ]
    /// The line currently being said, if any.
    @Published private(set) var speech: String?
    /// Where Boo is flying to, in screen points. nil when it is home.
    @Published private(set) var swoopTarget: CGPoint?
    @Published private(set) var spin: Double = 0
    @Published private(set) var stretch: CGFloat = 1
    /// 1 is full size, 0.28 is cursor-sized. Drives the shrink for orbiting.
    @Published private(set) var scale: CGFloat = 1
    /// Angle around the cursor while orbiting, in radians.
    @Published private(set) var orbitAngle: Double = 0
    /// Trail of recent positions, so the lap leaves a comet tail.
    @Published private(set) var trail: [CGPoint] = []

    init() {
        startCursorTracking()
        startIdleWatch()
        if scaresEnabled { scheduleScare() }
        scheduleSwoop()
        scheduleIdleAntic()
    }

    // MARK: - The focus swoop

    /// Off by default is wrong here — you asked for it — but it is still
    /// respectful: it never fires while you are away, and never over a
    /// fullscreen app you might be presenting from.
    var swoopEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "booSwoopEnabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "booSwoopEnabled")
            newValue ? scheduleSwoop() : swoopTimer?.invalidate()
            objectWillChange.send()
        }
    }

    private func scheduleSwoop() {
        swoopTimer?.invalidate()
        guard swoopEnabled else { return }
        swoopTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) {
            [weak self] _ in
            guard let me = self else { return }
            Task { @MainActor in me.swoop() }
        }
    }

    /// Shrink to cursor size, fly over, do a few laps, and go home.
    ///
    /// The laps are the point: a straight there-and-back reads as a
    /// notification, but circling reads as a creature that came to see you.
    func orbitCursor(laps: Int = 3) {
        // Interrupt whatever it was doing. Requiring an idle Boo meant that
        // after a heart shower the lap silently did nothing.
        guard act != .squashed, act != .orbiting else { return }
        actResetTask?.cancel()
        orbitTimer?.invalidate()
        act = .orbiting
        trail = []

        // Shrink first so the flight over is already cursor-sized.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { scale = 0.28 }

        let start = Date()
        let lapDuration = 0.85
        let total = lapDuration * Double(laps)

        orbitTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) {
            [weak self] t in
            guard let me = self else { t.invalidate(); return }
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(start)
                guard elapsed < total else {
                    t.invalidate()
                    me.endOrbit()
                    return
                }
                // Ease the radius in and out so it spirals in, circles,
                // then spirals out rather than snapping to a fixed ring.
                let progress = elapsed / total
                let envelope = sin(progress * .pi)              // 0 -> 1 -> 0
                let radius = 26 + 24 * envelope
                me.orbitAngle = elapsed / lapDuration * 2 * .pi

                let mouse = NSEvent.mouseLocation
                let point = CGPoint(
                    x: mouse.x + cos(me.orbitAngle) * radius,
                    y: mouse.y + sin(me.orbitAngle) * radius)
                me.swoopTarget = point

                // Keep a short tail of where it has been.
                me.trail.append(point)
                if me.trail.count > 14 { me.trail.removeFirst() }

                // Look where it is going, not where it came from.
                me.lookX = CGFloat(cos(me.orbitAngle + .pi / 2))
                me.lookY = CGFloat(-sin(me.orbitAngle + .pi / 2))
            }
        }
    }

    private func endOrbit() {
        withAnimation(.easeOut(duration: 0.3)) {
            trail = []
            lookX = 0
            lookY = 0
        }
        swoopTarget = nil                       // drift home
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { scale = 1 }
        actResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            if act == .orbiting { act = .none }
        }
    }

    /// Fly to the cursor, say something, fly home.
    func swoop() {
        // Automatic swoops still wait for a quiet moment — a pet that talks
        // over you is one you turn off. Manual ones come through the menu
        // and interrupt, since you just asked for it.
        guard swoopEnabled, act != .squashed, act != .orbiting else { return }
        guard Date().timeIntervalSince(lastUserActivity) < 120 else { return }

        let mouse = NSEvent.mouseLocation
        actResetTask?.cancel()
        act = .swooping
        // Land a little above-left of the pointer so it never covers what
        // you are actually looking at.
        swoopTarget = CGPoint(x: mouse.x - 70, y: mouse.y + 50)
        speech = Self.focusLines.randomElement()
        // A quick shrink on approach, back to size once it has landed.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { scale = 0.6 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { scale = 1 }
        }

        actResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { speech = nil }
            swoopTarget = nil          // drift home
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            if act == .swooping { act = .none }
        }
    }

    // MARK: - Idle antics

    /// Something small every 25-70 seconds so it is never quite still.
    private func scheduleIdleAntic() {
        idleTimer2?.invalidate()
        let delay = Double.random(in: 25...70)
        idleTimer2 = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            guard let me = self else { return }
            Task { @MainActor in
                me.performIdleAntic()
                me.scheduleIdleAntic()
            }
        }
    }

    private func performIdleAntic() {
        guard act == .none else { return }
        guard let antic = Idle.allCases.randomElement() else { return }

        switch antic {
        case .spin:
            act = .spinning
            withAnimation(.easeInOut(duration: 0.9)) { spin += 360 }
        case .yawn:
            act = .yawning
            withAnimation(.easeInOut(duration: 0.6)) { stretch = 1.12 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.5)) { stretch = 1 }
            }
        case .wobble, .hiccup:
            act = .wobbling
        case .sneeze:
            act = .sneezing
            emit(.sweat, count: 3)
        case .bounce:
            act = .bouncing
        case .stargaze:
            act = .stargazing
            emit(.star, count: 2)
        case .lookAround:
            // A deliberate look left, then right, then back.
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.45)) { self.lookX = -1 }
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 0.6)) { self.lookX = 1 }
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 0.45)) { self.lookX = 0 }
            }
        }

        let reset = antic.duration
        actResetTask?.cancel()
        actResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(reset))
            guard !Task.isCancelled else { return }
            if self.act == antic.act { self.act = .none }
        }
    }

    // No deinit teardown: timers cannot be touched from a nonisolated
    // deinit, and these objects live for the whole app run - the timers
    // die with the process. stop() handles the only real teardown case.

    /// Scares land somewhere between 20 and 50 minutes apart, and never
    /// while you're away — startling an empty chair is pointless, and
    /// startling someone mid-sentence is just rude.
    private func scheduleScare() {
        scareTimer?.invalidate()
        let delay = Double.random(in: 1200...3000)
        scareTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            guard let me = self else { return }
            Task { @MainActor in
                guard me.scaresEnabled else { return }
                if me.act == .none { me.peek() }
                me.scheduleScare()
            }
        }
    }

    // MARK: - Cursor peeking

    /// Boo watches your pointer. This is the single biggest "it's alive"
    /// signal — eyes that follow you read as attention, not animation.
    private func startCursorTracking() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) {
            [weak self] _ in
            guard let me = self else { return }
            Task { @MainActor in me.trackCursor() }
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
            guard let me = self else { return }
            Task { @MainActor in
                if Date().timeIntervalSince(me.lastUserActivity) > me.sleepAfter {
                    if me.act != .sleeping { me.act = .sleeping }
                } else if me.act == .sleeping {
                    me.wake()
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
    /// Click for hearts. Re-clicking must always work: it retriggers
    /// rather than being swallowed by the act still running from last time.
    func showerHearts() {
        noteActivity()
        // Short lock. 1.6s meant a double-click's second half, and any
        // follow-up action, hit a Boo that was still "doing hearts".
        set(.hearts, for: 0.7)
        emit(.heart, count: 10)
    }

    /// Rare, deliberately startling, then immediately apologetic.
    /// Peek out from behind the nearest screen edge, then duck back.
    ///
    /// Replaces the old jump scare. A scare is startling once and irritating
    /// every time after, and it fired while you were concentrating — the
    /// worst possible moment. Peeking is the same mischief without the
    /// adrenaline: it slides mostly off-screen, shows one eye, and hides.
    func peek() {
        guard act != .squashed, act != .orbiting else { return }
        noteActivity()
        actResetTask?.cancel()
        act = .peeking
        // A door appears beside Boo and it ducks behind it. The sliding was
        // never the problem — there was simply nothing to hide BEHIND, so
        // it read as a ghost drifting off into empty space.
        peekFromLeft = Bool.random()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
            doorOpen = 1
        }
        actResetTask = Task { @MainActor in
            // Door swings in, then Boo slips behind its edge.
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                peekSlide = peekFromLeft ? 38 : -38
            }
            try? await Task.sleep(for: .milliseconds(1700))
            guard !Task.isCancelled else { return }
            // Back out, then the door closes behind it.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) { peekSlide = 0 }
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { doorOpen = 0 }
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            if act == .peeking { act = .none }
        }
    }


    /// Kept so the menu item and any existing callers still work.
    func scare() { peek() }

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
        orbitTimer?.invalidate()
        act = .squashed
        // Picked up: it compresses like something being gripped.
        withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) { squash = 0.88 }
    }

    /// Lean into the direction of travel, so fast drags stretch and tilt.
    func dragging(velocity: CGSize) {
        let speed = min(hypot(velocity.width, velocity.height), 2400)
        // Stretch along the direction of motion — the classic squash-and-
        // stretch that makes moving objects read as having mass.
        let stretchAmount = 1 + (speed / 2400) * 0.22
        let tilt = max(-16, min(16, -velocity.width / 55))
        withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.7)) {
            squash = 1 / stretchAmount
            dragTilt = tilt
        }
    }

    func endDrag(velocity: CGSize = .zero) {
        act = .none
        // Let go: overshoot, wobble, settle. Faster throws wobble harder.
        let speed = min(hypot(velocity.width, velocity.height), 2400)
        let damping = 0.34 + (1 - speed / 2400) * 0.24
        withAnimation(.spring(response: 0.52, dampingFraction: damping)) {
            squash = 1
            dragTilt = 0
        }
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
            guard let me = self else { return }
            Task { @MainActor in
                guard me.act == .dancing else { return }
                // A slow sway, roughly two seconds a cycle.
                me.danceAngle = sin(Date().timeIntervalSince1970 * 3) * 9
                // Occasional music notes drifting off.
                if Int.random(in: 0..<40) == 0 { me.emit(.note, count: 1) }
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

    /// Hard ceiling on live particles. Without it, clicking repeatedly
    /// piles them up unbounded — the swarm grows, the 30fps step loop gets
    /// slower every click, and the whole thing bogs down.
    private static let maxParticles = 40

    func emit(_ kind: Particle.Kind, count: Int) {
        // Drop the oldest rather than refusing new ones, so a fresh click
        // always produces a visible burst.
        let room = Self.maxParticles - particles.count
        if room < count {
            particles.removeFirst(min(particles.count, count - max(room, 0)))
        }
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
            guard let me = self else { return }
            Task { @MainActor in me.stepParticles() }
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
